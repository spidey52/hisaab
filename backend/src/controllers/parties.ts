import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import type { Context } from "hono";
import { and, eq, inArray, isNull, max, or, sql } from "drizzle-orm";
import {
  auditEvents,
  entries,
  parties,
  partyGroups,
  syncChanges,
  withReadTransaction,
  withTransaction,
} from "../db";
import { isValidDateOnly, nowDate } from "../utils/date-utils";
import { normalizeOptionalPhone } from "../utils/phone-normalization";
import { authenticationSecret, throwApiError } from "../utils/security";
import {
  cursorMatchesStatementRequest,
  statementTotals,
  takeStatementPage,
} from "../utils/statement";
import { requireServerContext } from "../services/server-auth";
import {
  getEntryEntities,
  getPartyEntity,
  getPartyLedgerEntries,
} from "../services/server-entities";
import {
  appendSyncChange,
  appendSyncChanges,
  idempotencyConflict,
  lockLedgerMutation,
  lockOperation,
  operationRequestHash,
  readOperationReceipt,
  replayReceipt,
  storeOperationReceipt,
} from "../services/sync-server";

const createOperationType = "party.create";
const updateOperationType = "party.update";
const mergeOperationType = "party.merge";

const order = "newest_first" as const;

type StatementCursor = {
  version: 1;
  partyId: string;
  from: string | null;
  to: string | null;
  entryDate: string;
  sequence: number;
  order: typeof order;
  statementRevision: string;
};

export async function createParty(c: Context) {
  const request = c.req.raw;
  const context = await requireServerContext(request);
  const payload = c.get("json") as {
    clientId?: string;
    idempotencyKey?: string;
    name: string;
    phone?: string;
    shortName?: string;
    notes?: string;
    groupId?: string | null;
    confirmDuplicate?: boolean;
  };
  const name = payload.name;
  const phone = payload.phone ?? "";
  const phoneE164 = normalizeOptionalPhone(phone);
  const shortName = payload.shortName ?? "";
  const notes = payload.notes ?? "";
  const groupId = payload.groupId ?? null;

  const normalized = {
    clientId: payload.clientId ?? null,
    name,
    phone,
    phoneE164,
    shortName,
    notes,
    groupId,
  };
  const requestHash = operationRequestHash(createOperationType, normalized);

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
          body: replayReceipt(receipt, createOperationType, requestHash),
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
      const existingByIdRows = await client
        .select()
        .from(parties)
        .where(
          and(
            eq(parties.id, payload.clientId),
            eq(parties.companyId, context.companyId),
          ),
        );
      const existing = existingByIdRows[0];
      if (existing) {
        if (!partyMatchesCreate(existing, normalized)) {
          idempotencyConflict();
        }
        const party = await getPartyEntity(
          client,
          context.companyId,
          payload.clientId,
        );
        if (!party) throw new Error("Could not replay the saved party.");
        const [cursorRow] = await client
          .select({
            cursor: sql<string>`coalesce(${max(syncChanges.id)}, 0)::text`,
          })
          .from(syncChanges)
          .where(eq(syncChanges.companyId, context.companyId));
        const body = {
          id: party.id,
          reference: party.reference,
          replayed: false,
          party,
          changeCursor: cursorRow?.cursor ?? "0",
        };
        if (payload.idempotencyKey) {
          await storeOperationReceipt(client, {
            companyId: context.companyId,
            operationId: payload.idempotencyKey,
            operationType: createOperationType,
            requestHash,
            responseBody: body,
            statusCode: 200,
          });
        }
        return { body: { ...body, replayed: true }, status: 200 };
      }
    }

    if (groupId) {
      const groupRows = await client
        .select({ id: partyGroups.id })
        .from(partyGroups)
        .where(
          and(
            eq(partyGroups.id, groupId),
            eq(partyGroups.companyId, context.companyId),
          ),
        );
      if (!groupRows[0]) {
        throwApiError(400, "That group is no longer available.");
      }
    }

    const duplicateRows = await client
      .select({
        id: parties.id,
        name: parties.name,
        phone: parties.phone,
        reference: parties.reference,
      })
      .from(parties)
      .where(
        and(
          eq(parties.companyId, context.companyId),
          isNull(parties.mergedIntoId),
          or(
            sql`lower(${parties.name}) = lower(${name})`,
            and(
              sql`${parties.shortName} <> ''`,
              sql`lower(${parties.shortName}) = lower(${shortName || name})`,
            ),
            phoneE164 ? eq(parties.phoneE164, phoneE164) : sql`false`,
          ),
        ),
      )
      .limit(5);
    if (duplicateRows.length > 0 && !payload.confirmDuplicate) {
      throwApiError(409, "This customer or supplier may already exist.", {
        code: "DUPLICATE_WARNING",
        context: {
          duplicates: duplicateRows.map((row) => ({
            id: row.id,
            name: row.name,
            phone: String(row.phone ?? ""),
            reference: row.reference,
          })),
        },
      });
    }

    const partyId = payload.clientId ?? crypto.randomUUID();
    const reference = `HSB-${
      partyId.replaceAll("-", "").slice(0, 8).toUpperCase()
    }`;
    const now = nowDate();
    await client.insert(parties).values({
      id: partyId,
      companyId: context.companyId,
      reference,
      name,
      shortName,
      phone,
      phoneE164,
      notes,
      groupId,
      createdBy: context.userId,
      createdAt: now,
      updatedAt: now,
      version: 1,
    });
    await client.insert(auditEvents).values({
      id: crypto.randomUUID(),
      companyId: context.companyId,
      actorUserId: context.userId,
      entityType: "party",
      entityId: partyId,
      action: "created",
      details: { name, reference },
      createdAt: now,
    });
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
        operationType: createOperationType,
        requestHash,
        responseBody: body,
        statusCode: 201,
      });
    }
    return { body, status: 201 };
  });

  return Response.json(result.body, { status: result.status });
}

export async function mergeParties(c: Context) {
  const request = c.req.raw;
  const context = await requireServerContext(request);
  const payload = c.get("json") as {
    sourcePartyId: string;
    targetPartyId: string;
    idempotencyKey?: string;
    baseSourceVersion?: number;
    baseTargetVersion?: number;
  };
  const sourceId = payload.sourcePartyId;
  const targetId = payload.targetPartyId;
  const normalized = { sourceId, targetId };
  const requestHash = operationRequestHash(mergeOperationType, normalized);

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
          return replayReceipt(receipt, mergeOperationType, requestHash);
        }
      }
      await lockLedgerMutation(client, context.companyId);
      const locked = await client
        .select({ id: parties.id, version: parties.version })
        .from(parties)
        .where(
          and(
            eq(parties.companyId, context.companyId),
            inArray(parties.id, [sourceId, targetId]),
            isNull(parties.mergedIntoId),
          ),
        )
        .orderBy(parties.id)
        .for("update");
      if (locked.length !== 2) {
        throwApiError(
          404,
          "One of the selected records is no longer available.",
        );
      }
      const versions = new Map(
        locked.map((row) => [row.id, Number(row.version)]),
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
        throwApiError(409, "One of these parties changed on another device.", {
          code: "VERSION_CONFLICT",
          context: { current: { source, target } },
        });
      }

      const openingBalances = await client
        .select({ partyId: entries.partyId })
        .from(entries)
        .where(
          and(
            eq(entries.companyId, context.companyId),
            inArray(entries.partyId, [sourceId, targetId]),
            eq(entries.action, "opening_balance"),
            eq(entries.status, "posted"),
          ),
        )
        .orderBy(entries.partyId)
        .for("update");
      if (new Set(openingBalances.map((row) => row.partyId)).size > 1) {
        throwApiError(
          409,
          "Both records have an opening balance. Cancel or consolidate one before merging.",
          { code: "OPENING_BALANCE_CONFLICT" },
        );
      }

      const now = nowDate();
      const moved = await client
        .update(entries)
        .set({
          partyId: targetId,
          updatedAt: now,
          version: sql`${entries.version} + 1`,
        })
        .where(
          and(
            eq(entries.partyId, sourceId),
            eq(entries.companyId, context.companyId),
          ),
        )
        .returning({ id: entries.id, version: entries.version });
      await client
        .update(parties)
        .set({
          mergedIntoId: targetId,
          archivedAt: now,
          updatedBy: context.userId,
          updatedAt: now,
          version: sql`${parties.version} + 1`,
        })
        .where(
          and(
            eq(parties.id, sourceId),
            eq(parties.companyId, context.companyId),
          ),
        );
      await client
        .update(parties)
        .set({
          updatedBy: context.userId,
          updatedAt: now,
          version: sql`${parties.version} + 1`,
        })
        .where(
          and(
            eq(parties.id, targetId),
            eq(parties.companyId, context.companyId),
          ),
        );
      await client.insert(auditEvents).values({
        id: crypto.randomUUID(),
        companyId: context.companyId,
        actorUserId: context.userId,
        entityType: "party",
        entityId: sourceId,
        action: "merged",
        details: {
          mergedIntoId: targetId,
          movedEntryCount: moved.length,
        },
        createdAt: now,
      });

      const movedEntries = await getEntryEntities(
        client,
        context.companyId,
        moved.map((row) => row.id),
      );
      if (movedEntries.length !== moved.length) {
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
        movedEntryCount: moved.length,
        changeCursor,
      };
      if (payload.idempotencyKey) {
        await storeOperationReceipt(client, {
          companyId: context.companyId,
          operationId: payload.idempotencyKey,
          operationType: mergeOperationType,
          requestHash,
          responseBody: body,
          statusCode: 200,
        });
      }
      return body;
    },
    { statementTimeoutMs: 60_000 },
  );
  return c.json(result);
}

export async function updateParty(c: Context) {
  const request = c.req.raw;
  const context = await requireServerContext(request);
  const { id } = c.get("params") as { id: string };
  const payload = c.get("json") as {
    name?: string;
    phone?: string;
    shortName?: string;
    notes?: string;
    groupId?: string | null;
    archived?: boolean;
    idempotencyKey?: string;
    baseVersion?: number;
  };
  const intent = {
    partyId: id,
    name: payload.name,
    phone: payload.phone?.replace(/[^0-9+ ()-]/g, ""),
    shortName: payload.shortName,
    notes: payload.notes,
    groupId: payload.groupId === undefined
      ? undefined
      : payload.groupId || null,
    archived: payload.archived,
  };
  const requestHash = operationRequestHash(updateOperationType, intent);

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
        return replayReceipt(receipt, updateOperationType, requestHash);
      }
    }

    const existingRows = await client
      .select()
      .from(parties)
      .where(
        and(
          eq(parties.id, id),
          eq(parties.companyId, context.companyId),
          isNull(parties.mergedIntoId),
        ),
      )
      .for("update");
    const existing = existingRows[0];
    if (!existing) throwApiError(404, "Customer or supplier not found.");
    if (
      payload.baseVersion !== undefined &&
      Number(existing.version ?? 1) !== payload.baseVersion
    ) {
      const current = await getPartyEntity(client, context.companyId, id);
      throwApiError(409, "This party changed on another device.", {
        code: "VERSION_CONFLICT",
        context: { current },
      });
    }

    const name = intent.name ?? String(existing.name);
    if (name.length < 2) throwApiError(400, "Enter a valid name.");
    const phone = intent.phone ?? String(existing.phone ?? "");
    const phoneE164 = normalizeOptionalPhone(phone);
    const shortName = intent.shortName ?? existing.shortName;
    const notes = intent.notes ?? existing.notes;
    const groupId = intent.groupId === undefined
      ? existing.groupId
      : intent.groupId;
    if (groupId) {
      const groupRows = await client
        .select({ id: partyGroups.id })
        .from(partyGroups)
        .where(
          and(
            eq(partyGroups.id, groupId),
            eq(partyGroups.companyId, context.companyId),
          ),
        );
      if (!groupRows[0]) {
        throwApiError(400, "That group is no longer available.");
      }
    }
    const now = nowDate();
    const archivedAt = intent.archived === undefined
      ? existing.archivedAt
      : intent.archived
      ? now
      : null;
    await client
      .update(parties)
      .set({
        name,
        phone,
        phoneE164,
        shortName,
        notes,
        groupId,
        archivedAt,
        updatedBy: context.userId,
        updatedAt: now,
        version: sql`${parties.version} + 1`,
      })
      .where(and(eq(parties.id, id), eq(parties.companyId, context.companyId)));
    await client.insert(auditEvents).values({
      id: crypto.randomUUID(),
      companyId: context.companyId,
      actorUserId: context.userId,
      entityType: "party",
      entityId: id,
      action: intent.archived === true
        ? "archived"
        : intent.archived === false
        ? "restored"
        : "edited",
      details: {
        previousVersion: Number(existing.version ?? 1),
        changedFields: Object.keys(intent).filter(
          (key) =>
            key !== "partyId" &&
            intent[key as keyof typeof intent] !== undefined,
        ),
      },
      createdAt: now,
    });
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
        operationType: updateOperationType,
        requestHash,
        responseBody: body,
        statusCode: 200,
      });
    }
    return body;
  });

  return c.json(result);
}

export async function getStatement(c: Context) {
  const request = c.req.raw;
  const context = await requireServerContext(request);
  const { id } = c.get("params") as { id: string };
  const query = c.get("query") as {
    from?: string;
    to?: string;
    limit: number;
    cursor?: string;
  };
  const from = query.from ?? null;
  const to = query.to ?? null;
  const limit = query.limit;
  const cursor = decodeCursor(query.cursor ?? null);
  if (
    cursor &&
    !cursorMatchesStatementRequest(cursor, {
      partyId: id,
      from,
      to,
      order,
    })
  ) {
    return c.json(
      {
        error: "This statement cursor belongs to a different request.",
        code: "INVALID_CURSOR",
      },
      { status: 400 },
    );
  }

  const result = await withReadTransaction(async (client) => {
    const party = await getPartyEntity(client, context.companyId, id);
    if (!party) {
      throwApiError(404, "Party not found.");
    }
    const availableRows = await client
      .select({ id: parties.id })
      .from(parties)
      .where(
        and(
          eq(parties.id, id),
          eq(parties.companyId, context.companyId),
          isNull(parties.mergedIntoId),
        ),
      );
    if (!availableRows[0]) throwApiError(404, "Party not found.");

    const ledger = await getPartyLedgerEntries(
      client,
      context.companyId,
      id,
    );

    let openingBalancePaise = 0;
    let periodChangePaise = 0;
    let postedCount = 0;
    let cancelledCount = 0;
    let totalCount = 0;
    let revisionCount = 0;
    let revisionVersionSum = 0;
    let revisionMaxUpdatedAt: string | null = null;
    let revisionEffectSum = 0;
    let running = 0;

    const withRunning: Array<
      (typeof ledger)[number] & { runningBalancePaise: number }
    > = [];

    for (const entry of ledger) {
      if (entry.status === "posted") {
        running += entry.balanceEffectPaise;
      }
      withRunning.push({ ...entry, runningBalancePaise: running });

      const beforeFrom = from != null && entry.entryDate < from;
      const inPeriod = (from == null || entry.entryDate >= from) &&
        (to == null || entry.entryDate <= to);
      const upToTo = to == null || entry.entryDate <= to;

      if (entry.status === "posted" && beforeFrom) {
        openingBalancePaise += entry.balanceEffectPaise;
      }
      if (entry.status === "posted" && inPeriod) {
        periodChangePaise += entry.balanceEffectPaise;
        postedCount += 1;
      }
      if (entry.status === "cancelled" && inPeriod) cancelledCount += 1;
      if (inPeriod) totalCount += 1;
      if (upToTo) {
        revisionCount += 1;
        revisionVersionSum += entry.version;
        revisionEffectSum += entry.status === "posted"
          ? entry.balanceEffectPaise
          : 0;
        if (
          !revisionMaxUpdatedAt ||
          entry.updatedAt > revisionMaxUpdatedAt
        ) {
          revisionMaxUpdatedAt = entry.updatedAt;
        }
      }
    }

    const statementRevision = createHash("sha256")
      .update(
        JSON.stringify({
          partyVersion: party.version,
          count: revisionCount,
          versionSum: revisionVersionSum,
          maxUpdatedAt: revisionMaxUpdatedAt,
          effectSum: revisionEffectSum,
        }),
      )
      .digest("base64url");
    if (cursor && cursor.statementRevision !== statementRevision) {
      throwApiError(
        409,
        "This statement changed while it was being loaded. Start again.",
        { code: "STATEMENT_CHANGED" },
      );
    }

    const filtered = withRunning
      .filter((entry) => {
        if (from != null && entry.entryDate < from) return false;
        if (to != null && entry.entryDate > to) return false;
        if (!cursor) return true;
        if (entry.entryDate < cursor.entryDate) return true;
        if (
          entry.entryDate === cursor.entryDate &&
          entry.sequence < cursor.sequence
        ) {
          return true;
        }
        return false;
      })
      .reverse();

    const page = takeStatementPage(filtered, limit);
    const statementEntries = page.rows;
    const last = statementEntries.at(-1);
    const nextCursor = page.hasMore && last
      ? encodeCursor({
        version: 1,
        partyId: id,
        from,
        to,
        entryDate: last.entryDate,
        sequence: last.sequence,
        order,
        statementRevision,
      })
      : null;
    const totals = statementTotals({
      openingBalancePaise,
      periodChangePaise,
    });
    return {
      party,
      period: { from, to },
      ...totals,
      postedCount,
      cancelledCount,
      totalCount,
      order,
      statementRevision,
      entries: statementEntries,
      nextCursor,
      hasMore: page.hasMore,
    };
  });

  return c.json(result, {
    headers: { "cache-control": "private, no-store" },
  });
}

function partyMatchesCreate(
  existing: typeof parties.$inferSelect,
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
    (!expected.clientId || existing.id === expected.clientId) &&
    existing.name === expected.name &&
    String(existing.phone ?? "") === expected.phone &&
    (existing.phoneE164 ? String(existing.phoneE164) : null) ===
      expected.phoneE164 &&
    String(existing.shortName ?? "") === expected.shortName &&
    String(existing.notes ?? "") === expected.notes &&
    (existing.groupId ? String(existing.groupId) : null) === expected.groupId
  );
}

export function encodeCursor(cursor: StatementCursor) {
  const encoded = Buffer.from(JSON.stringify(cursor)).toString("base64url");
  const signature = createHmac("sha256", authenticationSecret())
    .update(encoded)
    .digest("base64url");
  return `${encoded}.${signature}`;
}

export function decodeCursor(value: string | null): StatementCursor | null {
  if (!value) return null;
  try {
    const [encoded, signature, extra] = value.split(".");
    if (!encoded || !signature || extra) throw new Error("Invalid cursor");
    const expected = createHmac("sha256", authenticationSecret())
      .update(encoded)
      .digest();
    const actual = Buffer.from(signature, "base64url");
    if (
      actual.length !== expected.length ||
      !timingSafeEqual(actual, expected)
    ) {
      throw new Error("Invalid signature");
    }
    const decoded = JSON.parse(
      Buffer.from(encoded, "base64url").toString("utf8"),
    ) as Partial<StatementCursor>;
    if (
      decoded.version !== 1 ||
      typeof decoded.partyId !== "string" ||
      (decoded.from !== null && !isValidDateOnly(decoded.from)) ||
      (decoded.to !== null && !isValidDateOnly(decoded.to)) ||
      !isValidDateOnly(decoded.entryDate) ||
      !Number.isSafeInteger(decoded.sequence) ||
      (decoded.sequence ?? 0) < 1 ||
      decoded.order !== order ||
      typeof decoded.statementRevision !== "string" ||
      !/^[A-Za-z0-9_-]{43}$/.test(decoded.statementRevision)
    ) {
      throw new Error("Invalid cursor");
    }
    return decoded as StatementCursor;
  } catch {
    throwApiError(400, "This statement cursor is invalid.", {
      code: "INVALID_CURSOR",
    });
  }
}
