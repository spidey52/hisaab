import type { PoolClient } from "pg";
import { rowToEntry, rowToParty } from "./server-data";
import type { Entry, Party } from "./types";

export async function getPartyEntity(
  client: PoolClient,
  companyId: string,
  partyId: string,
): Promise<Party | null> {
  const result = await client.query<Record<string, unknown>>(
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
     WHERE p.id = $1 AND p.company_id = $2
     GROUP BY p.id, g.name`,
    [partyId, companyId],
  );
  return result.rows[0] ? rowToParty(result.rows[0]) : null;
}

export async function getEntryEntity(
  client: PoolClient,
  companyId: string,
  entryId: string,
): Promise<Entry | null> {
  return (await getEntryEntities(client, companyId, [entryId]))[0] ?? null;
}

export async function getEntryEntities(
  client: PoolClient,
  companyId: string,
  entryIds: string[],
): Promise<Entry[]> {
  if (entryIds.length === 0) return [];
  const result = await client.query<Record<string, unknown>>(
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
       COALESCE(u.full_name, 'User ' || right(u.phone_e164, 4))
         AS created_by_name,
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
     WHERE e.company_id = $1 AND e.id = ANY($2::text[])
     ORDER BY e.sequence`,
    [companyId, entryIds],
  );
  return result.rows.map(rowToEntry);
}
