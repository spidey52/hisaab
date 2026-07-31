import type { Context } from "hono";
import { and, eq, inArray, isNull, or, sql } from "drizzle-orm";
import type { DbExecutor } from "../db";
import {
  auditEvents,
  companies,
  entries,
  entryRevisions,
  parties,
  withTransaction,
} from "../db";
import { nowDate, toDateOnly } from "../utils/date-utils";
import type { Party } from "../utils/types";
import type { UpdateEntryBody } from "../schema/entries";
import {
  requireServerContext,
  type ServerContext,
} from "../services/server-auth";
import { throwApiError } from "../utils/security";
import { getEntryEntity, getPartyEntity } from "../services/server-entities";
import {
  appendSyncChange,
  idempotencyConflict,
  lockLedgerMutation,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "../services/sync-server";

const createOperationType = "entry.create";

export async function createEntry(c: Context) {
  const request = c.req.raw;
  const context = await requireServerContext(request);
  const payload = c.get("json") as {
    clientId?: string;
    partyId: string;
    action: "gave" | "received";
    amountPaise: number;
    narration?: string;
    entryDate: string;
    paymentAccount?: "cash" | "bank" | null;
    idempotencyKey: string;
  };

  const normalized = {
    clientId: payload.clientId ?? null,
    partyId: payload.partyId,
    action: payload.action,
    amountPaise: payload.amountPaise,
    narration: (payload.narration ?? "").trim().slice(0, 240),
    entryDate: payload.entryDate,
    paymentAccount: payload.paymentAccount ?? null,
  };
  const operationId = payload.idempotencyKey;
  const requestHash = operationRequestHash(createOperationType, normalized);

  const result = await withTransaction(async (client) => {
    await lockOperation(client, context.companyId, operationId);
    const receipt = await readOperationReceipt(
      client,
      context.companyId,
      operationId,
    );
    if (receipt) {
      return {
        body: replayReceipt(receipt, createOperationType, requestHash),
        status: 200,
      };
    }

    await lockLedgerMutation(client, context.companyId);
    const existingRows = await client
      .select()
      .from(entries)
      .where(
        and(
          eq(entries.companyId, context.companyId),
          or(
            eq(entries.idempotencyKey, operationId),
            normalized.clientId
              ? eq(entries.id, normalized.clientId)
              : sql`false`,
          ),
        ),
      )
      .orderBy(sql`(idempotency_key = ${operationId}) DESC`)
      .limit(1);
    const existing = existingRows[0];
    if (existing) {
      if (!entryMatchesCreate(existing, normalized)) {
        idempotencyConflict();
      }
      const entry = await getEntryEntity(
        client,
        context.companyId,
        String(existing.id),
      );
      const party = await getPartyEntity(
        client,
        context.companyId,
        existing.partyId,
      );
      if (!entry || !party) throw new Error("Could not replay the entry.");
      const body = {
        id: entry.id,
        sequence: entry.sequence,
        replayed: false,
        entry,
        party,
      };
      await storeOperationReceipt(client, {
        companyId: context.companyId,
        operationId,
        operationType: createOperationType,
        requestHash,
        responseBody: body,
        statusCode: 200,
      });
      return { body: { ...body, replayed: true }, status: 200 };
    }

    const partyRows = await client
      .select({ id: parties.id })
      .from(parties)
      .where(
        and(
          eq(parties.id, normalized.partyId),
          eq(parties.companyId, context.companyId),
          isNull(parties.archivedAt),
          isNull(parties.mergedIntoId),
        ),
      )
      .for("update");
    if (!partyRows[0]) {
      throwApiError(400, "Choose an active customer or supplier.");
    }

    const sequenceResult = await client
      .update(companies)
      .set({ nextEntryNumber: sql`${companies.nextEntryNumber} + 1` })
      .where(eq(companies.id, context.companyId))
      .returning({
        sequence: sql<number>`${companies.nextEntryNumber} - 1`,
      });
    const sequence = Number(sequenceResult[0]?.sequence);
    if (!Number.isSafeInteger(sequence)) {
      throw new Error("Could not allocate entry number.");
    }

    const entryId = normalized.clientId ?? crypto.randomUUID();
    const now = nowDate();
    const balanceEffectPaise = normalized.action === "gave"
      ? normalized.amountPaise
      : -normalized.amountPaise;
    await client.insert(entries).values({
      id: entryId,
      companyId: context.companyId,
      partyId: normalized.partyId,
      sequence,
      action: normalized.action,
      amountPaise: normalized.amountPaise,
      balanceEffectPaise,
      narration: normalized.narration,
      entryDate: normalized.entryDate,
      paymentAccount: normalized.paymentAccount,
      status: "posted",
      idempotencyKey: operationId,
      createdBy: context.userId,
      createdAt: now,
      updatedAt: now,
      version: 1,
    });
    await client
      .update(parties)
      .set({
        updatedAt: now,
        version: sql`${parties.version} + 1`,
      })
      .where(
        and(
          eq(parties.id, normalized.partyId),
          eq(parties.companyId, context.companyId),
        ),
      );
    await client.insert(auditEvents).values({
      id: crypto.randomUUID(),
      companyId: context.companyId,
      actorUserId: context.userId,
      entityType: "entry",
      entityId: entryId,
      action: "created",
      details: { sequence },
      createdAt: now,
    });

    const entry = await getEntryEntity(
      client,
      context.companyId,
      entryId,
    );
    const party = await getPartyEntity(
      client,
      context.companyId,
      normalized.partyId,
    );
    if (!entry || !party) throw new Error("Could not read the saved entry.");

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
      id: entry.id,
      sequence: entry.sequence,
      replayed: false,
      entry,
      party,
      changeCursor,
    };
    await storeOperationReceipt(client, {
      companyId: context.companyId,
      operationId,
      operationType: createOperationType,
      requestHash,
      responseBody: body,
      statusCode: 201,
    });
    return { body, status: 201 };
  });

  return Response.json(result.body, { status: result.status });
}

export async function updateEntry(c: Context) {
  const request = c.req.raw;
  const context = await requireServerContext(request);
  const { id } = c.get("params") as { id: string };
  const payload = c.get("json") as UpdateEntryBody;
  const editPayload = payload.operation === "edit" ? payload : null;

  const operationType = `entry.${payload.operation}`;
  const normalizedIntent = payload.operation === "cancel"
    ? { entryId: id, operation: "cancel" as const }
    : {
      entryId: id,
      operation: "edit" as const,
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
    const existingRows = await client
      .select()
      .from(entries)
      .where(and(eq(entries.id, id), eq(entries.companyId, context.companyId)))
      .for("update");
    const existing = existingRows[0];
    if (!existing) {
      throwApiError(404, "Entry not found.");
    }

    if (payload.operation === "cancel" && existing.status === "cancelled") {
      const entry = await getEntryEntity(client, context.companyId, id);
      const party = await getPartyEntity(
        client,
        context.companyId,
        existing.partyId,
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
      throwApiError(409, "This entry changed on another device.", {
        code: "VERSION_CONFLICT",
        context: { current },
      });
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
    if (!editPayload) {
      throw new Error("Invalid entry edit payload.");
    }

    if (existing.status === "cancelled") {
      throwApiError(409, "A cancelled entry cannot be edited.");
    }
    if (existing.action === "opening_balance") {
      throwApiError(409, "Edit the opening balance from the statement.");
    }

    const targetPartyRows = await client
      .select({ id: parties.id })
      .from(parties)
      .where(
        and(
          eq(parties.id, editPayload.partyId),
          eq(parties.companyId, context.companyId),
          isNull(parties.mergedIntoId),
          or(isNull(parties.archivedAt), eq(parties.id, existing.partyId)),
        ),
      )
      .for("update");
    if (!targetPartyRows[0]) {
      throwApiError(400, "Choose an active customer or supplier.");
    }

    const now = nowDate();
    const effect = editPayload.action === "gave"
      ? editPayload.amountPaise
      : -editPayload.amountPaise;
    await client.insert(entryRevisions).values({
      id: crypto.randomUUID(),
      entryId: id,
      previousValues: existing,
      changedBy: context.userId,
      changedAt: now,
    });
    await client
      .update(entries)
      .set({
        partyId: editPayload.partyId,
        action: editPayload.action,
        amountPaise: editPayload.amountPaise,
        balanceEffectPaise: effect,
        narration: (editPayload.narration ?? "").trim().slice(0, 240),
        entryDate: editPayload.entryDate,
        paymentAccount: editPayload.paymentAccount ?? null,
        editedBy: context.userId,
        editedAt: now,
        updatedAt: now,
        version: sql`${entries.version} + 1`,
      })
      .where(and(eq(entries.id, id), eq(entries.companyId, context.companyId)));
    const affectedPartyIds = [
      ...new Set([existing.partyId, editPayload.partyId]),
    ];
    await client
      .update(parties)
      .set({
        updatedAt: now,
        version: sql`${parties.version} + 1`,
      })
      .where(
        and(
          eq(parties.companyId, context.companyId),
          inArray(parties.id, affectedPartyIds),
        ),
      );
    await client.insert(auditEvents).values({
      id: crypto.randomUUID(),
      companyId: context.companyId,
      actorUserId: context.userId,
      entityType: "entry",
      entityId: id,
      action: "edited",
      details: { sequence: existing.sequence },
      createdAt: now,
    });

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
    const party = affectedParties.find((item) => item.id === entry.partyId) ??
      null;
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

  return c.json(result.body);
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
  client: DbExecutor;
  context: ServerContext;
  id: string;
  existing: typeof entries.$inferSelect;
  operationType: string;
  operationId?: string;
  requestHash: string;
}) {
  const now = nowDate();
  await client
    .update(entries)
    .set({
      status: "cancelled",
      cancelledBy: context.userId,
      cancelledAt: now,
      updatedAt: now,
      version: sql`${entries.version} + 1`,
    })
    .where(and(eq(entries.id, id), eq(entries.companyId, context.companyId)));
  await client
    .update(parties)
    .set({
      updatedAt: now,
      version: sql`${parties.version} + 1`,
    })
    .where(
      and(
        eq(parties.id, existing.partyId),
        eq(parties.companyId, context.companyId),
      ),
    );
  await client.insert(auditEvents).values({
    id: crypto.randomUUID(),
    companyId: context.companyId,
    actorUserId: context.userId,
    entityType: "entry",
    entityId: id,
    action: "cancelled",
    details: { sequence: existing.sequence },
    createdAt: now,
  });
  const entry = await getEntryEntity(client, context.companyId, id);
  const party = await getPartyEntity(
    client,
    context.companyId,
    existing.partyId,
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
  client: DbExecutor,
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

function entryMatchesCreate(
  existing: typeof entries.$inferSelect,
  expected: {
    clientId: string | null;
    partyId: string;
    action: "gave" | "received";
    amountPaise: number;
    narration: string;
    entryDate: string;
    paymentAccount: "cash" | "bank" | null;
  },
) {
  return (
    (!expected.clientId || existing.id === expected.clientId) &&
    existing.partyId === expected.partyId &&
    existing.action === expected.action &&
    Number(existing.amountPaise) === expected.amountPaise &&
    String(existing.narration ?? "") === expected.narration &&
    toDateOnly(existing.entryDate) === expected.entryDate &&
    (existing.paymentAccount ? String(existing.paymentAccount) : null) ===
      expected.paymentAccount
  );
}
