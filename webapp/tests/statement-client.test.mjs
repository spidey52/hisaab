import assert from "node:assert/strict";
import test from "node:test";

import {
  fetchStatementBatch,
  StatementChangedError,
  statementNoteForExport,
} from "../lib/statement-client.ts";

test("keeps private narration out of exports unless explicitly enabled", () => {
  const value = { action: "gave", narration: " internal margin note " };
  assert.equal(statementNoteForExport(value), "");
  assert.equal(
    statementNoteForExport(value, true),
    "internal margin note",
  );
  assert.equal(
    statementNoteForExport(
      { action: "opening_balance", narration: "never shared" },
      true,
    ),
    "",
  );
});

test("follows signed cursors in bounded pages and preserves server balances", async () => {
  const requests = [];
  const responses = [
    statementPage({
      revision: "revision-a",
      entries: [entry("entry-3", 3, 3_000)],
      nextCursor: "cursor-1",
      totalCount: 2,
    }),
    statementPage({
      revision: "revision-a",
      entries: [entry("entry-2", 2, 2_000)],
      nextCursor: null,
      totalCount: 2,
    }),
  ];
  const result = await fetchStatementBatch("party/with space", {
    fetcher: async (input) => {
      requests.push(String(input));
      return Response.json(responses.shift());
    },
  });

  assert.equal(requests.length, 2);
  assert.match(
    requests[0],
    /^\/api\/parties\/party%2Fwith%20space\/statement\?limit=200$/,
  );
  assert.match(requests[1], /limit=200/);
  assert.match(requests[1], /cursor=cursor-1/);
  assert.deepEqual(
    result.entries.map((item) => item.runningBalancePaise),
    [3_000, 2_000],
  );
  assert.equal(result.openingBalancePaise, 125);
  assert.equal(result.periodChangePaise, 875);
  assert.equal(result.closingBalancePaise, 1_000);
  assert.equal(result.hasMore, false);
});

test("restarts a fresh statement once after STATEMENT_CHANGED", async () => {
  const requestedCursors = [];
  const responses = [
    Response.json(
      statementPage({
        revision: "revision-old",
        entries: [entry("old-2", 2, 200)],
        nextCursor: "old-cursor",
        totalCount: 2,
      }),
    ),
    Response.json(
      {
        error: "Statement changed",
        code: "STATEMENT_CHANGED",
      },
      { status: 409 },
    ),
    Response.json(
      statementPage({
        revision: "revision-new",
        entries: [entry("new-3", 3, 300)],
        nextCursor: "new-cursor",
        totalCount: 2,
      }),
    ),
    Response.json(
      statementPage({
        revision: "revision-new",
        entries: [entry("new-2", 2, 200)],
        nextCursor: null,
        totalCount: 2,
      }),
    ),
  ];

  const result = await fetchStatementBatch("party-1", {
    fetcher: async (input) => {
      requestedCursors.push(
        new URL(String(input), "https://hisaab.example").searchParams.get(
          "cursor",
        ),
      );
      return responses.shift();
    },
  });

  assert.deepEqual(requestedCursors, [
    null,
    "old-cursor",
    null,
    "new-cursor",
  ]);
  assert.deepEqual(
    result.entries.map((item) => item.id),
    ["new-3", "new-2"],
  );
  assert.equal(result.statementRevision, "revision-new");
});

test("caps a progressive batch without treating it as complete", async () => {
  let requestedLimit = "";
  const result = await fetchStatementBatch("party-1", {
    maxEntries: 2,
    fetcher: async (input) => {
      requestedLimit = new URL(
        String(input),
        "https://hisaab.example",
      ).searchParams.get("limit");
      return Response.json(
        statementPage({
          revision: "revision-a",
          entries: [
            entry("entry-4", 4, 400),
            entry("entry-3", 3, 300),
          ],
          nextCursor: "cursor-2",
          totalCount: 4,
        }),
      );
    },
  });

  assert.equal(requestedLimit, "2");
  assert.equal(result.entries.length, 2);
  assert.equal(result.hasMore, true);
  assert.equal(result.nextCursor, "cursor-2");
  assert.equal(result.totalCount, 4);
});

test("surfaces a continuation conflict so existing rows can be discarded", async () => {
  await assert.rejects(
    fetchStatementBatch("party-1", {
      initialCursor: "stale-cursor",
      fetcher: async () =>
        Response.json(
          { error: "Changed", code: "STATEMENT_CHANGED" },
          { status: 409 },
        ),
    }),
    StatementChangedError,
  );
});

function statementPage({
  revision,
  entries,
  nextCursor,
  totalCount,
}) {
  return {
    party: {
      id: "party-1",
      reference: "P-1",
      name: "Asha",
      shortName: "",
      phone: "",
      phoneE164: null,
      notes: "",
      groupId: null,
      groupName: null,
      balancePaise: 1_000,
      transactionCount: totalCount,
      archivedAt: null,
      createdAt: "2026-07-30T00:00:00.000Z",
      updatedAt: "2026-07-30T00:00:00.000Z",
      version: 1,
    },
    period: { from: null, to: null },
    openingBalancePaise: 125,
    periodChangePaise: 875,
    closingBalancePaise: 1_000,
    postedCount: totalCount,
    cancelledCount: 0,
    totalCount,
    statementRevision: revision,
    entries,
    nextCursor,
    hasMore: nextCursor !== null,
  };
}

function entry(id, sequence, runningBalancePaise) {
  return {
    id,
    partyId: "party-1",
    partyName: "Asha",
    sequence,
    action: "gave",
    amountPaise: 100,
    balanceEffectPaise: 100,
    narration: "",
    entryDate: `2026-07-${String(20 + sequence).padStart(2, "0")}`,
    paymentAccount: null,
    status: "posted",
    createdByName: "Owner",
    createdAt: "2026-07-30T00:00:00.000Z",
    editedAt: null,
    cancelledAt: null,
    revisionCount: 0,
    updatedAt: "2026-07-30T00:00:00.000Z",
    version: 1,
    runningBalancePaise,
  };
}
