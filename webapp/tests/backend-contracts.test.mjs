import assert from "node:assert/strict";
import test from "node:test";

import {
  MAX_DISCOVERY_PHONES,
  ContactDiscoveryValidationError,
  normalizeDiscoveryPhones,
  selectDiscoverableMatches,
} from "../lib/contact-discovery.ts";
import {
  operationRequestHash,
  replayReceipt,
} from "../lib/sync-server.ts";
import {
  cursorMatchesStatementRequest,
  statementTotals,
  takeStatementPage,
} from "../lib/statement.ts";
import { buildSyncPage } from "../lib/sync-feed.ts";
import {
  decodeCursor,
  encodeCursor,
} from "../app/api/parties/[id]/statement/route.ts";
import {
  parseSyncCursor,
  parseSyncLimit,
} from "../app/api/sync/pull/route.ts";

test("idempotency replays the same intent and rejects key reuse", () => {
  const firstHash = operationRequestHash("entry.create", {
    partyId: "party-1",
    amountPaise: 500,
  });
  const reorderedHash = operationRequestHash("entry.create", {
    amountPaise: 500,
    partyId: "party-1",
  });
  assert.equal(firstHash, reorderedHash);

  const receipt = {
    operationType: "entry.create",
    requestHash: firstHash,
    responseBody: { id: "entry-1", replayed: false },
    statusCode: 201,
  };
  assert.deepEqual(replayReceipt(receipt, "entry.create", reorderedHash), {
    id: "entry-1",
    replayed: true,
  });
  assert.throws(
    () =>
      replayReceipt(
        receipt,
        "entry.create",
        operationRequestHash("entry.create", {
          partyId: "party-1",
          amountPaise: 501,
        }),
      ),
    (error) => error instanceof Response && error.status === 409,
  );
});

test("statement cursors are signed, range-bound, and pagination is bounded", () => {
  const cursor = encodeCursor({
    version: 1,
    partyId: "party-1",
    from: "2026-07-01",
    to: "2026-07-31",
    entryDate: "2026-07-20",
    sequence: 42,
    order: "newest_first",
    statementRevision: "a".repeat(43),
  });
  assert.equal(decodeCursor(cursor)?.sequence, 42);
  const tampered = `${cursor.slice(0, -1)}${cursor.endsWith("a") ? "b" : "a"}`;
  assert.throws(
    () => decodeCursor(tampered),
    (error) => error instanceof Response && error.status === 400,
  );
  assert.equal(
    cursorMatchesStatementRequest(decodeCursor(cursor), {
      partyId: "party-1",
      from: "2026-07-01",
      to: "2026-07-30",
      order: "newest_first",
    }),
    false,
  );
  assert.deepEqual(takeStatementPage([5, 4, 3], 2), {
    rows: [5, 4],
    hasMore: true,
  });
  assert.deepEqual(
    statementTotals({
      openingBalancePaise: 10_000,
      periodChangePaise: -2_500,
    }),
    {
      openingBalancePaise: 10_000,
      periodChangePaise: -2_500,
      closingBalancePaise: 7_500,
    },
  );
});

test("contact discovery normalizes, bounds, deduplicates, and honors opt-out", () => {
  assert.deepEqual(
    normalizeDiscoveryPhones([
      "98765 43210",
      "+91 98765 43210",
      "not-a-phone",
    ]),
    ["+919876543210"],
  );
  assert.throws(
    () =>
      normalizeDiscoveryPhones(
        Array.from({ length: MAX_DISCOVERY_PHONES + 1 }, () => "+919000000000"),
      ),
    ContactDiscoveryValidationError,
  );
  assert.deepEqual(
    selectDiscoverableMatches(
      ["+919876543210", "+919000000001", "+919000000002"],
      [
        {
          phoneE164: "+919876543210",
          contactDiscoverable: true,
        },
        {
          phoneE164: "+919000000001",
          contactDiscoverable: false,
        },
        {
          phoneE164: "+919000000002",
          contactDiscoverable: true,
          deleted: true,
        },
      ],
    ),
    ["+919876543210"],
  );
});

test("sync cursors are bounded and pages cannot leak another company", () => {
  assert.equal(parseSyncCursor("00042"), "42");
  assert.equal(parseSyncLimit("500"), 500);
  assert.throws(
    () => parseSyncCursor("-1"),
    (error) => error instanceof Response && error.status === 400,
  );
  const page = buildSyncPage(
    [
      rawChange("company-a", "1", "party-a"),
      rawChange("company-b", "2", "party-b"),
      rawChange("company-a", "3", "party-c"),
    ],
    "company-a",
    1,
    "0",
  );
  assert.deepEqual(page.changes.map((change) => change.entityId), ["party-a"]);
  assert.equal(page.nextCursor, "1");
  assert.equal(page.hasMore, true);
});

function rawChange(companyId, cursor, entityId) {
  return {
    company_id: companyId,
    cursor,
    entity_type: "party",
    entity_id: entityId,
    change_type: "upsert",
    entity_version: 1,
    payload: { id: entityId },
    changed_at: "2026-07-30T00:00:00.000Z",
  };
}
