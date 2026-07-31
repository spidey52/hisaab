import { withReadTransaction } from "@/db";
import {
  handleRouteError,
  requireServerContext,
} from "@/lib/server-auth";
import { entryDisplayLabel } from "@/lib/entry-display";

export async function GET(request: Request) {
  try {
    const context = await requireServerContext();
    const format = new URL(request.url).searchParams.get("format") ?? "json";
    const snapshot = await withReadTransaction(async (client) => {
      const parties = await client.query(
        "SELECT * FROM parties WHERE company_id = $1 ORDER BY created_at",
        [context.companyId],
      );
      const entries = await client.query(
        `SELECT e.*, p.name AS party_name
         FROM entries e
         JOIN parties p ON p.id = e.party_id
         WHERE e.company_id = $1
         ORDER BY e.entry_date, e.sequence`,
        [context.companyId],
      );
      const groups = await client.query(
        "SELECT * FROM party_groups WHERE company_id = $1 ORDER BY name",
        [context.companyId],
      );
      const company = await client.query(
        `SELECT id, name, currency, timezone, version, updated_at
         FROM companies WHERE id = $1`,
        [context.companyId],
      );
      if (!company.rows[0]) {
        throw new Error("Company export snapshot is unavailable.");
      }
      return {
        company: company.rows[0],
        parties: parties.rows,
        entries: entries.rows,
        groups: groups.rows,
      };
    });

    const stamp = new Date().toISOString().slice(0, 10);
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
      const rows = snapshot.entries.map((row: Record<string, unknown>) => [
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
          generatedAt: new Date().toISOString(),
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
