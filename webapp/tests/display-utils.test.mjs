import assert from "node:assert/strict";
import test from "node:test";

import { isValidDateOnly } from "../lib/date-utils.ts";
import {
  entryAmountSign,
  entryDirectionLabel,
  entryDirectionTone,
  entryDisplayLabel,
} from "../lib/entry-display.ts";

test("uses plain fallback labels when an entry note is blank", () => {
  assert.equal(entryDisplayLabel("gave", ""), "You gave");
  assert.equal(entryDisplayLabel("received", "   "), "You got");
  assert.equal(entryDisplayLabel("opening_balance", null), "Opening balance");
  assert.equal(entryDisplayLabel("gave", "  Goods  "), "Goods");
});

test("presents money movement with an accessible sign and label", () => {
  assert.equal(entryDirectionTone("gave"), "gave");
  assert.equal(entryDirectionLabel("gave", 50000), "You gave");
  assert.equal(entryAmountSign("gave"), "−");

  assert.equal(entryDirectionTone("received"), "received");
  assert.equal(entryDirectionLabel("received", -50000), "You got");
  assert.equal(entryAmountSign("received"), "+");

  assert.equal(entryDirectionTone("opening_balance"), "opening");
  assert.equal(
    entryDirectionLabel("opening_balance", 50000),
    "They owe you",
  );
  assert.equal(
    entryDirectionLabel("opening_balance", -50000),
    "You owe them",
  );
  assert.equal(
    entryDirectionLabel("opening_balance", 0),
    "Opening balance",
  );
  assert.equal(entryAmountSign("opening_balance"), "");
});

test("accepts real calendar dates and rejects impossible dates", () => {
  assert.equal(isValidDateOnly("2026-07-30"), true);
  assert.equal(isValidDateOnly("2024-02-29"), true);
  assert.equal(isValidDateOnly("2026-02-29"), false);
  assert.equal(isValidDateOnly("2026-13-01"), false);
  assert.equal(isValidDateOnly("2026-04-31"), false);
  assert.equal(isValidDateOnly("30-07-2026"), false);
});
