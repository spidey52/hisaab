
import type { Entry, Party } from "./types";
import { apiFetch } from "./api-client";

export const STATEMENT_PAGE_LIMIT = 200;
export const STATEMENT_BATCH_LIMIT = 1_000;

export type StatementEntry = Entry & {
  runningBalancePaise: number;
};

export type StatementBatch = {
  party: Party;
  period: { from: string | null; to: string | null };
  openingBalancePaise: number;
  periodChangePaise: number;
  closingBalancePaise: number;
  postedCount: number;
  cancelledCount: number;
  totalCount: number;
  statementRevision: string;
  entries: StatementEntry[];
  nextCursor: string | null;
  hasMore: boolean;
};

export class StatementChangedError extends Error {
  constructor() {
    super("This statement changed while it was loading.");
    this.name = "StatementChangedError";
  }
}

export function statementNoteForExport(
  entry: Pick<Entry, "action" | "narration">,
  includePrivateNotes = false,
) {
  if (!includePrivateNotes || entry.action === "opening_balance") return "";
  return entry.narration.trim();
}

type ApiFetcher = (path: string, init?: RequestInit) => Promise<Response>;

type FetchStatementOptions = {
  initialCursor?: string | null;
  maxEntries?: number;
  fetcher?: ApiFetcher;
};

/**
 * Loads bounded 200-entry API pages. A fresh load is restarted once if the
 * ledger changes between pages. A continuation deliberately surfaces that
 * conflict so the caller can discard its older snapshot before restarting.
 */
export async function fetchStatementBatch(
  partyId: string,
  options: FetchStatementOptions = {},
): Promise<StatementBatch> {
  const initialCursor = options.initialCursor ?? null;
  const maxEntries = boundedBatchLimit(options.maxEntries);
  const fetcher = options.fetcher ?? apiFetch;
  const maximumAttempts = initialCursor ? 1 : 2;

  for (let attempt = 0; attempt < maximumAttempts; attempt += 1) {
    try {
      return await fetchPages({
        partyId,
        initialCursor,
        maxEntries,
        fetcher,
      });
    } catch (error) {
      if (!(error instanceof StatementChangedError)) throw error;
      if (attempt + 1 >= maximumAttempts) throw error;
    }
  }

  throw new StatementChangedError();
}

async function fetchPages({
  partyId,
  initialCursor,
  maxEntries,
  fetcher,
}: {
  partyId: string;
  initialCursor: string | null;
  maxEntries: number;
  fetcher: ApiFetcher;
}) {
  let cursor = initialCursor;
  let firstPage: StatementBatch | null = null;
  const entries: StatementEntry[] = [];
  const seenCursors = new Set<string>();

  while (entries.length < maxEntries) {
    const remaining = maxEntries - entries.length;
    const search = new URLSearchParams({
      limit: String(Math.min(STATEMENT_PAGE_LIMIT, remaining)),
    });
    if (cursor) search.set("cursor", cursor);
    const response = await fetcher(
      `/api/parties/${encodeURIComponent(partyId)}/statement?${search}`,
      {
        headers: { accept: "application/json" },
        cache: "no-store",
      },
    );
    const body = (await readResponseBody(response)) as Partial<StatementBatch> & {
      error?: unknown;
      code?: unknown;
    };
    if (!response.ok) {
      if (response.status === 409 && body.code === "STATEMENT_CHANGED") {
        throw new StatementChangedError();
      }
      throw new Error(
        typeof body.error === "string"
          ? body.error
          : "Could not load this statement.",
      );
    }

    const page = parseStatementPage(body);
    if (
      firstPage &&
      (page.statementRevision !== firstPage.statementRevision ||
        page.totalCount !== firstPage.totalCount ||
        page.openingBalancePaise !== firstPage.openingBalancePaise ||
        page.periodChangePaise !== firstPage.periodChangePaise ||
        page.closingBalancePaise !== firstPage.closingBalancePaise)
    ) {
      throw new StatementChangedError();
    }
    firstPage ??= page;
    entries.push(...page.entries);

    if (!page.hasMore || !page.nextCursor) {
      return { ...firstPage, entries, nextCursor: null, hasMore: false };
    }
    if (seenCursors.has(page.nextCursor)) {
      throw new Error("The statement server returned a repeated page.");
    }
    seenCursors.add(page.nextCursor);
    cursor = page.nextCursor;
  }

  if (!firstPage) {
    throw new Error("Could not load this statement.");
  }
  return { ...firstPage, entries, nextCursor: cursor, hasMore: true };
}

function parseStatementPage(body: Partial<StatementBatch>): StatementBatch {
  if (
    !body.party ||
    !body.period ||
    !Array.isArray(body.entries) ||
    typeof body.openingBalancePaise !== "number" ||
    typeof body.periodChangePaise !== "number" ||
    typeof body.closingBalancePaise !== "number" ||
    typeof body.postedCount !== "number" ||
    typeof body.cancelledCount !== "number" ||
    typeof body.totalCount !== "number" ||
    typeof body.statementRevision !== "string" ||
    typeof body.hasMore !== "boolean" ||
    (body.nextCursor !== null && typeof body.nextCursor !== "string") ||
    body.entries.some(
      (entry) =>
        typeof (entry as Partial<StatementEntry>).runningBalancePaise !==
        "number",
    )
  ) {
    throw new Error("Hisaab returned an invalid statement page.");
  }
  return body as StatementBatch;
}

async function readResponseBody(response: Response) {
  try {
    return (await response.json()) as unknown;
  } catch {
    return {};
  }
}

function boundedBatchLimit(value: number | undefined) {
  if (value === undefined) return STATEMENT_BATCH_LIMIT;
  if (!Number.isSafeInteger(value) || value < 1) {
    throw new Error("Statement batch size must be a positive whole number.");
  }
  return value;
}
