import { withTransaction } from "@/db";
import { normalizeOptionalPhone } from "@/lib/phone-normalization";
import { readJsonBody } from "@/lib/request-security";
import {
  handleRouteError,
  requireMutationContext,
} from "@/lib/server-auth";
import { getPartyEntity } from "@/lib/server-entities";
import {
  appendSyncChange,
  idempotencyConflict,
  isUuid,
  isValidOperationId,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "@/lib/sync-server";

type PartyPayload = {
  clientId?: string;
  idempotencyKey?: string;
  name?: string;
  phone?: string;
  shortName?: string;
  notes?: string;
  groupId?: string | null;
  confirmDuplicate?: boolean;
};

const operationType = "party.create";

export async function POST(request: Request) {
  try {
    const context = await requireMutationContext(request);
    const payload = await readJsonBody<PartyPayload>(request);
    const name = clean(payload.name, 100);
    const phone = cleanPhone(payload.phone);
    const phoneE164 = normalizeOptionalPhone(phone);
    const shortName = clean(payload.shortName, 100);
    const notes = clean(payload.notes, 500);
    const groupId = clean(payload.groupId, 80) || null;

    if (name.length < 2) {
      return Response.json(
        { error: "Enter a name with at least 2 characters." },
        { status: 400 },
      );
    }
    if (payload.clientId !== undefined && !isUuid(payload.clientId)) {
      return Response.json(
        { error: "This party has an invalid client identifier." },
        { status: 400 },
      );
    }
    if (
      payload.idempotencyKey !== undefined &&
      !isValidOperationId(payload.idempotencyKey)
    ) {
      return Response.json(
        { error: "This party has an invalid operation identifier." },
        { status: 400 },
      );
    }

    const normalized = {
      clientId: payload.clientId ?? null,
      name,
      phone,
      phoneE164,
      shortName,
      notes,
      groupId,
    };
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
          `party-client:${payload.clientId}`,
        );
        const existingById = await client.query<Record<string, unknown>>(
          `SELECT * FROM parties
           WHERE id = $1 AND company_id = $2`,
          [payload.clientId, context.companyId],
        );
        const existing = existingById.rows[0];
        if (existing) {
          if (!partyMatchesCreate(existing, normalized)) {
            throw idempotencyConflict();
          }
          const party = await getPartyEntity(
            client,
            context.companyId,
            payload.clientId,
          );
          if (!party) throw new Error("Could not replay the saved party.");
          const cursorResult = await client.query<{ cursor: string }>(
            `SELECT COALESCE(MAX(id), 0)::text AS cursor
             FROM sync_changes WHERE company_id = $1`,
            [context.companyId],
          );
          const body = {
            id: party.id,
            reference: party.reference,
            replayed: false,
            party,
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

      if (groupId) {
        const group = await client.query(
          `SELECT id FROM party_groups
           WHERE id = $1 AND company_id = $2`,
          [groupId, context.companyId],
        );
        if (!group.rows[0]) {
          throw jsonResponse("That group is no longer available.", 400);
        }
      }

      const duplicateResult = await client.query<Record<string, unknown>>(
        `SELECT id, name, phone, reference
         FROM parties
         WHERE company_id = $1 AND merged_into_id IS NULL
           AND (
             lower(name) = lower($2)
             OR (short_name <> '' AND lower(short_name) = lower($3))
             OR ($4::text IS NOT NULL AND phone_e164 = $4)
           )
         LIMIT 5`,
        [
          context.companyId,
          name,
          shortName || name,
          phoneE164,
        ],
      );
      if (duplicateResult.rows.length > 0 && !payload.confirmDuplicate) {
        throw new Response(
          JSON.stringify({
            error: "This customer or supplier may already exist.",
            code: "DUPLICATE_WARNING",
            duplicates: duplicateResult.rows.map((row) => ({
              id: String(row.id),
              name: String(row.name),
              phone: String(row.phone ?? ""),
              reference: String(row.reference),
            })),
          }),
          {
            status: 409,
            headers: { "content-type": "application/json" },
          },
        );
      }

      const partyId = payload.clientId ?? crypto.randomUUID();
      const reference = `HSB-${partyId.replaceAll("-", "").slice(0, 8).toUpperCase()}`;
      const now = new Date().toISOString();
      await client.query(
        `INSERT INTO parties (
           id, company_id, reference, name, short_name, phone, phone_e164,
           notes, group_id, created_by, created_at, updated_at, version
         ) VALUES (
           $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $11, 1
         )`,
        [
          partyId,
          context.companyId,
          reference,
          name,
          shortName,
          phone,
          phoneE164,
          notes,
          groupId,
          context.userId,
          now,
        ],
      );
      await client.query(
        `INSERT INTO audit_events (
           id, company_id, actor_user_id, entity_type, entity_id, action,
           details, created_at
         ) VALUES ($1, $2, $3, 'party', $4, 'created', $5::jsonb, $6)`,
        [
          crypto.randomUUID(),
          context.companyId,
          context.userId,
          partyId,
          JSON.stringify({ name, reference }),
          now,
        ],
      );
      const party = await getPartyEntity(
        client,
        context.companyId,
        partyId,
      );
      if (!party) throw new Error("Could not read the saved party.");
      const changeCursor = await appendSyncChange(client, {
        companyId: context.companyId,
        entityType: "party",
        entityId: party.id,
        version: party.version,
        payload: { party },
      });
      const body = {
        id: party.id,
        reference: party.reference,
        replayed: false,
        party,
        changeCursor,
      };
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

function clean(value: unknown, max: number) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

function cleanPhone(value: unknown) {
  return clean(value, 30).replace(/[^0-9+ ()-]/g, "");
}

function partyMatchesCreate(
  existing: Record<string, unknown>,
  expected: {
    clientId: string | null;
    name: string;
    phone: string;
    phoneE164: string | null;
    shortName: string;
    notes: string;
    groupId: string | null;
  },
) {
  return (
    (!expected.clientId || String(existing.id) === expected.clientId) &&
    String(existing.name) === expected.name &&
    String(existing.phone ?? "") === expected.phone &&
    (existing.phone_e164 ? String(existing.phone_e164) : null) ===
      expected.phoneE164 &&
    String(existing.short_name ?? "") === expected.shortName &&
    String(existing.notes ?? "") === expected.notes &&
    (existing.group_id ? String(existing.group_id) : null) === expected.groupId
  );
}

function jsonResponse(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}
