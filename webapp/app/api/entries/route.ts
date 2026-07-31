import { withTransaction } from "@/db";
import { isValidDateOnly, toDateOnly } from "@/lib/date-utils";
import { readJsonBody } from "@/lib/request-security";
import {
  handleRouteError,
  requireMutationContext,
} from "@/lib/server-auth";
import { getEntryEntity, getPartyEntity } from "@/lib/server-entities";
import {
  appendSyncChange,
  idempotencyConflict,
  isUuid,
  isValidOperationId,
  lockLedgerMutation,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "@/lib/sync-server";

type EntryPayload = {
  clientId?: string;
  partyId?: string;
  action?: "gave" | "received";
  amountPaise?: number;
  narration?: string;
  entryDate?: string;
  paymentAccount?: "cash" | "bank" | null;
  idempotencyKey?: string;
};

const operationType = "entry.create";

export async function POST(request: Request) {
  try {
    const context = await requireMutationContext(request);
    const payload = await readJsonBody<EntryPayload>(request);
    const validation = validateEntry(payload);
    if (validation) {
      return Response.json({ error: validation }, { status: 400 });
    }

    const normalized = {
      clientId: payload.clientId ?? null,
      partyId: payload.partyId!,
      action: payload.action!,
      amountPaise: payload.amountPaise!,
      narration: (payload.narration ?? "").trim().slice(0, 240),
      entryDate: payload.entryDate!,
      paymentAccount: payload.paymentAccount ?? null,
    };
    const operationId = payload.idempotencyKey!;
    const requestHash = operationRequestHash(operationType, normalized);

    const result = await withTransaction(async (client) => {
      await lockOperation(client, context.companyId, operationId);
      const receipt = await readOperationReceipt(
        client,
        context.companyId,
        operationId,
      );
      if (receipt) {
        return {
          body: replayReceipt(receipt, operationType, requestHash),
          status: 200,
        };
      }

      await lockLedgerMutation(client, context.companyId);
      const existingResult = await client.query<Record<string, unknown>>(
        `SELECT * FROM entries
         WHERE company_id = $1
           AND (idempotency_key = $2 OR ($3::text IS NOT NULL AND id = $3))
         ORDER BY (idempotency_key = $2) DESC
         LIMIT 1`,
        [context.companyId, operationId, normalized.clientId],
      );
      const existing = existingResult.rows[0];
      if (existing) {
        if (!entryMatchesCreate(existing, normalized)) {
          throw idempotencyConflict();
        }
        const entry = await getEntryEntity(
          client,
          context.companyId,
          String(existing.id),
        );
        const party = await getPartyEntity(
          client,
          context.companyId,
          String(existing.party_id),
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
          operationType,
          requestHash,
          responseBody: body,
          statusCode: 200,
        });
        return { body: { ...body, replayed: true }, status: 200 };
      }

      const partyResult = await client.query<{ id: string }>(
        `SELECT id FROM parties
         WHERE id = $1 AND company_id = $2 AND archived_at IS NULL
           AND merged_into_id IS NULL
         FOR UPDATE`,
        [normalized.partyId, context.companyId],
      );
      if (!partyResult.rows[0]) {
        throw new Response(
          JSON.stringify({
            error: "Choose an active customer or supplier.",
          }),
          {
            status: 400,
            headers: { "content-type": "application/json" },
          },
        );
      }

      const sequenceResult = await client.query<{ sequence: number }>(
        `UPDATE companies
         SET next_entry_number = next_entry_number + 1
         WHERE id = $1
         RETURNING next_entry_number - 1 AS sequence`,
        [context.companyId],
      );
      const sequence = Number(sequenceResult.rows[0]?.sequence);
      if (!Number.isSafeInteger(sequence)) {
        throw new Error("Could not allocate entry number.");
      }

      const entryId = normalized.clientId ?? crypto.randomUUID();
      const now = new Date().toISOString();
      const balanceEffectPaise =
        normalized.action === "gave"
          ? normalized.amountPaise
          : -normalized.amountPaise;
      await client.query(
        `INSERT INTO entries (
           id, company_id, party_id, sequence, action, amount_paise,
           balance_effect_paise, narration, entry_date, payment_account,
           status, idempotency_key, created_by, created_at, updated_at, version
         ) VALUES (
           $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
           'posted', $11, $12, $13, $13, 1
         )`,
        [
          entryId,
          context.companyId,
          normalized.partyId,
          sequence,
          normalized.action,
          normalized.amountPaise,
          balanceEffectPaise,
          normalized.narration,
          normalized.entryDate,
          normalized.paymentAccount,
          operationId,
          context.userId,
          now,
        ],
      );
      await client.query(
        `UPDATE parties
         SET updated_at = $1, version = version + 1
         WHERE id = $2 AND company_id = $3`,
        [now, normalized.partyId, context.companyId],
      );
      await client.query(
        `INSERT INTO audit_events (
           id, company_id, actor_user_id, entity_type, entity_id, action,
           details, created_at
         ) VALUES ($1, $2, $3, 'entry', $4, 'created', $5::jsonb, $6)`,
        [
          crypto.randomUUID(),
          context.companyId,
          context.userId,
          entryId,
          JSON.stringify({ sequence }),
          now,
        ],
      );

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
        operationType,
        requestHash,
        responseBody: body,
        statusCode: 201,
      });
      return { body, status: 201 };
    });

    return Response.json(result.body, { status: result.status });
  } catch (error) {
    return handleRouteError(error);
  }
}

function validateEntry(payload: EntryPayload) {
  if (payload.clientId !== undefined && !isUuid(payload.clientId)) {
    return "This entry has an invalid client identifier.";
  }
  if (!payload.partyId?.trim()) return "Choose a customer or supplier.";
  if (payload.action !== "gave" && payload.action !== "received") {
    return "Choose whether you gave or got money.";
  }
  if (
    !Number.isSafeInteger(payload.amountPaise) ||
    (payload.amountPaise ?? 0) <= 0 ||
    (payload.amountPaise ?? 0) > 99_99_99_99_900
  ) {
    return "Enter a valid amount.";
  }
  if (!isValidDateOnly(payload.entryDate)) {
    return "Choose a valid date.";
  }
  if (!isValidOperationId(payload.idempotencyKey)) {
    return "This entry could not be safely identified. Please try again.";
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

function entryMatchesCreate(
  existing: Record<string, unknown>,
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
    (!expected.clientId || String(existing.id) === expected.clientId) &&
    String(existing.party_id) === expected.partyId &&
    existing.action === expected.action &&
    Number(existing.amount_paise) === expected.amountPaise &&
    String(existing.narration ?? "") === expected.narration &&
    toDateOnly(existing.entry_date) === expected.entryDate &&
    (existing.payment_account ? String(existing.payment_account) : null) ===
      expected.paymentAccount
  );
}
