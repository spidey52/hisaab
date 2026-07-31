export type StatementRequestIdentity = {
  partyId: string;
  from: string | null;
  to: string | null;
  order: "newest_first";
};

export function cursorMatchesStatementRequest(
  cursor: StatementRequestIdentity,
  request: StatementRequestIdentity,
) {
  return (
    cursor.partyId === request.partyId &&
    cursor.from === request.from &&
    cursor.to === request.to &&
    cursor.order === request.order
  );
}

export function takeStatementPage<T>(rows: readonly T[], limit: number) {
  return {
    rows: rows.slice(0, limit),
    hasMore: rows.length > limit,
  };
}

export function statementTotals(values: {
  openingBalancePaise: number;
  periodChangePaise: number;
}) {
  return {
    openingBalancePaise: values.openingBalancePaise,
    periodChangePaise: values.periodChangePaise,
    closingBalancePaise:
      values.openingBalancePaise + values.periodChangePaise,
  };
}
