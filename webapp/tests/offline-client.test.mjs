import assert from "node:assert/strict";
import test from "node:test";

import {
  canAutomaticallyRetry,
  classifyQueueResponse,
  flushBeforeBootstrap,
  flushEntryQueue,
  getQueue,
  queueEntry,
  readCachedData,
  reconcileQueuedEntries,
  removeQueuedEntry,
  retryQueuedEntry,
  updateQueuedEntry,
} from "../lib/offline-client.ts";

class MemoryStorage {
  #values = new Map();

  getItem(key) {
    return this.#values.get(key) ?? null;
  }

  setItem(key, value) {
    this.#values.set(key, String(value));
  }
}

function installBrowserGlobals({ online, fetchImpl }) {
  Object.defineProperty(globalThis, "localStorage", {
    configurable: true,
    value: new MemoryStorage(),
  });
  Object.defineProperty(globalThis, "navigator", {
    configurable: true,
    value: { onLine: online },
  });
  Object.defineProperty(globalThis, "fetch", {
    configurable: true,
    value: fetchImpl,
  });
}

test("queues entries while offline without attempting an upload", async () => {
  let fetchCalls = 0;
  installBrowserGlobals({
    online: false,
    fetchImpl: async () => {
      fetchCalls += 1;
      return new Response(null, { status: 201 });
    },
  });

  const queued = queueEntry("+919876543301", {
    narration: "Offline payment",
  });
  const result = await flushEntryQueue("+919876543301");

  assert.match(queued.id, /^[0-9a-f-]{36}$/);
  assert.equal(getQueue("+919876543301").length, 1);
  assert.deepEqual(result, {
    uploaded: 0,
    remaining: 1,
    needsAttention: 0,
    rateLimited: 0,
  });
  assert.equal(fetchCalls, 0);
});

test("uploads queued entries after reconnecting and clears the queue", async () => {
  installBrowserGlobals({
    online: true,
    fetchImpl: async () => new Response(null, { status: 201 }),
  });

  queueEntry("+919876543302", { narration: "Queued sale" });
  const result = await flushEntryQueue("+919876543302");

  assert.deepEqual(result, {
    uploaded: 1,
    remaining: 0,
    needsAttention: 0,
    rateLimited: 0,
  });
  assert.deepEqual(getQueue("+919876543302"), []);
});

test("keeps transient server failures queued and tolerates corrupt cache data", async () => {
  installBrowserGlobals({
    online: true,
    fetchImpl: async () => new Response(null, { status: 503 }),
  });

  queueEntry("+919876543303", { narration: "Retry later" });
  const result = await flushEntryQueue("+919876543303");
  localStorage.setItem("hisaab-cache-v2:+919876543303", "{not-json");

  assert.deepEqual(result, {
    uploaded: 0,
    remaining: 1,
    needsAttention: 0,
    rateLimited: 0,
  });
  assert.equal(getQueue("+919876543303").length, 1);
  assert.equal(getQueue("+919876543303")[0].status, "pending");
  assert.equal(readCachedData("+919876543303"), null);
});

test("keeps a blank optional note intact while an entry waits to upload", () => {
  installBrowserGlobals({
    online: false,
    fetchImpl: async () => new Response(null, { status: 201 }),
  });

  queueEntry("+919876543304", {
    partyId: "party-1",
    action: "gave",
    amountPaise: 50000,
    narration: "",
    entryDate: "2026-07-30",
  });

  assert.equal(getQueue("+919876543304")[0].body.narration, "");
});

test("preserves auth, conflict, validation, and rate-limit failures for review", async () => {
  for (const [statusCode, expected] of [
    [401, "needs_auth"],
    [409, "conflict"],
    [422, "conflict"],
    [429, "rate_limited"],
    [400, "rejected"],
  ]) {
    const account = `queue-${statusCode}`;
    installBrowserGlobals({
      online: true,
      fetchImpl: async () =>
        Response.json(
          { error: `failure-${statusCode}` },
          {
            status: statusCode,
            headers: statusCode === 429 ? { "retry-after": "120" } : {},
          },
        ),
    });
    queueEntry(account, { amountPaise: 100 });
    const result = await flushEntryQueue(account);
    const retained = getQueue(account)[0];
    assert.equal(result.remaining, 1);
    assert.equal(retained.status, expected);
    assert.equal(retained.lastError, `failure-${statusCode}`);
    if (statusCode === 429) {
      assert.equal(result.rateLimited, 1);
      assert.equal(canAutomaticallyRetry(retained), false);
    } else {
      assert.equal(result.needsAttention, 1);
    }
  }
});

test("only retries pending or elapsed rate-limited entries automatically", () => {
  assert.equal(classifyQueueResponse(503), "pending");
  assert.equal(
    canAutomaticallyRetry({ status: "pending", retryAfter: undefined }),
    true,
  );
  assert.equal(
    canAutomaticallyRetry({
      status: "rate_limited",
      retryAfter: "2026-01-01T00:00:00.000Z",
    }, Date.parse("2026-01-01T00:00:01.000Z")),
    true,
  );
  assert.equal(
    canAutomaticallyRetry({ status: "conflict", retryAfter: undefined }),
    false,
  );
});

test("stops after a transient failure so queued entry order is preserved", async () => {
  let calls = 0;
  installBrowserGlobals({
    online: true,
    fetchImpl: async () => {
      calls += 1;
      return new Response(null, { status: 503 });
    },
  });
  queueEntry("ordered-queue", { narration: "first" });
  queueEntry("ordered-queue", { narration: "second" });

  const result = await flushEntryQueue("ordered-queue");

  assert.equal(calls, 1);
  assert.equal(result.remaining, 2);
  assert.deepEqual(
    getQueue("ordered-queue").map((item) => item.body.narration),
    ["first", "second"],
  );
});

test("startup flush completes before the fresh bootstrap snapshot loads", async () => {
  const order = [];
  installBrowserGlobals({
    online: true,
    fetchImpl: async () => {
      order.push("mutation");
      return new Response(null, { status: 201 });
    },
  });
  queueEntry("startup-order", { narration: "before bootstrap" });

  const result = await flushBeforeBootstrap("startup-order", async () => {
    order.push("bootstrap");
    return { loaded: true };
  });

  assert.deepEqual(order, ["mutation", "bootstrap"]);
  assert.equal(result.queue.uploaded, 1);
  assert.deepEqual(result.bootstrap, { loaded: true });
});

test("rebuilds unresolved optimistic entries over a fresh server bootstrap", () => {
  installBrowserGlobals({
    online: false,
    fetchImpl: async () => new Response(null, { status: 201 }),
  });
  const queued = queueEntry("durable-projection", {
    partyId: "party-1",
    action: "gave",
    amountPaise: 12_345,
    narration: "Still waiting",
    entryDate: "2026-07-30",
    paymentAccount: "cash",
    clientId: "11111111-1111-4111-8111-111111111111",
  });
  const server = bootstrapFixture();

  const projected = reconcileQueuedEntries(
    server,
    getQueue("durable-projection"),
  );
  const projectedAgain = reconcileQueuedEntries(
    projected,
    getQueue("durable-projection"),
  );

  assert.equal(projected.entries[0].id, queued.body.clientId);
  assert.equal(projected.entries[0].clientSync, "waiting");
  assert.equal(projected.parties[0].balancePaise, 12_345);
  assert.equal(projected.parties[0].transactionCount, 1);
  assert.deepEqual(projectedAgain, projected);
});

test("marks rejected projections for review and removes them only on discard", async () => {
  installBrowserGlobals({
    online: true,
    fetchImpl: async () =>
      Response.json({ error: "Party is archived" }, { status: 400 }),
  });
  const queued = queueEntry("rejected-projection", {
    partyId: "party-1",
    action: "received",
    amountPaise: 500,
    entryDate: "2026-07-30",
    clientId: "22222222-2222-4222-8222-222222222222",
  });
  await flushEntryQueue("rejected-projection");

  const retained = getQueue("rejected-projection")[0];
  const projected = reconcileQueuedEntries(bootstrapFixture(), [retained]);
  assert.equal(projected.entries[0].clientSync, "failed");
  assert.equal(projected.parties[0].balancePaise, -500);

  retryQueuedEntry("rejected-projection", queued.id);
  assert.equal(getQueue("rejected-projection")[0].status, "pending");
  removeQueuedEntry("rejected-projection", queued.id);
  assert.equal(getQueue("rejected-projection").length, 0);
  assert.equal(
    reconcileQueuedEntries(projected, []).entries.length,
    0,
  );
  assert.equal(
    reconcileQueuedEntries(projected, []).parties[0].balancePaise,
    0,
  );
});

test("does not duplicate an outbox item already confirmed in server data", () => {
  installBrowserGlobals({
    online: false,
    fetchImpl: async () => new Response(null, { status: 201 }),
  });
  queueEntry("confirmed-projection", {
    partyId: "party-1",
    action: "gave",
    amountPaise: 700,
    entryDate: "2026-07-30",
    clientId: "33333333-3333-4333-8333-333333333333",
  });
  const server = bootstrapFixture();
  server.entries.push({
    id: "33333333-3333-4333-8333-333333333333",
    partyId: "party-1",
    partyName: "Asha",
    sequence: 8,
    action: "gave",
    amountPaise: 700,
    balanceEffectPaise: 700,
    narration: "",
    entryDate: "2026-07-30",
    paymentAccount: null,
    status: "posted",
    createdByName: "Owner",
    createdAt: "2026-07-30T00:00:00.000Z",
    editedAt: null,
    cancelledAt: null,
    revisionCount: 0,
    updatedAt: "2026-07-30T00:00:00.000Z",
    version: 1,
  });
  server.parties[0].balancePaise = 700;
  server.parties[0].transactionCount = 1;

  const projected = reconcileQueuedEntries(
    server,
    getQueue("confirmed-projection"),
  );
  assert.equal(projected.entries.length, 1);
  assert.equal(projected.entries[0].clientSync, undefined);
  assert.equal(projected.parties[0].balancePaise, 700);
});

test("correcting a rejected item moves its optimistic balance atomically", async () => {
  installBrowserGlobals({
    online: true,
    fetchImpl: async () =>
      Response.json({ error: "Correct these details" }, { status: 400 }),
  });
  const queued = queueEntry("corrected-projection", {
    partyId: "party-1",
    action: "gave",
    amountPaise: 1_000,
    narration: "Old",
    entryDate: "2026-07-29",
    clientId: "44444444-4444-4444-8444-444444444444",
    idempotencyKey: "55555555-5555-4555-8555-555555555555",
  });
  await flushEntryQueue("corrected-projection");
  const server = bootstrapFixture();
  server.parties.push({
    ...server.parties[0],
    id: "party-2",
    reference: "P-2",
    name: "Bilal",
  });
  const rejected = reconcileQueuedEntries(
    server,
    getQueue("corrected-projection"),
  );

  updateQueuedEntry("corrected-projection", queued.id, {
    partyId: "party-2",
    action: "received",
    amountPaise: 800,
    narration: "Corrected",
    entryDate: "2026-07-30",
  });
  const correctedQueue = getQueue("corrected-projection");
  const corrected = reconcileQueuedEntries(rejected, correctedQueue);

  assert.equal(correctedQueue[0].status, "pending");
  assert.equal(correctedQueue[0].lastError, undefined);
  assert.notEqual(correctedQueue[0].body.clientId, queued.body.clientId);
  assert.notEqual(
    correctedQueue[0].body.idempotencyKey,
    queued.body.idempotencyKey,
  );
  assert.equal(corrected.parties[0].balancePaise, 0);
  assert.equal(corrected.parties[0].transactionCount, 0);
  assert.equal(corrected.parties[1].balancePaise, -800);
  assert.equal(corrected.parties[1].transactionCount, 1);
  assert.equal(corrected.entries.length, 1);
  assert.equal(corrected.entries[0].partyId, "party-2");
  assert.equal(corrected.entries[0].clientSync, "waiting");
});

function bootstrapFixture() {
  return {
    user: {
      id: "user-1",
      phoneE164: "+919876543210",
      fullName: "Owner",
      language: "en",
      accessibilityMode: false,
      contactDiscoverable: false,
      version: 1,
    },
    company: {
      id: "company-1",
      name: "Hisaab",
      currency: "INR",
      timezone: "Asia/Kolkata",
      version: 1,
      updatedAt: "2026-07-30T00:00:00.000Z",
    },
    companies: [],
    groups: [],
    parties: [
      {
        id: "party-1",
        reference: "P-1",
        name: "Asha",
        shortName: "",
        phone: "",
        phoneE164: null,
        notes: "",
        groupId: null,
        groupName: null,
        balancePaise: 0,
        transactionCount: 0,
        archivedAt: null,
        createdAt: "2026-07-30T00:00:00.000Z",
        updatedAt: "2026-07-30T00:00:00.000Z",
        version: 1,
      },
    ],
    entries: [],
    serverTime: "2026-07-30T00:00:00.000Z",
    syncCursor: "0",
  };
}
