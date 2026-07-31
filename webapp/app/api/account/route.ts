import { withTransaction } from "@/db";
import {
  handleRouteError,
  requireMutationContext,
} from "@/lib/server-auth";
import { clearSessionCookies } from "@/lib/phone-auth";
import { readJsonBody } from "@/lib/request-security";

export async function DELETE(request: Request) {
  try {
    const context = await requireMutationContext(request);
    const payload = await readJsonBody<{ confirmation?: string }>(request);
    if (payload.confirmation !== "DELETE MY ACCOUNT") {
      return Response.json(
        { error: 'Type "DELETE MY ACCOUNT" to confirm.' },
        { status: 400 },
      );
    }
    if (context.role !== "owner") {
      return Response.json(
        { error: "Only the company owner can delete this account." },
        { status: 403 },
      );
    }

    await withTransaction(async (client) => {
      await client.query("SELECT id FROM companies WHERE id = $1 FOR UPDATE", [
        context.companyId,
      ]);
      const memberCount = await client.query<{ count: number }>(
        "SELECT COUNT(*)::int AS count FROM memberships WHERE company_id = $1",
        [context.companyId],
      );
      if (Number(memberCount.rows[0]?.count ?? 0) > 1) {
        throw new Response(
          JSON.stringify({
            error:
              "Remove or transfer other company members before deleting the account.",
          }),
          { status: 409, headers: { "content-type": "application/json" } },
        );
      }
      const now = new Date().toISOString();
      // Company cascades remove ledger data, operation receipts, and sync feed.
      await client.query("DELETE FROM companies WHERE id = $1", [
        context.companyId,
      ]);
      await client.query(
        `UPDATE users
         SET deleted_at = $1, updated_at = $1, version = version + 1
         WHERE id = $2`,
        [now, context.userId],
      );
    });
    await clearSessionCookies();
    return Response.json({ ok: true });
  } catch (error) {
    return handleRouteError(error);
  }
}
