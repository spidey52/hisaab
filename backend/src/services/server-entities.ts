import { and, asc, eq, inArray, sql } from "drizzle-orm";
import {
  entries,
  entryRevisions,
  parties,
  partyGroups,
  users,
  type DbExecutor,
} from "../db";
import { rowToEntry, rowToParty } from "./server-data";
import type { Entry, Party } from "../utils/types";

const entrySelect = {
  id: entries.id,
  party_id: entries.partyId,
  party_name: parties.name,
  sequence: entries.sequence,
  action: entries.action,
  amount_paise: entries.amountPaise,
  balance_effect_paise: entries.balanceEffectPaise,
  narration: entries.narration,
  entry_date: entries.entryDate,
  payment_account: entries.paymentAccount,
  status: entries.status,
  created_by_name: sql<string>`coalesce(${users.fullName}, 'User ' || right(${users.phoneE164}, 4))`,
  created_at: entries.createdAt,
  edited_at: entries.editedAt,
  cancelled_at: entries.cancelledAt,
  updated_at: entries.updatedAt,
  version: entries.version,
  revision_count: sql<number>`(select count(*)::int from ${entryRevisions} r where r.entry_id = ${entries.id})`.mapWith(
    Number,
  ),
};

export async function getPartyEntity(
  client: DbExecutor,
  companyId: string,
  partyId: string,
): Promise<Party | null> {
  const rows = await client
    .select({
      id: parties.id,
      reference: parties.reference,
      name: parties.name,
      short_name: parties.shortName,
      phone: parties.phone,
      phone_e164: parties.phoneE164,
      notes: parties.notes,
      group_id: parties.groupId,
      group_name: partyGroups.name,
      archived_at: parties.archivedAt,
      created_at: parties.createdAt,
      updated_at: parties.updatedAt,
      version: parties.version,
      balance_paise: sql<number>`coalesce(sum(case when ${entries.status} = 'posted' then ${entries.balanceEffectPaise} else 0 end), 0)`.mapWith(
        Number,
      ),
      transaction_count: sql<number>`count(${entries.id})`.mapWith(Number),
    })
    .from(parties)
    .leftJoin(partyGroups, eq(partyGroups.id, parties.groupId))
    .leftJoin(entries, eq(entries.partyId, parties.id))
    .where(and(eq(parties.id, partyId), eq(parties.companyId, companyId)))
    .groupBy(parties.id, partyGroups.name);
  return rows[0] ? rowToParty(rows[0] as Record<string, unknown>) : null;
}

export async function getEntryEntity(
  client: DbExecutor,
  companyId: string,
  entryId: string,
): Promise<Entry | null> {
  return (await getEntryEntities(client, companyId, [entryId]))[0] ?? null;
}

export async function getEntryEntities(
  client: DbExecutor,
  companyId: string,
  entryIds: string[],
): Promise<Entry[]> {
  if (entryIds.length === 0) return [];
  const rows = await client
    .select(entrySelect)
    .from(entries)
    .innerJoin(parties, eq(parties.id, entries.partyId))
    .innerJoin(users, eq(users.id, entries.createdBy))
    .where(and(eq(entries.companyId, companyId), inArray(entries.id, entryIds)))
    .orderBy(entries.sequence);
  return rows.map((row) => rowToEntry(row as Record<string, unknown>));
}

/** All ledger rows for a party, oldest first (for statements / running balances). */
export async function getPartyLedgerEntries(
  client: DbExecutor,
  companyId: string,
  partyId: string,
): Promise<Entry[]> {
  const rows = await client
    .select(entrySelect)
    .from(entries)
    .innerJoin(parties, eq(parties.id, entries.partyId))
    .innerJoin(users, eq(users.id, entries.createdBy))
    .where(and(eq(entries.companyId, companyId), eq(entries.partyId, partyId)))
    .orderBy(asc(entries.entryDate), asc(entries.sequence));
  return rows.map((row) => rowToEntry(row as Record<string, unknown>));
}
