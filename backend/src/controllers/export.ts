import type { Context } from "hono";
import { asc, eq } from "drizzle-orm";
import {
  companies,
  entries,
  parties,
  partyGroups,
  withReadTransaction,
} from "../db";
import {
  handleRouteError,
  requireServerContext,
} from "../services/server-auth";
import { entryDisplayLabel } from "../utils/entry-display";
import { nowIso, todayDateOnly } from "../utils/date-utils";

export async function exportData(c: Context) {
  try {
    const request = c.req.raw;
    const context = await requireServerContext(request);
    const { format } = c.get("query") as { format: "json" | "csv" };
    const snapshot = await withReadTransaction(async (client) => {
      const partyRows = await client
        .select({
          id: parties.id,
          company_id: parties.companyId,
          reference: parties.reference,
          name: parties.name,
          short_name: parties.shortName,
          phone: parties.phone,
          phone_e164: parties.phoneE164,
          notes: parties.notes,
          group_id: parties.groupId,
          created_by: parties.createdBy,
          updated_by: parties.updatedBy,
          created_at: parties.createdAt,
          updated_at: parties.updatedAt,
          archived_at: parties.archivedAt,
          merged_into_id: parties.mergedIntoId,
          version: parties.version,
        })
        .from(parties)
        .where(eq(parties.companyId, context.companyId))
        .orderBy(asc(parties.createdAt));

      const entryRows = await client
        .select({
          id: entries.id,
          company_id: entries.companyId,
          party_id: entries.partyId,
          sequence: entries.sequence,
          action: entries.action,
          amount_paise: entries.amountPaise,
          balance_effect_paise: entries.balanceEffectPaise,
          narration: entries.narration,
          entry_date: entries.entryDate,
          payment_account: entries.paymentAccount,
          status: entries.status,
          idempotency_key: entries.idempotencyKey,
          created_by: entries.createdBy,
          created_at: entries.createdAt,
          updated_at: entries.updatedAt,
          version: entries.version,
          edited_by: entries.editedBy,
          edited_at: entries.editedAt,
          cancelled_by: entries.cancelledBy,
          cancelled_at: entries.cancelledAt,
          party_name: parties.name,
        })
        .from(entries)
        .innerJoin(parties, eq(parties.id, entries.partyId))
        .where(eq(entries.companyId, context.companyId))
        .orderBy(asc(entries.entryDate), asc(entries.sequence));

      const groupRows = await client
        .select({
          id: partyGroups.id,
          company_id: partyGroups.companyId,
          name: partyGroups.name,
          created_at: partyGroups.createdAt,
          updated_at: partyGroups.updatedAt,
          version: partyGroups.version,
        })
        .from(partyGroups)
        .where(eq(partyGroups.companyId, context.companyId))
        .orderBy(asc(partyGroups.name));

      const companyRows = await client
        .select({
          id: companies.id,
          name: companies.name,
          currency: companies.currency,
          timezone: companies.timezone,
          version: companies.version,
          updated_at: companies.updatedAt,
        })
        .from(companies)
        .where(eq(companies.id, context.companyId));

      const company = companyRows[0];
      if (!company) {
        throw new Error("Company export snapshot is unavailable.");
      }
      return {
        company,
        parties: partyRows,
        entries: entryRows,
        groups: groupRows,
      };
    });

    const stamp = todayDateOnly();
    if (format === "csv") {
      const header = [
        "Entry number",
        "Date",
        "Party",
        "Action",
        "Amount paise",
        "Balance effect paise",
        "Note",
        "Status",
        "Created at",
      ];
      const rows = snapshot.entries.map((row) => [
        row.sequence,
        row.entry_date,
        row.party_name,
        row.action,
        row.amount_paise,
        row.balance_effect_paise,
        entryDisplayLabel(row.action, row.narration),
        row.status,
        row.created_at,
      ]);
      const csv = [header, ...rows]
        .map((row) => row.map(csvValue).join(","))
        .join("\n");
      return new Response(csv, {
        headers: {
          "content-type": "text/csv; charset=utf-8",
          "content-disposition": `attachment; filename="hisaab-${stamp}.csv"`,
          "cache-control": "private, no-store",
        },
      });
    }

    return new Response(
      JSON.stringify(
        {
          generatedAt: nowIso(),
          company: snapshot.company,
          parties: snapshot.parties,
          entries: snapshot.entries,
          groups: snapshot.groups,
        },
        null,
        2,
      ),
      {
        headers: {
          "content-type": "application/json; charset=utf-8",
          "content-disposition": `attachment; filename="hisaab-${stamp}.json"`,
          "cache-control": "private, no-store",
        },
      },
    );
  } catch (error) {
    return handleRouteError(error);
  }
}

function csvValue(value: unknown) {
  const text = value == null ? "" : String(value);
  return `"${text.replaceAll('"', '""')}"`;
}
