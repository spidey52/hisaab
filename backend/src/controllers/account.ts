import type { Context } from "hono";
import { eq, sql } from "drizzle-orm";
import { companies, memberships, users, withTransaction } from "../db";
import {
  extractBearerToken,
  revokeBearerSession,
} from "../services/phone-auth";
import { requireServerContext } from "../services/server-auth";
import { nowDate } from "../utils/date-utils";
import { throwApiError } from "../utils/security";

export async function deleteAccount(c: Context) {
  const request = c.req.raw;
  const context = await requireServerContext(request);
  c.get("json");
  if (context.role !== "owner") {
    return c.json(
      { error: "Only the company owner can delete this account." },
      { status: 403 },
    );
  }

  await withTransaction(async (client) => {
    await client
      .select({ id: companies.id })
      .from(companies)
      .where(eq(companies.id, context.companyId))
      .for("update");

    const memberCount = await client
      .select({ count: sql<number>`count(*)::int`.mapWith(Number) })
      .from(memberships)
      .where(eq(memberships.companyId, context.companyId));

    if (Number(memberCount[0]?.count ?? 0) > 1) {
      throwApiError(
        409,
        "Remove or transfer other company members before deleting the account.",
      );
    }
    const now = nowDate();
    await client
      .delete(companies)
      .where(eq(companies.id, context.companyId));
    await client
      .update(users)
      .set({
        deletedAt: now,
        updatedAt: now,
        version: sql`${users.version} + 1`,
      })
      .where(eq(users.id, context.userId));
  });
  await revokeBearerSession(extractBearerToken(request));
  return c.json({ ok: true });
}
