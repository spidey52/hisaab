import type { PoolClient } from "pg";
import { withTransaction } from ".";
import { normalizeOptionalPhone } from "../lib/phone-normalization";

type Migration = {
  version: number;
  name: string;
  statements: readonly string[];
  run?: (client: PoolClient) => Promise<void>;
};

const migrations: readonly Migration[] = [
  {
    version: 1,
    name: "offline_sync_foundations",
    statements: [
      `ALTER TABLE users
       ADD COLUMN IF NOT EXISTS contact_discoverable BOOLEAN NOT NULL DEFAULT FALSE`,
      `ALTER TABLE users
       ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1`,
      `ALTER TABLE companies
       ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1`,
      `ALTER TABLE parties
       ADD COLUMN IF NOT EXISTS phone_e164 TEXT`,
      `ALTER TABLE parties
       ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1`,
      `ALTER TABLE party_groups
       ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP`,
      `ALTER TABLE party_groups
       ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1`,
      `ALTER TABLE entries
       ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP`,
      `ALTER TABLE entries
       ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1`,
      `UPDATE entries
       SET updated_at = GREATEST(
         created_at,
         COALESCE(edited_at, created_at),
         COALESCE(cancelled_at, created_at)
       )`,
      `CREATE TABLE IF NOT EXISTS operation_receipts (
        company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
        operation_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        request_hash TEXT NOT NULL,
        response_body JSONB NOT NULL,
        status_code INTEGER NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (company_id, operation_id)
      )`,
      `CREATE TABLE IF NOT EXISTS sync_changes (
        id BIGSERIAL PRIMARY KEY,
        company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        change_type TEXT NOT NULL CHECK(change_type IN ('upsert', 'tombstone')),
        entity_version BIGINT NOT NULL,
        payload JSONB NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      )`,
      `CREATE TABLE IF NOT EXISTS contact_discovery_usage (
        user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        window_start TIMESTAMPTZ NOT NULL,
        request_count INTEGER NOT NULL DEFAULT 0,
        phone_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, window_start)
      )`,
      `CREATE INDEX IF NOT EXISTS parties_company_phone_e164_idx
       ON parties(company_id, phone_e164)
       WHERE phone_e164 IS NOT NULL`,
      `CREATE INDEX IF NOT EXISTS sync_changes_company_id_idx
       ON sync_changes(company_id, id)`,
      `CREATE INDEX IF NOT EXISTS sync_changes_entity_idx
       ON sync_changes(company_id, entity_type, entity_id, id)`,
      `CREATE INDEX IF NOT EXISTS operation_receipts_created_idx
       ON operation_receipts(created_at)`,
      `CREATE INDEX IF NOT EXISTS contact_discovery_usage_window_idx
       ON contact_discovery_usage(window_start)`,
      `INSERT INTO audit_events (
         id, company_id, actor_user_id, entity_type, entity_id, action,
         details, created_at
       )
       SELECT
         'migration-opening-' || id,
         company_id,
         created_by,
         'entry',
         id,
         'duplicate_opening_balance_cancelled',
         jsonb_build_object('sequence', sequence),
         CURRENT_TIMESTAMP
       FROM (
         SELECT
           id, company_id, created_by, sequence,
           ROW_NUMBER() OVER (
             PARTITION BY company_id, party_id
             ORDER BY sequence, created_at, id
           ) AS position
         FROM entries
         WHERE action = 'opening_balance' AND status = 'posted'
       ) duplicate_openings
       WHERE position > 1
       ON CONFLICT DO NOTHING`,
      `WITH duplicate_openings AS (
         SELECT id
         FROM (
           SELECT
             id,
             ROW_NUMBER() OVER (
               PARTITION BY company_id, party_id
               ORDER BY sequence, created_at, id
             ) AS position
           FROM entries
           WHERE action = 'opening_balance' AND status = 'posted'
         ) ranked
         WHERE position > 1
       )
       UPDATE entries
       SET
         status = 'cancelled',
         cancelled_by = COALESCE(cancelled_by, created_by),
         cancelled_at = COALESCE(cancelled_at, CURRENT_TIMESTAMP),
         updated_at = CURRENT_TIMESTAMP,
         version = version + 1
       WHERE id IN (SELECT id FROM duplicate_openings)`,
      `CREATE UNIQUE INDEX IF NOT EXISTS entries_one_active_opening_balance_uq
       ON entries(company_id, party_id)
       WHERE action = 'opening_balance' AND status = 'posted'`,
    ],
    run: backfillPartyPhoneNumbers,
  },
];

export async function runNumberedMigrations() {
  await withTransaction(
    async (client) => {
      await client.query(
        "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
        ["hisaab-numbered-schema-migrations"],
      );
      await client.query(
        `CREATE TABLE IF NOT EXISTS schema_migrations (
          version INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
        )`,
      );

      for (const migration of migrations) {
        if (await isApplied(client, migration.version)) continue;
        for (const statement of migration.statements) {
          await client.query(statement);
        }
        await migration.run?.(client);
        await client.query(
          `INSERT INTO schema_migrations (version, name)
           VALUES ($1, $2)
           ON CONFLICT (version) DO NOTHING`,
          [migration.version, migration.name],
        );
      }
    },
    { statementTimeoutMs: 300_000 },
  );
}

async function backfillPartyPhoneNumbers(client: PoolClient) {
  const result = await client.query<{ id: string; phone: string }>(
    `SELECT id, phone
     FROM parties
     WHERE phone_e164 IS NULL AND phone <> ''`,
  );
  const updates = result.rows.flatMap((party) => {
    const phoneE164 = normalizeOptionalPhone(party.phone);
    return phoneE164 ? [{ id: party.id, phoneE164 }] : [];
  });
  for (let offset = 0; offset < updates.length; offset += 500) {
    const chunk = updates.slice(offset, offset + 500);
    await client.query(
      `UPDATE parties AS p
       SET phone_e164 = values_to_apply.phone_e164
       FROM unnest($1::text[], $2::text[])
         AS values_to_apply(id, phone_e164)
       WHERE p.id = values_to_apply.id`,
      [
        chunk.map((item) => item.id),
        chunk.map((item) => item.phoneE164),
      ],
    );
  }
}

async function isApplied(client: PoolClient, version: number) {
  const result = await client.query(
    "SELECT 1 FROM schema_migrations WHERE version = $1",
    [version],
  );
  return result.rowCount === 1;
}
