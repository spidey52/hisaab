import { apiFetch } from "./api-client";
import {
  addMsFromNow,
  addSecondsFromNow,
  nowIso,
  nowMs,
} from "./date-utils";
import type { BootstrapData, Entry } from "./types";
import { createClientId } from "./client-id";
import dayjs from "dayjs";

export type QueueStatus =
  | "pending"
  | "needs_auth"
  | "conflict"
  | "rate_limited"
  | "rejected";

export type QueuedEntry = {
  id: string;
  body: Record<string, unknown>;
  createdAt: string;
  status: QueueStatus;
  attempts: number;
  lastAttemptAt?: string;
  lastError?: string;
  retryAfter?: string;
};

function cacheKey(accountKey: string) {
  return `hisaab-cache-v2:${accountKey}`;
}

function queueKey(accountKey: string) {
  return `hisaab-entry-queue-v2:${accountKey}`;
}

export function readCachedData(accountKey: string): BootstrapData | null {
  try {
    const raw = localStorage.getItem(cacheKey(accountKey));
    return raw ? (JSON.parse(raw) as BootstrapData) : null;
  } catch {
    return null;
  }
}

export function writeCachedData(accountKey: string, data: BootstrapData) {
  try {
    localStorage.setItem(cacheKey(accountKey), JSON.stringify(data));
  } catch {
    // A full or private browser store should not stop online use.
  }
}

export function getQueue(accountKey: string): QueuedEntry[] {
  try {
    const raw = localStorage.getItem(queueKey(accountKey));
    const parsed = raw ? (JSON.parse(raw) as Partial<QueuedEntry>[]) : [];
    return parsed
      .filter(
        (item): item is Partial<QueuedEntry> & {
          id: string;
          body: Record<string, unknown>;
          createdAt: string;
        } =>
          typeof item.id === "string" &&
          !!item.body &&
          typeof item.body === "object" &&
          typeof item.createdAt === "string",
      )
      .map((item) => ({
        id: item.id,
        body: item.body,
        createdAt: item.createdAt,
        status: isQueueStatus(item.status) ? item.status : "pending",
        attempts:
          Number.isSafeInteger(item.attempts) && (item.attempts ?? 0) >= 0
            ? item.attempts!
            : 0,
        lastAttemptAt:
          typeof item.lastAttemptAt === "string"
            ? item.lastAttemptAt
            : undefined,
        lastError:
          typeof item.lastError === "string"
            ? item.lastError.slice(0, 300)
            : undefined,
        retryAfter:
          typeof item.retryAfter === "string" ? item.retryAfter : undefined,
      }));
  } catch {
    return [];
  }
}

export function queueEntry(
  accountKey: string,
  body: Record<string, unknown>,
): QueuedEntry {
  const queued: QueuedEntry = {
    id: createClientId(),
    body,
    createdAt: nowIso(),
    status: "pending",
    attempts: 0,
  };
  saveQueue(accountKey, [...getQueue(accountKey), queued]);
  return queued;
}

export function removeQueuedEntry(accountKey: string, id: string) {
  saveQueue(
    accountKey,
    getQueue(accountKey).filter((item) => item.id !== id),
  );
}

export function retryQueuedEntry(accountKey: string, id: string) {
  saveQueue(
    accountKey,
    getQueue(accountKey).map((item) =>
      item.id === id
        ? {
            ...item,
            status: "pending",
            lastError: undefined,
            retryAfter: undefined,
          }
        : item,
    ),
  );
}

export function updateQueuedEntry(
  accountKey: string,
  id: string,
  updates: {
    partyId: string;
    action: "gave" | "received";
    amountPaise: number;
    narration: string;
    entryDate: string;
  },
) {
  let updated: QueuedEntry | null = null;
  const next = getQueue(accountKey).map((item) => {
    if (item.id !== id) return item;
    updated = {
      ...item,
      body: {
        ...item.body,
        ...updates,
        // A corrected payload is a new mutation intent. New identifiers avoid
        // reusing an idempotency receipt or a conflicting client entity ID.
        clientId: createClientId(),
        idempotencyKey: createClientId(),
      },
      status: "pending",
      lastError: undefined,
      retryAfter: undefined,
    };
    return updated;
  });
  saveQueue(accountKey, next);
  return updated;
}

/**
 * Rebuilds optimistic entries from the durable queue over any server or cached
 * snapshot. Existing optimistic projections are removed first, which makes the
 * operation idempotent and prevents balances being applied twice after reload.
 */
export function reconcileQueuedEntries(
  data: BootstrapData,
  queued = getQueue(data.user.phoneE164),
): BootstrapData {
  const parties = new Map<string, BootstrapData["parties"][number]>(
    data.parties.map((party) => [party.id, { ...party }]),
  );
  const stableEntries: Entry[] = [];

  for (const entry of data.entries) {
    if (!entry.clientSync) {
      stableEntries.push(entry);
      continue;
    }
    const party = parties.get(entry.partyId);
    if (party) {
      party.balancePaise -= entry.balanceEffectPaise;
      party.transactionCount = Math.max(0, party.transactionCount - 1);
    }
  }

  const stableIds = new Set(stableEntries.map((entry) => entry.id));
  const optimisticEntries: Entry[] = [];
  for (const item of queued) {
    const optimistic = queuedEntryProjection(data, item);
    if (!optimistic || stableIds.has(optimistic.id)) continue;
    optimisticEntries.push(optimistic);
    const party = parties.get(optimistic.partyId);
    if (party) {
      party.balancePaise += optimistic.balanceEffectPaise;
      party.transactionCount += 1;
    }
  }
  optimisticEntries.sort((left, right) =>
    right.createdAt.localeCompare(left.createdAt),
  );

  return {
    ...data,
    parties: data.parties.map((party) => parties.get(party.id) ?? party),
    entries: [...optimisticEntries, ...stableEntries],
  };
}

export async function flushEntryQueue(accountKey: string) {
  const queued = getQueue(accountKey);
  if (queued.length === 0 || !navigator.onLine) {
    return queueFlushResult(0, queued);
  }
  const remaining: QueuedEntry[] = [];
  let uploaded = 0;
  let stopAutomaticFlush = false;

  for (const item of queued) {
    if (stopAutomaticFlush || !canAutomaticallyRetry(item)) {
      remaining.push(item);
      continue;
    }
    const attempted = {
      ...item,
      attempts: item.attempts + 1,
      lastAttemptAt: nowIso(),
    };
    try {
      const response = await apiFetch("/api/entries", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(item.body),
      });
      if (response.ok) {
        uploaded += 1;
        continue;
      }
      const error = await responseError(response);
      const status = classifyQueueResponse(response.status);
      const retryAfter =
        status === "rate_limited"
          ? retryDate(response.headers.get("retry-after"))
          : undefined;
      remaining.push({
        ...attempted,
        status,
        lastError: error,
        retryAfter,
      });
      if (
        status === "pending" ||
        status === "needs_auth" ||
        status === "rate_limited"
      ) {
        stopAutomaticFlush = true;
      }
    } catch {
      remaining.push({
        ...attempted,
        status: "pending",
        lastError: "Could not reach Hisaab. This entry remains saved.",
      });
      stopAutomaticFlush = true;
    }
  }
  saveQueue(accountKey, remaining);
  return queueFlushResult(uploaded, remaining);
}

export async function flushBeforeBootstrap<T>(
  accountKey: string,
  loadBootstrap: () => Promise<T>,
) {
  const queue = await flushEntryQueue(accountKey);
  const bootstrap = await loadBootstrap();
  return { queue, bootstrap };
}

export function classifyQueueResponse(status: number): QueueStatus {
  if (status === 401 || status === 403) return "needs_auth";
  if (status === 409 || status === 422) return "conflict";
  if (status === 429) return "rate_limited";
  if (status >= 400 && status < 500) return "rejected";
  return "pending";
}

export function canAutomaticallyRetry(
  item: Pick<QueuedEntry, "status" | "retryAfter">,
  now = nowMs(),
) {
  if (item.status === "pending") return true;
  if (item.status !== "rate_limited") return false;
  if (!item.retryAfter) return false;
  const retryAt = dayjs(item.retryAfter);
  return retryAt.isValid() && retryAt.valueOf() <= now;
}

function queueFlushResult(uploaded: number, remaining: QueuedEntry[]) {
  return {
    uploaded,
    remaining: remaining.length,
    needsAttention: remaining.filter(
      (item) =>
        item.status === "needs_auth" ||
        item.status === "conflict" ||
        item.status === "rejected",
    ).length,
    rateLimited: remaining.filter((item) => item.status === "rate_limited")
      .length,
  };
}

function saveQueue(accountKey: string, queue: QueuedEntry[]) {
  localStorage.setItem(queueKey(accountKey), JSON.stringify(queue));
}

function isQueueStatus(value: unknown): value is QueueStatus {
  return (
    value === "pending" ||
    value === "needs_auth" ||
    value === "conflict" ||
    value === "rate_limited" ||
    value === "rejected"
  );
}

function queuedEntryProjection(
  data: BootstrapData,
  item: QueuedEntry,
): Entry | null {
  const partyId =
    typeof item.body.partyId === "string" ? item.body.partyId : null;
  const party = data.parties.find((candidate) => candidate.id === partyId);
  const action = item.body.action;
  const amountPaise = item.body.amountPaise;
  const entryDate = item.body.entryDate;
  if (
    !party ||
    (action !== "gave" && action !== "received") ||
    typeof amountPaise !== "number" ||
    !Number.isSafeInteger(amountPaise) ||
    amountPaise <= 0 ||
    typeof entryDate !== "string"
  ) {
    return null;
  }
  const id =
    typeof item.body.clientId === "string"
      ? item.body.clientId
      : `local-${item.id}`;
  const balanceEffectPaise = action === "gave" ? amountPaise : -amountPaise;
  const paymentAccount =
    item.body.paymentAccount === "cash" || item.body.paymentAccount === "bank"
      ? item.body.paymentAccount
      : null;
  return {
    id,
    partyId: party.id,
    partyName: party.name,
    sequence: 0,
    action,
    amountPaise,
    balanceEffectPaise,
    narration:
      typeof item.body.narration === "string" ? item.body.narration : "",
    entryDate,
    paymentAccount,
    status: "posted",
    createdByName: data.user.fullName,
    createdAt: item.createdAt,
    updatedAt: item.createdAt,
    version: 1,
    editedAt: null,
    cancelledAt: null,
    revisionCount: 0,
    clientSync:
      item.status === "pending" || item.status === "rate_limited"
        ? "waiting"
        : "failed",
  };
}

async function responseError(response: Response) {
  try {
    const body = (await response.json()) as { error?: unknown };
    if (typeof body.error === "string") return body.error.slice(0, 300);
  } catch {
    // Keep a stable local error when the server did not return JSON.
  }
  return `Hisaab could not save this entry (${response.status}).`;
}

function retryDate(value: string | null) {
  if (!value) return addMsFromNow(60_000);
  if (/^\d+$/.test(value)) return addSecondsFromNow(Number(value));
  const parsed = dayjs(value);
  return parsed.isValid() ? parsed.toISOString() : addMsFromNow(60_000);
}
