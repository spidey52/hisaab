import type { Context } from "hono";
import { and, eq, sql } from "drizzle-orm";
import { withTransaction, partyGroups, syncChanges } from "../db";
import {
  handleRouteError,
  requireServerContext,
} from "../services/server-auth";
import { nowDate, nowIso } from "../utils/date-utils";
import {
  appendSyncChange,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "../services/sync-server";

const operationType = "group.create";

export async function createGroup(c: Context) {
  try {
    const request = c.req.raw;
    const context = await requireServerContext(request);
    const payload = c.get("json") as {
      name: string;
      clientId?: string;
      idempotencyKey?: string;
    };
    const name = payload.name;
    const normalized = { name, clientId: payload.clientId ?? null };
    const requestHash = operationRequestHash(operationType, normalized);

    const result = await withTransaction(async (client) => {
      if (payload.idempotencyKey) {
        await lockOperation(
          client,
          context.companyId,
          payload.idempotencyKey,
        );
        const receipt = await readOperationReceipt(
          client,
          context.companyId,
          payload.idempotencyKey,
        );
        if (receipt) {
          return {
            body: replayReceipt(receipt, operationType, requestHash),
            status: 200,
          };
        }
      }
      if (payload.clientId) {
        await lockOperation(
          client,
          context.companyId,
          `group-client:${payload.clientId}`,
        );
        const existing = await client
          .select({
            id: partyGroups.id,
            name: partyGroups.name,
            version: partyGroups.version,
            updated_at: partyGroups.updatedAt,
          })
          .from(partyGroups)
          .where(
            and(
              eq(partyGroups.id, payload.clientId),
              eq(partyGroups.companyId, context.companyId),
            ),
          )
          .limit(1);
        const row = existing[0];
        if (row) {
          if (row.name !== name) {
            throw new Response(
              JSON.stringify({
                error:
                  "This operation identifier was already used for different details.",
                code: "IDEMPOTENCY_CONFLICT",
              }),
              {
                status: 409,
                headers: { "content-type": "application/json" },
              },
            );
          }
          const group = {
            id: row.id,
            name: row.name,
            version: Number(row.version),
            updatedAt: String(row.updated_at),
          };
          const cursorResult = await client
            .select({
              cursor: sql<string>`coalesce(max(${syncChanges.id}), 0)::text`.mapWith(
                String,
              ),
            })
            .from(syncChanges)
            .where(eq(syncChanges.companyId, context.companyId));
          const body = {
            ...group,
            group,
            replayed: false,
            changeCursor: cursorResult[0]?.cursor ?? "0",
          };
          if (payload.idempotencyKey) {
            await storeOperationReceipt(client, {
              companyId: context.companyId,
              operationId: payload.idempotencyKey,
              operationType,
              requestHash,
              responseBody: body,
              statusCode: 200,
            });
          }
          return { body: { ...body, replayed: true }, status: 200 };
        }
      }
      await lockOperation(
        client,
        context.companyId,
        `group-name:${name.toLocaleLowerCase("en-US")}`,
      );
      const duplicate = await client
        .select({ id: partyGroups.id })
        .from(partyGroups)
        .where(
          and(
            eq(partyGroups.companyId, context.companyId),
            sql`lower(${partyGroups.name}) = lower(${name})`,
          ),
        )
        .limit(1);
      if (duplicate[0]) {
        throw new Response(
          JSON.stringify({
            error: "A group with this name already exists.",
            code: "GROUP_EXISTS",
          }),
          { status: 409, headers: { "content-type": "application/json" } },
        );
      }
      const id = payload.clientId ?? crypto.randomUUID();
      const now = nowDate();
      await client.insert(partyGroups).values({
        id,
        companyId: context.companyId,
        name,
        createdAt: now,
        updatedAt: now,
        version: 1,
      });
      const group = { id, name, version: 1, updatedAt: nowIso() };
      const changeCursor = await appendSyncChange(client, {
        companyId: context.companyId,
        entityType: "group",
        entityId: id,
        version: group.version,
        payload: { group },
      });
      const body = { ...group, group, replayed: false, changeCursor };
      if (payload.idempotencyKey) {
        await storeOperationReceipt(client, {
          companyId: context.companyId,
          operationId: payload.idempotencyKey,
          operationType,
          requestHash,
          responseBody: body,
          statusCode: 201,
        });
      }
      return { body, status: 201 };
    });
    return Response.json(result.body, { status: result.status });
  } catch (error) {
    return handleRouteError(error);
  }
}
