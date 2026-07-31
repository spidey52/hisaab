import { createHash } from "node:crypto";
import type { PoolClient } from "pg";

export type OperationReceipt = {
  operationType: string;
  requestHash: string;
  responseBody: Record<string, unknown>;
  statusCode: number;
};

export function isValidOperationId(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length >= 12 &&
    value.length <= 100 &&
    /^[A-Za-z0-9._:-]+$/.test(value)
  );
}

export function isUuid(value: unknown): value is string {
  return (
    typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    )
  );
}

export function operationRequestHash(
  operationType: string,
  payload: unknown,
) {
  return createHash("sha256")
    .update(`${operationType}\n${stableJson(payload)}`)
    .digest("hex");
}

export async function lockOperation(
  client: PoolClient,
  companyId: string,
  operationId: string,
) {
  await client.query(
    "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
    [`operation:${companyId}:${operationId}`],
  );
}

/**
 * Financial mutations take this company-scoped lock before row locks. It keeps
 * party, company-sequence, and entry updates in one deterministic order and
 * avoids cross-endpoint deadlocks while offline operations are replayed.
 */
export async function lockLedgerMutation(
  client: PoolClient,
  companyId: string,
) {
  await client.query(
    "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
    [`ledger:${companyId}`],
  );
}

export async function readOperationReceipt(
  client: PoolClient,
  companyId: string,
  operationId: string,
): Promise<OperationReceipt | null> {
  const result = await client.query<{
    operation_type: string;
    request_hash: string;
    response_body: Record<string, unknown> | string;
    status_code: number;
  }>(
    `SELECT operation_type, request_hash, response_body, status_code
     FROM operation_receipts
     WHERE company_id = $1 AND operation_id = $2`,
    [companyId, operationId],
  );
  const row = result.rows[0];
  if (!row) return null;
  const responseBody =
    typeof row.response_body === "string"
      ? (JSON.parse(row.response_body) as Record<string, unknown>)
      : row.response_body;
  return {
    operationType: row.operation_type,
    requestHash: row.request_hash,
    responseBody,
    statusCode: row.status_code,
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
    throw idempotencyConflict();
  }
  return {
    ...receipt.responseBody,
    replayed: true,
  };
}

export async function storeOperationReceipt(
  client: PoolClient,
  values: {
    companyId: string;
    operationId: string;
    operationType: string;
    requestHash: string;
    responseBody: Record<string, unknown>;
    statusCode: number;
  },
) {
  await client.query(
    `INSERT INTO operation_receipts (
       company_id, operation_id, operation_type, request_hash,
       response_body, status_code
     ) VALUES ($1, $2, $3, $4, $5::jsonb, $6)`,
    [
      values.companyId,
      values.operationId,
      values.operationType,
      values.requestHash,
      JSON.stringify(values.responseBody),
      values.statusCode,
    ],
  );
}

export async function appendSyncChange(
  client: PoolClient,
  values: {
    companyId: string;
    entityType: string;
    entityId: string;
    changeType?: "upsert" | "tombstone";
    version: number;
    payload: Record<string, unknown>;
  },
) {
  const result = await client.query<{ cursor: string }>(
    `INSERT INTO sync_changes (
       company_id, entity_type, entity_id, change_type, entity_version, payload
     ) VALUES ($1, $2, $3, $4, $5, $6::jsonb)
     RETURNING id::text AS cursor`,
    [
      values.companyId,
      values.entityType,
      values.entityId,
      values.changeType ?? "upsert",
      values.version,
      JSON.stringify(values.payload),
    ],
  );
  return result.rows[0]!.cursor;
}

export async function appendSyncChanges(
  client: PoolClient,
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
  const result = await client.query<{ cursor: string }>(
    `WITH inserted AS (
       INSERT INTO sync_changes (
         company_id, entity_type, entity_id, change_type,
         entity_version, payload
       )
       SELECT
         $1,
         item->>'entityType',
         item->>'entityId',
         COALESCE(item->>'changeType', 'upsert'),
         (item->>'version')::bigint,
         item->'payload'
       FROM jsonb_array_elements($2::jsonb) AS item
       RETURNING id
     )
     SELECT MAX(id)::text AS cursor FROM inserted`,
    [
      companyId,
      JSON.stringify(
        changes.map((change) => ({
          ...change,
          changeType: change.changeType ?? "upsert",
        })),
      ),
    ],
  );
  return result.rows[0]?.cursor ?? "0";
}

export function idempotencyConflict() {
  return new Response(
    JSON.stringify({
      error:
        "This operation identifier was already used for different details.",
      code: "IDEMPOTENCY_CONFLICT",
    }),
    {
      status: 409,
      headers: {
        "cache-control": "no-store",
        "content-type": "application/json",
      },
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
  return `{${Object.entries(value as Record<string, unknown>)
    .filter(([, item]) => item !== undefined)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, item]) => `${JSON.stringify(key)}:${stableJson(item)}`)
    .join(",")}}`;
}
