import 'dart:async';

import 'package:get/get.dart';

import '../../core/network/api_failure.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/models/statement_models.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../services/app_translations.dart';

enum LedgerSyncStatus {
  idle,
  syncing,
  waitingToRetry,
  needsAttention,
  authenticationRequired,
}

class LedgerController extends GetxController {
  LedgerController(this._repository);

  final LedgerRepository _repository;

  final data = Rxn<BootstrapData>();
  final loading = false.obs;
  final mutating = false.obs;
  final isOffline = false.obs;
  final message = RxnString();

  final syncStatus = LedgerSyncStatus.idle.obs;
  final pendingCount = 0.obs;
  final needsAttentionCount = 0.obs;
  final lastSyncedAt = Rxn<DateTime>();
  final nextSyncAttemptAt = Rxn<DateTime>();
  final lastQueuedOperationId = RxnString();

  final partySearch = ''.obs;
  final partyFilter = 'active'.obs;
  final entrySearch = ''.obs;
  final entryDirection = 'all'.obs;
  final entryPeriod = 'all'.obs;

  Future<void> _operationTail = Future<void>.value();
  Future<void>? _activeReload;
  Future<SyncRunResult>? _activeSync;
  void Function()? _requestSync;
  String? _appliedLanguage = Get.locale?.languageCode;

  List<Party> get parties => data.value?.parties ?? const [];
  List<LedgerEntry> get entries => data.value?.entries ?? const [];
  List<PartyGroup> get groups => data.value?.groups ?? const [];

  int get totalReceive => parties
      .where((party) => !party.isArchived && party.balancePaise > 0)
      .fold(0, (total, party) => total + party.balancePaise);

  int get totalPay => parties
      .where((party) => !party.isArchived && party.balancePaise < 0)
      .fold(0, (total, party) => total + party.balancePaise.abs());

  List<Party> get filteredParties {
    final query = partySearch.value.trim().toLowerCase();
    return parties.where((party) {
      final filterMatches = switch (partyFilter.value) {
        'receive' => !party.isArchived && party.balancePaise > 0,
        'pay' => !party.isArchived && party.balancePaise < 0,
        'settled' => !party.isArchived && party.balancePaise == 0,
        'archived' => party.isArchived,
        _ => !party.isArchived,
      };
      if (!filterMatches) return false;
      return query.isEmpty ||
          party.name.toLowerCase().contains(query) ||
          party.shortName.toLowerCase().contains(query) ||
          party.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
    }).toList();
  }

  List<LedgerEntry> get filteredEntries {
    final query = entrySearch.value.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return entries.where((entry) {
      final directionMatches = switch (entryDirection.value) {
        'gave' => entry.action == EntryAction.gave,
        'received' => entry.action == EntryAction.received,
        _ => true,
      };
      final periodMatches = switch (entryPeriod.value) {
        '7' => !entry.entryDate.isBefore(
          today.subtract(const Duration(days: 6)),
        ),
        '30' => !entry.entryDate.isBefore(
          today.subtract(const Duration(days: 29)),
        ),
        '90' => !entry.entryDate.isBefore(
          today.subtract(const Duration(days: 89)),
        ),
        _ => true,
      };
      final searchMatches =
          query.isEmpty ||
          entry.partyName.toLowerCase().contains(query) ||
          entry.narration.toLowerCase().contains(query) ||
          entry.sequence.toString().contains(query);
      return directionMatches && periodMatches && searchMatches;
    }).toList();
  }

  /// Installs the coordinator callback used after an optimistic mutation.
  ///
  /// Root composition should pass `() => unawaited(coordinator.syncNow())`.
  void setSyncRequestHandler(void Function() handler) {
    _requestSync = handler;
  }

  /// Shows encrypted cached data immediately and then safely catches up.
  Future<void> initializeLocalFirst({bool refresh = true}) async {
    final hadCache = loadCached();
    await refreshSyncState();
    if (!refresh) return;
    if (hadCache) {
      final hasCheckpoint = _isSyncCursor(data.value?.syncCursor);
      final hasQueuedChanges =
          pendingCount.value > 0 || needsAttentionCount.value > 0;
      if (!hasCheckpoint && !hasQueuedChanges) {
        await reload();
        return;
      }
      final result = await syncNow(pullRemoteChanges: hasCheckpoint);
      if (result.authenticationRequired) {
        throw const ApiFailure(
          'Your session has expired. Sign in again.',
          statusCode: 401,
        );
      }
      if (!hasCheckpoint &&
          result.pendingCount == 0 &&
          result.needsAttentionCount == 0) {
        await reload();
      }
      return;
    }
    await reload();
  }

  /// Fetches a full bootstrap only when doing so cannot erase queued changes.
  Future<void> reload({bool showLoader = true}) {
    final active = _activeReload;
    if (active != null) return active;
    late final Future<void> tracked;
    final queued = _serialize(() => _performReload(showLoader: showLoader));
    tracked = queued.whenComplete(() {
      if (identical(_activeReload, tracked)) _activeReload = null;
    });
    _activeReload = tracked;
    return tracked;
  }

  Future<void> _performReload({required bool showLoader}) async {
    if (showLoader) loading.value = true;
    message.value = null;
    try {
      final summary = await _repository.outboxSummary();
      if (summary.pendingCount > 0 || summary.needsAttentionCount > 0) {
        final result = await _performSync(
          pullRemoteChanges: _isSyncCursor(data.value?.syncCursor),
        );
        if (result.authenticationRequired) {
          throw const ApiFailure(
            'Your session has expired. Sign in again.',
            statusCode: 401,
          );
        }
        if (result.pendingCount > 0 || result.needsAttentionCount > 0) {
          _refreshFromCache();
          return;
        }
      }
      _acceptData(await _repository.bootstrap());
      isOffline.value = false;
      message.value = null;
      await refreshSyncState();
    } on ApiFailure catch (failure) {
      if (failure.isConnectionError && data.value != null) {
        isOffline.value = true;
        message.value =
            'Offline mode — saved changes will sync when Hisaab is reachable.';
      }
      rethrow;
    } finally {
      loading.value = false;
    }
  }

  bool loadCached() {
    final cached = _repository.cachedBootstrap();
    if (cached == null) return false;
    _acceptData(cached);
    isOffline.value = true;
    message.value =
        'Showing saved data — you can keep working while Hisaab reconnects.';
    return true;
  }

  Future<OptimisticMutationResult> createParty({
    required String name,
    required String phone,
    String shortName = '',
    String notes = '',
    String? groupId,
    bool confirmDuplicate = false,
    String? idempotencyKey,
  }) async {
    return _queueMutation(
      () => _repository.queuePartyCreation(
        name: name,
        phone: phone,
        shortName: shortName,
        notes: notes,
        groupId: groupId,
        confirmDuplicate: confirmDuplicate,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<OptimisticMutationResult> createEntry({
    required String partyId,
    required EntryAction action,
    required int amountPaise,
    required String narration,
    required String entryDate,
    required String idempotencyKey,
    String? paymentAccount,
  }) {
    return _queueMutation(
      () => _repository.queueEntryCreation(
        partyId: partyId,
        action: action,
        amountPaise: amountPaise,
        narration: narration,
        entryDate: entryDate,
        idempotencyKey: idempotencyKey,
        paymentAccount: paymentAccount,
      ),
    );
  }

  Future<void> cancelEntry(String id, {String? idempotencyKey}) async {
    final entry = entries.where((item) => item.id == id).firstOrNull;
    await _onlineMutation(
      () => _repository.cancelEntry(
        id,
        baseVersion: entry?.version,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<void> updateEntry({
    required String id,
    required String partyId,
    required EntryAction action,
    required int amountPaise,
    required String narration,
    required String entryDate,
    String? paymentAccount,
    String? idempotencyKey,
  }) async {
    final entry = entries.where((item) => item.id == id).firstOrNull;
    await _onlineMutation(
      () => _repository.updateEntry(
        id: id,
        partyId: partyId,
        action: action,
        amountPaise: amountPaise,
        narration: narration,
        entryDate: entryDate,
        paymentAccount: paymentAccount,
        baseVersion: entry?.version,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<void> updateParty({
    required String id,
    required String name,
    required String phone,
    required String shortName,
    required String notes,
    String? groupId,
    String? idempotencyKey,
  }) async {
    final party = partyById(id);
    await _onlineMutation(
      () => _repository.updateParty(
        id: id,
        name: name,
        phone: phone,
        shortName: shortName,
        notes: notes,
        groupId: groupId,
        setGroupId: true,
        baseVersion: party?.version,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<void> saveOpeningBalance({
    required String partyId,
    required int amountPaise,
    required String direction,
    required String entryDate,
    required String idempotencyKey,
  }) async {
    final existing = entries
        .where(
          (entry) =>
              entry.partyId == partyId &&
              entry.isOpeningBalance &&
              entry.status == EntryStatus.posted,
        )
        .firstOrNull;
    await _onlineMutation(
      () => _repository.saveOpeningBalance(
        partyId: partyId,
        amountPaise: amountPaise,
        direction: direction,
        entryDate: entryDate,
        idempotencyKey: idempotencyKey,
        baseVersion: existing?.version,
        clientId: existing?.id,
      ),
    );
  }

  Future<void> archiveParty(
    Party party, {
    required bool archived,
    String? idempotencyKey,
  }) async {
    await _onlineMutation(
      () => _repository.updateParty(
        id: party.id,
        archived: archived,
        baseVersion: party.version,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<void> updateSettings({
    String? companyName,
    String? timezone,
    String? language,
    bool? accessibilityMode,
    bool? contactDiscoverable,
    String? idempotencyKey,
  }) async {
    await _onlineMutation(
      () => _repository.updateSettings(
        companyName: companyName,
        timezone: timezone,
        language: language,
        accessibilityMode: accessibilityMode,
        contactDiscoverable: contactDiscoverable,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<PartyGroup> createGroup(
    String name, {
    String? clientId,
    String? idempotencyKey,
  }) {
    return _onlineValueMutation(
      () => _repository.createGroup(
        name,
        clientId: clientId,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<void> mergeParties({
    required Party source,
    required Party target,
    String? idempotencyKey,
  }) {
    return _onlineMutation(
      () => _repository.mergeParties(
        source: source,
        target: target,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  Future<ExportedLedgerFile> exportLedger({
    LedgerExportFormat format = LedgerExportFormat.json,
  }) async {
    final queued = await _repository.outboxSummary();
    if (queued.pendingCount > 0 || queued.needsAttentionCount > 0) {
      throw const ApiFailure(
        'Sync or resolve saved changes before exporting a complete server copy.',
      );
    }
    return _repository.exportLedger(format: format);
  }

  Future<void> deleteAccount() => _repository.deleteAccount();

  Future<PartyStatementPage> fetchPartyStatement({
    required String partyId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    String? cursor,
  }) {
    return _repository.fetchPartyStatement(
      partyId: partyId,
      from: from,
      to: to,
      limit: limit,
      cursor: cursor,
    );
  }

  Future<SyncRunResult> syncNow({bool pullRemoteChanges = true}) {
    final active = _activeSync;
    if (active != null) return active;
    late final Future<SyncRunResult> tracked;
    final queued = _serialize(
      () => _performSync(pullRemoteChanges: pullRemoteChanges),
    );
    tracked = queued.whenComplete(() {
      if (identical(_activeSync, tracked)) _activeSync = null;
    });
    _activeSync = tracked;
    return tracked;
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final predecessor = _operationTail;
    final released = Completer<void>();
    _operationTail = released.future;

    Future<T> execute() async {
      await predecessor;
      try {
        return await operation();
      } finally {
        released.complete();
      }
    }

    return execute();
  }

  Future<SyncRunResult> _performSync({required bool pullRemoteChanges}) async {
    syncStatus.value = LedgerSyncStatus.syncing;
    final result = await _repository.syncPending(
      pullRemoteChanges: pullRemoteChanges,
    );
    _acceptData(result.bootstrap);
    pendingCount.value = result.pendingCount;
    needsAttentionCount.value = result.needsAttentionCount;
    lastSyncedAt.value = result.lastSyncedAt;
    nextSyncAttemptAt.value = result.nextAttemptAt;

    if (result.authenticationRequired) {
      syncStatus.value = LedgerSyncStatus.authenticationRequired;
      message.value = 'Your session has expired. Sign in to resume syncing.';
    } else if (result.needsAttentionCount > 0) {
      syncStatus.value = LedgerSyncStatus.needsAttention;
      message.value =
          '${result.needsAttentionCount} saved '
          '${result.needsAttentionCount == 1 ? 'change needs' : 'changes need'} '
          'your attention.';
    } else if (result.pendingCount > 0 || result.nextAttemptAt != null) {
      syncStatus.value = LedgerSyncStatus.waitingToRetry;
      message.value = result.pendingCount > 0
          ? '${result.pendingCount} saved '
                '${result.pendingCount == 1 ? 'change is' : 'changes are'} '
                'waiting to sync.'
          : 'Hisaab will try syncing again automatically.';
    } else {
      syncStatus.value = LedgerSyncStatus.idle;
      message.value = null;
    }

    if (result.failure?.isConnectionError ?? false) {
      isOffline.value = true;
    } else if (result.failure == null) {
      isOffline.value = false;
    }
    return result;
  }

  Future<SyncRunResult> retryPending({String? operationId}) async {
    await _repository.retryPending(operationId: operationId);
    await refreshSyncState();
    return syncNow();
  }

  Future<UndoPendingResult> undoPending(String operationId) async {
    final result = await _repository.undoPending(operationId);
    _refreshFromCache();
    await refreshSyncState();
    return result;
  }

  Future<DiscardNeedsAttentionResult> discardNeedsAttention(
    String operationId,
  ) async {
    final result = await _repository.discardNeedsAttention(operationId);
    _refreshFromCache();
    await refreshSyncState();
    return result;
  }

  Future<ReviseNeedsAttentionResult> reviseNeedsAttentionParty({
    required String operationId,
    required String name,
    required String phone,
    String shortName = '',
    String notes = '',
    String? groupId,
    bool confirmDuplicate = false,
  }) async {
    final result = await _repository.reviseNeedsAttentionParty(
      operationId: operationId,
      name: name,
      phone: phone,
      shortName: shortName,
      notes: notes,
      groupId: groupId,
      confirmDuplicate: confirmDuplicate,
    );
    await _finishNeedsAttentionRevision(result);
    return result;
  }

  Future<ReviseNeedsAttentionResult> reviseNeedsAttentionEntry({
    required String operationId,
    required EntryAction action,
    required int amountPaise,
    required String narration,
    required String entryDate,
    String? paymentAccount,
    bool setPaymentAccount = false,
  }) async {
    final result = await _repository.reviseNeedsAttentionEntry(
      operationId: operationId,
      action: action,
      amountPaise: amountPaise,
      narration: narration,
      entryDate: entryDate,
      paymentAccount: paymentAccount,
      setPaymentAccount: setPaymentAccount,
    );
    await _finishNeedsAttentionRevision(result);
    return result;
  }

  Future<void> _finishNeedsAttentionRevision(
    ReviseNeedsAttentionResult result,
  ) async {
    _refreshFromCache();
    await refreshSyncState();
    if (result == ReviseNeedsAttentionResult.revised) {
      _requestSync?.call();
    }
  }

  Future<void> refreshSyncState() async {
    final summary = await _repository.outboxSummary();
    pendingCount.value = summary.pendingCount;
    needsAttentionCount.value = summary.needsAttentionCount;
    nextSyncAttemptAt.value = summary.nextAttemptAt;
    final metadata = await _repository.syncMetadata();
    lastSyncedAt.value = metadata.lastSyncedAt;
    if (needsAttentionCount.value > 0) {
      syncStatus.value = LedgerSyncStatus.needsAttention;
    } else if (pendingCount.value > 0) {
      syncStatus.value = LedgerSyncStatus.waitingToRetry;
    } else if (syncStatus.value != LedgerSyncStatus.authenticationRequired) {
      syncStatus.value = LedgerSyncStatus.idle;
    }
  }

  Future<OptimisticMutationResult> _queueMutation(
    Future<OptimisticMutationResult> Function() operation,
  ) async {
    if (mutating.value) {
      throw const ApiFailure('Please wait for the current change to finish.');
    }
    mutating.value = true;
    try {
      final result = await operation();
      _acceptData(result.bootstrap);
      lastQueuedOperationId.value = result.operationId;
      await refreshSyncState();
      _requestSync?.call();
      return result;
    } finally {
      mutating.value = false;
    }
  }

  Future<void> _onlineMutation(Future<void> Function() operation) async {
    if (mutating.value) {
      throw const ApiFailure('Please wait for the current change to finish.');
    }
    mutating.value = true;
    try {
      await operation();
      _refreshFromCache();
      isOffline.value = false;
      message.value = null;
    } on ApiFailure catch (failure) {
      if (failure.isConnectionError) isOffline.value = true;
      rethrow;
    } finally {
      mutating.value = false;
    }
  }

  Future<T> _onlineValueMutation<T>(Future<T> Function() operation) async {
    if (mutating.value) {
      throw const ApiFailure('Please wait for the current change to finish.');
    }
    mutating.value = true;
    try {
      final result = await operation();
      _refreshFromCache();
      isOffline.value = false;
      message.value = null;
      return result;
    } on ApiFailure catch (failure) {
      if (failure.isConnectionError) isOffline.value = true;
      rethrow;
    } finally {
      mutating.value = false;
    }
  }

  void _refreshFromCache() {
    final cached = _repository.cachedBootstrap();
    _acceptData(cached);
  }

  void _acceptData(BootstrapData? value) {
    if (value == null) return;
    data.value = value;
    final language = value.user.language.toLowerCase().startsWith('hi')
        ? 'hi'
        : 'en';
    if (_appliedLanguage == language) return;
    _appliedLanguage = language;
    setFormattingLocale(language);
    if (Get.context != null) {
      Get.updateLocale(HisaabTranslations.localeFor(language));
    }
  }

  Party? partyById(String id) {
    for (final party in parties) {
      if (party.id == id) return party;
    }
    return null;
  }

  void clear() {
    data.value = null;
    isOffline.value = false;
    message.value = null;
    pendingCount.value = 0;
    needsAttentionCount.value = 0;
    lastSyncedAt.value = null;
    nextSyncAttemptAt.value = null;
    lastQueuedOperationId.value = null;
    syncStatus.value = LedgerSyncStatus.idle;
    _appliedLanguage = Get.locale?.languageCode;
  }
}

bool _isSyncCursor(String? value) {
  if (value == null || !RegExp(r'^\d{1,19}$').hasMatch(value)) return false;
  final parsed = BigInt.tryParse(value);
  return parsed != null &&
      parsed >= BigInt.zero &&
      parsed <= BigInt.parse('9223372036854775807');
}
