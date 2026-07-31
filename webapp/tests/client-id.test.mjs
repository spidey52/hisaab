import assert from "node:assert/strict";
import { test } from "node:test";
import { createClientId } from "../lib/client-id.ts";
import {
  formatLedgerDate,
  toDateOnly,
} from "../lib/date-utils.ts";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

test("uses browser randomUUID when the secure-context API is available", () => {
  const expected = "11111111-1111-4111-8111-111111111111";
  assert.equal(createClientId({ randomUUID: () => expected }), expected);
});

test("creates a UUID with getRandomValues on an insecure HTTP origin", () => {
  const id = createClientId({
    getRandomValues(values) {
      values.forEach((_, index) => {
        values[index] = index;
      });
      return values;
    },
  });
  assert.match(id, uuidPattern);
});

test("keeps a collision-resistant fallback for restricted browsers", () => {
  const first = createClientId({});
  const second = createClientId({});
  assert.match(first, uuidPattern);
  assert.match(second, uuidPattern);
  assert.notEqual(first, second);
});

test("normalizes PostgreSQL date values without crashing the Entries page", () => {
  assert.equal(toDateOnly("2026-07-29"), "2026-07-29");
  assert.equal(
    toDateOnly(new Date("2026-07-29T00:00:00.000Z")),
    "2026-07-29",
  );
  assert.equal(toDateOnly("Wed Jul 29 2026 00:00:00 GMT+0000"), "2026-07-29");
  assert.equal(formatLedgerDate("not-a-date"), "Unknown date");
});
