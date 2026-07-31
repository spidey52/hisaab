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

type OpeningBalancePayload = {
  clientId?: string;
  partyId?: string;
  amountPaise?: number;
  direction?: "receive" | "pay";
  entryDate?: string;
  idempotencyKey?: string;
  baseVersion?: number;
};

const operationType = "opening_balance.save";

export async function POST(request: Request) {
  try {
    const context = await requireMutationContext(request);
    const payload = await readJsonBody<OpeningBalancePayload>(request);
    const validation = validateOpeningBalance(payload);
    if (validation) {
      return Response.json({ error: validation }, { status: 400 });
    }

    const normalized = {
      clientId: payload.clientId ?? null,
      partyId: payload.partyId!,
      amountPaise: payload.amountPaise!,
      direction: payload.direction!,
      entryDate: payload.entryDate!,
    };
    const operationId = payload.idempotencyKey ?? `opening-${crypto.randomUUID()}`;
    const requestHash = operationRequestHash(operationType, normalized);

    const result = await withTransaction(async (client) => {
      await lockOperation(client, context.companyId, operationId);
      if (payload.idempotencyKey) {
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
      }

      await lockLedgerMutation(client, context.companyId);
      if (payload.idempotencyKey) {
        const legacyResult = await client.query<Record<string, unknown>>(
          `SELECT * FROM entries
           WHERE company_id = $1 AND idempotency_key = $2`,
          [context.companyId, operationId],
        );
        const legacy = legacyResult.rows[0];
        if (legacy) {
          if (!openingMatches(legacy, normalized)) {
            throw idempotencyConflict();
          }
          const entry = await getEntryEntity(
            client,
            context.companyId,
            String(legacy.id),
          );
          const party = await getPartyEntity(
            client,
            context.companyId,
            String(legacy.party_id),
          );
          if (!entry || !party) throw new Error("Could not replay balance.");
          const body = {
            id: entry.id,
            sequence: entry.sequence,
            updated: false,
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
      }

      const partyResult = await client.query<{ id: string }>(
        `SELECT id FROM parties
         WHERE id = $1 AND company_id = $2
           AND merged_into_id IS NULL AND archived_at IS NULL
         FOR UPDATE`,
        [normalized.partyId, context.companyId],
      );
      if (!partyResult.rows[0]) {
        throw jsonResponse("Customer or supplier not found.", 404);
      }

      const existingResult = await client.query<Record<string, unknown>>(
        `SELECT * FROM entries
         WHERE company_id = $1 AND party_id = $2
           AND action = 'opening_balance' AND status = 'posted'
         ORDER BY sequence
         LIMIT 1
         FOR UPDATE`,
        [context.companyId, normalized.partyId],
      );
      const existing = existingResult.rows[0];
      if (existing && openingMatches(existing, normalized)) {
        const entry = await getEntryEntity(
          client,
          context.companyId,
          String(existing.id),
        );
        const party = await getPartyEntity(
          client,
          context.companyId,
          normalized.partyId,
        );
        if (!entry || !party) throw new Error("Could not replay balance.");
        const cursorResult = await client.query<{ cursor: string }>(
          `SELECT COALESCE(MAX(id), 0)::text AS cursor
           FROM sync_changes WHERE company_id = $1`,
          [context.companyId],
        );
        const body = {
          id: entry.id,
          sequence: entry.sequence,
          updated: true,
          replayed: false,
          entry,
          party,
          changeCursor: cursorResult.rows[0]?.cursor ?? "0",
        };
        if (payload.idempotencyKey) {
          await storeOperationReceipt(client, {
            companyId: context.companyId,
            operationId,
            operationType,
            requestHash,
            responseBody: body,
            statusCode: 200,
          });
        }
        return { body: { ...body, replayed: true }, status: 200 };
      }
      if (
        existing &&
        payload.baseVersion !== undefined &&
        Number(existing.version ?? 1) !== payload.baseVersion
      ) {
        const current = await getEntryEntity(
          client,
          context.companyId,
          String(existing.id),
        );
        throw new Response(
          JSON.stringify({
            error: "The opening balance changed on another device.",
            code: "VERSION_CONFLICT",
            current,
          }),
          {
            status: 409,
            headers: { "content-type": "application/json" },
          },
        );
      }

      const now = new Date().toISOString();
      const effect =
        normalized.direction === "receive"
          ? normalized.amountPaise
          : -normalized.amountPaise;
      let entryId: string;
      let sequence: number;
      let updated: boolean;

      if (existing) {
        entryId = String(existing.id);
        sequence = Number(existing.sequence);
        updated = true;
        await client.query(
          `INSERT INTO entry_revisions (
             id, entry_id, previous_values, changed_by, changed_at
           ) VALUES ($1, $2, $3::jsonb, $4, $5)`,
          [
            crypto.randomUUID(),
            entryId,
            JSON.stringify(existing),
            context.userId,
            now,
          ],
        );
        await client.query(
          `UPDATE entries
           SET amount_paise = $1, balance_effect_paise = $2,
               entry_date = $3, edited_by = $4, edited_at = $5,
               updated_at = $5, version = version + 1
           WHERE id = $6 AND company_id = $7`,
          [
            normalized.amountPaise,
            effect,
            normalized.entryDate,
            context.userId,
            now,
            entryId,
            context.companyId,
          ],
        );
      } else {
        const sequenceResult = await client.query<{ sequence: number }>(
          `UPDATE companies
           SET next_entry_number = next_entry_number + 1
           WHERE id = $1
           RETURNING next_entry_number - 1 AS sequence`,
          [context.companyId],
        );
        sequence = Number(sequenceResult.rows[0]?.sequence);
        if (!Number.isSafeInteger(sequence)) {
          throw new Error("Could not allocate entry number.");
        }
        entryId = normalized.clientId ?? crypto.randomUUID();
        updated = false;
        await client.query(
          `INSERT INTO entries (
             id, company_id, party_id, sequence, action, amount_paise,
             balance_effect_paise, narration, entry_date, status,
             idempotency_key, created_by, created_at, updated_at, version
           ) VALUES (
             $1, $2, $3, $4, 'opening_balance', $5, $6,
             'Opening balance', $7, 'posted', $8, $9, $10, $10, 1
           )`,
          [
            entryId,
            context.companyId,
            normalized.partyId,
            sequence,
            normalized.amountPaise,
            effect,
            normalized.entryDate,
            operationId,
            context.userId,
            now,
          ],
        );
      }

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
         ) VALUES ($1, $2, $3, 'entry', $4, $5, $6::jsonb, $7)`,
        [
          crypto.randomUUID(),
          context.companyId,
          context.userId,
          entryId,
          updated ? "opening_balance_edited" : "opening_balance_created",
          JSON.stringify({ sequence, amountPaise: normalized.amountPaise }),
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
      if (!entry || !party) throw new Error("Could not read opening balance.");
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
        updated,
        replayed: false,
        entry,
        party,
        changeCursor,
      };
      if (payload.idempotencyKey) {
        await storeOperationReceipt(client, {
          companyId: context.companyId,
          operationId,
          operationType,
          requestHash,
          responseBody: body,
          statusCode: updated ? 200 : 201,
        });
      }
      return { body, status: updated ? 200 : 201 };
    });

    return Response.json(result.body, { status: result.status });
  } catch (error) {
    return handleRouteError(error);
  }
}

function validateOpeningBalance(payload: OpeningBalancePayload) {
  if (payload.clientId !== undefined && !isUuid(payload.clientId)) {
    return "This opening balance has an invalid client identifier.";
  }
  if (
    !payload.partyId ||
    !Number.isSafeInteger(payload.amountPaise) ||
    (payload.amountPaise ?? -1) < 0 ||
    (payload.amountPaise ?? 0) > 99_99_99_99_900 ||
    (payload.direction !== "receive" && payload.direction !== "pay") ||
    !isValidDateOnly(payload.entryDate)
  ) {
    return "Enter a valid opening balance.";
  }
  if (
    payload.idempotencyKey !== undefined &&
    !isValidOperationId(payload.idempotencyKey)
  ) {
    return "This opening balance has an invalid operation identifier.";
  }
  if (
    payload.baseVersion !== undefined &&
    (!Number.isSafeInteger(payload.baseVersion) || payload.baseVersion < 1)
  ) {
    return "This opening balance version is invalid.";
  }
  return null;
}

function openingMatches(
  row: Record<string, unknown>,
  expected: {
    clientId: string | null;
    partyId: string;
    amountPaise: number;
    direction: "receive" | "pay";
    entryDate: string;
  },
) {
  const effect =
    expected.direction === "receive"
      ? expected.amountPaise
      : -expected.amountPaise;
  return (
    row.action === "opening_balance" &&
    (!expected.clientId || String(row.id) === expected.clientId) &&
    String(row.party_id) === expected.partyId &&
    Number(row.amount_paise) === expected.amountPaise &&
    Number(row.balance_effect_paise) === effect &&
    toDateOnly(row.entry_date) === expected.entryDate
  );
}

function jsonResponse(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}
