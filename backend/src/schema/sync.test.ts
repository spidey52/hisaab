import { describe, expect, test } from "bun:test";
import { updateEntrySchema } from "./entries";
import { syncPullQuerySchema } from "./sync";

describe("syncPullQuerySchema", () => {
  test("normalizes a safe cursor and applies the default page size", () => {
    expect(syncPullQuerySchema.parse({ cursor: "00042" })).toEqual({
      cursor: "42",
      limit: 200,
    });
  });

  test("rejects cursors that cannot be represented safely", () => {
    expect(() => syncPullQuerySchema.parse({ cursor: "9007199254740992" }))
      .toThrow("This sync cursor is invalid.");
  });
});

describe("updateEntrySchema", () => {
  test("requires all fields for an edit operation", () => {
    expect(
      updateEntrySchema.safeParse({ operation: "edit" }).success,
    ).toBeFalse();
  });

  test("allows cancellation without edit fields", () => {
    expect(
      updateEntrySchema.safeParse({ operation: "cancel" }).success,
    ).toBeTrue();
  });
});
