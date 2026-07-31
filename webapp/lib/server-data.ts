import { withReadTransaction } from "@/db";
import type { BootstrapData, Entry, Group, Party } from "./types";
import type { ServerContext } from "./server-auth";
import { toDateOnly } from "./date-utils";

export async function getBootstrapData(
  context: ServerContext,
): Promise<BootstrapData> {
  return withReadTransaction(async (client) => {
    const cursorResult = await client.query<{ cursor: string }>(
      "SELECT COALESCE(MAX(id), 0)::text AS cursor FROM sync_changes",
    );
    const syncCursor = cursorResult.rows[0]?.cursor ?? "0";
    const partyResult = await client.query<Record<string, unknown>>(
      `SELECT
            p.id,
            p.reference,
            p.name,
            p.short_name,
            p.phone,
            p.phone_e164,
            p.notes,
            p.group_id,
            g.name AS group_name,
            p.archived_at,
            p.created_at,
            p.updated_at,
            p.version,
            COALESCE(SUM(CASE
              WHEN e.status = 'posted' THEN e.balance_effect_paise
              ELSE 0 END), 0) AS balance_paise,
            COUNT(e.id) AS transaction_count
          FROM parties p
          LEFT JOIN party_groups g ON g.id = p.group_id
          LEFT JOIN entries e ON e.party_id = p.id
          WHERE p.company_id = $1 AND p.merged_into_id IS NULL
          GROUP BY p.id, g.name
          ORDER BY p.archived_at IS NOT NULL, lower(p.name)`,
      [context.companyId],
    );
    const entryResult = await client.query<Record<string, unknown>>(
      `SELECT
            e.id,
            e.party_id,
            p.name AS party_name,
            e.sequence,
            e.action,
            e.amount_paise,
            e.balance_effect_paise,
            e.narration,
            e.entry_date,
            e.payment_account,
            e.status,
            COALESCE(u.full_name, 'User ' || right(u.phone_e164, 4)) AS created_by_name,
            e.created_at,
            e.edited_at,
            e.cancelled_at,
            e.updated_at,
            e.version,
            (SELECT COUNT(*) FROM entry_revisions r WHERE r.entry_id = e.id)
              AS revision_count
          FROM entries e
          JOIN parties p ON p.id = e.party_id
          JOIN users u ON u.id = e.created_by
          WHERE e.company_id = $1
          ORDER BY e.entry_date DESC, e.sequence DESC
          LIMIT 1000`,
      [context.companyId],
    );
    const groupResult = await client.query<Record<string, unknown>>(
      `SELECT id, name, updated_at, version FROM party_groups
       WHERE company_id = $1 ORDER BY lower(name)`,
      [context.companyId],
    );
    const companyResult = await client.query<Record<string, unknown>>(
      `SELECT c.id, c.name, c.currency, c.timezone, c.updated_at, c.version
          FROM companies c
          JOIN memberships m ON m.company_id = c.id
          WHERE m.user_id = $1
          ORDER BY m.created_at`,
      [context.userId],
    );
    const userResult = await client.query<Record<string, unknown>>(
      `SELECT
         id, phone_e164,
         COALESCE(full_name, 'User ' || right(phone_e164, 4)) AS full_name,
         language, accessibility_mode, contact_discoverable, version
       FROM users
       WHERE id = $1 AND deleted_at IS NULL`,
      [context.userId],
    );
    const user = userResult.rows[0];
    const currentCompany = companyResult.rows.find(
      (row) => String(row.id) === context.companyId,
    );
    if (!user || !currentCompany) {
      throw new Error("Authenticated account snapshot is unavailable.");
    }

    return {
      user: {
        id: String(user.id),
        phoneE164: String(user.phone_e164),
        fullName: String(user.full_name),
        language: user.language === "hi" ? "hi" : "en",
        accessibilityMode: Boolean(user.accessibility_mode),
        contactDiscoverable: Boolean(user.contact_discoverable),
        version: Number(user.version ?? 1),
      },
      company: {
        id: String(currentCompany.id),
        name: String(currentCompany.name),
        currency: "INR",
        timezone: String(currentCompany.timezone),
        version: Number(currentCompany.version ?? 1),
        updatedAt: String(currentCompany.updated_at),
      },
      companies: companyResult.rows.map((row) => ({
        id: String(row.id),
        name: String(row.name),
        currency: "INR" as const,
        timezone: String(row.timezone),
        version: Number(row.version ?? 1),
        updatedAt: String(row.updated_at),
      })),
      groups: groupResult.rows.map((row) => rowToGroup(row)),
      parties: partyResult.rows.map((row) => rowToParty(row)),
      entries: entryResult.rows.map((row) => rowToEntry(row)),
      serverTime: new Date().toISOString(),
      syncCursor,
    };
  });
}

function rowToGroup(row: Record<string, unknown>): Group {
  return {
    id: String(row.id),
    name: String(row.name),
    version: Number(row.version ?? 1),
    updatedAt: String(row.updated_at),
  };
}

export function rowToParty(row: Record<string, unknown>): Party {
  return {
    id: String(row.id),
    reference: String(row.reference),
    name: String(row.name),
    shortName: String(row.short_name ?? ""),
    phone: String(row.phone ?? ""),
    phoneE164: row.phone_e164 ? String(row.phone_e164) : null,
    notes: String(row.notes ?? ""),
    groupId: row.group_id ? String(row.group_id) : null,
    groupName: row.group_name ? String(row.group_name) : null,
    balancePaise: Number(row.balance_paise ?? 0),
    transactionCount: Number(row.transaction_count ?? 0),
    archivedAt: row.archived_at ? String(row.archived_at) : null,
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
    version: Number(row.version ?? 1),
  };
}

export function rowToEntry(row: Record<string, unknown>): Entry {
  const action =
    row.action === "received"
      ? "received"
      : row.action === "opening_balance"
        ? "opening_balance"
        : "gave";
  return {
    id: String(row.id),
    partyId: String(row.party_id),
    partyName: String(row.party_name),
    sequence: Number(row.sequence),
    action,
    amountPaise: Number(row.amount_paise),
    balanceEffectPaise: Number(row.balance_effect_paise),
    narration: String(row.narration ?? ""),
    entryDate: toDateOnly(row.entry_date),
    paymentAccount: row.payment_account
      ? String(row.payment_account)
      : null,
    status: row.status === "cancelled" ? "cancelled" : "posted",
    createdByName: String(row.created_by_name),
    createdAt: String(row.created_at),
    editedAt: row.edited_at ? String(row.edited_at) : null,
    cancelledAt: row.cancelled_at ? String(row.cancelled_at) : null,
    revisionCount: Number(row.revision_count ?? 0),
    updatedAt: String(row.updated_at ?? row.created_at),
    version: Number(row.version ?? 1),
  };
}
