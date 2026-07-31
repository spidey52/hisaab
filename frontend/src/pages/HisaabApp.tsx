import {
  Archive,
  ArrowLeft,
  ArrowUpRight,
  BookOpen,
  Building2,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  Clock3,
  CloudOff,
  Download,
  FileClock,
  FileText,
  Home,
  Languages,
  LoaderCircle,
  Merge,
  MoreHorizontal,
  Pencil,
  Plus,
  ReceiptText,
  RefreshCw,
  Scale,
  Search,
  Settings,
  Share2,
  ShieldCheck,
  SlidersHorizontal,
  Trash2,
  UserPlus,
  Users,
  Wifi,
  X,
} from "lucide-react";
import {
  createContext,
  type FormEvent,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  useNavigate,
  useParams,
  useRouter,
  useRouterState,
} from "@tanstack/react-router";
import { Brand } from "../components/Brand";
import {
  flushBeforeBootstrap,
  flushEntryQueue,
  getQueue,
  type QueuedEntry,
  queueEntry,
  readCachedData,
  reconcileQueuedEntries,
  removeQueuedEntry,
  retryQueuedEntry,
  updateQueuedEntry,
  writeCachedData,
} from "@/lib/offline-client";
import { createClientId } from "@/lib/client-id";
import {
  formatLedgerDate,
  formatLocalDateTime,
  formatLongDate,
  isValidDateOnly,
  isWithinLastDays,
  nowIso,
  parseMs,
  shiftDateOnly,
  todayInTimezone,
} from "@/lib/date-utils";
import {
  entryAmountSign,
  entryDirectionLabel,
  entryDirectionTone,
  entryDisplayLabel,
} from "@/lib/entry-display";
import {
  fetchStatementBatch,
  type StatementBatch,
  StatementChangedError,
  statementNoteForExport,
} from "@/lib/statement-client";
import type { ApiError, BootstrapData, Entry, Party } from "@/lib/types";
import { apiFetch, clearSessionToken } from "@/lib/api-client";

type Tab = "home" | "parties" | "entries" | "learn" | "more";
type Filter = "all" | "receive" | "pay" | "settled" | "recent" | "archived";
type DatePreset = "all" | "month" | "30days" | "custom";
type EntryActionChoice = "gave" | "received";
type Overlay =
  | {
    kind: "party-form";
    partyId?: string;
    continueEntryAction?: EntryActionChoice;
  }
  | {
    kind: "entry-form";
    partyId?: string;
    entryId?: string;
    action?: EntryActionChoice;
  }
  | { kind: "entry-detail"; entryId: string }
  | { kind: "opening-balance"; partyId: string }
  | { kind: "merge" }
  | { kind: "offline-queue" }
  | { kind: "delete-account" }
  | null;

const OverlayReturnFocusContext = createContext<
  {
    current: HTMLElement | null;
  } | null
>(null);

const copy = {
  en: {
    home: "Home",
    parties: "Parties",
    entries: "Entries",
    learn: "Learn",
    more: "More",
    addPerson: "Add customer or supplier",
    receive: "You will receive",
    pay: "You will pay",
    settled: "Settled",
    search: "Search name, phone or reference",
    all: "All",
    recent: "Recent",
    archived: "Archived",
  },
  hi: {
    home: "होम",
    parties: "पार्टी",
    entries: "एंट्री",
    learn: "सीखें",
    more: "और",
    addPerson: "ग्राहक या सप्लायर जोड़ें",
    receive: "आपको मिलेंगे",
    pay: "आप देंगे",
    settled: "हिसाब बराबर",
    search: "नाम, फ़ोन या रेफ़रेंस खोजें",
    all: "सभी",
    recent: "हाल के",
    archived: "संग्रहित",
  },
} as const;

export function HisaabClient({ signedInPhone }: { signedInPhone: string }) {
  const navigate = useNavigate();
  const router = useRouter();
  const pathname = useRouterState({
    select: (state) => state.location.pathname,
  });
  const { partyId } = useParams({ strict: false }) as { partyId?: string };
  const tab: Tab = pathname.startsWith("/app/parties")
    ? "parties"
    : pathname.startsWith("/app/entries")
    ? "entries"
    : pathname.startsWith("/app/learn")
    ? "learn"
    : pathname.startsWith("/app/settings")
    ? "more"
    : "home";
  const selectedPartyId = partyId ?? null;

  const setTab = useCallback(
    (next: Tab) => {
      if (next === "home") void navigate({ to: "/app" });
      if (next === "parties") void navigate({ to: "/app/parties" });
      if (next === "entries") void navigate({ to: "/app/entries" });
      if (next === "learn") void navigate({ to: "/app/learn" });
      if (next === "more") void navigate({ to: "/app/settings" });
    },
    [navigate],
  );

  const setSelectedPartyId = useCallback(
    (next: string | null) => {
      if (next) {
        void navigate({
          to: "/app/parties/$partyId",
          params: { partyId: next },
        });
        return;
      }
      void navigate({ to: "/app/parties" });
    },
    [navigate],
  );

  const [data, setData] = useState<BootstrapData | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [partyQuery, setPartyQuery] = useState("");
  const [entryQuery, setEntryQuery] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const [offline, setOffline] = useState(false);
  const [queueCount, setQueueCount] = useState(0);
  const [queueItems, setQueueItems] = useState<QueuedEntry[]>([]);
  const [statements, setStatements] = useState<Record<string, StatementBatch>>(
    {},
  );
  const [statementErrors, setStatementErrors] = useState<
    Record<string, string>
  >({});
  const [statementLoadingId, setStatementLoadingId] = useState<string | null>(
    null,
  );
  const [overlay, setOverlay] = useState<Overlay>(null);
  const overlayReturnFocus = useRef<HTMLElement | null>(null);
  const [toast, setToast] = useState<
    {
      message: string;
      action?: { label: string; run: () => void };
    } | null
  >(null);

  const refreshQueueState = useCallback(() => {
    const next = getQueue(signedInPhone);
    setQueueItems(next);
    setQueueCount(next.length);
    return next;
  }, [signedInPhone]);

  const loadData = useCallback(async () => {
    try {
      const response = await apiFetch("/api/bootstrap", {
        headers: { accept: "application/json" },
        cache: "no-store",
      });
      if (response.status === 401) {
        clearSessionToken();
        await router.invalidate();
        return;
      }
      if (!response.ok) throw new Error("Could not load your Hisaab.");
      const next = (await response.json()) as BootstrapData;
      const reconciled = reconcileQueuedEntries(
        next,
        refreshQueueState(),
      );
      setData(reconciled);
      writeCachedData(signedInPhone, reconciled);
      setOffline(false);
      setLoadError("");
    } catch {
      const cached = readCachedData(signedInPhone);
      if (cached) {
        const reconciled = reconcileQueuedEntries(
          cached,
          refreshQueueState(),
        );
        setData(reconciled);
        writeCachedData(signedInPhone, reconciled);
        setOffline(true);
      } else {
        setLoadError(
          "Your Hisaab could not be loaded. Check your internet and try again.",
        );
      }
    } finally {
      refreshQueueState();
      setLoading(false);
    }
  }, [refreshQueueState, router, signedInPhone]);

  useEffect(() => {
    async function start() {
      // A prior session may have closed before the browser emitted `online`.
      // Retry its durable outbox before reading the fresh server snapshot.
      const { queue: result } = await flushBeforeBootstrap(
        signedInPhone,
        loadData,
      );
      refreshQueueState();
      if (result.uploaded > 0) {
        setToast({
          message: `${result.uploaded} saved ${
            result.uploaded === 1 ? "entry" : "entries"
          } uploaded.`,
        });
      } else if (result.needsAttention > 0) {
        setToast({
          message: `${result.needsAttention} saved ${
            result.needsAttention === 1 ? "entry needs" : "entries need"
          } your review.`,
        });
      }
    }
    void start();
  }, [loadData, refreshQueueState, signedInPhone]);

  useEffect(() => {
    async function reconnect() {
      setOffline(false);
      const result = await flushEntryQueue(signedInPhone);
      refreshQueueState();
      if (result.uploaded > 0) {
        setToast({
          message: `${result.uploaded} saved ${
            result.uploaded === 1 ? "entry" : "entries"
          } uploaded.`,
        });
      } else if (result.needsAttention > 0) {
        setToast({
          message: `${result.needsAttention} saved ${
            result.needsAttention === 1 ? "entry needs" : "entries need"
          } your review.`,
        });
      }
      await loadData();
    }
    function disconnect() {
      setOffline(true);
    }
    window.addEventListener("online", reconnect);
    window.addEventListener("offline", disconnect);
    return () => {
      window.removeEventListener("online", reconnect);
      window.removeEventListener("offline", disconnect);
    };
  }, [loadData, refreshQueueState, signedInPhone]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 5000);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const language = data?.user.language ?? "en";
  const t = (key: keyof (typeof copy)["en"]) => copy[language][key];

  const loadPartyStatement = useCallback(
    async (partyId: string, cursor: string | null = null) => {
      setStatementLoadingId(partyId);
      setStatementErrors((current) => {
        const next = { ...current };
        delete next[partyId];
        return next;
      });
      try {
        let append = Boolean(cursor);
        let result: StatementBatch;
        try {
          result = await fetchStatementBatch(partyId, {
            initialCursor: cursor,
          });
        } catch (error) {
          if (!(error instanceof StatementChangedError) || !cursor) throw error;
          // A continuation belongs to the old revision. Discard it and restart
          // once from the newest page so mixed-revision rows are never shown.
          result = await fetchStatementBatch(partyId);
          append = false;
        }
        setStatements((current) => {
          const previous = current[partyId];
          if (
            !append ||
            !previous ||
            previous.statementRevision !== result.statementRevision
          ) {
            return { ...current, [partyId]: result };
          }
          const ids = new Set(previous.entries.map((entry) => entry.id));
          return {
            ...current,
            [partyId]: {
              ...result,
              entries: [
                ...previous.entries,
                ...result.entries.filter((entry) => !ids.has(entry.id)),
              ],
            },
          };
        });
      } catch (error) {
        setStatementErrors((current) => ({
          ...current,
          [partyId]: error instanceof Error
            ? error.message
            : "Could not load this statement.",
        }));
      } finally {
        setStatementLoadingId((current) =>
          current === partyId ? null : current
        );
      }
    },
    [],
  );

  const routedPartyRequest = useRef<string | null>(null);
  useEffect(() => {
    if (!selectedPartyId) {
      routedPartyRequest.current = null;
      return;
    }
    if (!data || offline || routedPartyRequest.current === selectedPartyId) {
      return;
    }
    if (!data.parties.some((party) => party.id === selectedPartyId)) {
      void navigate({ to: "/app/parties", replace: true });
      return;
    }
    routedPartyRequest.current = selectedPartyId;
    void loadPartyStatement(selectedPartyId);
  }, [data, loadPartyStatement, navigate, offline, selectedPartyId]);

  const visibleParties = useMemo(() => {
    if (!data) return [];
    const needle = partyQuery.toLowerCase().replace(/\s/g, "");
    const now = parseMs(data.serverTime);
    return data.parties.filter((party) => {
      const haystack = [
        party.name,
        party.shortName,
        party.phone.replace(/\s/g, ""),
        party.reference,
      ]
        .join(" ")
        .toLowerCase()
        .replace(/\s/g, "");
      const matchesSearch = !needle || haystack.includes(needle);
      const archived = Boolean(party.archivedAt);
      let matchesFilter = !archived;
      if (filter === "archived") matchesFilter = archived;
      if (filter === "receive") {
        matchesFilter = !archived && party.balancePaise > 0;
      }
      if (filter === "pay") {
        matchesFilter = !archived && party.balancePaise < 0;
      }
      if (filter === "settled") {
        matchesFilter = !archived && party.balancePaise === 0;
      }
      if (filter === "recent") {
        matchesFilter = !archived &&
          isWithinLastDays(party.createdAt, 30, now);
      }
      return matchesSearch && matchesFilter;
    });
  }, [data, filter, partyQuery]);

  const totals = useMemo(() => {
    const parties = data?.parties.filter((party) => !party.archivedAt) ?? [];
    return parties.reduce(
      (result, party) => {
        if (party.balancePaise > 0) result.receive += party.balancePaise;
        if (party.balancePaise < 0) result.pay += -party.balancePaise;
        return result;
      },
      { receive: 0, pay: 0 },
    );
  }, [data]);

  const selectedParty =
    data?.parties.find((party) => party.id === selectedPartyId) ?? null;
  const selectedEntryId =
    overlay?.kind === "entry-detail" || overlay?.kind === "entry-form"
      ? overlay.entryId
      : undefined;
  const selectedEntry = selectedEntryId
    ? data?.entries.find((entry) => entry.id === selectedEntryId) ??
      Object.values(statements)
        .flatMap((statement) => statement.entries)
        .find((entry) => entry.id === selectedEntryId) ??
      null
    : null;

  async function refreshAfter(message: string) {
    await loadData();
    setStatements({});
    if (selectedPartyId) await loadPartyStatement(selectedPartyId);
    setToast({ message });
  }

  async function signOut() {
    try {
      await apiFetch("/api/auth/logout", { method: "POST" });
    } finally {
      clearSessionToken();
      await router.invalidate();
    }
  }

  async function leaveDeletedAccount() {
    clearSessionToken();
    await router.invalidate();
  }

  async function cancelEntry(entry: Entry) {
    const response = await apiFetch(`/api/entries/${entry.id}`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        operation: "cancel",
        idempotencyKey: createClientId(),
        baseVersion: entry.version,
      }),
    });
    if (!response.ok) {
      const error = (await response.json()) as ApiError;
      throw new Error(error.error);
    }
    setOverlay(null);
    await refreshAfter(`Entry ${entry.sequence} cancelled. Balance updated.`);
  }

  async function undoCreatedEntry(id: string, sequence: number) {
    const response = await apiFetch(`/api/entries/${id}`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        operation: "cancel",
        idempotencyKey: createClientId(),
      }),
    });
    if (!response.ok) {
      setToast({
        message: "The entry could not be undone. Open it to cancel.",
      });
      return;
    }
    await refreshAfter(
      `Entry ${sequence} undone. Its number remains in history.`,
    );
  }

  function openEntryForm(action: EntryActionChoice, partyId?: string) {
    const hasActiveParty = data?.parties.some((party) => !party.archivedAt);
    if (!partyId && !hasActiveParty) {
      showOverlay({ kind: "party-form", continueEntryAction: action });
      setToast({ message: "Add a party before creating your first entry." });
      return;
    }
    showOverlay({ kind: "entry-form", partyId, action });
  }

  function showOverlay(next: Exclude<Overlay, null>) {
    overlayReturnFocus.current = document.activeElement instanceof HTMLElement
      ? document.activeElement
      : null;
    setOverlay(next);
  }

  function openParty(party: Party) {
    setSelectedPartyId(party.id);
  }

  if (loading) return <LoadingScreen />;
  if (!data) {
    return (
      <main className="fatal-state">
        <Brand />
        <CircleAlert size={38} aria-hidden="true" />
        <h1>We could not open your Hisaab</h1>
        <p>{loadError}</p>
        <button className="button button-primary" onClick={loadData}>
          <RefreshCw size={18} /> Try again
        </button>
      </main>
    );
  }

  return (
    <OverlayReturnFocusContext.Provider value={overlayReturnFocus}>
      <div
        className={`app-shell ${
          data.user.accessibilityMode ? "accessible-type" : ""
        }`}
      >
        <aside className="side-nav">
          <Brand compact />
          <nav aria-label="Application navigation">
            <NavButton
              selected={tab === "home"}
              label={t("home")}
              icon={<Home />}
              onClick={() => setTab("home")}
            />
            <NavButton
              selected={tab === "parties"}
              label={t("parties")}
              icon={<Users />}
              onClick={() => setTab("parties")}
            />
            <NavButton
              selected={tab === "entries"}
              label={t("entries")}
              icon={<ReceiptText />}
              onClick={() => setTab("entries")}
            />
            <NavButton
              selected={tab === "learn"}
              label={t("learn")}
              icon={<BookOpen />}
              onClick={() => setTab("learn")}
            />
            <NavButton
              selected={tab === "more"}
              label={t("more")}
              icon={<MoreHorizontal />}
              onClick={() => setTab("more")}
            />
          </nav>
          <div className="side-nav-bottom">
            <SyncStatus
              offline={offline}
              queueCount={queueCount}
              onReview={() => showOverlay({ kind: "offline-queue" })}
            />
            <div className="account-mini">
              <span className="avatar">{initials(data.user.fullName)}</span>
              <div>
                <strong>{data.user.fullName}</strong>
                <small>{data.user.phoneE164}</small>
              </div>
            </div>
          </div>
        </aside>

        <main className="app-main">
          <header className="app-header">
            <div>
              <strong>{data.company.name}</strong>
              <span>{formatLongDate(undefined, data.company.timezone)}</span>
            </div>
            <div className="app-header-actions">
              <SyncStatus
                offline={offline}
                queueCount={queueCount}
                compact
                onReview={() => showOverlay({ kind: "offline-queue" })}
              />
              <span className="avatar">{initials(data.user.fullName)}</span>
            </div>
          </header>
          {queueCount
            ? (
              <button
                type="button"
                className="mobile-sync-review"
                onClick={() => showOverlay({ kind: "offline-queue" })}
              >
                {offline ? <CloudOff /> : <CircleAlert />}
                <span>
                  <strong>
                    {queueCount} saved offline{" "}
                    {queueCount === 1 ? "entry" : "entries"}
                  </strong>
                  <small>Tap to review upload status or fix a problem.</small>
                </span>
                <ChevronRight />
              </button>
            )
            : null}

          {tab === "home"
            ? (
              <HomeView
                data={data}
                totals={totals}
                t={t}
                onOpenEntry={(entry) =>
                  showOverlay({ kind: "entry-detail", entryId: entry.id })}
                onAddEntry={(action) => openEntryForm(action)}
                onAddParty={() => showOverlay({ kind: "party-form" })}
                onViewParties={() => setTab("parties")}
              />
            )
            : null}

          {tab === "parties"
            ? (
              <PartiesView
                data={data}
                parties={visibleParties}
                query={partyQuery}
                setQuery={setPartyQuery}
                filter={filter}
                setFilter={setFilter}
                selectedParty={selectedParty}
                selectedStatementEntries={selectedParty
                  ? mergePendingStatementEntries(
                    statements[selectedParty.id]?.entries ??
                      data.entries.filter(
                        (entry) => entry.partyId === selectedParty.id,
                      ),
                    data.entries,
                    selectedParty.id,
                  )
                  : []}
                statement={selectedParty
                  ? statements[selectedParty.id]
                  : undefined}
                statementError={selectedParty
                  ? statementErrors[selectedParty.id]
                  : undefined}
                statementLoading={statementLoadingId === selectedParty?.id}
                onSelectParty={openParty}
                onBack={() => setSelectedPartyId(null)}
                onAddParty={() => showOverlay({ kind: "party-form" })}
                onAddEntry={(party, action) => openEntryForm(action, party.id)}
                onEditParty={(party) =>
                  showOverlay({ kind: "party-form", partyId: party.id })}
                onOpeningBalance={(party) =>
                  showOverlay({ kind: "opening-balance", partyId: party.id })}
                onOpenEntry={(entry) =>
                  showOverlay({ kind: "entry-detail", entryId: entry.id })}
                onLoadOlder={(party, cursor) =>
                  loadPartyStatement(party.id, cursor)}
                onArchive={async (party) => {
                  const response = await apiFetch(`/api/parties/${party.id}`, {
                    method: "PATCH",
                    headers: { "content-type": "application/json" },
                    body: JSON.stringify({
                      archived: !party.archivedAt,
                      idempotencyKey: createClientId(),
                      baseVersion: party.version,
                    }),
                  });
                  if (!response.ok) {
                    throw new Error(
                      "Could not update this party.",
                    );
                  }
                  setStatements((current) => {
                    const next = { ...current };
                    delete next[party.id];
                    return next;
                  });
                  setSelectedPartyId(null);
                  await refreshAfter(
                    party.archivedAt ? "Party restored." : "Party archived.",
                  );
                }}
              />
            )
            : null}

          {tab === "entries"
            ? (
              <EntriesView
                entries={data.entries}
                timezone={data.company.timezone}
                query={entryQuery}
                setQuery={setEntryQuery}
                onOpenEntry={(entry) =>
                  showOverlay({ kind: "entry-detail", entryId: entry.id })}
                onAddEntry={(action) => openEntryForm(action)}
              />
            )
            : null}

          {tab === "learn"
            ? (
              <LearnView
                onAddEntry={(action) => openEntryForm(action)}
                onAddParty={() => showOverlay({ kind: "party-form" })}
                onViewParties={() => setTab("parties")}
              />
            )
            : null}

          {tab === "more"
            ? (
              <MoreView
                data={data}
                offline={offline}
                onRefresh={loadData}
                onMerge={() => showOverlay({ kind: "merge" })}
                onDelete={() => showOverlay({ kind: "delete-account" })}
                onUpdated={(message) => refreshAfter(message)}
                onSignOut={signOut}
              />
            )
            : null}
        </main>

        <nav className="bottom-nav" aria-label="Application navigation">
          <NavButton
            selected={tab === "home"}
            label={t("home")}
            icon={<Home />}
            onClick={() => setTab("home")}
          />
          <NavButton
            selected={tab === "parties"}
            label={t("parties")}
            icon={<Users />}
            onClick={() => setTab("parties")}
          />
          <NavButton
            selected={tab === "entries"}
            label={t("entries")}
            icon={<ReceiptText />}
            onClick={() => setTab("entries")}
          />
          <NavButton
            selected={tab === "learn"}
            label={t("learn")}
            icon={<BookOpen />}
            onClick={() => setTab("learn")}
          />
          <NavButton
            selected={tab === "more"}
            label={t("more")}
            icon={<MoreHorizontal />}
            onClick={() => setTab("more")}
          />
        </nav>

        {overlay?.kind === "party-form"
          ? (
            <PartyFormDialog
              data={data}
              existing={data.parties.find(
                (party) => party.id === overlay.partyId,
              )}
              onClose={() => setOverlay(null)}
              onOpenParty={(partyId) => {
                setOverlay(null);
                setSelectedPartyId(partyId);
              }}
              onSaved={async (createdPartyId) => {
                const wasEditing = Boolean(overlay.partyId);
                const continueEntryAction = overlay.continueEntryAction;
                if (!wasEditing && createdPartyId && continueEntryAction) {
                  await loadData();
                  setStatements({});
                  setOverlay({
                    kind: "entry-form",
                    partyId: createdPartyId,
                    action: continueEntryAction,
                  });
                  setToast({ message: "Party added. Now enter the amount." });
                  return;
                }
                setOverlay(null);
                await refreshAfter(
                  wasEditing ? "Party updated." : "Party added.",
                );
              }}
            />
          )
          : overlay?.kind === "entry-form"
          ? (
            <EntryFormDialog
              data={data}
              signedInPhone={signedInPhone}
              initialPartyId={overlay.partyId}
              initialAction={overlay.action}
              editing={selectedEntry ?? undefined}
              onClose={() => setOverlay(null)}
              onSaved={async (message, optimistic, created, queuedId) => {
                setOverlay(null);
                if (optimistic) {
                  setStatements({});
                  setData(optimistic);
                  writeCachedData(signedInPhone, optimistic);
                  refreshQueueState();
                  setToast({
                    message,
                    action: queuedId
                      ? {
                        label: "Undo",
                        run: () => {
                          removeQueuedEntry(signedInPhone, queuedId);
                          setData(data);
                          writeCachedData(signedInPhone, data);
                          refreshQueueState();
                        },
                      }
                      : undefined,
                  });
                } else {
                  await loadData();
                  setStatements({});
                  if (selectedPartyId) {
                    await loadPartyStatement(selectedPartyId);
                  }
                  setToast({
                    message,
                    action: created
                      ? {
                        label: "Undo",
                        run: () => {
                          void undoCreatedEntry(created.id, created.sequence);
                        },
                      }
                      : undefined,
                  });
                }
              }}
            />
          )
          : overlay?.kind === "entry-detail" && selectedEntry
          ? (
            <EntryDetailDialog
              entry={selectedEntry}
              readOnly={Boolean(
                data.parties.find((party) => party.id === selectedEntry.partyId)
                  ?.archivedAt || selectedEntry.clientSync,
              )}
              onClose={() => setOverlay(null)}
              onEdit={() => {
                setOverlay({ kind: "entry-form", entryId: selectedEntry.id });
              }}
              onCancel={() => cancelEntry(selectedEntry)}
            />
          )
          : overlay?.kind === "opening-balance"
          ? (
            <OpeningBalanceDialog
              party={data.parties.find((party) =>
                party.id === overlay.partyId
              )!}
              existing={(
                statements[overlay.partyId]?.entries ?? data.entries
              ).find(
                (entry) => entry.partyId === overlay.partyId &&
                  entry.action === "opening_balance" &&
                  entry.status === "posted",
              )}
              timezone={data.company.timezone}
              onClose={() => setOverlay(null)}
              onSaved={async () => {
                setOverlay(null);
                await refreshAfter(
                  "Opening balance saved and history recalculated.",
                );
              }}
            />
          )
          : overlay?.kind === "merge"
          ? (
            <MergeDialog
              parties={data.parties.filter((party) => !party.archivedAt)}
              onClose={() => setOverlay(null)}
              onSaved={async () => {
                setOverlay(null);
                await refreshAfter("Duplicate records merged safely.");
              }}
            />
          )
          : overlay?.kind === "offline-queue"
          ? (
            <OfflineQueueDialog
              items={queueItems}
              parties={data.parties}
              offline={offline}
              onClose={() => setOverlay(null)}
              onRetry={async (id) => {
                retryQueuedEntry(signedInPhone, id);
                const pending = refreshQueueState();
                setData((current) =>
                  current ? reconcileQueuedEntries(current, pending) : current
                );
                if (offline) {
                  setToast({
                    message:
                      "Marked for retry. Hisaab will upload it when you reconnect.",
                  });
                  return;
                }
                const result = await flushEntryQueue(signedInPhone);
                refreshQueueState();
                await loadData();
                setStatements({});
                if (selectedPartyId) {
                  await loadPartyStatement(selectedPartyId);
                }
                setToast({
                  message: result.uploaded
                    ? "Saved entry uploaded."
                    : "The entry is still saved and needs your review.",
                });
              }}
              onDiscard={(id) => {
                removeQueuedEntry(signedInPhone, id);
                const remaining = refreshQueueState();
                setData((current) =>
                  current ? reconcileQueuedEntries(current, remaining) : current
                );
                setToast({ message: "Saved offline entry discarded." });
              }}
              onEdit={(id, updates) => {
                updateQueuedEntry(signedInPhone, id, updates);
                const corrected = refreshQueueState();
                setData((current) =>
                  current ? reconcileQueuedEntries(current, corrected) : current
                );
                setToast({
                  message: offline
                    ? "Correction saved. It will retry when you reconnect."
                    : "Correction saved. Choose Retry now to upload it.",
                });
              }}
            />
          )
          : overlay?.kind === "delete-account"
          ? (
            <DeleteAccountDialog
              onClose={() => setOverlay(null)}
              onDeleted={leaveDeletedAccount}
            />
          )
          : null}

        {toast
          ? (
            <div className="toast" role="status">
              <span>{toast.message}</span>
              {toast.action
                ? (
                  <button
                    onClick={() => {
                      toast.action?.run();
                      setToast(null);
                    }}
                  >
                    {toast.action.label}
                  </button>
                )
                : null}
              <button aria-label="Dismiss" onClick={() => setToast(null)}>
                <X />
              </button>
            </div>
          )
          : null}
      </div>
    </OverlayReturnFocusContext.Provider>
  );
}

function EntryActionButtons({
  onChoose,
  compact = false,
}: {
  onChoose: (action: EntryActionChoice) => void;
  compact?: boolean;
}) {
  return (
    <section
      className={`entry-action-buttons ${compact ? "compact" : ""}`}
      aria-label="Record an entry"
    >
      <button
        type="button"
        className="entry-action-choice gave"
        onClick={() => onChoose("gave")}
      >
        <span aria-hidden="true">−</span>
        You gave
      </button>
      <button
        type="button"
        className="entry-action-choice received"
        onClick={() => onChoose("received")}
      >
        <span aria-hidden="true">+</span>
        You got
      </button>
    </section>
  );
}

function HomeView({
  data,
  totals,
  t,
  onOpenEntry,
  onAddEntry,
  onAddParty,
  onViewParties,
}: {
  data: BootstrapData;
  totals: { receive: number; pay: number };
  t: (key: keyof (typeof copy)["en"]) => string;
  onOpenEntry: (entry: Entry) => void;
  onAddEntry: (action: EntryActionChoice) => void;
  onAddParty: () => void;
  onViewParties: () => void;
}) {
  const recentEntries = data.entries
    .filter((entry) => entry.status === "posted")
    .slice(0, 5);
  return (
    <div className="app-view">
      <div className="view-title-row">
        <div>
          <h1>{t("home")}</h1>
          <p>Your Hisaab at a glance</p>
        </div>
      </div>

      <section className="balance-rail">
        <div className="primary-balance">
          <span>{t("receive")}</span>
          <strong>{formatInr(totals.receive)}</strong>
        </div>
        <div className="secondary-balance">
          <span>{t("pay")}</span>
          <strong>{formatInr(totals.pay)}</strong>
        </div>
        <div className="record-count">
          <span>Active people</span>
          <strong>
            {data.parties.filter((party) => !party.archivedAt).length}
          </strong>
        </div>
      </section>

      <EntryActionButtons onChoose={onAddEntry} />

      <div className="section-title-row">
        <div>
          <h2>Recent activity</h2>
          <p>Your latest saved entries</p>
        </div>
        <button className="quiet-action" onClick={onViewParties}>
          View all parties <ChevronRight />
        </button>
      </div>

      <section className="entry-list home-entry-list">
        {recentEntries.length === 0
          ? (
            <EmptyState
              icon={<ReceiptText />}
              title="No entries yet"
              body="Add a party, then record what you gave or got."
              action={{ label: "Add your first party", run: onAddParty }}
            />
          )
          : (
            recentEntries.map((entry) => (
              <button
                key={entry.id}
                className={`entry-row ${
                  entry.status === "cancelled" ? "cancelled" : ""
                }`}
                onClick={() => onOpenEntry(entry)}
              >
                <EntryDirectionBadge entry={entry} />
                <span className="entry-main">
                  <strong>{entry.partyName}</strong>
                  <small>{entryNoteLabel(entry)}</small>
                  <span className="entry-meta">
                    {formatEntryDate(entry.entryDate)}
                    <i>·</i>
                    {entry.sequence > 0
                      ? `Entry ${entry.sequence}`
                      : "On this phone"}
                  </span>
                </span>
                <EntryMoney entry={entry} className="entry-amount" />
                <ChevronRight />
              </button>
            ))
          )}
      </section>
    </div>
  );
}

function PartiesView({
  data,
  parties,
  query,
  setQuery,
  filter,
  setFilter,
  selectedParty,
  selectedStatementEntries,
  statement,
  statementError,
  statementLoading,
  onSelectParty,
  onBack,
  onAddParty,
  onAddEntry,
  onEditParty,
  onOpeningBalance,
  onOpenEntry,
  onLoadOlder,
  onArchive,
}: {
  data: BootstrapData;
  parties: Party[];
  query: string;
  setQuery: (value: string) => void;
  filter: Filter;
  setFilter: (value: Filter) => void;
  selectedParty: Party | null;
  selectedStatementEntries: Entry[];
  statement?: StatementBatch;
  statementError?: string;
  statementLoading: boolean;
  onSelectParty: (party: Party) => void;
  onBack: () => void;
  onAddParty: () => void;
  onAddEntry: (party: Party, action: EntryActionChoice) => void;
  onEditParty: (party: Party) => void;
  onOpeningBalance: (party: Party) => void;
  onOpenEntry: (entry: Entry) => void;
  onLoadOlder: (party: Party, cursor: string | null) => Promise<void>;
  onArchive: (party: Party) => Promise<void>;
}) {
  const filters: Array<{ id: Filter; label: string }> = [
    { id: "all", label: "All" },
    { id: "receive", label: "To receive" },
    { id: "pay", label: "To pay" },
    { id: "settled", label: "Settled" },
    { id: "recent", label: "Recent" },
    { id: "archived", label: "Archived" },
  ];
  const [filterOpen, setFilterOpen] = useState(false);
  const filterPanelId = useId();
  const activeFilterLabel = filters.find((item) => item.id === filter)?.label ??
    "Filter";

  return (
    <div
      className={`app-view parties-view ${
        selectedParty ? "show-statement" : ""
      }`}
    >
      <section className="parties-directory">
        <div className="view-title-row">
          <div>
            <h1>Parties</h1>
            <p>Everyone you buy from or sell to</p>
          </div>
          <button
            className="button button-primary desktop-only"
            onClick={onAddParty}
          >
            <UserPlus size={18} /> Add party
          </button>
        </div>
        <div className="list-tools">
          <label className="search-control">
            <Search aria-hidden="true" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search by name or phone"
            />
            {query
              ? (
                <button aria-label="Clear search" onClick={() => setQuery("")}>
                  <X />
                </button>
              )
              : null}
          </label>
          <button
            type="button"
            className={`filter-trigger ${filter !== "all" ? "active" : ""}`}
            aria-expanded={filterOpen}
            aria-controls={filterPanelId}
            onClick={() => setFilterOpen((value) => !value)}
          >
            <SlidersHorizontal />
            <span>{filter === "all" ? "Filter" : activeFilterLabel}</span>
            <ChevronRight className={filterOpen ? "rotated" : ""} />
          </button>
          {filterOpen
            ? (
              <div
                className="filter-panel party-filter-panel"
                id={filterPanelId}
              >
                <span className="filter-panel-label">Show parties</span>
                <div className="filter-row" aria-label="Party balance filters">
                  {filters.map((item) => (
                    <button
                      type="button"
                      key={item.id}
                      className={filter === item.id ? "selected" : ""}
                      onClick={() => {
                        setFilter(item.id);
                        setFilterOpen(false);
                      }}
                    >
                      {item.label}
                    </button>
                  ))}
                </div>
                {filter !== "all"
                  ? (
                    <button
                      type="button"
                      className="clear-filter"
                      onClick={() => {
                        setFilter("all");
                        setFilterOpen(false);
                      }}
                    >
                      Clear filter
                    </button>
                  )
                  : null}
              </div>
            )
            : null}
        </div>
        <section className="party-list" aria-label="All parties">
          {parties.length === 0
            ? (
              <EmptyState
                icon={<Users />}
                title={query ? "No matching parties" : "No parties here yet"}
                body={query
                  ? "Try a different name or phone number."
                  : filter === "archived"
                  ? "Archived parties will appear here."
                  : "A name is enough to start keeping Hisaab."}
                action={query || filter === "archived"
                  ? undefined
                  : { label: "Add party", run: onAddParty }}
              />
            )
            : (
              parties.map((party) => (
                <button
                  className={`party-row ${
                    selectedParty?.id === party.id ? "selected" : ""
                  }`}
                  key={party.id}
                  onClick={() => onSelectParty(party)}
                >
                  <span
                    className={`avatar ${
                      party.balancePaise < 0 ? "amber" : ""
                    }`}
                  >
                    {initials(party.name)}
                  </span>
                  <span className="party-name">
                    <strong>{party.name}</strong>
                    <small>
                      {party.phone || party.shortName || party.reference}
                    </small>
                  </span>
                  <span
                    className={`amount ${
                      party.balancePaise < 0
                        ? "pay"
                        : party.balancePaise > 0
                        ? "receive"
                        : "settled"
                    }`}
                  >
                    {party.balancePaise === 0 ? <strong>Settled</strong> : (
                      <>
                        <strong>
                          {formatInr(Math.abs(party.balancePaise))}
                        </strong>
                        <small>
                          {party.balancePaise > 0
                            ? "You will receive"
                            : "You will pay"}
                        </small>
                      </>
                    )}
                  </span>
                  <ChevronRight aria-hidden="true" />
                </button>
              ))
            )}
        </section>
        <button
          className="mobile-add-entry button button-primary"
          onClick={onAddParty}
        >
          <UserPlus /> Add party
        </button>
      </section>

      <section className="statement-pane" aria-label="Selected party statement">
        {selectedParty
          ? (
            <PartyStatementView
              key={selectedParty.id}
              companyName={data.company.name}
              timezone={data.company.timezone}
              party={selectedParty}
              entries={selectedStatementEntries}
              statement={statement}
              statementError={statementError}
              loading={statementLoading}
              onBack={onBack}
              onEdit={() => onEditParty(selectedParty)}
              onAddEntry={(action) => onAddEntry(selectedParty, action)}
              onOpeningBalance={() => onOpeningBalance(selectedParty)}
              onOpenEntry={onOpenEntry}
              onReload={() => onLoadOlder(selectedParty, null)}
              onLoadOlder={statement?.nextCursor
                ? () => onLoadOlder(selectedParty, statement.nextCursor!)
                : undefined}
              onArchive={() => onArchive(selectedParty)}
            />
          )
          : (
            <div className="statement-placeholder">
              <Users />
              <h2>Select a party</h2>
              <p>Their balance and full statement will appear here.</p>
            </div>
          )}
      </section>
    </div>
  );
}

function EntriesView({
  entries,
  timezone,
  query,
  setQuery,
  onOpenEntry,
  onAddEntry,
}: {
  entries: Entry[];
  timezone: string;
  query: string;
  setQuery: (value: string) => void;
  onOpenEntry: (entry: Entry) => void;
  onAddEntry: (action: EntryActionChoice) => void;
}) {
  const [datePreset, setDatePreset] = useState<DatePreset>("all");
  const [customFrom, setCustomFrom] = useState("");
  const [customTo, setCustomTo] = useState("");
  const needle = query.toLowerCase();
  const range = dateRangeForPreset(datePreset, timezone, customFrom, customTo);
  const visible = entries.filter((entry) => {
    const matchesSearch = `${entry.partyName} ${
      entryNoteLabel(
        entry,
      )
    } ${
      entryDirectionLabel(
        entry.action,
        entry.balanceEffectPaise,
      )
    } ${entry.sequence}`
      .toLowerCase()
      .includes(needle);
    return (
      matchesSearch &&
      (!range.from || entry.entryDate >= range.from) &&
      (!range.to || entry.entryDate <= range.to)
    );
  });
  return (
    <div className="app-view">
      <div className="view-title-row">
        <div>
          <h1>Entries</h1>
          <p>Every saved, edited and cancelled record</p>
        </div>
      </div>
      <EntryActionButtons onChoose={onAddEntry} />
      <div className="list-tools">
        <label className="search-control">
          <Search aria-hidden="true" />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search by party, note or entry number"
          />
          {query
            ? (
              <button aria-label="Clear search" onClick={() => setQuery("")}>
                <X />
              </button>
            )
            : null}
        </label>
        <DatePresetControl
          value={datePreset}
          onChange={setDatePreset}
          customFrom={customFrom}
          customTo={customTo}
          onCustomFrom={setCustomFrom}
          onCustomTo={setCustomTo}
        />
      </div>
      <section className="entry-list">
        {visible.length === 0
          ? (
            <EmptyState
              icon={<FileClock />}
              title="No entries found"
              body="Saved entries will appear here with their reference numbers."
            />
          )
          : (
            visible.map((entry) => (
              <button
                key={entry.id}
                className={`entry-row ${
                  entry.status === "cancelled" ? "cancelled" : ""
                }`}
                onClick={() => onOpenEntry(entry)}
              >
                <EntryDirectionBadge entry={entry} />
                <span className="entry-main">
                  <strong>{entry.partyName}</strong>
                  <small>{entryNoteLabel(entry)}</small>
                  <span className="entry-meta">
                    {entry.sequence > 0
                      ? `Entry ${entry.sequence}`
                      : "On this phone"}
                    <i>·</i>
                    {formatEntryDate(entry.entryDate)}
                    {entry.editedAt ? <em>Edited</em> : null}
                    {entry.status === "cancelled"
                      ? <em className="cancelled-label">Cancelled</em>
                      : entry.clientSync === "waiting"
                      ? (
                        <em className="waiting-label">
                          <Clock3 /> Waiting to upload
                        </em>
                      )
                      : entry.clientSync === "failed"
                      ? (
                        <em className="failed-label">
                          <CircleAlert /> Needs review
                        </em>
                      )
                      : (
                        <em className="saved-label">
                          <CheckCircle2 /> Saved
                        </em>
                      )}
                  </span>
                </span>
                <EntryMoney entry={entry} className="entry-amount" />
                <ChevronRight />
              </button>
            ))
          )}
      </section>
    </div>
  );
}

function LearnView({
  onAddEntry,
  onAddParty,
  onViewParties,
}: {
  onAddEntry: (action: EntryActionChoice) => void;
  onAddParty: () => void;
  onViewParties: () => void;
}) {
  const [openLesson, setOpenLesson] = useState("gave-received");
  return (
    <div className="app-view learn-view">
      <div className="view-title-row">
        <div>
          <h1>Learn Hisaab</h1>
          <p>Simple guides for everyday records</p>
        </div>
      </div>
      <section className="lesson-list">
        {LEARN_LESSONS.map((lesson) => {
          const open = openLesson === lesson.id;
          return (
            <article className={`lesson ${open ? "open" : ""}`} key={lesson.id}>
              <button
                className="lesson-heading"
                aria-expanded={open}
                onClick={() =>
                  setOpenLesson(open ? "" : lesson.id)}
              >
                <span className="lesson-icon">
                  <LearnIcon kind={lesson.icon} />
                </span>
                <span>
                  <strong>{lesson.title}</strong>
                  <small>{lesson.summary}</small>
                  <em>{lesson.time}</em>
                </span>
                <ChevronRight className={open ? "rotated" : ""} />
              </button>
              {open
                ? (
                  <div className="lesson-body">
                    <p>{lesson.intro}</p>
                    <ul>
                      {lesson.points.map((point) => (
                        <li key={point}>{point}</li>
                      ))}
                    </ul>
                    {lesson.action === "entry"
                      ? <EntryActionButtons onChoose={onAddEntry} compact />
                      : lesson.action === "party"
                      ? (
                        <button
                          className="button button-secondary compact"
                          onClick={onAddParty}
                        >
                          <UserPlus /> Add a party
                        </button>
                      )
                      : lesson.action === "parties"
                      ? (
                        <button
                          className="button button-secondary compact"
                          onClick={onViewParties}
                        >
                          <Users /> View parties
                        </button>
                      )
                      : null}
                  </div>
                )
                : null}
            </article>
          );
        })}
      </section>
      <div className="learn-note">
        <ShieldCheck />
        <span>
          <strong>No accounting knowledge needed.</strong>
          Hisaab uses simple words and keeps cancelled entries in history.
        </span>
      </div>
    </div>
  );
}

type LearnLesson = {
  id: string;
  title: string;
  summary: string;
  time: string;
  icon: "arrows" | "balance" | "party" | "entry" | "opening" | "fix" | "safe";
  intro: string;
  points: string[];
  action?: "entry" | "party" | "parties";
};

const LEARN_LESSONS: LearnLesson[] = [
  {
    id: "gave-received",
    title: "You gave or got?",
    summary: "Choose the right side without accounting words.",
    time: "2 min",
    icon: "arrows",
    intro: "Think about which way the value moved.",
    points: [
      "You gave goods worth ₹500 → choose You gave.",
      "A customer paid you ₹300 → choose You got.",
      "Read the balance sentence before saving.",
    ],
    action: "entry",
  },
  {
    id: "balance",
    title: "Understand a balance",
    summary: "See who owes whom in simple words.",
    time: "2 min",
    icon: "balance",
    intro: "The words beside the amount tell you what happens next.",
    points: [
      "You will receive means this party owes you.",
      "You will pay means you owe this party.",
      "Settled means nothing is due.",
    ],
    action: "parties",
  },
  {
    id: "party",
    title: "Add your first party",
    summary: "Save a customer or supplier once.",
    time: "2 min",
    icon: "party",
    intro: "A party is anyone you buy from or sell to.",
    points: [
      "Only the name is required.",
      "Phone, notes and groups are optional.",
      "The same party can both buy from and sell to you.",
    ],
    action: "party",
  },
  {
    id: "entry",
    title: "Add and read entries",
    summary: "Record a transaction and check its statement.",
    time: "3 min",
    icon: "entry",
    intro: "Each saved entry changes that party’s running balance.",
    points: [
      "Tap You gave or You got, choose the party if asked, then enter the amount.",
      "Notes are optional, and the date starts as Today.",
      "Open the party to see every entry in its statement.",
    ],
    action: "entry",
  },
  {
    id: "opening",
    title: "Opening balance",
    summary: "Start with money that was already due.",
    time: "2 min",
    icon: "opening",
    intro: "Use this once when you start keeping an existing Hisaab.",
    points: [
      "Open the party and choose More options.",
      "Choose They owe you or You owe them.",
      "Later entries will be calculated from this starting amount.",
    ],
    action: "parties",
  },
  {
    id: "fix",
    title: "Fix a mistake",
    summary: "Edit or cancel without losing history.",
    time: "3 min",
    icon: "fix",
    intro: "Hisaab keeps a clear history so balances remain trustworthy.",
    points: [
      "Use Undo immediately after saving when available.",
      "Open an entry to edit it later.",
      "Cancel removes its balance effect but keeps the record visible.",
    ],
  },
  {
    id: "safe",
    title: "Keep records safe",
    summary: "Know when an offline entry has uploaded.",
    time: "2 min",
    icon: "safe",
    intro: "Hisaab can save a new entry on this phone when the internet drops.",
    points: [
      "Waiting to upload means the entry is still only on this device.",
      "Keep the app open after reconnecting until it says Saved.",
      "Export a backup from More before major account changes.",
    ],
  },
];

function LearnIcon({ kind }: { kind: LearnLesson["icon"] }) {
  if (kind === "balance") return <Scale />;
  if (kind === "party") return <UserPlus />;
  if (kind === "entry") return <ReceiptText />;
  if (kind === "opening") return <FileClock />;
  if (kind === "fix") return <Settings />;
  if (kind === "safe") return <ShieldCheck />;
  return <ArrowUpRight />;
}

function DatePresetControl({
  value,
  onChange,
  customFrom,
  customTo,
  onCustomFrom,
  onCustomTo,
}: {
  value: DatePreset;
  onChange: (value: DatePreset) => void;
  customFrom: string;
  customTo: string;
  onCustomFrom: (value: string) => void;
  onCustomTo: (value: string) => void;
}) {
  const presets: Array<{ id: DatePreset; label: string }> = [
    { id: "all", label: "All time" },
    { id: "month", label: "This month" },
    { id: "30days", label: "Last 30 days" },
    { id: "custom", label: "Custom" },
  ];
  const invalidRange = Boolean(
    customFrom && customTo && customFrom > customTo,
  );
  const [open, setOpen] = useState(false);
  const panelId = useId();
  const activeLabel = presets.find((preset) => preset.id === value)?.label ??
    "Filter";

  return (
    <div className="date-filter">
      <button
        type="button"
        className={`filter-trigger ${value !== "all" ? "active" : ""}`}
        aria-expanded={open}
        aria-controls={panelId}
        onClick={() => setOpen((current) => (invalidRange ? true : !current))}
      >
        <SlidersHorizontal />
        <span>{value === "all" ? "Filter" : activeLabel}</span>
        <ChevronRight className={open ? "rotated" : ""} />
      </button>
      {open
        ? (
          <div className="filter-panel" id={panelId}>
            <span className="filter-panel-label">Date period</span>
            <div className="date-preset-row" aria-label="Choose date range">
              {presets.map((preset) => (
                <button
                  type="button"
                  key={preset.id}
                  className={value === preset.id ? "selected" : ""}
                  onClick={() => {
                    onChange(preset.id);
                    if (preset.id === "all") {
                      onCustomFrom("");
                      onCustomTo("");
                    }
                    if (preset.id !== "custom") setOpen(false);
                  }}
                >
                  {preset.label}
                </button>
              ))}
            </div>
            {value === "custom"
              ? (
                <div className="statement-range" aria-label="Custom date range">
                  <label>
                    <span>From</span>
                    <input
                      type="date"
                      value={customFrom}
                      max={customTo || undefined}
                      onChange={(event) => onCustomFrom(event.target.value)}
                      onInput={(event) =>
                        onCustomFrom(event.currentTarget.value)}
                    />
                  </label>
                  <label>
                    <span>To</span>
                    <input
                      type="date"
                      value={customTo}
                      min={customFrom || undefined}
                      onChange={(event) => onCustomTo(event.target.value)}
                      onInput={(event) => onCustomTo(event.currentTarget.value)}
                    />
                  </label>
                </div>
              )
              : null}
            {invalidRange
              ? (
                <p className="date-filter-error">
                  The From date must be before the To date.
                </p>
              )
              : null}
            {value !== "all"
              ? (
                <button
                  type="button"
                  className="clear-filter"
                  onClick={() => {
                    onChange("all");
                    onCustomFrom("");
                    onCustomTo("");
                    setOpen(false);
                  }}
                >
                  Clear filter
                </button>
              )
              : null}
          </div>
        )
        : null}
    </div>
  );
}

function dateRangeForPreset(
  preset: DatePreset,
  timezone: string,
  customFrom: string,
  customTo: string,
) {
  const today = todayInTimezone(timezone);
  if (preset === "month") {
    return { from: `${today.slice(0, 7)}-01`, to: today };
  }
  if (preset === "30days") {
    return { from: shiftDateOnly(today, -29), to: today };
  }
  if (preset === "custom") {
    return { from: customFrom, to: customTo };
  }
  return { from: "", to: "" };
}

function PartyFormDialog({
  data,
  existing,
  onClose,
  onOpenParty,
  onSaved,
}: {
  data: BootstrapData;
  existing?: Party;
  onClose: () => void;
  onOpenParty: (partyId: string) => void;
  onSaved: (createdPartyId?: string) => Promise<void>;
}) {
  const [more, setMore] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [duplicates, setDuplicates] = useState<ApiError["duplicates"]>([]);
  const formRef = useRef<HTMLFormElement>(null);
  const clientId = useRef(createClientId());
  const operationId = useRef(createClientId());
  const savedDetailCount = [
    existing?.shortName,
    existing?.notes,
    existing?.groupId,
  ].filter(Boolean).length;

  async function submit(event: FormEvent<HTMLFormElement>, confirm = false) {
    event.preventDefault();
    if (!navigator.onLine) {
      setError("Connect to the internet to add a new customer or supplier.");
      return;
    }
    setSaving(true);
    setError("");
    const form = new FormData(event.currentTarget);
    const response = await apiFetch(
      existing ? `/api/parties/${existing.id}` : "/api/parties",
      {
        method: existing ? "PATCH" : "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          name: form.get("name"),
          phone: form.get("phone"),
          shortName: form.get("shortName"),
          notes: form.get("notes"),
          groupId: form.get("groupId") || null,
          confirmDuplicate: existing ? undefined : confirm,
          clientId: existing ? undefined : clientId.current,
          idempotencyKey: operationId.current,
          baseVersion: existing?.version,
        }),
      },
    );
    const body = (await response.json()) as ApiError & { id?: string };
    if (response.status === 409 && body.code === "DUPLICATE_WARNING") {
      setDuplicates(body.duplicates ?? []);
      setError(body.error);
      setSaving(false);
      return;
    }
    if (!response.ok) {
      setError(body.error);
      setSaving(false);
      return;
    }
    await onSaved(body.id);
  }

  return (
    <Dialog
      title={existing ? "Edit party" : "Add party"}
      onClose={onClose}
    >
      <form ref={formRef} onSubmit={submit} className="form-stack">
        <p className="form-intro">
          {existing
            ? "Change only what you need."
            : "A name is enough. Everything else is optional."}
        </p>
        <Field label="Name" required>
          <input
            name="name"
            autoFocus
            required
            maxLength={100}
            defaultValue={existing?.name}
          />
        </Field>
        <Field label="Phone number" hint="Optional">
          <input
            name="phone"
            inputMode="tel"
            maxLength={30}
            defaultValue={existing?.phone}
          />
        </Field>
        {error
          ? (
            <div
              className={`form-alert ${duplicates?.length ? "warning" : ""}`}
            >
              <CircleAlert />
              <div>
                <strong>{error}</strong>
                {duplicates?.map((duplicate) => (
                  <span key={duplicate.id}>
                    {duplicate.name}
                    {duplicate.phone ? ` · ${duplicate.phone}` : ""}
                  </span>
                ))}
                {duplicates?.[0]
                  ? (
                    <button
                      type="button"
                      className="inline-alert-action"
                      onClick={() => onOpenParty(duplicates[0].id)}
                    >
                      Open existing party
                    </button>
                  )
                  : null}
              </div>
            </div>
          )
          : null}
        <DisclosureButton
          open={more}
          onToggle={() => setMore((value) => !value)}
          label="More details"
          summary={savedDetailCount
            ? `${savedDetailCount} saved ${
              savedDetailCount === 1 ? "detail" : "details"
            }`
            : "Short name, notes and group"}
        />
        <div className="more-fields" hidden={!more}>
          <Field label="Short or shop name">
            <input
              name="shortName"
              maxLength={100}
              defaultValue={existing?.shortName}
            />
          </Field>
          <Field label="Notes">
            <textarea
              name="notes"
              rows={3}
              maxLength={500}
              defaultValue={existing?.notes}
            />
          </Field>
          <Field label="Group">
            <select name="groupId" defaultValue={existing?.groupId ?? ""}>
              <option value="">No group</option>
              {data.groups.map((group) => (
                <option key={group.id} value={group.id}>
                  {group.name}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <div className="dialog-actions">
          <button
            type="button"
            className="button button-secondary"
            onClick={onClose}
          >
            Cancel
          </button>
          {duplicates?.length && !existing
            ? (
              <button
                type="button"
                className="button button-primary"
                disabled={saving}
                onClick={() => {
                  if (formRef.current) {
                    submit(
                      {
                        preventDefault() {},
                        currentTarget: formRef.current,
                      } as FormEvent<HTMLFormElement>,
                      true,
                    );
                  }
                }}
              >
                Add anyway
              </button>
            )
            : (
              <button className="button button-primary" disabled={saving}>
                {saving
                  ? <LoaderCircle className="spin" />
                  : existing
                  ? <Check />
                  : <Plus />}
                {existing ? "Save changes" : "Add party"}
              </button>
            )}
        </div>
      </form>
    </Dialog>
  );
}

function EntryFormDialog({
  data,
  signedInPhone,
  initialPartyId,
  initialAction,
  editing,
  onClose,
  onSaved,
}: {
  data: BootstrapData;
  signedInPhone: string;
  initialPartyId?: string;
  initialAction?: EntryActionChoice;
  editing?: Entry;
  onClose: () => void;
  onSaved: (
    message: string,
    optimistic?: BootstrapData,
    created?: { id: string; sequence: number },
    queuedId?: string,
  ) => Promise<void>;
}) {
  const activeParties = data.parties.filter(
    (party) => !party.archivedAt || party.id === editing?.partyId,
  );
  const today = todayInTimezone(data.company.timezone);
  const [partyId, setPartyId] = useState(
    editing?.partyId ||
      initialPartyId ||
      (activeParties.length === 1 ? activeParties[0].id : ""),
  );
  const [action, setAction] = useState<"" | "gave" | "received">(
    editing?.action === "gave"
      ? "gave"
      : editing?.action === "received"
      ? "received"
      : initialAction ?? "",
  );
  const [amount, setAmount] = useState(
    editing ? paiseToInput(editing.amountPaise) : "",
  );
  const [narration, setNarration] = useState(editing?.narration ?? "");
  const [entryDate, setEntryDate] = useState(
    editing?.entryDate ?? today,
  );
  const [dateOpen, setDateOpen] = useState(
    Boolean(editing?.entryDate && editing.entryDate !== today),
  );
  const [more, setMore] = useState(
    Boolean(
      editing?.narration.trim() ||
        (editing?.entryDate && editing.entryDate !== today) ||
        editing?.paymentAccount,
    ),
  );
  const [paymentAccount, setPaymentAccount] = useState(
    editing?.paymentAccount ?? "",
  );
  const [saving, setSaving] = useState(false);
  const clientId = useRef(editing?.id ?? createClientId());
  const [error, setError] = useState("");
  const idempotencyKey = useRef(createClientId());
  const selectedParty = data.parties.find((party) => party.id === partyId);
  const partyIsFixed = Boolean(
    initialPartyId || editing || activeParties.length === 1,
  );
  const amountPaise = parseAmountToPaise(amount);
  const effect = amountPaise == null || !action
    ? 0
    : action === "gave"
    ? amountPaise
    : -amountPaise;
  const baseBalance = (selectedParty?.balancePaise ?? 0) -
    (editing?.balanceEffectPaise ?? 0);
  const newBalance = baseBalance + effect;
  const optionalDetailCount = [
    narration.trim(),
    entryDate !== today ? entryDate : "",
    paymentAccount,
  ].filter(Boolean).length;

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedParty) return setError("Choose a customer or supplier.");
    if (action !== "gave" && action !== "received") {
      return setError("Choose You gave or You got.");
    }
    if (amountPaise == null || amountPaise <= 0) {
      return setError("Enter a valid amount.");
    }
    const confirmedParty = selectedParty;
    const confirmedAmountPaise = amountPaise;
    const confirmedAction = action;
    setSaving(true);
    setError("");
    const body = {
      partyId,
      action: confirmedAction,
      amountPaise,
      narration: narration.trim(),
      entryDate,
      paymentAccount: paymentAccount || null,
      clientId: editing ? undefined : clientId.current,
      idempotencyKey: idempotencyKey.current,
      baseVersion: editing?.version,
    };

    if (editing) {
      if (!navigator.onLine) {
        setSaving(false);
        return setError("Connect to the internet to edit a saved entry.");
      }
      const response = await apiFetch(`/api/entries/${editing.id}`, {
        method: "PATCH",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ ...body, operation: "edit" }),
      });
      if (!response.ok) {
        const apiError = (await response.json()) as ApiError;
        setSaving(false);
        return setError(apiError.error);
      }
      await onSaved(`Entry ${editing.sequence} updated.`);
      return;
    }

    async function saveOffline() {
      const queued = queueEntry(signedInPhone, body);
      const optimisticEntry: Entry = {
        id: clientId.current,
        partyId,
        partyName: confirmedParty.name,
        sequence: 0,
        action: confirmedAction,
        amountPaise: confirmedAmountPaise,
        balanceEffectPaise: effect,
        narration: narration.trim(),
        entryDate,
        paymentAccount: paymentAccount || null,
        status: "posted",
        createdByName: data.user.fullName,
        createdAt: nowIso(),
        updatedAt: nowIso(),
        version: 1,
        editedAt: null,
        cancelledAt: null,
        revisionCount: 0,
        clientSync: "waiting",
      };
      const optimistic: BootstrapData = {
        ...data,
        parties: data.parties.map((party) =>
          party.id === partyId
            ? {
              ...party,
              balancePaise: party.balancePaise + effect,
              transactionCount: party.transactionCount + 1,
            }
            : party
        ),
        entries: [optimisticEntry, ...data.entries],
      };
      await onSaved(
        "Saved on this phone. It will upload when internet is available.",
        optimistic,
        undefined,
        queued.id,
      );
    }

    if (!navigator.onLine) {
      await saveOffline();
      return;
    }

    try {
      const response = await apiFetch("/api/entries", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!response.ok) {
        const apiError = (await response.json()) as ApiError;
        setSaving(false);
        return setError(apiError.error);
      }
      const result = (await response.json()) as {
        id: string;
        sequence: number;
      };
      await onSaved(
        `Entry ${result.sequence} saved successfully.`,
        undefined,
        result,
      );
    } catch {
      setSaving(false);
      await saveOffline();
    }
  }

  return (
    <Dialog
      title={editing
        ? `Edit entry ${editing.sequence}`
        : action === "gave"
        ? "You gave"
        : action === "received"
        ? "You got"
        : "Choose what happened"}
      onClose={onClose}
    >
      <form onSubmit={submit} className="form-stack entry-form">
        {partyIsFixed && selectedParty
          ? (
            <div className="selected-context">
              <span>Party</span>
              <strong>{selectedParty.name}</strong>
            </div>
          )
          : (
            <Field label="Party" required>
              <select
                name="partyId"
                value={partyId}
                autoFocus
                onChange={(event) => setPartyId(event.target.value)}
              >
                <option value="">Choose a party</option>
                {activeParties.map((party) => (
                  <option key={party.id} value={party.id}>
                    {party.name}
                  </option>
                ))}
              </select>
            </Field>
          )}
        {editing || !initialAction
          ? (
            <div className="action-segment">
              <button
                type="button"
                className={action === "gave" ? "selected gave" : "gave"}
                onClick={() => setAction("gave")}
              >
                <span aria-hidden="true">−</span>
                <strong>You gave</strong>
              </button>
              <button
                type="button"
                className={action === "received"
                  ? "selected received"
                  : "received"}
                onClick={() => setAction("received")}
              >
                <span aria-hidden="true">+</span>
                <strong>You got</strong>
              </button>
            </div>
          )
          : null}
        <Field label="Amount" required>
          <div
            className={`amount-input ${
              action === "gave"
                ? "gave"
                : action === "received"
                ? "received"
                : ""
            }`}
          >
            <span aria-hidden="true">
              {action === "gave" ? "−₹" : action === "received" ? "+₹" : "₹"}
            </span>
            <input
              value={amount}
              onChange={(event) => setAmount(
                event.target.value
                  .replace(/[^\d.]/g, "")
                  .replace(/^(\d{9})\d+/, "$1"),
              )}
              inputMode="decimal"
              autoFocus={partyIsFixed}
              placeholder="0"
              aria-label="Amount in rupees"
            />
          </div>
        </Field>
        {selectedParty && amountPaise
          ? (
            <div className="balance-preview">
              <CheckCircle2 />
              <span>
                {previewBalance(selectedParty.name, newBalance, amountPaise)}
              </span>
            </div>
          )
          : null}
        <DisclosureButton
          open={more}
          onToggle={() => setMore((value) => !value)}
          label="Optional details"
          summary={optionalDetailCount
            ? `${optionalDetailCount} ${
              optionalDetailCount === 1 ? "detail" : "details"
            } added`
            : "Note, date or payment account"}
        />
        <div className="more-fields" hidden={!more}>
          <Field label="Note" hint="Optional">
            <input
              aria-label="Note (optional)"
              value={narration}
              onChange={(event) => setNarration(event.target.value)}
              placeholder="What was this for?"
              maxLength={240}
            />
          </Field>
          <button
            type="button"
            className="date-summary-row"
            aria-expanded={dateOpen}
            onClick={() => setDateOpen((value) => !value)}
          >
            <CalendarDays />
            <span>
              <strong>Date</strong>
              <small>
                {entryDate === today ? "Today" : formatEntryDate(entryDate)}
              </small>
            </span>
            <em>{dateOpen ? "Done" : "Change"}</em>
          </button>
          {dateOpen
            ? (
              <Field label="Entry date" required>
                <input
                  type="date"
                  value={entryDate}
                  max={today}
                  onChange={(event) => setEntryDate(event.target.value)}
                  onInput={(event) => setEntryDate(event.currentTarget.value)}
                />
              </Field>
            )
            : null}
          <Field
            label="Recorded payment account"
            hint="This tracks recorded movement, not your actual account balance."
          >
            <select
              value={paymentAccount}
              onChange={(event) => setPaymentAccount(event.target.value)}
            >
              <option value="">Not selected</option>
              <option value="cash">Cash</option>
              <option value="bank">Bank</option>
            </select>
          </Field>
        </div>
        {error ? <div className="form-error">{error}</div> : null}
        <div className="dialog-actions">
          <button
            type="button"
            className="button button-secondary"
            onClick={onClose}
          >
            Cancel
          </button>
          <button
            className={`button button-primary entry-save-button ${action}`}
            disabled={saving}
          >
            {saving ? <LoaderCircle className="spin" /> : <Check />}
            {editing
              ? "Save changes"
              : amountPaise
              ? `Save ${entryAmountSign(action)}${formatInr(amountPaise)}`
              : "Save"}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

function PartyStatementView({
  companyName,
  timezone,
  party,
  entries,
  statement,
  statementError,
  loading,
  onBack,
  onEdit,
  onAddEntry,
  onOpeningBalance,
  onOpenEntry,
  onReload,
  onLoadOlder,
  onArchive,
}: {
  companyName: string;
  timezone: string;
  party: Party;
  entries: Entry[];
  statement?: StatementBatch;
  statementError?: string;
  loading: boolean;
  onBack: () => void;
  onEdit: () => void;
  onAddEntry: (action: EntryActionChoice) => void;
  onOpeningBalance: () => void;
  onOpenEntry: (entry: Entry) => void;
  onReload: () => Promise<void>;
  onLoadOlder?: () => Promise<void>;
  onArchive: () => Promise<void>;
}) {
  const [error, setError] = useState("");
  const [datePreset, setDatePreset] = useState<DatePreset>("all");
  const [customFrom, setCustomFrom] = useState("");
  const [customTo, setCustomTo] = useState("");
  const [includePrivateNotes, setIncludePrivateNotes] = useState(false);
  const range = dateRangeForPreset(
    datePreset,
    timezone,
    customFrom,
    customTo,
  );
  const chronological = [...entries].sort(
    (a, b) => a.entryDate.localeCompare(b.entryDate) || a.sequence - b.sequence,
  );
  const statementRows = chronological.reduce<
    Array<{ entry: Entry; running: number }>
  >((rows, entry) => {
    const previous = rows.at(-1)?.running ?? 0;
    const running = typeof entry.runningBalancePaise === "number"
      ? entry.runningBalancePaise
      : entry.status === "posted"
      ? previous + entry.balanceEffectPaise
      : previous;
    return [...rows, { entry, running }];
  }, []);
  const visibleStatementRows = statementRows.filter(
    ({ entry }) =>
      (!range.from || entry.entryDate >= range.from) &&
      (!range.to || entry.entryDate <= range.to),
  );
  const pendingEffect = entries.reduce(
    (sum, entry) =>
      entry.clientSync && entry.status === "posted"
        ? sum + entry.balanceEffectPaise
        : sum,
    0,
  );
  const pendingEffectThroughRange = entries.reduce(
    (sum, entry) =>
      entry.clientSync &&
        entry.status === "posted" &&
        (!range.to || entry.entryDate <= range.to)
        ? sum + entry.balanceEffectPaise
        : sum,
    0,
  );
  const finalBalance = range.to
    ? statement
      ? (statementRows
        .filter(
          ({ entry }) => !entry.clientSync && entry.entryDate <= range.to!,
        )
        .at(-1)?.running ?? 0) + pendingEffectThroughRange
      : statementRows.filter(({ entry }) => entry.entryDate <= range.to).at(-1)
        ?.running ?? 0
    : statement
    ? statement.closingBalancePaise + pendingEffect
    : party.balancePaise;
  const provisional = !statement;
  const incomplete = provisional || Boolean(statement?.hasMore) ||
    Boolean(statementError);
  const filteredClosingIncomplete = Boolean(
    (range.from || range.to) && (provisional || statement?.hasMore),
  );
  const canExport = !loading && !incomplete;
  const dateRangeLabel = range.from || range.to
    ? `${range.from ? formatEntryDate(range.from) : "Beginning"} to ${
      range.to ? formatEntryDate(range.to) : "Today"
    }`
    : "All time";

  async function shareStatement() {
    const lines = visibleStatementRows
      .map(({ entry, running: rowBalance }) => {
        const note = statementNoteForExport(entry, includePrivateNotes);
        const noteText = note ? ` · ${note}` : "";
        const direction = entry.action === "opening_balance"
          ? `Opening balance · ${
            entryDirectionLabel(entry.action, entry.balanceEffectPaise)
          }`
          : entryDirectionLabel(entry.action, entry.balanceEffectPaise);
        return `${
          formatEntryDate(entry.entryDate)
        } · Entry ${entry.sequence} · ${direction} ${
          signedEntryAmount(entry)
        }${noteText} · Balance ${balancePosition(rowBalance)}${
          entry.status === "cancelled" ? " · Cancelled" : ""
        }`;
      })
      .join("\n");
    const text =
      `${companyName}\nStatement for ${party.name}\n${dateRangeLabel}\n\n${
        lines || "No entries in this period."
      }\n\n${balanceSentence(finalBalance)}\nGenerated ${
        formatLongDate(undefined, "Asia/Kolkata")
      }`;
    try {
      if (navigator.share) {
        await navigator.share({
          title: `${party.name} · Hisaab statement`,
          text,
        });
      } else {
        await navigator.clipboard.writeText(text);
        setError("Statement copied. You can paste it into WhatsApp or email.");
      }
    } catch {
      // Closing the share sheet is not an application error.
    }
  }

  async function toggleArchive() {
    try {
      await onArchive();
    } catch (caught) {
      setError(
        caught instanceof Error
          ? caught.message
          : "Could not update this party.",
      );
    }
  }

  return (
    <div className="party-statement">
      <button className="statement-back" onClick={onBack}>
        <ArrowLeft /> All parties
      </button>
      <header className="party-statement-header">
        <div>
          <h2>{party.name}</h2>
          <p>{party.phone || party.shortName || party.reference}</p>
        </div>
      </header>
      <section
        className={`party-balance-panel ${
          party.balancePaise < 0
            ? "pay"
            : party.balancePaise === 0
            ? "settled"
            : ""
        }`}
      >
        <span>
          {party.balancePaise > 0
            ? "You will receive"
            : party.balancePaise < 0
            ? "You will pay"
            : "Settled"}
        </span>
        <strong>{formatInr(Math.abs(party.balancePaise))}</strong>
        <small>Current balance with {party.name}</small>
      </section>
      {party.archivedAt
        ? (
          <div className="archived-party-note">
            <Archive />
            <span>
              <strong>This party is archived</strong>
              <small>Restore it before adding or changing entries.</small>
            </span>
            <button className="button button-secondary" onClick={toggleArchive}>
              Restore party
            </button>
          </div>
        )
        : <EntryActionButtons onChoose={onAddEntry} />}

      <div className="statement-toolbar">
        <div>
          <h3>Statement</h3>
          <span>
            {loading && !statement
              ? "Loading statement pages…"
              : statement?.hasMore
              ? `${statement.entries.length} of ${statement.totalCount} entries loaded`
              : statement
              ? `${visibleStatementRows.length} entries shown · complete`
              : "Recent cached entries only · provisional"}
          </span>
        </div>
        <button
          className="icon-button"
          aria-label="Share statement"
          title={canExport
            ? "Share statement"
            : "Load the complete statement before sharing"}
          onClick={shareStatement}
          disabled={!canExport}
        >
          <Share2 />
        </button>
        <button
          className="icon-button"
          aria-label="Print statement"
          title={canExport
            ? "Print statement"
            : "Load the complete statement before printing"}
          onClick={() => window.print()}
          disabled={!canExport}
        >
          <FileText />
        </button>
      </div>
      {statementError
        ? (
          <div className="statement-load-note error" role="alert">
            <span>
              <strong>Could not refresh the complete statement.</strong>
              <small>
                {statementError} The entries below are still saved locally.
              </small>
            </span>
            <button
              className="button button-secondary compact"
              disabled={loading}
              onClick={() => void onReload()}
            >
              <RefreshCw /> Retry
            </button>
          </div>
        )
        : statement?.hasMore && onLoadOlder
        ? (
          <div className="statement-load-note">
            <span>
              <strong>Older entries are not shown yet.</strong>
              <small>
                Running balances and totals come from the server. Load older
                pages before sharing or printing.
              </small>
            </span>
            <button
              className="button button-secondary compact"
              disabled={loading}
              onClick={() => void onLoadOlder()}
            >
              {loading ? <LoaderCircle className="spin" /> : <RefreshCw />}
              Load older
            </button>
          </div>
        )
        : provisional
        ? (
          <div className="statement-load-note">
            <span>
              <strong>Showing a provisional cached statement.</strong>
              <small>
                Connect and refresh to verify every entry and running balance.
              </small>
            </span>
            <button
              className="button button-secondary compact"
              disabled={loading}
              onClick={() => void onReload()}
            >
              {loading ? <LoaderCircle className="spin" /> : <RefreshCw />}
              Refresh
            </button>
          </div>
        )
        : null}
      <DatePresetControl
        value={datePreset}
        onChange={setDatePreset}
        customFrom={customFrom}
        customTo={customTo}
        onCustomFrom={setCustomFrom}
        onCustomTo={setCustomTo}
      />
      <label className="statement-export-options">
        <input
          type="checkbox"
          checked={includePrivateNotes}
          onChange={(event) => setIncludePrivateNotes(event.target.checked)}
        />
        <span>
          <strong>Include private notes when sharing or printing</strong>
          <small>
            Off by default. Turn this on only when the party should see your
            internal notes.
          </small>
        </span>
      </label>
      {filteredClosingIncomplete
        ? (
          <p className="statement-filter-incomplete" role="status">
            This date-filtered view is incomplete. Load every older page before
            using its closing balance.
          </p>
        )
        : null}

      <div className="statement-list printable-statement">
        <div className="print-heading">
          <h1>{companyName}</h1>
          <h2>Statement for {party.name}</h2>
          <p>
            {dateRangeLabel} · Generated {formatLongDate(undefined, timezone)}
          </p>
        </div>
        {visibleStatementRows.length === 0
          ? <p className="empty-statement">No entries in this period.</p>
          : (
            visibleStatementRows
              .slice()
              .reverse()
              .map(({ entry, running: rowBalance }) => (
                <button
                  className={`statement-row ${
                    entry.status === "cancelled" ? "cancelled" : ""
                  }`}
                  key={entry.id}
                  onClick={() => onOpenEntry(entry)}
                >
                  <div>
                    <strong>
                      <span className="statement-label-screen">
                        {entryNoteLabel(entry)}
                      </span>
                      <span className="statement-label-print">
                        {includePrivateNotes
                          ? entryNoteLabel(entry)
                          : entryDisplayLabel(entry.action, "")}
                      </span>
                    </strong>
                    <small>
                      {formatEntryDate(entry.entryDate)} · Entry{" "}
                      {entry.sequence}
                      {entry.editedAt ? " · Edited" : ""}
                      {entry.status === "cancelled" ? " · Cancelled" : ""}
                    </small>
                  </div>
                  <EntryMoney
                    entry={entry}
                    className="statement-entry-amount"
                  />
                  <small>Balance {balancePosition(rowBalance)}</small>
                </button>
              ))
          )}
        <div
          className={`statement-total ${
            filteredClosingIncomplete ? "incomplete" : ""
          }`}
        >
          {filteredClosingIncomplete
            ? "Closing balance unavailable until the full statement is loaded."
            : balanceSentence(finalBalance)}
        </div>
        <div className="print-final">
          {filteredClosingIncomplete
            ? "Incomplete statement — closing balance not available."
            : balanceSentence(finalBalance)}
        </div>
      </div>
      {error ? <p className="inline-note">{error}</p> : null}

      {!party.archivedAt
        ? (
          <details className="party-more-options">
            <summary>More options</summary>
            <button onClick={onEdit}>
              <Pencil />
              <span>
                <strong>Edit party</strong>
                <small>Change name, phone or other details</small>
              </span>
              <ChevronRight />
            </button>
            <button onClick={onOpeningBalance}>
              <FileClock />
              <span>
                <strong>Opening balance</strong>
                <small>
                  {entries.some(
                      (entry) =>
                        entry.action === "opening_balance" &&
                        entry.status === "posted",
                    )
                    ? "View or change the starting balance"
                    : "Set money due before you started"}
                </small>
              </span>
              <ChevronRight />
            </button>
            <button onClick={toggleArchive}>
              <Archive />
              <span>
                <strong>Archive party</strong>
                <small>Hide this party without deleting history</small>
              </span>
              <ChevronRight />
            </button>
          </details>
        )
        : null}
    </div>
  );
}

function EntryDetailDialog({
  entry,
  readOnly,
  onClose,
  onEdit,
  onCancel,
}: {
  entry: Entry;
  readOnly: boolean;
  onClose: () => void;
  onEdit: () => void;
  onCancel: () => Promise<void>;
}) {
  const [confirming, setConfirming] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  return (
    <Dialog title={`Entry ${entry.sequence || ""}`} onClose={onClose}>
      <div className="entry-detail">
        <div className="entry-detail-title">
          <EntryDirectionBadge entry={entry} />
          <div>
            <h3>{entry.partyName}</h3>
            <span>{entryNoteLabel(entry)}</span>
          </div>
          <EntryMoney entry={entry} className="entry-detail-amount" />
        </div>
        <dl>
          {entry.narration.trim()
            ? <Detail label="Note" value={entry.narration.trim()} />
            : null}
          <Detail label="Date" value={formatEntryDate(entry.entryDate)} />
          <Detail label="Entry number" value={String(entry.sequence)} />
          <Detail label="Created by" value={entry.createdByName} />
          <Detail
            label="Saved"
            value={formatLocalDateTime(entry.createdAt)}
          />
          {entry.editedAt
            ? (
              <Detail
                label="Edited"
                value={`${
                  formatLocalDateTime(entry.editedAt)
                } · previous version kept`}
              />
            )
            : null}
        </dl>
        {entry.status === "cancelled"
          ? (
            <div className="cancelled-banner">
              <CircleAlert /> Cancelled entry — kept in financial history
            </div>
          )
          : readOnly
          ? (
            <div className="cancelled-banner">
              {entry.clientSync ? <Clock3 /> : <Archive />}
              {entry.clientSync
                ? "This device copy must upload before it can be edited"
                : "Archived party — restore the party before changing entries"}
            </div>
          )
          : confirming
          ? (
            <div className="confirm-panel">
              <strong>Cancel this entry?</strong>
              <p>
                It will stay in history and all affected balances will be
                recalculated.
              </p>
              {error ? <span className="form-error">{error}</span> : null}
              <div>
                <button
                  className="button button-secondary"
                  onClick={() => setConfirming(false)}
                >
                  Keep entry
                </button>
                <button
                  className="button button-danger"
                  disabled={saving}
                  onClick={async () => {
                    setSaving(true);
                    try {
                      await onCancel();
                    } catch (caught) {
                      setError(
                        caught instanceof Error
                          ? caught.message
                          : "Could not cancel entry.",
                      );
                      setSaving(false);
                    }
                  }}
                >
                  Cancel entry
                </button>
              </div>
            </div>
          )
          : (
            <div className="dialog-actions split-actions">
              {entry.action !== "opening_balance"
                ? (
                  <button className="button button-secondary" onClick={onEdit}>
                    <Pencil /> Edit
                  </button>
                )
                : <span />}
              <button
                className="button button-danger"
                onClick={() => setConfirming(true)}
              >
                <Trash2 /> Cancel entry
              </button>
            </div>
          )}
      </div>
    </Dialog>
  );
}

function OpeningBalanceDialog({
  party,
  existing,
  timezone,
  onClose,
  onSaved,
}: {
  party: Party;
  existing?: Entry;
  timezone: string;
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const today = todayInTimezone(timezone);
  const [direction, setDirection] = useState<"receive" | "pay">(
    (existing?.balanceEffectPaise ?? 0) < 0 ? "pay" : "receive",
  );
  const [amount, setAmount] = useState(
    existing ? paiseToInput(existing.amountPaise) : "",
  );
  const [date, setDate] = useState(
    existing?.entryDate ?? today,
  );
  const [dateOpen, setDateOpen] = useState(
    Boolean(existing?.entryDate && existing.entryDate !== today),
  );
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const clientId = useRef(existing?.id ?? createClientId());
  const operationId = useRef(createClientId());
  const amountPaise = parseAmountToPaise(amount);
  const openingEffect = amountPaise == null
    ? 0
    : direction === "receive"
    ? amountPaise
    : -amountPaise;
  const balanceBeforeOpening = party.balancePaise -
    (existing?.balanceEffectPaise ?? 0);
  const balanceAfterOpening = balanceBeforeOpening + openingEffect;

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (amountPaise == null || amountPaise < 0) {
      return setError("Enter a valid opening balance.");
    }
    if (existing && !confirming) {
      setError("");
      setConfirming(true);
      return;
    }
    setSaving(true);
    const response = await apiFetch("/api/opening-balance", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        partyId: party.id,
        amountPaise,
        direction,
        entryDate: date,
        clientId: clientId.current,
        idempotencyKey: operationId.current,
        baseVersion: existing?.version,
      }),
    });
    if (!response.ok) {
      const body = (await response.json()) as ApiError;
      setSaving(false);
      return setError(body.error);
    }
    await onSaved();
  }

  return (
    <Dialog title="Opening balance" onClose={onClose}>
      <form onSubmit={submit} className="form-stack">
        <p className="form-intro">
          Use this only when money was already due before you started using
          Hisaab for {party.name}.
        </p>
        <div className="action-segment">
          <button
            type="button"
            className={direction === "receive" ? "selected" : ""}
            onClick={() => {
              setDirection("receive");
              setConfirming(false);
            }}
          >
            They owe you
          </button>
          <button
            type="button"
            className={direction === "pay" ? "selected" : ""}
            onClick={() => {
              setDirection("pay");
              setConfirming(false);
            }}
          >
            You owe them
          </button>
        </div>
        <Field label="Amount" required>
          <div className="amount-input">
            <span>₹</span>
            <input
              value={amount}
              onChange={(event) => {
                setAmount(event.target.value.replace(/[^\d.]/g, ""));
                setConfirming(false);
              }}
              inputMode="decimal"
              autoFocus
            />
          </div>
        </Field>
        <button
          type="button"
          className="date-summary-row"
          aria-expanded={dateOpen}
          onClick={() => setDateOpen((value) => !value)}
        >
          <CalendarDays />
          <span>
            <strong>Date</strong>
            <small>{date === today ? "Today" : formatEntryDate(date)}</small>
          </span>
          <em>{dateOpen ? "Done" : "Change"}</em>
        </button>
        {dateOpen
          ? (
            <Field label="Starting date" required>
              <input
                type="date"
                value={date}
                max={today}
                onChange={(event) => {
                  setDate(event.target.value);
                  setConfirming(false);
                }}
                onInput={(event) => {
                  setDate(event.currentTarget.value);
                  setConfirming(false);
                }}
              />
            </Field>
          )
          : null}
        <div className="balance-preview">
          <CheckCircle2 />
          <span>
            {previewBalance(party.name, balanceAfterOpening, amountPaise)}
          </span>
        </div>
        {error ? <div className="form-error">{error}</div> : null}
        {confirming
          ? (
            <div className="confirm-panel">
              <strong>Update this starting balance?</strong>
              <p>
                Later running balances will be recalculated. The previous value
                will remain in the audit history.
              </p>
              <div>
                <button
                  type="button"
                  className="button button-secondary"
                  onClick={() => setConfirming(false)}
                >
                  Go back
                </button>
                <button
                  className="button button-primary"
                  disabled={saving}
                  type="submit"
                >
                  {saving ? <LoaderCircle className="spin" /> : <Check />}
                  Confirm update
                </button>
              </div>
            </div>
          )
          : (
            <div className="dialog-actions">
              <button
                type="button"
                className="button button-secondary"
                onClick={onClose}
              >
                Cancel
              </button>
              <button className="button button-primary" disabled={saving}>
                {saving ? <LoaderCircle className="spin" /> : <Check />}
                {existing ? "Review change" : "Save opening balance"}
              </button>
            </div>
          )}
      </form>
    </Dialog>
  );
}

function MergeDialog({
  parties,
  onClose,
  onSaved,
}: {
  parties: Party[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const [sourceId, setSourceId] = useState(parties[0]?.id ?? "");
  const [targetId, setTargetId] = useState(parties[1]?.id ?? "");
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  const operationId = useRef(createClientId());
  const sourceParty = parties.find((party) => party.id === sourceId);
  const targetParty = parties.find((party) => party.id === targetId);

  if (parties.length < 2) {
    return (
      <Dialog title="Merge duplicate records" onClose={onClose}>
        <div className="form-stack">
          <p className="form-intro">
            You need at least two active parties before you can merge a
            duplicate.
          </p>
          <div className="dialog-actions">
            <button className="button button-primary" onClick={onClose}>
              Got it
            </button>
          </div>
        </div>
      </Dialog>
    );
  }

  async function merge() {
    if (!sourceId || !targetId || sourceId === targetId) {
      return setError("Choose two different records.");
    }
    setSaving(true);
    const response = await apiFetch("/api/parties/merge", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        sourcePartyId: sourceId,
        targetPartyId: targetId,
        idempotencyKey: operationId.current,
        baseSourceVersion: sourceParty?.version,
        baseTargetVersion: targetParty?.version,
      }),
    });
    if (!response.ok) {
      const body = (await response.json()) as ApiError;
      setSaving(false);
      return setError(body.error);
    }
    await onSaved();
  }

  return (
    <Dialog title="Merge duplicate records" onClose={onClose}>
      <div className="form-stack">
        <p className="form-intro">
          Use this only when the same party was added twice. No entries will be
          deleted.
        </p>
        <Field label="Move entries from">
          <select
            value={sourceId}
            onChange={(event) => {
              const nextSource = event.target.value;
              setSourceId(nextSource);
              if (targetId === nextSource) {
                setTargetId(
                  parties.find((party) => party.id !== nextSource)?.id ?? "",
                );
              }
            }}
          >
            {parties.map((party) => (
              <option key={party.id} value={party.id}>{party.name}</option>
            ))}
          </select>
        </Field>
        <Field label="Keep this party">
          <select
            value={targetId}
            onChange={(event) => setTargetId(event.target.value)}
          >
            {parties.filter((party) => party.id !== sourceId).map((party) => (
              <option key={party.id} value={party.id}>{party.name}</option>
            ))}
          </select>
        </Field>
        {error ? <div className="form-error">{error}</div> : null}
        {confirming
          ? (
            <div className="confirm-panel">
              <strong>Move every entry to {targetParty?.name}?</strong>
              <p>
                All entries from {sourceParty?.name} will move to{" "}
                {targetParty?.name}. {sourceParty?.name} will then be archived.
              </p>
              <div>
                <button
                  className="button button-secondary"
                  onClick={() => setConfirming(false)}
                >
                  Go back
                </button>
                <button
                  className="button button-danger"
                  disabled={saving}
                  onClick={merge}
                >
                  Merge records
                </button>
              </div>
            </div>
          )
          : (
            <div className="dialog-actions">
              <button className="button button-secondary" onClick={onClose}>
                Cancel
              </button>
              <button
                className="button button-primary"
                onClick={() => setConfirming(true)}
              >
                Review merge
              </button>
            </div>
          )}
      </div>
    </Dialog>
  );
}

function MoreView({
  data,
  offline,
  onRefresh,
  onMerge,
  onDelete,
  onUpdated,
  onSignOut,
}: {
  data: BootstrapData;
  offline: boolean;
  onRefresh: () => Promise<void>;
  onMerge: () => void;
  onDelete: () => void;
  onUpdated: (message: string) => Promise<void>;
  onSignOut: () => Promise<void>;
}) {
  const [companyName, setCompanyName] = useState(data.company.name);
  const [timezone, setTimezone] = useState(data.company.timezone);
  const [language, setLanguage] = useState(data.user.language);
  const [accessibility, setAccessibility] = useState(
    data.user.accessibilityMode,
  );
  const [companyMore, setCompanyMore] = useState(false);
  const [preferencesMore, setPreferencesMore] = useState(false);
  const [groupsOpen, setGroupsOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [groupName, setGroupName] = useState("");

  async function downloadExport(format: "json" | "csv") {
    const response = await apiFetch(`/api/export?format=${format}`);
    if (!response.ok) {
      setError("Could not download that export.");
      return;
    }
    const blob = await response.blob();
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = format === "csv"
      ? "hisaab-entries.csv"
      : "hisaab-backup.json";
    anchor.click();
    URL.revokeObjectURL(url);
  }
  const settingsOperationId = useRef(createClientId());
  const groupClientId = useRef(createClientId());
  const groupOperationId = useRef(createClientId());
  const activePartyCount = data.parties.filter(
    (party) => !party.archivedAt,
  ).length;

  async function saveSettings(
    event: FormEvent<HTMLFormElement>,
    successMessage: string,
  ) {
    event.preventDefault();
    setSaving(true);
    const response = await apiFetch("/api/settings", {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        companyName,
        timezone,
        language,
        accessibilityMode: accessibility,
        idempotencyKey: settingsOperationId.current,
        baseCompanyVersion: data.company.version,
        baseUserVersion: data.user.version,
      }),
    });
    if (!response.ok) {
      const body = (await response.json()) as ApiError;
      setError(body.error);
      setSaving(false);
      return;
    }
    setSaving(false);
    settingsOperationId.current = createClientId();
    await onUpdated(successMessage);
  }

  async function addGroup(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!groupName.trim()) return;
    const response = await apiFetch("/api/groups", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        name: groupName,
        clientId: groupClientId.current,
        idempotencyKey: groupOperationId.current,
      }),
    });
    if (!response.ok) {
      const body = (await response.json()) as ApiError;
      return setError(body.error);
    }
    setGroupName("");
    groupClientId.current = createClientId();
    groupOperationId.current = createClientId();
    await onUpdated("Group added.");
  }

  return (
    <div className="app-view more-view">
      <div className="view-title-row">
        <div>
          <h1>More</h1>
          <p>Business settings and your data</p>
        </div>
      </div>
      <section className="settings-section">
        <div className="settings-heading">
          <Building2 />
          <div>
            <h2>Business</h2>
            <p>Name and date settings</p>
          </div>
        </div>
        <form
          className="settings-form"
          onSubmit={(event) => saveSettings(event, "Company settings saved.")}
        >
          <Field label="Company name">
            <input
              value={companyName}
              onChange={(e) => setCompanyName(e.target.value)}
            />
          </Field>
          <DisclosureButton
            open={companyMore}
            onToggle={() => setCompanyMore((value) => !value)}
            label="More company settings"
            summary="Timezone and currency"
          />
          <div className="more-fields settings-advanced" hidden={!companyMore}>
            <Field label="Company timezone">
              <select
                value={timezone}
                onChange={(e) => setTimezone(e.target.value)}
              >
                <option value="Asia/Kolkata">India — Asia/Kolkata</option>
                <option value="Asia/Kathmandu">Nepal — Asia/Kathmandu</option>
                <option value="Asia/Dubai">UAE — Asia/Dubai</option>
                <option value="UTC">UTC</option>
              </select>
            </Field>
            <div className="read-only-setting">
              <span>Currency</span>
              <strong>INR — Indian Rupee</strong>
              <small>Fixed for this version of Hisaab</small>
            </div>
          </div>
          <button
            className="button button-primary compact"
            disabled={saving || offline}
          >
            {saving ? <LoaderCircle className="spin" /> : <Check />}{" "}
            Save company
          </button>
        </form>
      </section>
      <section className="settings-section">
        <div className="settings-heading">
          <Languages />
          <div>
            <h2>Your preferences</h2>
            <p>These settings belong to you, not the company</p>
          </div>
        </div>
        <form
          className="settings-form"
          onSubmit={(event) => saveSettings(event, "Preferences saved.")}
        >
          <Field label="Language">
            <select
              value={language}
              onChange={(e) => setLanguage(e.target.value as "en" | "hi")}
            >
              <option value="en">English</option>
              <option value="hi">हिंदी</option>
            </select>
          </Field>
          <DisclosureButton
            open={preferencesMore}
            onToggle={() => setPreferencesMore((value) => !value)}
            label="Accessibility"
            summary={accessibility ? "Large text is on" : "Optional"}
          />
          <div
            className="more-fields settings-advanced"
            hidden={!preferencesMore}
          >
            <label className="switch-row">
              <span>
                <strong>Large, accessible text</strong>
                <small>Use larger labels and controls</small>
              </span>
              <input
                type="checkbox"
                checked={accessibility}
                onChange={(e) => setAccessibility(e.target.checked)}
              />
            </label>
          </div>
          <button
            className="button button-primary compact"
            disabled={saving || offline}
          >
            <Check /> Save preferences
          </button>
        </form>
      </section>
      <section className="settings-section">
        <div className="settings-heading">
          <Users />
          <div>
            <h2>Party groups</h2>
            <p>Optional labels for organising parties</p>
          </div>
        </div>
        <DisclosureButton
          open={groupsOpen}
          onToggle={() => setGroupsOpen((value) => !value)}
          label="Manage groups"
          summary={data.groups.length
            ? `${data.groups.length} ${
              data.groups.length === 1 ? "group" : "groups"
            }`
            : "Optional"}
        />
        <div className="settings-collapsible" hidden={!groupsOpen}>
          <div className="group-list">
            {data.groups.map((group) => <span key={group.id}>{group.name}
            </span>)}
          </div>
          <form className="inline-form" onSubmit={addGroup}>
            <input
              value={groupName}
              onChange={(e) => setGroupName(e.target.value)}
              placeholder="New group name"
            />
            <button
              className="button button-secondary compact"
              disabled={offline}
            >
              <Plus /> Add
            </button>
          </form>
        </div>
      </section>
      <section className="settings-section">
        <div className="settings-heading">
          <ShieldCheck />
          <div>
            <h2>Your data</h2>
            <p>Backups, duplicates and account controls</p>
          </div>
        </div>
        <div className="settings-actions">
          <button
            type="button"
            className="setting-action"
            onClick={() => void downloadExport("json")}
          >
            <Download />
            <span>
              <strong>Export all data</strong>
              <small>Download a complete JSON backup</small>
            </span>
            <ChevronRight />
          </button>
          <button
            type="button"
            className="setting-action"
            onClick={() => void downloadExport("csv")}
          >
            <FileText />
            <span>
              <strong>Export entries as CSV</strong>
              <small>Open in spreadsheet software</small>
            </span>
            <ChevronRight />
          </button>
          <button
            className="setting-action"
            onClick={onMerge}
            disabled={activePartyCount < 2}
          >
            <Merge />
            <span>
              <strong>Merge duplicate people</strong>
              <small>
                {activePartyCount < 2
                  ? "Available when you have two active parties"
                  : "Move entries safely into one record"}
              </small>
            </span>
            <ChevronRight />
          </button>
          <button className="setting-action" onClick={onRefresh}>
            <RefreshCw />
            <span>
              <strong>Refresh data</strong>
              <small>Reload the latest saved records</small>
            </span>
            <ChevronRight />
          </button>
          <button
            className="setting-action"
            onClick={() => void onSignOut()}
          >
            <ArrowLeft />
            <span>
              <strong>Sign out</strong>
              <small>End this browser session</small>
            </span>
            <ChevronRight />
          </button>
          <button className="setting-action danger" onClick={onDelete}>
            <Trash2 />
            <span>
              <strong>Delete account</strong>
              <small>Download an export first</small>
            </span>
            <ChevronRight />
          </button>
        </div>
      </section>
      <div className="recorded-balance-note">
        <CircleAlert />
        <p>
          <strong>About Cash and Bank figures</strong>
          They show recorded money received and paid through customer entries.
          They may not match your actual cash or bank balance.
        </p>
      </div>
      <div className="registered-account-note">
        Signed in with{" "}
        {data.user.phoneE164}. Export a backup before asking an administrator to
        change this number.
      </div>
      {error ? <div className="form-error">{error}</div> : null}
    </div>
  );
}

function OfflineQueueDialog({
  items,
  parties,
  offline,
  onClose,
  onRetry,
  onDiscard,
  onEdit,
}: {
  items: QueuedEntry[];
  parties: Party[];
  offline: boolean;
  onClose: () => void;
  onRetry: (id: string) => Promise<void>;
  onDiscard: (id: string) => void;
  onEdit: (
    id: string,
    updates: {
      partyId: string;
      action: "gave" | "received";
      amountPaise: number;
      narration: string;
      entryDate: string;
    },
  ) => void;
}) {
  const [busyId, setBusyId] = useState<string | null>(null);
  const [confirmDiscardId, setConfirmDiscardId] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [error, setError] = useState("");

  return (
    <Dialog title="Saved offline entries" onClose={onClose} wide>
      <div className="offline-queue">
        <p className="form-intro">
          These entries stay on this device until Hisaab confirms that the
          server saved them. Review any problem before retrying or discarding.
        </p>
        {items.length === 0
          ? (
            <div className="queue-empty">
              <CheckCircle2 />
              <div>
                <strong>Everything is uploaded</strong>
                <small>There are no offline entries waiting for review.</small>
              </div>
            </div>
          )
          : (
            <div className="offline-queue-list">
              {items.map((item) => {
                const party = parties.find(
                  (candidate) => candidate.id === item.body.partyId,
                );
                const amount = typeof item.body.amountPaise === "number"
                  ? formatInr(item.body.amountPaise)
                  : "Invalid amount";
                const action = item.body.action === "gave"
                  ? "You gave"
                  : item.body.action === "received"
                  ? "You got"
                  : "Entry";
                const confirming = confirmDiscardId === item.id;
                const editing = editingId === item.id;
                return (
                  <article
                    className={`offline-queue-item ${
                      queueNeedsAttention(item) ? "needs-attention" : ""
                    }`}
                    key={item.id}
                  >
                    <header>
                      <div>
                        <strong>{party?.name ?? "Unknown party"}</strong>
                        <span>
                          {action} {amount}
                        </span>
                      </div>
                      <em>{queueStatusLabel(item)}</em>
                    </header>
                    <dl>
                      <Detail
                        label="Date"
                        value={typeof item.body.entryDate === "string"
                          ? formatEntryDate(item.body.entryDate)
                          : "Missing"}
                      />
                      <Detail
                        label="Saved on device"
                        value={formatLocalDateTime(item.createdAt)}
                      />
                      <Detail
                        label="Attempts"
                        value={String(item.attempts)}
                      />
                      {typeof item.body.narration === "string" &&
                          item.body.narration.trim()
                        ? (
                          <Detail
                            label="Note"
                            value={item.body.narration.trim()}
                          />
                        )
                        : null}
                    </dl>
                    {item.lastError
                      ? (
                        <div className="queue-error" role="alert">
                          <CircleAlert />
                          <span>
                            <strong>Why it needs attention</strong>
                            <small>{item.lastError}</small>
                          </span>
                        </div>
                      )
                      : null}
                    {item.retryAfter
                      ? (
                        <small className="queue-retry-time">
                          Automatic retry after{" "}
                          {formatLocalDateTime(item.retryAfter)}
                        </small>
                      )
                      : null}
                    {editing
                      ? (
                        <OfflineQueueEditForm
                          item={item}
                          parties={parties}
                          onCancel={() => setEditingId(null)}
                          onSave={(updates) => {
                            onEdit(item.id, updates);
                            setEditingId(null);
                          }}
                        />
                      )
                      : confirming
                      ? (
                        <div className="queue-confirm-discard">
                          <p>
                            Discarding removes the only unsynced copy from this
                            device. This cannot be undone.
                          </p>
                          <div>
                            <button
                              className="button button-secondary compact"
                              onClick={() => setConfirmDiscardId(null)}
                            >
                              Keep entry
                            </button>
                            <button
                              className="button button-danger compact"
                              onClick={() => {
                                onDiscard(item.id);
                                setConfirmDiscardId(null);
                              }}
                            >
                              Discard permanently
                            </button>
                          </div>
                        </div>
                      )
                      : (
                        <div className="queue-actions">
                          <button
                            className="button button-secondary compact"
                            disabled={busyId === item.id}
                            onClick={() => {
                              setConfirmDiscardId(null);
                              setEditingId(item.id);
                            }}
                          >
                            <Pencil /> Edit
                          </button>
                          <button
                            className="button button-secondary compact"
                            disabled={busyId === item.id}
                            onClick={async () => {
                              setBusyId(item.id);
                              setError("");
                              try {
                                await onRetry(item.id);
                              } catch (caught) {
                                setError(
                                  caught instanceof Error
                                    ? caught.message
                                    : "Could not retry this entry.",
                                );
                              } finally {
                                setBusyId(null);
                              }
                            }}
                          >
                            {busyId === item.id
                              ? <LoaderCircle className="spin" />
                              : <RefreshCw />}
                            {offline ? "Retry when online" : "Retry now"}
                          </button>
                          <button
                            className="quiet-link danger"
                            onClick={() => setConfirmDiscardId(item.id)}
                          >
                            Discard
                          </button>
                        </div>
                      )}
                  </article>
                );
              })}
            </div>
          )}
        {error ? <div className="form-error">{error}</div> : null}
        <div className="dialog-actions">
          <button className="button button-primary" onClick={onClose}>
            Done
          </button>
        </div>
      </div>
    </Dialog>
  );
}

function OfflineQueueEditForm({
  item,
  parties,
  onCancel,
  onSave,
}: {
  item: QueuedEntry;
  parties: Party[];
  onCancel: () => void;
  onSave: (updates: {
    partyId: string;
    action: "gave" | "received";
    amountPaise: number;
    narration: string;
    entryDate: string;
  }) => void;
}) {
  const currentPartyId = typeof item.body.partyId === "string"
    ? item.body.partyId
    : "";
  const availableParties = parties.filter((party) => !party.archivedAt);
  const [partyId, setPartyId] = useState(
    availableParties.some((party) => party.id === currentPartyId)
      ? currentPartyId
      : availableParties[0]?.id ?? "",
  );
  const [action, setAction] = useState<"gave" | "received">(
    item.body.action === "received" ? "received" : "gave",
  );
  const [amount, setAmount] = useState(
    typeof item.body.amountPaise === "number"
      ? paiseToInput(item.body.amountPaise)
      : "",
  );
  const [entryDate, setEntryDate] = useState(
    typeof item.body.entryDate === "string" ? item.body.entryDate : "",
  );
  const [narration, setNarration] = useState(
    typeof item.body.narration === "string" ? item.body.narration : "",
  );
  const [error, setError] = useState("");

  return (
    <form
      className="queue-edit-form"
      onSubmit={(event) => {
        event.preventDefault();
        const amountPaise = parseAmountToPaise(amount);
        if (!availableParties.some((party) => party.id === partyId)) {
          return setError("Choose an active party.");
        }
        if (amountPaise == null || amountPaise <= 0) {
          return setError("Enter a valid amount.");
        }
        if (!isValidDateOnly(entryDate)) {
          return setError("Choose a valid entry date.");
        }
        onSave({
          partyId,
          action,
          amountPaise,
          narration: narration.trim().slice(0, 240),
          entryDate,
        });
      }}
    >
      <strong>Correct this offline entry</strong>
      <div className="queue-edit-grid">
        <Field label="Party" required>
          <select
            value={partyId}
            onChange={(event) => setPartyId(event.target.value)}
          >
            <option value="">Choose a party</option>
            {availableParties.map((party) => (
              <option value={party.id} key={party.id}>
                {party.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Amount" required>
          <div className="amount-input">
            <span>₹</span>
            <input
              value={amount}
              inputMode="decimal"
              onChange={(event) =>
                setAmount(event.target.value.replace(/[^\d.]/g, ""))}
            />
          </div>
        </Field>
        <Field label="Date" required>
          <input
            type="date"
            value={entryDate}
            onChange={(event) => setEntryDate(event.target.value)}
          />
        </Field>
      </div>
      <div className="action-segment compact">
        <button
          type="button"
          className={action === "gave" ? "selected" : ""}
          onClick={() => setAction("gave")}
        >
          You gave
        </button>
        <button
          type="button"
          className={action === "received" ? "selected" : ""}
          onClick={() => setAction("received")}
        >
          You got
        </button>
      </div>
      <Field label="Note" hint="Optional">
        <textarea
          value={narration}
          maxLength={240}
          onChange={(event) => setNarration(event.target.value)}
        />
      </Field>
      {error ? <div className="form-error">{error}</div> : null}
      <div className="queue-edit-actions">
        <button
          type="button"
          className="button button-secondary compact"
          onClick={onCancel}
        >
          Cancel
        </button>
        <button className="button button-primary compact">
          <Check /> Save correction
        </button>
      </div>
    </form>
  );
}

function DeleteAccountDialog({
  onClose,
  onDeleted,
}: {
  onClose: () => void;
  onDeleted: () => Promise<void>;
}) {
  const [confirmation, setConfirmation] = useState("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);
  async function remove() {
    setSaving(true);
    const response = await apiFetch("/api/account", {
      method: "DELETE",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ confirmation }),
    });
    if (!response.ok) {
      const body = (await response.json()) as ApiError;
      setSaving(false);
      return setError(body.error);
    }
    await onDeleted();
  }
  return (
    <Dialog title="Delete account" onClose={onClose}>
      <div className="form-stack">
        <div className="form-alert danger">
          <CircleAlert />
          <div>
            <strong>This permanently removes your company data.</strong>
            <span>Export your data first. This action cannot be undone.</span>
          </div>
        </div>
        <Field label='Type "DELETE MY ACCOUNT" to confirm'>
          <input
            value={confirmation}
            onChange={(e) => setConfirmation(e.target.value)}
            autoComplete="off"
          />
        </Field>
        {error ? <div className="form-error">{error}</div> : null}
        <div className="dialog-actions">
          <button className="button button-secondary" onClick={onClose}>
            Cancel
          </button>
          <button
            className="button button-danger"
            disabled={saving || confirmation !== "DELETE MY ACCOUNT"}
            onClick={remove}
          >
            {saving ? <LoaderCircle className="spin" /> : <Trash2 />}{" "}
            Delete permanently
          </button>
        </div>
      </div>
    </Dialog>
  );
}

function Dialog({
  title,
  children,
  onClose,
  wide = false,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
  wide?: boolean;
}) {
  const titleId = useId();
  const dialogRef = useRef<HTMLElement>(null);
  const closeRef = useRef(onClose);
  const returnFocusRef = useContext(OverlayReturnFocusContext);
  useEffect(() => {
    closeRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    const previous = document.body.style.overflow;
    const previousFocus = returnFocusRef?.current ??
      (document.activeElement instanceof HTMLElement
        ? document.activeElement
        : null);
    document.body.style.overflow = "hidden";
    const focusableSelector =
      'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])';
    const animationFrame = window.requestAnimationFrame(() => {
      const dialog = dialogRef.current;
      const first = dialog?.querySelector<HTMLElement>("[autofocus]") ??
        dialog?.querySelector<HTMLElement>(focusableSelector);
      first?.focus();
    });
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        closeRef.current();
        return;
      }
      if (event.key !== "Tab" || !dialogRef.current) return;
      const focusable = Array.from(
        dialogRef.current.querySelectorAll<HTMLElement>(focusableSelector),
      ).filter((element) => element.offsetParent !== null);
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable.at(-1)!;
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.cancelAnimationFrame(animationFrame);
      document.body.style.overflow = previous;
      window.removeEventListener("keydown", handleKeyDown);
      window.requestAnimationFrame(() => {
        if (
          !document.querySelector('[role="dialog"]') &&
          previousFocus?.isConnected
        ) {
          previousFocus.focus();
          if (returnFocusRef?.current === previousFocus) {
            returnFocusRef.current = null;
          }
        }
      });
    };
  }, [returnFocusRef]);
  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={onClose}>
      <section
        ref={dialogRef}
        className={`dialog ${wide ? "dialog-wide" : ""}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onMouseDown={(event) =>
          event.stopPropagation()}
      >
        <header>
          <h2 id={titleId}>{title}</h2>
          <button className="icon-button" aria-label="Close" onClick={onClose}>
            <X />
          </button>
        </header>
        <div className="dialog-body">{children}</div>
      </section>
    </div>
  );
}

function Field({
  label,
  hint,
  required,
  children,
}: {
  label: string;
  hint?: string;
  required?: boolean;
  children: ReactNode;
}) {
  return (
    <label className="field">
      <span>
        {label}
        {required ? <b>Required</b> : hint ? <small>{hint}</small> : null}
      </span>
      {children}
    </label>
  );
}

function DisclosureButton({
  open,
  onToggle,
  label,
  summary,
}: {
  open: boolean;
  onToggle: () => void;
  label: string;
  summary: string;
}) {
  return (
    <button
      type="button"
      className="disclosure-row"
      aria-expanded={open}
      onClick={onToggle}
    >
      <Settings aria-hidden="true" />
      <span className="disclosure-copy">
        <strong>{label}</strong>
        <small>{summary}</small>
      </span>
      <ChevronRight
        className={open ? "rotated" : ""}
        aria-hidden="true"
      />
    </button>
  );
}

function NavButton({
  selected,
  label,
  icon,
  onClick,
}: {
  selected: boolean;
  label: string;
  icon: ReactNode;
  onClick: () => void;
}) {
  return (
    <button className={selected ? "selected" : ""} onClick={onClick}>
      {icon}
      <span>{label}</span>
    </button>
  );
}

function SyncStatus({
  offline,
  queueCount,
  compact = false,
  onReview,
}: {
  offline: boolean;
  queueCount: number;
  compact?: boolean;
  onReview: () => void;
}) {
  return (
    <button
      type="button"
      className={`sync-status ${offline ? "offline" : ""} ${
        compact ? "compact" : ""
      } ${queueCount ? "actionable" : ""}`}
      disabled={!queueCount}
      onClick={onReview}
      title={queueCount
        ? "Review saved offline entries"
        : "Everything is up to date"}
    >
      {offline ? <CloudOff /> : queueCount ? <Clock3 /> : <Wifi />}
      <span>
        {offline
          ? queueCount ? `Offline · ${queueCount} saved` : "Offline"
          : queueCount
          ? `${queueCount} to review`
          : "Up to date"}
      </span>
    </button>
  );
}

function EmptyState({
  icon,
  title,
  body,
  action,
}: {
  icon: ReactNode;
  title: string;
  body: string;
  action?: { label: string; run: () => void };
}) {
  return (
    <div className="empty-state">
      <span>{icon}</span>
      <h3>{title}</h3>
      <p>{body}</p>
      {action
        ? (
          <button className="button button-secondary" onClick={action.run}>
            {action.label}
          </button>
        )
        : null}
    </div>
  );
}

function LoadingScreen() {
  return (
    <main className="loading-screen">
      <Brand />
      <LoaderCircle className="spin" />
      <p>Loading your Hisaab safely…</p>
    </main>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}

type EntryMoneyData = Pick<
  Entry,
  "action" | "amountPaise" | "balanceEffectPaise" | "narration"
>;

function EntryDirectionBadge({ entry }: { entry: EntryMoneyData }) {
  const tone = entryDirectionTone(entry.action);
  return (
    <span className={`entry-action ${tone}`} aria-hidden="true">
      {tone === "opening"
        ? <FileClock />
        : <b>{entryAmountSign(entry.action)}</b>}
    </span>
  );
}

function EntryMoney({
  entry,
  className,
}: {
  entry: EntryMoneyData;
  className: string;
}) {
  const tone = entryDirectionTone(entry.action);
  const label = entryDirectionLabel(entry.action, entry.balanceEffectPaise);
  return (
    <span className={`${className} entry-money ${tone}`}>
      <strong>{signedEntryAmount(entry)}</strong>
      <small>{label}</small>
    </span>
  );
}

function entryNoteLabel(entry: EntryMoneyData) {
  return entryDisplayLabel(entry.action, entry.narration);
}

function signedEntryAmount(entry: Pick<Entry, "action" | "amountPaise">) {
  return `${entryAmountSign(entry.action)}${formatInr(entry.amountPaise)}`;
}

function mergePendingStatementEntries(
  statementEntries: Entry[],
  bootstrapEntries: Entry[],
  partyId: string,
) {
  const ids = new Set(statementEntries.map((entry) => entry.id));
  const pending = bootstrapEntries.filter(
    (entry) =>
      entry.partyId === partyId && entry.clientSync && !ids.has(entry.id),
  );
  return [...pending, ...statementEntries];
}

function queueNeedsAttention(item: QueuedEntry) {
  return (
    item.status === "needs_auth" ||
    item.status === "conflict" ||
    item.status === "rejected"
  );
}

function queueStatusLabel(item: QueuedEntry) {
  if (item.status === "needs_auth") return "Sign-in required";
  if (item.status === "conflict") return "Review conflict";
  if (item.status === "rejected") return "Rejected";
  if (item.status === "rate_limited") return "Retry scheduled";
  return item.attempts ? "Waiting to retry" : "Waiting to upload";
}

function initials(name: string) {
  return name.trim().split(/\s+/).slice(0, 2).map((part) => part[0]).join("")
    .toUpperCase();
}

function parseAmountToPaise(input: string) {
  const match = input.trim().match(/^(\d{1,9})(?:\.(\d{0,2}))?$/);
  if (!match) return null;
  const rupees = Number.parseInt(match[1], 10);
  const paise = Number.parseInt((match[2] ?? "").padEnd(2, "0") || "0", 10);
  const total = rupees * 100 + paise;
  return Number.isSafeInteger(total) ? total : null;
}

function paiseToInput(paise: number) {
  const rupees = Math.floor(paise / 100);
  const remainder = paise % 100;
  return remainder
    ? `${rupees}.${String(remainder).padStart(2, "0")}`
    : String(rupees);
}

function formatInr(paise: number) {
  const absolute = Math.abs(paise);
  const rupees = Math.floor(absolute / 100);
  const remainder = absolute % 100;
  const formatted = new Intl.NumberFormat("en-IN", {
    maximumFractionDigits: 0,
  }).format(rupees);
  return `₹${formatted}${
    remainder ? `.${String(remainder).padStart(2, "0")}` : ""
  }`;
}

function formatEntryDate(value: string) {
  return formatLedgerDate(value);
}

function previewBalance(
  name: string,
  balance: number,
  amountPaise: number | null,
) {
  if (!amountPaise) return "Enter an amount to see the new balance.";
  if (balance > 0) {
    return `After this entry, you will receive ${
      formatInr(balance)
    } from ${name}.`;
  }
  if (balance < 0) {
    return `After this entry, you will pay ${formatInr(-balance)} to ${name}.`;
  }
  return `After this entry, your balance with ${name} will be settled.`;
}

function balanceSentence(balance: number) {
  if (balance > 0) return `Final: You will receive ${formatInr(balance)}.`;
  if (balance < 0) return `Final: You will pay ${formatInr(-balance)}.`;
  return "Final: Your balance is settled.";
}

function balancePosition(balance: number) {
  if (balance > 0) return `${formatInr(balance)} to receive`;
  if (balance < 0) return `${formatInr(-balance)} to pay`;
  return "settled";
}
