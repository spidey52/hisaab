import type { Context } from "hono";
import { and, eq, gt, sql } from "drizzle-orm";
import { db, syncChanges } from "../db";
import { handleRouteError, requireServerContext } from "../services/server-auth";
import { buildSyncPage, type RawSyncChange } from "../utils/sync-feed";

export async function pull(c: Context) {
  try {
    const context = await requireServerContext(c.req.raw);
    const { cursor, limit } = c.get("query") as { cursor: string; limit: number };
    const rows = await db
      .select({
        company_id: syncChanges.companyId,
        cursor: sql<string>`${syncChanges.id}::text`,
        entity_type: syncChanges.entityType,
        entity_id: syncChanges.entityId,
        change_type: syncChanges.changeType,
        entity_version: syncChanges.entityVersion,
        payload: syncChanges.payload,
        changed_at: sql<string>`${syncChanges.createdAt}::text`,
      })
      .from(syncChanges)
      .where(
        and(
          eq(syncChanges.companyId, context.companyId),
          gt(syncChanges.id, Number(cursor)),
        ),
      )
      .orderBy(syncChanges.id)
      .limit(limit + 1);
    return c.json(
      buildSyncPage(rows as RawSyncChange[], context.companyId, limit, cursor),
      { headers: { "cache-control": "private, no-store" } },
    );
  } catch (error) {
    return handleRouteError(error);
  }
}
