import type { Context } from "hono";
import { and, asc, eq, isNull, max, sql } from "drizzle-orm";
import {
  auditEvents,
  companies,
  entries,
  entryRevisions,
  parties,
  syncChanges,
  withTransaction,
} from "../db";
import { nowDate, toDateOnly } from "../utils/date-utils";
import {
  handleRouteError,
  requireServerContext,
} from "../services/server-auth";
import { apiError } from "../utils/security";
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

const operationType = "opening_balance.save";

export async function upsertOpeningBalance(c: Context) {
  try {
    const request = c.req.raw;
    const context = await requireServerContext(request);
    const payload = c.get("json") as {
      clientId?: string;
      partyId: string;
      amountPaise: number;
      direction: "receive" | "pay";
      entryDate: string;
      idempotencyKey?: string;
      baseVersion?: number;
    };

    const normalized = {
      clientId: payload.clientId ?? null,
      partyId: payload.partyId,
      amountPaise: payload.amountPaise,
      direction: payload.direction,
      entryDate: payload.entryDate,
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
        const legacyRows = await client
          .select()
          .from(entries)
          .where(
            and(
              eq(entries.companyId, context.companyId),
              eq(entries.idempotencyKey, operationId),
            ),
          );
        const legacy = legacyRows[0];
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
            legacy.partyId,
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

      const partyRows = await client
        .select({ id: parties.id })
        .from(parties)
        .where(
          and(
            eq(parties.id, normalized.partyId),
            eq(parties.companyId, context.companyId),
            isNull(parties.mergedIntoId),
            isNull(parties.archivedAt),
          ),
        )
        .for("update");
      if (!partyRows[0]) {
        throw apiError("Customer or supplier not found.", 404);
      }

      const existingRows = await client
        .select()
        .from(entries)
        .where(
          and(
            eq(entries.companyId, context.companyId),
            eq(entries.partyId, normalized.partyId),
            eq(entries.action, "opening_balance"),
            eq(entries.status, "posted"),
          ),
        )
        .orderBy(asc(entries.sequence))
        .limit(1)
        .for("update");
      const existing = existingRows[0];
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
        const [cursorRow] = await client
          .select({
            cursor: sql<string>`coalesce(${max(syncChanges.id)}, 0)::text`,
          })
          .from(syncChanges)
          .where(eq(syncChanges.companyId, context.companyId));
        const body = {
          id: entry.id,
          sequence: entry.sequence,
          updated: true,
          replayed: false,
          entry,
          party,
          changeCursor: cursorRow?.cursor ?? "0",
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

      const now = nowDate();
      const effect =
        normalized.direction === "receive"
          ? normalized.amountPaise
          : -normalized.amountPaise;
      let entryId: string;
      let sequence: number;
      let updated: boolean;

      if (existing) {
        entryId = existing.id;
        sequence = Number(existing.sequence);
        updated = true;
        await client.insert(entryRevisions).values({
          id: crypto.randomUUID(),
          entryId,
          previousValues: existing,
          changedBy: context.userId,
          changedAt: now,
        });
        await client
          .update(entries)
          .set({
            amountPaise: normalized.amountPaise,
            balanceEffectPaise: effect,
            entryDate: normalized.entryDate,
            editedBy: context.userId,
            editedAt: now,
            updatedAt: now,
            version: sql`${entries.version} + 1`,
          })
          .where(
            and(eq(entries.id, entryId), eq(entries.companyId, context.companyId)),
          );
      } else {
        const sequenceResult = await client
          .update(companies)
          .set({ nextEntryNumber: sql`${companies.nextEntryNumber} + 1` })
          .where(eq(companies.id, context.companyId))
          .returning({
            sequence: sql<number>`${companies.nextEntryNumber} - 1`,
          });
        sequence = Number(sequenceResult[0]?.sequence);
        if (!Number.isSafeInteger(sequence)) {
          throw new Error("Could not allocate entry number.");
        }
        entryId = normalized.clientId ?? crypto.randomUUID();
        updated = false;
        await client.insert(entries).values({
          id: entryId,
          companyId: context.companyId,
          partyId: normalized.partyId,
          sequence,
          action: "opening_balance",
          amountPaise: normalized.amountPaise,
          balanceEffectPaise: effect,
          narration: "Opening balance",
          entryDate: normalized.entryDate,
          status: "posted",
          idempotencyKey: operationId,
          createdBy: context.userId,
          createdAt: now,
          updatedAt: now,
          version: 1,
        });
      }

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
        action: updated ? "opening_balance_edited" : "opening_balance_created",
        details: { sequence, amountPaise: normalized.amountPaise },
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

function openingMatches(
  row: typeof entries.$inferSelect,
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
    (!expected.clientId || row.id === expected.clientId) &&
    row.partyId === expected.partyId &&
    Number(row.amountPaise) === expected.amountPaise &&
    Number(row.balanceEffectPaise) === effect &&
    toDateOnly(row.entryDate) === expected.entryDate
  );
}
