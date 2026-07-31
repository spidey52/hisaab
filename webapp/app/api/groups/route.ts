import { withTransaction } from "@/db";
import { readJsonBody } from "@/lib/request-security";
import {
  handleRouteError,
  requireMutationContext,
} from "@/lib/server-auth";
import {
  appendSyncChange,
  isUuid,
  isValidOperationId,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "@/lib/sync-server";

type GroupPayload = {
  name?: string;
  clientId?: string;
  idempotencyKey?: string;
};

const operationType = "group.create";

export async function POST(request: Request) {
  try {
    const context = await requireMutationContext(request);
    const payload = await readJsonBody<GroupPayload>(request);
    const name = payload.name?.trim().slice(0, 60) ?? "";
    if (name.length < 2) {
      return Response.json({ error: "Enter a group name." }, { status: 400 });
    }
    if (payload.clientId !== undefined && !isUuid(payload.clientId)) {
      return Response.json(
        { error: "This group has an invalid client identifier." },
        { status: 400 },
      );
    }
    if (
      payload.idempotencyKey !== undefined &&
      !isValidOperationId(payload.idempotencyKey)
    ) {
      return Response.json(
        { error: "This group has an invalid operation identifier." },
        { status: 400 },
      );
    }
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
        const existing = await client.query<{
          id: string;
          name: string;
          version: number;
          updated_at: string;
        }>(
          `SELECT id, name, version, updated_at
           FROM party_groups
           WHERE id = $1 AND company_id = $2`,
          [payload.clientId, context.companyId],
        );
        const row = existing.rows[0];
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
          const cursorResult = await client.query<{ cursor: string }>(
            `SELECT COALESCE(MAX(id), 0)::text AS cursor
             FROM sync_changes WHERE company_id = $1`,
            [context.companyId],
          );
          const body = {
            ...group,
            group,
            replayed: false,
            changeCursor: cursorResult.rows[0]?.cursor ?? "0",
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
      const duplicate = await client.query(
        `SELECT id FROM party_groups
         WHERE company_id = $1 AND lower(name) = lower($2)
         LIMIT 1`,
        [context.companyId, name],
      );
      if (duplicate.rows[0]) {
        throw new Response(
          JSON.stringify({
            error: "A group with this name already exists.",
            code: "GROUP_EXISTS",
          }),
          { status: 409, headers: { "content-type": "application/json" } },
        );
      }
      const id = payload.clientId ?? crypto.randomUUID();
      const now = new Date().toISOString();
      await client.query(
        `INSERT INTO party_groups (
           id, company_id, name, created_at, updated_at, version
         ) VALUES ($1, $2, $3, $4, $4, 1)`,
        [id, context.companyId, name, now],
      );
      const group = { id, name, version: 1, updatedAt: now };
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
