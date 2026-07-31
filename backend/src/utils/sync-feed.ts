export type RawSyncChange = {
  company_id: string;
  cursor: string;
  entity_type: string;
  entity_id: string;
  change_type: "upsert" | "tombstone";
  entity_version: number;
  payload: Record<string, unknown> | string;
  changed_at: string;
};

export function buildSyncPage(
  rows: readonly RawSyncChange[],
  companyId: string,
  limit: number,
  fallbackCursor: string,
) {
  // SQL applies this scope as the primary boundary; this filter is a
  // defense-in-depth guard against a future query regression.
  const scoped = rows.filter((row) => row.company_id === companyId);
  const hasMore = scoped.length > limit;
  const changes = scoped.slice(0, limit).map((row) => ({
    cursor: row.cursor,
    entityType: row.entity_type,
    entityId: row.entity_id,
    changeType: row.change_type,
    version: Number(row.entity_version),
    changedAt: String(row.changed_at),
    payload:
      typeof row.payload === "string"
        ? (JSON.parse(row.payload) as Record<string, unknown>)
        : row.payload,
  }));
  return {
    changes,
    nextCursor: changes.at(-1)?.cursor ?? fallbackCursor,
    hasMore,
  };
}
