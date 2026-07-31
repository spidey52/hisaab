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
  isValidOperationId,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "@/lib/sync-server";

type UpdatePayload = {
  name?: string;
  phone?: string;
  shortName?: string;
  notes?: string;
  groupId?: string | null;
  archived?: boolean;
  idempotencyKey?: string;
  baseVersion?: number;
};

const operationType = "party.update";

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const context = await requireMutationContext(request);
    const { id } = await params;
    const payload = await readJsonBody<UpdatePayload>(request);
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
        { error: "This party version is invalid." },
        { status: 400 },
      );
    }
    const intent = {
      partyId: id,
      name: cleanOptional(payload.name, 100),
      phone: cleanOptional(payload.phone, 30)?.replace(/[^0-9+ ()-]/g, ""),
      shortName: cleanOptional(payload.shortName, 100),
      notes: cleanOptional(payload.notes, 500),
      groupId:
        payload.groupId === undefined ? undefined : payload.groupId || null,
      archived: payload.archived,
    };
    const requestHash = operationRequestHash(operationType, intent);

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
          return replayReceipt(receipt, operationType, requestHash);
        }
      }

      const existingResult = await client.query<Record<string, unknown>>(
        `SELECT * FROM parties
         WHERE id = $1 AND company_id = $2 AND merged_into_id IS NULL
         FOR UPDATE`,
        [id, context.companyId],
      );
      const existing = existingResult.rows[0];
      if (!existing) throw jsonResponse("Customer or supplier not found.", 404);
      if (
        payload.baseVersion !== undefined &&
        Number(existing.version ?? 1) !== payload.baseVersion
      ) {
        const current = await getPartyEntity(client, context.companyId, id);
        throw new Response(
          JSON.stringify({
            error: "This party changed on another device.",
            code: "VERSION_CONFLICT",
            current,
          }),
          { status: 409, headers: { "content-type": "application/json" } },
        );
      }

      const name = intent.name ?? String(existing.name);
      if (name.length < 2) throw jsonResponse("Enter a valid name.", 400);
      const phone = intent.phone ?? String(existing.phone ?? "");
      const phoneE164 = normalizeOptionalPhone(phone);
      const shortName = intent.shortName ?? String(existing.short_name ?? "");
      const notes = intent.notes ?? String(existing.notes ?? "");
      const groupId =
        intent.groupId === undefined
          ? existing.group_id
            ? String(existing.group_id)
            : null
          : intent.groupId;
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
      const archivedAt =
        intent.archived === undefined
          ? existing.archived_at
          : intent.archived
            ? new Date().toISOString()
            : null;
      const now = new Date().toISOString();
      await client.query(
        `UPDATE parties SET
           name = $1, phone = $2, phone_e164 = $3, short_name = $4,
           notes = $5, group_id = $6, archived_at = $7, updated_by = $8,
           updated_at = $9, version = version + 1
         WHERE id = $10 AND company_id = $11`,
        [
          name,
          phone,
          phoneE164,
          shortName,
          notes,
          groupId,
          archivedAt,
          context.userId,
          now,
          id,
          context.companyId,
        ],
      );
      await client.query(
        `INSERT INTO audit_events (
           id, company_id, actor_user_id, entity_type, entity_id, action,
           details, created_at
         ) VALUES ($1, $2, $3, 'party', $4, $5, $6::jsonb, $7)`,
        [
          crypto.randomUUID(),
          context.companyId,
          context.userId,
          id,
          intent.archived === true
            ? "archived"
            : intent.archived === false
              ? "restored"
              : "edited",
          JSON.stringify({
            previousVersion: Number(existing.version ?? 1),
            changedFields: Object.keys(intent).filter(
              (key) =>
                key !== "partyId" &&
                intent[key as keyof typeof intent] !== undefined,
            ),
          }),
          now,
        ],
      );
      const party = await getPartyEntity(client, context.companyId, id);
      if (!party) throw new Error("Could not read the saved party.");
      const changeCursor = await appendSyncChange(client, {
        companyId: context.companyId,
        entityType: "party",
        entityId: id,
        version: party.version,
        payload: { party },
      });
      const body = { ok: true, replayed: false, party, changeCursor };
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
    });

    return Response.json(result);
  } catch (error) {
    return handleRouteError(error);
  }
}

function cleanOptional(value: unknown, max: number) {
  return typeof value === "string" ? value.trim().slice(0, max) : undefined;
}

function jsonResponse(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}
