import { createHash } from "node:crypto";
import { and, eq, sql } from "drizzle-orm";
import { type DbExecutor, operationReceipts, syncChanges } from "../db";
import { throwApiError } from "../utils/security";

export type OperationReceipt = {
  operationType: string;
  requestHash: string;
  responseBody: Record<string, unknown>;
  statusCode: number;
};

export function operationRequestHash(
  operationType: string,
  payload: unknown,
) {
  return createHash("sha256")
    .update(`${operationType}\n${stableJson(payload)}`)
    .digest("hex");
}

export async function lockOperation(
  client: DbExecutor,
  companyId: string,
  operationId: string,
) {
  await client.execute(
    sql`SELECT pg_advisory_xact_lock(hashtextextended(${`operation:${companyId}:${operationId}`}, 0))`,
  );
}

/**
 * Financial mutations take this company-scoped lock before row locks. It keeps
 * party, company-sequence, and entry updates in one deterministic order and
 * avoids cross-endpoint deadlocks while offline operations are replayed.
 */
export async function lockLedgerMutation(
  client: DbExecutor,
  companyId: string,
) {
  await client.execute(
    sql`SELECT pg_advisory_xact_lock(hashtextextended(${`ledger:${companyId}`}, 0))`,
  );
}

export async function readOperationReceipt(
  client: DbExecutor,
  companyId: string,
  operationId: string,
): Promise<OperationReceipt | null> {
  const rows = await client
    .select({
      operationType: operationReceipts.operationType,
      requestHash: operationReceipts.requestHash,
      responseBody: operationReceipts.responseBody,
      statusCode: operationReceipts.statusCode,
    })
    .from(operationReceipts)
    .where(
      and(
        eq(operationReceipts.companyId, companyId),
        eq(operationReceipts.operationId, operationId),
      ),
    )
    .limit(1);
  const row = rows[0];
  if (!row) return null;
  const responseBody = typeof row.responseBody === "string"
    ? (JSON.parse(row.responseBody) as Record<string, unknown>)
    : (row.responseBody as Record<string, unknown>);
  return {
    operationType: row.operationType,
    requestHash: row.requestHash,
    responseBody,
    statusCode: row.statusCode,
  };
}

export function replayReceipt(
  receipt: OperationReceipt,
  operationType: string,
  requestHash: string,
) {
  if (
    receipt.operationType !== operationType ||
    receipt.requestHash !== requestHash
  ) {
    idempotencyConflict();
  }
  return {
    ...receipt.responseBody,
    replayed: true,
  };
}

export async function storeOperationReceipt(
  client: DbExecutor,
  values: {
    companyId: string;
    operationId: string;
    operationType: string;
    requestHash: string;
    responseBody: Record<string, unknown>;
    statusCode: number;
  },
) {
  await client.insert(operationReceipts).values({
    companyId: values.companyId,
    operationId: values.operationId,
    operationType: values.operationType,
    requestHash: values.requestHash,
    responseBody: values.responseBody,
    statusCode: values.statusCode,
  });
}

export async function appendSyncChange(
  client: DbExecutor,
  values: {
    companyId: string;
    entityType: string;
    entityId: string;
    changeType?: "upsert" | "tombstone";
    version: number;
    payload: Record<string, unknown>;
  },
) {
  const rows = await client
    .insert(syncChanges)
    .values({
      companyId: values.companyId,
      entityType: values.entityType,
      entityId: values.entityId,
      changeType: values.changeType ?? "upsert",
      entityVersion: values.version,
      payload: values.payload,
    })
    .returning({ id: syncChanges.id });
  return String(rows[0]!.id);
}

export async function appendSyncChanges(
  client: DbExecutor,
  companyId: string,
  changes: {
    entityType: string;
    entityId: string;
    changeType?: "upsert" | "tombstone";
    version: number;
    payload: Record<string, unknown>;
  }[],
) {
  if (changes.length === 0) return "0";
  const rows = await client
    .insert(syncChanges)
    .values(
      changes.map((change) => ({
        companyId,
        entityType: change.entityType,
        entityId: change.entityId,
        changeType: change.changeType ?? "upsert",
        entityVersion: change.version,
        payload: change.payload,
      })),
    )
    .returning({ id: syncChanges.id });
  const maxId = rows.reduce((max, row) => Math.max(max, Number(row.id)), 0);
  return String(maxId);
}

export function idempotencyConflict() {
  throwApiError(
    409,
    "This operation identifier was already used for different details.",
    {
      code: "IDEMPOTENCY_CONFLICT",
    },
  );
}

export function stableJson(value: unknown): string {
  if (value === undefined) return "null";
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value) as string;
  }
  if (Array.isArray(value)) {
    return `[${value.map(stableJson).join(",")}]`;
  }
  return `{${
    Object.entries(value as Record<string, unknown>)
      .filter(([, item]) => item !== undefined)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, item]) => `${JSON.stringify(key)}:${stableJson(item)}`)
      .join(",")
  }}`;
}
