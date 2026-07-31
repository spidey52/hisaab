import { describe, expect, test } from "bun:test";
import { buildSyncPage, type RawSyncChange } from "./sync-feed";

function change(cursor: string, companyId = "company-1"): RawSyncChange {
  return {
    company_id: companyId,
    cursor,
    entity_type: "party",
    entity_id: `party-${cursor}`,
    change_type: "upsert",
    entity_version: 1,
    payload: { party: { id: `party-${cursor}` } },
    changed_at: "2026-07-31T00:00:00.000Z",
  };
}

describe("buildSyncPage", () => {
  test("returns a page cursor and detects another page", () => {
    const page = buildSyncPage(
      [change("11"), change("12"), change("13")],
      "company-1",
      2,
      "10",
    );

    expect(page.changes.map((item) => item.cursor)).toEqual(["11", "12"]);
    expect(page.nextCursor).toBe("12");
    expect(page.hasMore).toBeTrue();
  });

  test("defensively excludes changes from another company", () => {
    const page = buildSyncPage(
      [change("11", "company-2")],
      "company-1",
      2,
      "10",
    );

    expect(page.changes).toEqual([]);
    expect(page.nextCursor).toBe("10");
  });
});
