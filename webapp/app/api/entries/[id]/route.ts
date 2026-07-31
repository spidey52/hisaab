import { withTransaction } from "@/db";
import type { PoolClient } from "pg";
import { isValidDateOnly } from "@/lib/date-utils";
import { readJsonBody } from "@/lib/request-security";
import {
  handleRouteError,
  requireMutationContext,
} from "@/lib/server-auth";
import { getEntryEntity, getPartyEntity } from "@/lib/server-entities";
import {
  appendSyncChange,
  isValidOperationId,
  lockLedgerMutation,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "@/lib/sync-server";
import type { Party } from "@/lib/types";

type EntryUpdatePayload =
  | {
      operation: "cancel";
      idempotencyKey?: string;
      baseVersion?: number;
    }
  | {
      operation: "edit";
      partyId: string;
      action: "gave" | "received";
      amountPaise: number;
      narration?: string;
      entryDate: string;
      paymentAccount?: "cash" | "bank" | null;
      idempotencyKey?: string;
      baseVersion?: number;
    };

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const context = await requireMutationContext(request);
    const { id } = await params;
    const payload = await readJsonBody<EntryUpdatePayload>(request);
    if (payload.operation !== "cancel" && payload.operation !== "edit") {
      return Response.json({ error: "Unknown entry action." }, { status: 400 });
    }
    if (
      payload.idempotencyKey !== undefined &&
      !isValidOperationId(payload.idempotencyKey)
    ) {
      return Response.json(
        { error: "This change has an invalid operation identifier." },
        { status: 400 },
      );
    }
    if (
      payload.baseVersion !== undefined &&
      (!Number.isSafeInteger(payload.baseVersion) || payload.baseVersion < 1)
    ) {
      return Response.json(
        { error: "This entry version is invalid." },
        { status: 400 },
      );
    }
    if (payload.operation === "edit") {
      const validation = validateUpdate(payload);
      if (validation) {
        return Response.json({ error: validation }, { status: 400 });
      }
    }

    const operationType = `entry.${payload.operation}`;
    const normalizedIntent =
      payload.operation === "cancel"
        ? { entryId: id, operation: "cancel" }
        : {
            entryId: id,
            operation: "edit",
            partyId: payload.partyId,
            action: payload.action,
            amountPaise: payload.amountPaise,
            narration: (payload.narration ?? "").trim().slice(0, 240),
            entryDate: payload.entryDate,
            paymentAccount: payload.paymentAccount ?? null,
          };
    const requestHash = operationRequestHash(operationType, normalizedIntent);

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
          };
        }
      }

      await lockLedgerMutation(client, context.companyId);
      const existingResult = await client.query<Record<string, unknown>>(
        `SELECT * FROM entries
         WHERE id = $1 AND company_id = $2
         FOR UPDATE`,
        [id, context.companyId],
      );
      const existing = existingResult.rows[0];
      if (!existing) {
        throw jsonResponse("Entry not found.", 404);
      }

      if (payload.operation === "cancel" && existing.status === "cancelled") {
        const entry = await getEntryEntity(client, context.companyId, id);
        const party = await getPartyEntity(
          client,
          context.companyId,
          String(existing.party_id),
        );
        if (!entry || !party) throw new Error("Could not replay cancellation.");
        const body = { ok: true, replayed: false, entry, party };
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
        return { body: { ...body, replayed: true } };
      }

      if (
        payload.baseVersion !== undefined &&
        Number(existing.version ?? 1) !== payload.baseVersion
      ) {
        const current = await getEntryEntity(client, context.companyId, id);
        throw new Response(
          JSON.stringify({
            error: "This entry changed on another device.",
            code: "VERSION_CONFLICT",
            current,
          }),
          {
            status: 409,
            headers: { "content-type": "application/json" },
          },
        );
      }

      if (payload.operation === "cancel") {
        return cancelEntry({
          client,
          context,
          id,
          existing,
          operationType,
          operationId: payload.idempotencyKey,
          requestHash,
        });
      }

      if (existing.status === "cancelled") {
        throw jsonResponse("A cancelled entry cannot be edited.", 409);
      }
      if (existing.action === "opening_balance") {
        throw jsonResponse(
          "Edit the opening balance from the statement.",
          409,
        );
      }

      const targetParty = await client.query<{ id: string }>(
        `SELECT id FROM parties
         WHERE id = $1 AND company_id = $2 AND merged_into_id IS NULL
           AND (archived_at IS NULL OR id = $3)
         FOR UPDATE`,
        [payload.partyId, context.companyId, existing.party_id],
      );
      if (!targetParty.rows[0]) {
        throw jsonResponse("Choose an active customer or supplier.", 400);
      }

      const now = new Date().toISOString();
      const effect =
        payload.action === "gave" ? payload.amountPaise : -payload.amountPaise;
      await client.query(
        `INSERT INTO entry_revisions (
           id, entry_id, previous_values, changed_by, changed_at
         ) VALUES ($1, $2, $3::jsonb, $4, $5)`,
        [
          crypto.randomUUID(),
          id,
          JSON.stringify(existing),
          context.userId,
          now,
        ],
      );
      await client.query(
        `UPDATE entries
         SET party_id = $1, action = $2, amount_paise = $3,
             balance_effect_paise = $4, narration = $5, entry_date = $6,
             payment_account = $7, edited_by = $8, edited_at = $9,
             updated_at = $9, version = version + 1
         WHERE id = $10 AND company_id = $11`,
        [
          payload.partyId,
          payload.action,
          payload.amountPaise,
          effect,
          (payload.narration ?? "").trim().slice(0, 240),
          payload.entryDate,
          payload.paymentAccount ?? null,
          context.userId,
          now,
          id,
          context.companyId,
        ],
      );
      const affectedPartyIds = [
        ...new Set([String(existing.party_id), payload.partyId]),
      ];
      await client.query(
        `UPDATE parties
         SET updated_at = $1, version = version + 1
         WHERE company_id = $2 AND id = ANY($3::text[])`,
        [now, context.companyId, affectedPartyIds],
      );
      await client.query(
        `INSERT INTO audit_events (
           id, company_id, actor_user_id, entity_type, entity_id, action,
           details, created_at
         ) VALUES ($1, $2, $3, 'entry', $4, 'edited', $5::jsonb, $6)`,
        [
          crypto.randomUUID(),
          context.companyId,
          context.userId,
          id,
          JSON.stringify({ sequence: existing.sequence }),
          now,
        ],
      );

      const entry = await getEntryEntity(client, context.companyId, id);
      if (!entry) throw new Error("Could not read the updated entry.");
      const affectedParties = await readParties(
        client,
        context.companyId,
        affectedPartyIds,
      );
      await appendSyncChange(client, {
        companyId: context.companyId,
        entityType: "entry",
        entityId: entry.id,
        version: entry.version,
        payload: { entry },
      });
      let changeCursor = "0";
      for (const party of affectedParties) {
        changeCursor = await appendSyncChange(client, {
          companyId: context.companyId,
          entityType: "party",
          entityId: party.id,
          version: party.version,
          payload: { party },
        });
      }
      const party =
        affectedParties.find((item) => item.id === entry.partyId) ?? null;
      const body = {
        ok: true,
        replayed: false,
        entry,
        party,
        affectedParties,
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
      return { body };
    });

    return Response.json(result.body);
  } catch (error) {
    return handleRouteError(error);
  }
}

async function cancelEntry({
  client,
  context,
  id,
  existing,
  operationType,
  operationId,
  requestHash,
}: {
  client: PoolClient;
  context: Awaited<ReturnType<typeof requireMutationContext>>;
  id: string;
  existing: Record<string, unknown>;
  operationType: string;
  operationId?: string;
  requestHash: string;
}) {
  const now = new Date().toISOString();
  await client.query(
    `UPDATE entries
     SET status = 'cancelled', cancelled_by = $1, cancelled_at = $2,
         updated_at = $2, version = version + 1
     WHERE id = $3 AND company_id = $4`,
    [context.userId, now, id, context.companyId],
  );
  await client.query(
    `UPDATE parties
     SET updated_at = $1, version = version + 1
     WHERE id = $2 AND company_id = $3`,
    [now, existing.party_id, context.companyId],
  );
  await client.query(
    `INSERT INTO audit_events (
       id, company_id, actor_user_id, entity_type, entity_id, action,
       details, created_at
     ) VALUES ($1, $2, $3, 'entry', $4, 'cancelled', $5::jsonb, $6)`,
    [
      crypto.randomUUID(),
      context.companyId,
      context.userId,
      id,
      JSON.stringify({ sequence: existing.sequence }),
      now,
    ],
  );
  const entry = await getEntryEntity(client, context.companyId, id);
  const party = await getPartyEntity(
    client,
    context.companyId,
    String(existing.party_id),
  );
  if (!entry || !party) throw new Error("Could not read cancelled entry.");
  await appendSyncChange(client, {
    companyId: context.companyId,
    entityType: "entry",
    entityId: entry.id,
    version: entry.version,
    payload: { entry },
  });
  const changeCursor = await appendSyncChange(client, {
    companyId: context.companyId,
    entityType: "party",
    entityId: party.id,
    version: party.version,
    payload: { party },
  });
  const body = {
    ok: true,
    replayed: false,
    entry,
    party,
    changeCursor,
  };
  if (operationId) {
    await storeOperationReceipt(client, {
      companyId: context.companyId,
      operationId,
      operationType,
      requestHash,
      responseBody: body,
      statusCode: 200,
    });
  }
  return { body };
}

async function readParties(
  client: PoolClient,
  companyId: string,
  ids: string[],
) {
  const parties: Party[] = [];
  for (const id of ids) {
    const party = await getPartyEntity(client, companyId, id);
    if (party) parties.push(party);
  }
  return parties;
}

function validateUpdate(
  payload: Extract<EntryUpdatePayload, { operation: "edit" }>,
) {
  if (!payload.partyId?.trim()) return "Choose a customer or supplier.";
  if (payload.action !== "gave" && payload.action !== "received") {
    return "Choose a valid action.";
  }
  if (
    !Number.isSafeInteger(payload.amountPaise) ||
    payload.amountPaise <= 0 ||
    payload.amountPaise > 99_99_99_99_900
  ) {
    return "Enter a valid amount.";
  }
  if (!isValidDateOnly(payload.entryDate)) {
    return "Choose a valid date.";
  }
  if (
    payload.paymentAccount !== undefined &&
    payload.paymentAccount !== null &&
    payload.paymentAccount !== "cash" &&
    payload.paymentAccount !== "bank"
  ) {
    return "Choose Cash or Bank.";
  }
  return null;
}

function jsonResponse(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}
