import { withTransaction } from "@/db";
import { readJsonBody } from "@/lib/request-security";
import {
  handleRouteError,
  requireMutationContext,
} from "@/lib/server-auth";
import { getEntryEntities, getPartyEntity } from "@/lib/server-entities";
import {
  appendSyncChange,
  appendSyncChanges,
  isValidOperationId,
  lockLedgerMutation,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "@/lib/sync-server";

type MergePayload = {
  sourcePartyId?: string;
  targetPartyId?: string;
  idempotencyKey?: string;
  baseSourceVersion?: number;
  baseTargetVersion?: number;
};

const operationType = "party.merge";

export async function POST(request: Request) {
  try {
    const context = await requireMutationContext(request);
    const payload = await readJsonBody<MergePayload>(request);
    const sourceId = payload.sourcePartyId?.trim() ?? "";
    const targetId = payload.targetPartyId?.trim() ?? "";
    if (!sourceId || !targetId || sourceId === targetId) {
      return Response.json(
        { error: "Choose two different customers or suppliers." },
        { status: 400 },
      );
    }
    if (
      payload.idempotencyKey !== undefined &&
      !isValidOperationId(payload.idempotencyKey)
    ) {
      return Response.json(
        { error: "This merge has an invalid operation identifier." },
        { status: 400 },
      );
    }
    for (const version of [
      payload.baseSourceVersion,
      payload.baseTargetVersion,
    ]) {
      if (
        version !== undefined &&
        (!Number.isSafeInteger(version) || version < 1)
      ) {
        return Response.json(
          { error: "One of the party versions is invalid." },
          { status: 400 },
        );
      }
    }
    const normalized = { sourceId, targetId };
    const requestHash = operationRequestHash(operationType, normalized);

    const result = await withTransaction(
      async (client) => {
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
            return replayReceipt(receipt, operationType, requestHash);
          }
        }
        await lockLedgerMutation(client, context.companyId);
        const locked = await client.query<{
          id: string;
          version: number;
        }>(
          `SELECT id, version
           FROM parties
           WHERE company_id = $1 AND id = ANY($2::text[])
             AND merged_into_id IS NULL
           ORDER BY id
           FOR UPDATE`,
          [context.companyId, [sourceId, targetId]],
        );
        if (locked.rows.length !== 2) {
          throw jsonResponse(
            "One of the selected records is no longer available.",
            404,
          );
        }
        const versions = new Map(
          locked.rows.map((row) => [row.id, Number(row.version)]),
        );
        if (
          (payload.baseSourceVersion !== undefined &&
            versions.get(sourceId) !== payload.baseSourceVersion) ||
          (payload.baseTargetVersion !== undefined &&
            versions.get(targetId) !== payload.baseTargetVersion)
        ) {
          const [source, target] = await Promise.all([
            getPartyEntity(client, context.companyId, sourceId),
            getPartyEntity(client, context.companyId, targetId),
          ]);
          throw new Response(
            JSON.stringify({
              error: "One of these parties changed on another device.",
              code: "VERSION_CONFLICT",
              current: { source, target },
            }),
            { status: 409, headers: { "content-type": "application/json" } },
          );
        }

        const openingBalances = await client.query<{ party_id: string }>(
          `SELECT party_id
           FROM entries
           WHERE company_id = $1 AND party_id = ANY($2::text[])
             AND action = 'opening_balance' AND status = 'posted'
           ORDER BY party_id
           FOR UPDATE`,
          [context.companyId, [sourceId, targetId]],
        );
        if (new Set(openingBalances.rows.map((row) => row.party_id)).size > 1) {
          throw new Response(
            JSON.stringify({
              error:
                "Both records have an opening balance. Cancel or consolidate one before merging.",
              code: "OPENING_BALANCE_CONFLICT",
            }),
            { status: 409, headers: { "content-type": "application/json" } },
          );
        }

        const now = new Date().toISOString();
        const moved = await client.query<{ id: string; version: number }>(
          `UPDATE entries
           SET party_id = $1, updated_at = $2, version = version + 1
           WHERE party_id = $3 AND company_id = $4
           RETURNING id, version`,
          [targetId, now, sourceId, context.companyId],
        );
        await client.query(
          `UPDATE parties
           SET merged_into_id = $1, archived_at = $2, updated_by = $3,
               updated_at = $2, version = version + 1
           WHERE id = $4 AND company_id = $5`,
          [targetId, now, context.userId, sourceId, context.companyId],
        );
        await client.query(
          `UPDATE parties
           SET updated_by = $1, updated_at = $2, version = version + 1
           WHERE id = $3 AND company_id = $4`,
          [context.userId, now, targetId, context.companyId],
        );
        await client.query(
          `INSERT INTO audit_events (
             id, company_id, actor_user_id, entity_type, entity_id, action,
             details, created_at
           ) VALUES ($1, $2, $3, 'party', $4, 'merged', $5::jsonb, $6)`,
          [
            crypto.randomUUID(),
            context.companyId,
            context.userId,
            sourceId,
            JSON.stringify({
              mergedIntoId: targetId,
              movedEntryCount: moved.rows.length,
            }),
            now,
          ],
        );

        const movedEntries = await getEntryEntities(
          client,
          context.companyId,
          moved.rows.map((row) => row.id),
        );
        if (movedEntries.length !== moved.rows.length) {
          throw new Error("Could not read all moved entries.");
        }
        let changeCursor = await appendSyncChanges(
          client,
          context.companyId,
          movedEntries.map((entry) => ({
            entityType: "entry",
            entityId: entry.id,
            version: entry.version,
            payload: { entry, remappedFromPartyId: sourceId },
          })),
        );
        const target = await getPartyEntity(
          client,
          context.companyId,
          targetId,
        );
        if (!target) throw new Error("Could not read the merged party.");
        changeCursor = await appendSyncChange(client, {
          companyId: context.companyId,
          entityType: "party",
          entityId: targetId,
          version: target.version,
          payload: { party: target },
        });
        const sourceVersion = (versions.get(sourceId) ?? 1) + 1;
        changeCursor = await appendSyncChange(client, {
          companyId: context.companyId,
          entityType: "party",
          entityId: sourceId,
          changeType: "tombstone",
          version: sourceVersion,
          payload: { mergedIntoId: targetId },
        });
        const body = {
          ok: true,
          replayed: false,
          sourcePartyId: sourceId,
          targetParty: target,
          movedEntryCount: moved.rows.length,
          changeCursor,
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
        return body;
      },
      { statementTimeoutMs: 60_000 },
    );
    return Response.json(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

function jsonResponse(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}
