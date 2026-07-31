import { and, asc, desc, eq, isNull, sql } from "drizzle-orm";
import {
  companies,
  entries,
  entryRevisions,
  memberships,
  parties,
  partyGroups,
  syncChanges,
  users,
  withReadTransaction,
} from "../db";
import type { BootstrapData, Entry, Group, Party } from "../utils/types";
import type { ServerContext } from "./server-auth";
import { nowIso, toDateOnly } from "../utils/date-utils";

export async function getBootstrapData(
  context: ServerContext,
): Promise<BootstrapData> {
  return withReadTransaction(async (client) => {
    const cursorResult = await client
      .select({
        cursor: sql<string>`coalesce(max(${syncChanges.id}), 0)::text`.mapWith(
          String,
        ),
      })
      .from(syncChanges);
    const syncCursor = cursorResult[0]?.cursor ?? "0";

    const partyResult = await client
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
        balance_paise: sql<
          number
        >`coalesce(sum(case when ${entries.status} = 'posted' then ${entries.balanceEffectPaise} else 0 end), 0)`
          .mapWith(
            Number,
          ),
        transaction_count: sql<number>`count(${entries.id})`.mapWith(Number),
      })
      .from(parties)
      .leftJoin(partyGroups, eq(partyGroups.id, parties.groupId))
      .leftJoin(entries, eq(entries.partyId, parties.id))
      .where(
        and(
          eq(parties.companyId, context.companyId),
          isNull(parties.mergedIntoId),
        ),
      )
      .groupBy(parties.id, partyGroups.name)
      .orderBy(
        sql`${parties.archivedAt} IS NOT NULL`,
        sql`lower(${parties.name})`,
      );

    const entryResult = await client
      .select({
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
        created_by_name: sql<
          string
        >`coalesce(${users.fullName}, 'User ' || right(${users.phoneE164}, 4))`,
        created_at: entries.createdAt,
        edited_at: entries.editedAt,
        cancelled_at: entries.cancelledAt,
        updated_at: entries.updatedAt,
        version: entries.version,
        revision_count: sql<
          number
        >`(select count(*)::int from ${entryRevisions} r where r.entry_id = ${entries.id})`
          .mapWith(
            Number,
          ),
      })
      .from(entries)
      .innerJoin(parties, eq(parties.id, entries.partyId))
      .innerJoin(users, eq(users.id, entries.createdBy))
      .where(eq(entries.companyId, context.companyId))
      .orderBy(desc(entries.entryDate), desc(entries.sequence));

    const groupResult = await client
      .select({
        id: partyGroups.id,
        name: partyGroups.name,
        updated_at: partyGroups.updatedAt,
        version: partyGroups.version,
      })
      .from(partyGroups)
      .where(eq(partyGroups.companyId, context.companyId))
      .orderBy(sql`lower(${partyGroups.name})`);

    const companyResult = await client
      .select({
        id: companies.id,
        name: companies.name,
        currency: companies.currency,
        timezone: companies.timezone,
        updated_at: companies.updatedAt,
        version: companies.version,
      })
      .from(companies)
      .innerJoin(memberships, eq(memberships.companyId, companies.id))
      .where(eq(memberships.userId, context.userId))
      .orderBy(asc(memberships.createdAt));

    const userResult = await client
      .select({
        id: users.id,
        phone_e164: users.phoneE164,
        full_name: sql<
          string
        >`coalesce(${users.fullName}, 'User ' || right(${users.phoneE164}, 4))`,
        language: users.language,
        accessibility_mode: users.accessibilityMode,
        contact_discoverable: users.contactDiscoverable,
        version: users.version,
      })
      .from(users)
      .where(and(eq(users.id, context.userId), isNull(users.deletedAt)));

    const user = userResult[0];
    const currentCompany = companyResult.find(
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
      companies: companyResult.map((row) => ({
        id: String(row.id),
        name: String(row.name),
        currency: "INR" as const,
        timezone: String(row.timezone),
        version: Number(row.version ?? 1),
        updatedAt: String(row.updated_at),
      })),
      groups: groupResult.map((row) =>
        rowToGroup(row as Record<string, unknown>)
      ),
      parties: partyResult.map((row) =>
        rowToParty(row as Record<string, unknown>)
      ),
      entries: entryResult.map((row) =>
        rowToEntry(row as Record<string, unknown>)
      ),
      serverTime: nowIso(),
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
  const action = row.action === "received"
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
    paymentAccount: row.payment_account ? String(row.payment_account) : null,
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
