import { withReadTransaction } from "@/db";
import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { isValidDateOnly } from "@/lib/date-utils";
import { authenticationSecret } from "@/lib/request-security";
import { handleRouteError, requireServerContext } from "@/lib/server-auth";
import { getPartyEntity } from "@/lib/server-entities";
import { rowToEntry } from "@/lib/server-data";
import {
  cursorMatchesStatementRequest,
  statementTotals,
  takeStatementPage,
} from "@/lib/statement";

const DEFAULT_LIMIT = 100;
const MAX_LIMIT = 200;
const order = "newest_first" as const;

type StatementCursor = {
  version: 1;
  partyId: string;
  from: string | null;
  to: string | null;
  entryDate: string;
  sequence: number;
  order: typeof order;
  statementRevision: string;
};

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const context = await requireServerContext();
    const { id } = await params;
    const url = new URL(request.url);
    const from = optionalDate(url.searchParams.get("from"), "from");
    const to = optionalDate(url.searchParams.get("to"), "to");
    if (from && to && from > to) {
      return Response.json(
        { error: "The statement start date must not be after its end date." },
        { status: 400 },
      );
    }
    const limit = boundedLimit(url.searchParams.get("limit"));
    const cursor = decodeCursor(url.searchParams.get("cursor"));
    if (
      cursor &&
      !cursorMatchesStatementRequest(cursor, {
        partyId: id,
        from,
        to,
        order,
      })
    ) {
      return Response.json(
        {
          error: "This statement cursor belongs to a different request.",
          code: "INVALID_CURSOR",
        },
        { status: 400 },
      );
    }

    const result = await withReadTransaction(async (client) => {
      const party = await getPartyEntity(client, context.companyId, id);
      if (!party) {
        throw jsonResponse("Party not found.", 404);
      }
      const available = await client.query(
        `SELECT id FROM parties
         WHERE id = $1 AND company_id = $2 AND merged_into_id IS NULL`,
        [id, context.companyId],
      );
      if (!available.rows[0]) throw jsonResponse("Party not found.", 404);

      const summaryResult = await client.query<{
        opening_balance_paise: number;
        period_change_paise: number;
        posted_count: number;
        cancelled_count: number;
        total_count: number;
        revision_count: number;
        revision_version_sum: number;
        revision_max_updated_at: string | null;
        revision_effect_sum: number;
      }>(
        `SELECT
           COALESCE(SUM(CASE
             WHEN status = 'posted'
              AND $3::date IS NOT NULL
              AND entry_date < $3::date
             THEN balance_effect_paise ELSE 0 END), 0)
             AS opening_balance_paise,
           COALESCE(SUM(CASE
             WHEN status = 'posted'
              AND ($3::date IS NULL OR entry_date >= $3::date)
              AND ($4::date IS NULL OR entry_date <= $4::date)
             THEN balance_effect_paise ELSE 0 END), 0)
             AS period_change_paise,
           COUNT(*) FILTER (
             WHERE status = 'posted'
              AND ($3::date IS NULL OR entry_date >= $3::date)
              AND ($4::date IS NULL OR entry_date <= $4::date)
           )::int AS posted_count,
           COUNT(*) FILTER (
             WHERE status = 'cancelled'
              AND ($3::date IS NULL OR entry_date >= $3::date)
              AND ($4::date IS NULL OR entry_date <= $4::date)
           )::int AS cancelled_count,
           COUNT(*) FILTER (
             WHERE ($3::date IS NULL OR entry_date >= $3::date)
              AND ($4::date IS NULL OR entry_date <= $4::date)
           )::int AS total_count,
           COUNT(*) FILTER (
             WHERE $4::date IS NULL OR entry_date <= $4::date
           )::int AS revision_count,
           COALESCE(SUM(version) FILTER (
             WHERE $4::date IS NULL OR entry_date <= $4::date
           ), 0) AS revision_version_sum,
           MAX(updated_at) FILTER (
             WHERE $4::date IS NULL OR entry_date <= $4::date
           )::text AS revision_max_updated_at,
           COALESCE(SUM(CASE
             WHEN status = 'posted'
              AND ($4::date IS NULL OR entry_date <= $4::date)
             THEN balance_effect_paise ELSE 0 END), 0)
             AS revision_effect_sum
         FROM entries
         WHERE company_id = $1 AND party_id = $2`,
        [context.companyId, id, from, to],
      );
      const summary = summaryResult.rows[0]!;
      const statementRevision = createHash("sha256")
        .update(
          JSON.stringify({
            partyVersion: party.version,
            count: Number(summary.revision_count ?? 0),
            versionSum: Number(summary.revision_version_sum ?? 0),
            maxUpdatedAt: summary.revision_max_updated_at,
            effectSum: Number(summary.revision_effect_sum ?? 0),
          }),
        )
        .digest("base64url");
      if (cursor && cursor.statementRevision !== statementRevision) {
        throw new Response(
          JSON.stringify({
            error:
              "This statement changed while it was being loaded. Start again.",
            code: "STATEMENT_CHANGED",
          }),
          {
            status: 409,
            headers: { "content-type": "application/json" },
          },
        );
      }

      const entriesResult = await client.query<Record<string, unknown>>(
        `WITH ledger AS (
           SELECT
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
               AS revision_count,
             SUM(CASE
               WHEN e.status = 'posted' THEN e.balance_effect_paise
               ELSE 0 END
             ) OVER (
               ORDER BY e.entry_date, e.sequence
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
             ) AS running_balance_paise
           FROM entries e
           JOIN parties p ON p.id = e.party_id
           JOIN users u ON u.id = e.created_by
           WHERE e.company_id = $1 AND e.party_id = $2
         )
         SELECT *
         FROM ledger
         WHERE ($3::date IS NULL OR entry_date >= $3::date)
           AND ($4::date IS NULL OR entry_date <= $4::date)
           AND (
             $5::date IS NULL
             OR entry_date < $5::date
             OR (entry_date = $5::date AND sequence < $6::bigint)
           )
         ORDER BY entry_date DESC, sequence DESC
         LIMIT $7`,
        [
          context.companyId,
          id,
          from,
          to,
          cursor?.entryDate ?? null,
          cursor?.sequence ?? null,
          limit + 1,
        ],
      );
      const page = takeStatementPage(entriesResult.rows, limit);
      const hasMore = page.hasMore;
      const pageRows = page.rows;
      const entries = pageRows.map((row) => ({
        ...rowToEntry(row),
        // This is the chronological posted-only balance immediately after this
        // entry. A cancelled entry therefore has the same balance as before it.
        runningBalancePaise: Number(row.running_balance_paise ?? 0),
      }));
      const last = entries.at(-1);
      const nextCursor =
        hasMore && last
          ? encodeCursor({
              version: 1,
              partyId: id,
              from,
              to,
              entryDate: last.entryDate,
              sequence: last.sequence,
              order,
              statementRevision,
            })
          : null;
      const openingBalancePaise = Number(
        summary.opening_balance_paise ?? 0,
      );
      const periodChangePaise = Number(summary.period_change_paise ?? 0);
      const totals = statementTotals({
        openingBalancePaise,
        periodChangePaise,
      });
      return {
        party,
        period: { from, to },
        ...totals,
        postedCount: Number(summary.posted_count ?? 0),
        cancelledCount: Number(summary.cancelled_count ?? 0),
        totalCount: Number(summary.total_count ?? 0),
        order,
        statementRevision,
        entries,
        nextCursor,
        hasMore,
      };
    });

    return Response.json(result, {
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return handleRouteError(error);
  }
}

function optionalDate(value: string | null, label: string) {
  if (value === null) return null;
  if (!isValidDateOnly(value)) {
    throw new Response(
      JSON.stringify({
        error: `Choose a valid statement ${label} date.`,
      }),
      {
        status: 400,
        headers: { "content-type": "application/json" },
      },
    );
  }
  return value;
}

function boundedLimit(value: string | null) {
  if (value === null) return DEFAULT_LIMIT;
  if (!/^\d+$/.test(value)) {
    throw jsonResponse("Choose a valid statement page size.", 400);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1 || parsed > MAX_LIMIT) {
    throw jsonResponse(
      `Statement page size must be between 1 and ${MAX_LIMIT}.`,
      400,
    );
  }
  return parsed;
}

export function encodeCursor(cursor: StatementCursor) {
  const encoded = Buffer.from(JSON.stringify(cursor)).toString("base64url");
  const signature = createHmac("sha256", authenticationSecret())
    .update(encoded)
    .digest("base64url");
  return `${encoded}.${signature}`;
}

export function decodeCursor(value: string | null): StatementCursor | null {
  if (!value) return null;
  try {
    const [encoded, signature, extra] = value.split(".");
    if (!encoded || !signature || extra) throw new Error("Invalid cursor");
    const expected = createHmac("sha256", authenticationSecret())
      .update(encoded)
      .digest();
    const actual = Buffer.from(signature, "base64url");
    if (
      actual.length !== expected.length ||
      !timingSafeEqual(actual, expected)
    ) {
      throw new Error("Invalid signature");
    }
    const decoded = JSON.parse(
      Buffer.from(encoded, "base64url").toString("utf8"),
    ) as Partial<StatementCursor>;
    if (
      decoded.version !== 1 ||
      typeof decoded.partyId !== "string" ||
      (decoded.from !== null && !isValidDateOnly(decoded.from)) ||
      (decoded.to !== null && !isValidDateOnly(decoded.to)) ||
      !isValidDateOnly(decoded.entryDate) ||
      !Number.isSafeInteger(decoded.sequence) ||
      (decoded.sequence ?? 0) < 1 ||
      decoded.order !== order ||
      typeof decoded.statementRevision !== "string" ||
      !/^[A-Za-z0-9_-]{43}$/.test(decoded.statementRevision)
    ) {
      throw new Error("Invalid cursor");
    }
    return decoded as StatementCursor;
  } catch {
    throw new Response(
      JSON.stringify({
        error: "This statement cursor is invalid.",
        code: "INVALID_CURSOR",
      }),
      {
        status: 400,
        headers: { "content-type": "application/json" },
      },
    );
  }
}

function jsonResponse(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}
