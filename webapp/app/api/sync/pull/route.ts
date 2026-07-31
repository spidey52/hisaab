import { pool } from "@/db";
import { handleRouteError, requireServerContext } from "@/lib/server-auth";
import { buildSyncPage, type RawSyncChange } from "@/lib/sync-feed";

const DEFAULT_LIMIT = 200;
const MAX_LIMIT = 500;

export async function GET(request: Request) {
  try {
    const context = await requireServerContext();
    const url = new URL(request.url);
    const cursor = parseSyncCursor(url.searchParams.get("cursor"));
    const limit = parseSyncLimit(url.searchParams.get("limit"));
    const result = await pool.query<RawSyncChange>(
      `SELECT
         company_id,
         id::text AS cursor,
         entity_type,
         entity_id,
         change_type,
         entity_version,
         payload,
         created_at AS changed_at
       FROM sync_changes
       WHERE company_id = $1 AND id > $2::bigint
       ORDER BY id
       LIMIT $3`,
      [context.companyId, cursor, limit + 1],
    );
    return Response.json(
      buildSyncPage(result.rows, context.companyId, limit, cursor),
      { headers: { "cache-control": "private, no-store" } },
    );
  } catch (error) {
    return handleRouteError(error);
  }
}

export function parseSyncCursor(value: string | null) {
  const cursor = value ?? "0";
  if (!/^\d{1,19}$/.test(cursor)) {
    throw jsonResponse("This sync cursor is invalid.", 400, "INVALID_CURSOR");
  }
  try {
    const parsed = BigInt(cursor);
    if (parsed < 0n || parsed > 9_223_372_036_854_775_807n) {
      throw new Error("out of range");
    }
  } catch {
    throw jsonResponse("This sync cursor is invalid.", 400, "INVALID_CURSOR");
  }
  return cursor.replace(/^0+(?=\d)/, "");
}

export function parseSyncLimit(value: string | null) {
  if (value === null) return DEFAULT_LIMIT;
  if (!/^\d+$/.test(value)) {
    throw jsonResponse("Choose a valid sync page size.", 400);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1 || parsed > MAX_LIMIT) {
    throw jsonResponse(
      `Sync page size must be between 1 and ${MAX_LIMIT}.`,
      400,
    );
  }
  return parsed;
}

function jsonResponse(message: string, status: number, code?: string) {
  return new Response(JSON.stringify({ error: message, code }), {
    status,
    headers: { "content-type": "application/json" },
  });
}
