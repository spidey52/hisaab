// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/storage/app_storage.dart';
import '../../core/storage/local_database.dart';
import '../../core/storage/local_diagnostics.dart';
import '../models/models.dart';
import '../models/statement_models.dart';
import '../models/sync_models.dart';

class LedgerRepository {
  LedgerRepository(
    this._api,
    this._storage, {
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
    Random? random,
  }) : _uuid = uuid,
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  static const undoWindow = Duration(seconds: 8);

  final ApiClient _api;
  final AppStorage _storage;
  final Uuid _uuid;
  final DateTime Function() _now;
  final Random _random;
  final Map<String, _StableMutation> _stableMutations = {};

  Future<BootstrapData> bootstrap({StorageScopeLease? expectedLease}) async {
    if (expectedLease != null && !_storage.isCurrentLease(expectedLease)) {
      final cached = cachedBootstrap();
      if (cached != null) return cached;
      throw StateError('The active account changed during refresh.');
    }
    final queued = await outboxSummary();
    if (queued.pendingCount > 0 || queued.needsAttentionCount > 0) {
      final cached = cachedBootstrap();
      if (cached != null) return cached;
      throw StateError(
        'A full refresh is blocked until locally saved changes are resolved.',
      );
    }
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _api.get('/api/bootstrap');
      final json = _map(response.data);
      final data = BootstrapData.fromJson(json);
      if (expectedLease != null && !_storage.isCurrentLease(expectedLease)) {
        return data;
      }
      try {
        await _storage.cacheBootstrap(json);
      } on PendingOutboxConflict {
        final cached = cachedBootstrap();
        if (cached != null) return cached;
        rethrow;
      }
      await _storage.updateSyncMetadata(
        lastSyncedAt: _now().toUtc(),
        syncCursor: data.syncCursor,
        expectedLease: expectedLease,
      );
      await _record(
        DiagnosticEvent.bootstrap,
        DiagnosticStatus.succeeded,
        duration: stopwatch.elapsed,
        itemCount: data.parties.length + data.entries.length,
      );
      return data;
    } on ApiFailure catch (failure) {
      await _record(
        DiagnosticEvent.bootstrap,
        failure.isConnectionError
            ? DiagnosticStatus.offline
            : failure.isUnauthorized
            ? DiagnosticStatus.authenticationRequired
            : DiagnosticStatus.failed,
        duration: stopwatch.elapsed,
      );
      rethrow;
    }
  }

  BootstrapData? cachedBootstrap() {
    final json = _storage.readCachedBootstrap();
    return json == null ? null : BootstrapData.fromJson(json);
  }

  /// Immediate online create retained for callers that explicitly need it.
  ///
  /// Normal mobile flows should use [queuePartyCreation], which persists the
  /// identifiers and intent before attempting the network request.
  Future<void> createParty({
    required String name,
    required String phone,
    String shortName = '',
    String notes = '',
    String? groupId,
    bool confirmDuplicate = false,
    String? clientId,
    String? idempotencyKey,
  }) async {
    final lease = _storage.activeScopeLease;
    final response = await _api.post(
      '/api/parties',
      data: {
        'clientId': clientId ?? _uuid.v4(),
        'idempotencyKey': idempotencyKey ?? _uuid.v4(),
        'name': name,
        'phone': phone,
        'shortName': shortName,
        'notes': notes,
        'groupId': groupId,
        'confirmDuplicate': confirmDuplicate,
      },
    );
    await _applyCanonicalResponse(_map(response.data), expectedLease: lease);
  }

  Future<OptimisticMutationResult> queuePartyCreation({
    required String name,
    required String phone,
    String shortName = '',
    String notes = '',
    String? groupId,
    bool confirmDuplicate = false,
    String? idempotencyKey,
  }) async {
    final current = _requireBootstrap();
    if (idempotencyKey != null &&
        !Uuid.isValidUUID(fromString: idempotencyKey)) {
      throw const ApiFailure('This saved change has an invalid identifier.');
    }
    final operationId = idempotencyKey ?? _uuid.v4();
    final replay = await _replayQueuedParty(
      operationId: operationId,
      current: current,
      name: name,
      phone: phone,
      shortName: shortName,
      notes: notes,
      groupId: groupId,
      confirmDuplicate: confirmDuplicate,
    );
    if (replay != null) return replay;
    final clientId = _uuid.v4();
    final now = _now().toUtc();
    final groupName = current.groups
        .where((group) => group.id == groupId)
        .map((group) => group.name)
        .firstOrNull;
    final party = Party(
      id: clientId,
      reference: '',
      name: name.trim(),
      shortName: shortName.trim(),
      phone: phone.trim(),
      notes: notes.trim(),
      groupId: groupId,
      groupName: groupName,
      balancePaise: 0,
      transactionCount: 0,
      archivedAt: null,
      createdAt: now,
      updatedAt: now,
      localSyncStatus: LocalSyncStatus.pending,
      clientOperationId: operationId,
    );
    final payload = <String, dynamic>{
      'clientId': clientId,
      'idempotencyKey': operationId,
      'name': party.name,
      'phone': party.phone,
      'shortName': party.shortName,
      'notes': party.notes,
      'groupId': groupId,
      'confirmDuplicate': confirmDuplicate,
    };
    final updated = current.copyWith(parties: [party, ...current.parties]);
    await _storage.saveOptimisticMutation(
      bootstrap: updated.toJson(),
      operation: StoredOutboxDraft(
        id: operationId,
        kind: OutboxKind.createParty,
        payload: payload,
        notBefore: now.add(undoWindow),
      ),
      changedEntities: [_partyWrite(party)],
    );
    await _record(
      DiagnosticEvent.outboxEnqueue,
      DiagnosticStatus.succeeded,
      itemCount: 1,
    );
    return OptimisticMutationResult(
      operationId: operationId,
      entityId: clientId,
      bootstrap: updated,
      undoUntil: now.add(undoWindow),
    );
  }

  Future<void> updateParty({
    required String id,
    String? name,
    String? phone,
    String? shortName,
    String? notes,
    String? groupId,
    bool? archived,
    bool setGroupId = false,
    int? baseVersion,
    String? idempotencyKey,
  }) async {
    final lease = _storage.activeScopeLease;
    final intent = <String, dynamic>{
      'name': ?name,
      'phone': ?phone,
      'shortName': ?shortName,
      'notes': ?notes,
      if (setGroupId) 'groupId': groupId,
      'archived': ?archived,
      'baseVersion': ?baseVersion,
    };
    final operationScope = 'party.update:$id';
    final operationId = _stableOperationId(
      scope: operationScope,
      intent: intent,
      provided: idempotencyKey,
    );
    final response = await _api.patch(
      '/api/parties/$id',
      data: {...intent, 'idempotencyKey': operationId},
    );
    await _applyCanonicalResponse(_map(response.data), expectedLease: lease);
    _completeStableOperation(operationScope, operationId);
  }

  /// Immediate online create retained for tests and explicitly online flows.
  Future<void> createEntry({
    required String partyId,
    required EntryAction action,
    required int amountPaise,
    required String narration,
    required String entryDate,
    required String idempotencyKey,
    String? paymentAccount,
    String? clientId,
  }) async {
    _validateEntryAmount(amountPaise);
    final lease = _storage.activeScopeLease;
    final response = await _api.post(
      '/api/entries',
      data: {
        'clientId': clientId ?? _uuid.v4(),
        'partyId': partyId,
        'action': action == EntryAction.gave ? 'gave' : 'received',
        'amountPaise': amountPaise,
        'narration': narration,
        'entryDate': entryDate,
        'idempotencyKey': idempotencyKey,
        'paymentAccount': paymentAccount,
      },
    );
    await _applyCanonicalResponse(_map(response.data), expectedLease: lease);
  }

  Future<OptimisticMutationResult> queueEntryCreation({
    required String partyId,
    required EntryAction action,
    required int amountPaise,
    required String narration,
    required String entryDate,
    String? idempotencyKey,
    String? paymentAccount,
  }) async {
    _validateEntryAmount(amountPaise);
    if (action == EntryAction.openingBalance) {
      throw const ApiFailure(
        'Opening balances must be saved while connected.',
        isConnectionError: true,
      );
    }
    final current = _requireBootstrap();
    final partyIndex = current.parties.indexWhere(
      (party) => party.id == partyId,
    );
    if (partyIndex < 0 || current.parties[partyIndex].isArchived) {
      throw const ApiFailure('Choose an active customer or supplier.');
    }
    if (idempotencyKey != null &&
        !Uuid.isValidUUID(fromString: idempotencyKey)) {
      throw const ApiFailure('This saved change has an invalid identifier.');
    }
    final operationId = idempotencyKey ?? _uuid.v4();
    final replay = await _replayQueuedEntry(
      operationId: operationId,
      current: current,
      partyId: partyId,
      action: action,
      amountPaise: amountPaise,
      narration: narration,
      entryDate: entryDate,
      paymentAccount: paymentAccount,
    );
    if (replay != null) return replay;
    final clientId = _uuid.v4();
    final now = _now().toUtc();
    final party = current.parties[partyIndex];
    final balanceEffect = action == EntryAction.gave
        ? amountPaise
        : -amountPaise;
    final nextSequence = current.entries.fold<int>(
      0,
      (largest, entry) => max(largest, entry.sequence),
    );
    final entry = LedgerEntry(
      id: clientId,
      partyId: party.id,
      partyName: party.name,
      sequence: nextSequence + 1,
      action: action,
      amountPaise: amountPaise,
      balanceEffectPaise: balanceEffect,
      narration: narration.trim(),
      entryDate: DateTime.tryParse(entryDate) ?? now,
      paymentAccount: paymentAccount,
      status: EntryStatus.posted,
      createdByName: current.user.fullName,
      createdAt: now,
      editedAt: null,
      cancelledAt: null,
      revisionCount: 0,
      updatedAt: now,
      localSyncStatus: LocalSyncStatus.pending,
      clientOperationId: operationId,
    );
    final updatedParty = party.copyWith(
      balancePaise: party.balancePaise + balanceEffect,
      transactionCount: party.transactionCount + 1,
      updatedAt: now,
    );
    final parties = [...current.parties]..[partyIndex] = updatedParty;
    final updated = current.copyWith(
      parties: parties,
      entries: [entry, ...current.entries],
    );
    final payload = <String, dynamic>{
      'clientId': clientId,
      'partyId': party.id,
      'action': action == EntryAction.gave ? 'gave' : 'received',
      'amountPaise': amountPaise,
      'narration': entry.narration,
      'entryDate': entryDate,
      'idempotencyKey': operationId,
      'paymentAccount': paymentAccount,
    };
    await _storage.saveOptimisticMutation(
      bootstrap: updated.toJson(),
      operation: StoredOutboxDraft(
        id: operationId,
        kind: OutboxKind.createEntry,
        payload: payload,
        dependsOnOperationId: party.localSyncStatus == LocalSyncStatus.pending
            ? party.clientOperationId
            : null,
        notBefore: now.add(undoWindow),
      ),
      changedEntities: [_entryWrite(entry), _partyWrite(updatedParty)],
    );
    await _record(
      DiagnosticEvent.outboxEnqueue,
      DiagnosticStatus.succeeded,
      itemCount: 1,
    );
    return OptimisticMutationResult(
      operationId: operationId,
      entityId: clientId,
      bootstrap: updated,
      undoUntil: now.add(undoWindow),
    );
  }

  Future<void> cancelEntry(
    String id, {
    int? baseVersion,
    String? idempotencyKey,
  }) async {
    final lease = _storage.activeScopeLease;
    final intent = <String, dynamic>{
      'operation': 'cancel',
      'baseVersion': ?baseVersion,
    };
    final operationScope = 'entry.cancel:$id';
    final operationId = _stableOperationId(
      scope: operationScope,
      intent: intent,
      provided: idempotencyKey,
    );
    final response = await _api.patch(
      '/api/entries/$id',
      data: {...intent, 'idempotencyKey': operationId},
    );
    await _applyCanonicalResponse(_map(response.data), expectedLease: lease);
    _completeStableOperation(operationScope, operationId);
  }

  Future<void> updateEntry({
    required String id,
    required String partyId,
    required EntryAction action,
    required int amountPaise,
    required String narration,
    required String entryDate,
    String? paymentAccount,
    int? baseVersion,
    String? idempotencyKey,
  }) async {
    final lease = _storage.activeScopeLease;
    final intent = <String, dynamic>{
      'operation': 'edit',
      'partyId': partyId,
      'action': action == EntryAction.gave ? 'gave' : 'received',
      'amountPaise': amountPaise,
      'narration': narration,
      'entryDate': entryDate,
      'paymentAccount': paymentAccount,
      'baseVersion': ?baseVersion,
    };
    final operationScope = 'entry.edit:$id';
    final operationId = _stableOperationId(
      scope: operationScope,
      intent: intent,
      provided: idempotencyKey,
    );
    final response = await _api.patch(
      '/api/entries/$id',
      data: {...intent, 'idempotencyKey': operationId},
    );
    await _applyCanonicalResponse(_map(response.data), expectedLease: lease);
    _completeStableOperation(operationScope, operationId);
  }

  Future<void> saveOpeningBalance({
    required String partyId,
    required int amountPaise,
    required String direction,
    required String entryDate,
    required String idempotencyKey,
    int? baseVersion,
    String? clientId,
  }) async {
    final lease = _storage.activeScopeLease;
    final stableClientId =
        clientId ??
        _uuid.v5(
          '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
          'hisaab-opening:$idempotencyKey',
        );
    final response = await _api.post(
      '/api/opening-balance',
      data: {
        'clientId': stableClientId,
        'partyId': partyId,
        'amountPaise': amountPaise,
        'direction': direction,
        'entryDate': entryDate,
        'idempotencyKey': idempotencyKey,
        'baseVersion': ?baseVersion,
      },
    );
    await _applyCanonicalResponse(_map(response.data), expectedLease: lease);
  }

  Future<void> updateSettings({
    String? companyName,
    String? timezone,
    String? language,
    bool? accessibilityMode,
    bool? contactDiscoverable,
    String? idempotencyKey,
  }) async {
    final lease = _storage.activeScopeLease;
    final current = cachedBootstrap();
    final updatesCompany = companyName != null || timezone != null;
    final updatesUser =
        language != null ||
        accessibilityMode != null ||
        contactDiscoverable != null;
    final intent = <String, dynamic>{
      'companyName': ?companyName,
      'timezone': ?timezone,
      'language': ?language,
      'accessibilityMode': ?accessibilityMode,
      'contactDiscoverable': ?contactDiscoverable,
      if (updatesCompany) 'baseCompanyVersion': ?current?.company.version,
      if (updatesUser) 'baseUserVersion': ?current?.user.version,
    };
    const operationScope = 'settings.update';
    final operationId = _stableOperationId(
      scope: operationScope,
      intent: intent,
      provided: idempotencyKey,
    );
    final response = await _api.patch(
      '/api/settings',
      data: {...intent, 'idempotencyKey': operationId},
    );
    await _applySettingsResponse(_map(response.data), expectedLease: lease);
    _completeStableOperation(operationScope, operationId);
  }

  Future<PartyGroup> createGroup(
    String name, {
    String? clientId,
    String? idempotencyKey,
  }) async {
    final lease = _storage.activeScopeLease;
    final intent = <String, dynamic>{'name': name.trim()};
    const operationScope = 'group.create';
    final operationId = _stableOperationId(
      scope: operationScope,
      intent: intent,
      provided: idempotencyKey,
    );
    final stableClientId =
        clientId ??
        _uuid.v5(
          '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
          'hisaab-group:$operationId',
        );
    final response = await _api.post(
      '/api/groups',
      data: {
        'name': name,
        'clientId': stableClientId,
        'idempotencyKey': operationId,
      },
    );
    final json = _map(response.data);
    final group = PartyGroup.fromJson(
      _map(json['group']).isEmpty ? json : _map(json['group']),
    );
    final current = cachedBootstrap();
    if (current != null) {
      final updated = current.copyWith(groups: [group, ...current.groups]);
      await _storage.saveCanonicalUpdate(
        bootstrap: updated.toJson(),
        changedEntities: [_groupWrite(group)],
        expectedLease: lease,
      );
    }
    if (lease == null || _storage.isCurrentLease(lease)) {
      _completeStableOperation(operationScope, operationId);
    }
    return group;
  }

  Future<void> mergeParties({
    required Party source,
    required Party target,
    String? idempotencyKey,
  }) async {
    final lease = _storage.activeScopeLease;
    final intent = <String, dynamic>{
      'sourcePartyId': source.id,
      'targetPartyId': target.id,
      'baseSourceVersion': ?source.version,
      'baseTargetVersion': ?target.version,
    };
    const operationScope = 'party.merge';
    final operationId = _stableOperationId(
      scope: operationScope,
      intent: intent,
      provided: idempotencyKey,
    );
    await _api.post(
      '/api/parties/merge',
      data: {...intent, 'idempotencyKey': operationId},
    );
    // A merge can rewrite an arbitrary number of entry party references.
    // Pulling the server snapshot is the safest bounded online-only refresh.
    await bootstrap(expectedLease: lease);
    if (lease == null || _storage.isCurrentLease(lease)) {
      _completeStableOperation(operationScope, operationId);
    }
  }

  Future<void> deleteAccount() async {
    await _api.delete(
      '/api/account',
      data: const {'confirmation': 'DELETE MY ACCOUNT'},
    );
    await _storage.clearAll();
  }

  Future<ExportedLedgerFile> exportLedger({
    LedgerExportFormat format = LedgerExportFormat.json,
  }) async {
    final queued = await outboxSummary();
    if (queued.pendingCount > 0 || queued.needsAttentionCount > 0) {
      throw const ApiFailure(
        'Sync or resolve saved changes before exporting a complete server copy.',
      );
    }
    final response = await _api.get(
      '/api/export',
      queryParameters: {'format': format.name},
    );
    final bytes = switch (response.data) {
      Uint8List value => value,
      List<int> value => Uint8List.fromList(value),
      String value => Uint8List.fromList(utf8.encode(value)),
      Object? value => Uint8List.fromList(utf8.encode(jsonEncode(value))),
    };
    final disposition = response.headers.value('content-disposition') ?? '';
    final filename =
        RegExp(r'filename="([^"]+)"').firstMatch(disposition)?.group(1) ??
        'hisaab-export.${format.name}';
    return ExportedLedgerFile(
      filename: filename,
      bytes: bytes,
      mimeType:
          response.headers.value('content-type') ??
          (format == LedgerExportFormat.csv
              ? 'text/csv; charset=utf-8'
              : 'application/json; charset=utf-8'),
    );
  }

  Future<Set<String>> discoverRegisteredContacts(
    Iterable<String> phones,
  ) async {
    final unique = phones
        .map((phone) => phone.trim())
        .where((phone) => phone.isNotEmpty)
        .toSet()
        .take(500)
        .toList(growable: false);
    if (unique.isEmpty) return const {};
    final response = await _api.post(
      '/api/contact-discovery',
      data: {'phones': unique},
    );
    final matches = _map(response.data)['matches'];
    return matches is List
        ? matches.map((value) => value.toString()).toSet()
        : const {};
  }

  Future<PartyStatementPage> fetchPartyStatement({
    required String partyId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    String? cursor,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _api.get(
        '/api/parties/$partyId/statement',
        queryParameters: {
          'from': ?_dateOnly(from),
          'to': ?_dateOnly(to),
          'limit': limit.clamp(1, 200),
          'cursor': ?cursor,
        },
      );
      final page = PartyStatementPage.fromJson(_map(response.data));
      await _record(
        DiagnosticEvent.statementFetch,
        DiagnosticStatus.succeeded,
        duration: stopwatch.elapsed,
        itemCount: page.entries.length,
      );
      return page;
    } on ApiFailure catch (failure) {
      await _record(
        DiagnosticEvent.statementFetch,
        failure.isConnectionError
            ? DiagnosticStatus.offline
            : failure.isUnauthorized
            ? DiagnosticStatus.authenticationRequired
            : DiagnosticStatus.failed,
        duration: stopwatch.elapsed,
      );
      rethrow;
    }
  }

  Future<OutboxSummary> outboxSummary() async {
    final rows = await _storage.readOutbox();
    return OutboxSummary(
      pendingCount: rows
          .where(
            (row) =>
                row.state == OutboxState.pending ||
                row.state == OutboxState.syncing,
          )
          .length,
      needsAttentionCount: rows
          .where((row) => row.state == OutboxState.needsAttention)
          .length,
      nextAttemptAt: rows
          .where((row) => row.state == OutboxState.pending)
          .map((row) => row.nextAttemptAt)
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            (earliest, value) =>
                earliest == null || value.isBefore(earliest) ? value : earliest,
          ),
    );
  }

  Future<LocalSyncMetadata> syncMetadata() => _storage.readSyncMetadata();

  Future<OptimisticMutationResult?> _replayQueuedParty({
    required String operationId,
    required BootstrapData current,
    required String name,
    required String phone,
    required String shortName,
    required String notes,
    required String? groupId,
    required bool confirmDuplicate,
  }) async {
    final existing = await _storage.readOutboxOperation(operationId);
    if (existing == null) return null;
    final payload = existing.payload;
    final matches =
        existing.kind == OutboxKind.createParty &&
        payload['name'] == name.trim() &&
        payload['phone'] == phone.trim() &&
        payload['shortName'] == shortName.trim() &&
        payload['notes'] == notes.trim() &&
        payload['groupId'] == groupId &&
        payload['confirmDuplicate'] == confirmDuplicate;
    if (!matches) throw _localIdempotencyConflict();
    final entityId = payload['clientId']?.toString() ?? '';
    final party = current.parties
        .where((candidate) => candidate.id == entityId)
        .firstOrNull;
    if (party == null) {
      throw StateError('The queued party snapshot is incomplete.');
    }
    return OptimisticMutationResult(
      operationId: operationId,
      entityId: entityId,
      bootstrap: current,
      undoUntil: existing.createdAt.add(undoWindow),
    );
  }

  Future<OptimisticMutationResult?> _replayQueuedEntry({
    required String operationId,
    required BootstrapData current,
    required String partyId,
    required EntryAction action,
    required int amountPaise,
    required String narration,
    required String entryDate,
    required String? paymentAccount,
  }) async {
    final existing = await _storage.readOutboxOperation(operationId);
    if (existing == null) return null;
    final payload = existing.payload;
    final matches =
        existing.kind == OutboxKind.createEntry &&
        payload['partyId'] == partyId &&
        payload['action'] ==
            (action == EntryAction.gave ? 'gave' : 'received') &&
        payload['amountPaise'] == amountPaise &&
        payload['narration'] == narration.trim() &&
        payload['entryDate'] == entryDate &&
        payload['paymentAccount'] == paymentAccount;
    if (!matches) throw _localIdempotencyConflict();
    final entityId = payload['clientId']?.toString() ?? '';
    final entry = current.entries
        .where((candidate) => candidate.id == entityId)
        .firstOrNull;
    if (entry == null) {
      throw StateError('The queued entry snapshot is incomplete.');
    }
    return OptimisticMutationResult(
      operationId: operationId,
      entityId: entityId,
      bootstrap: current,
      undoUntil: existing.createdAt.add(undoWindow),
    );
  }

  Future<void> retryPending({String? operationId}) async {
    final operations = await _storage.readOutbox(
      states: const {OutboxState.needsAttention},
    );
    for (final operation in operations) {
      if (operationId == null || operation.id == operationId) {
        await _storage.markOutboxPending(operation.id);
      }
    }
  }

  Future<UndoPendingResult> undoPending(String operationId) async {
    final operations = await _storage.readOutbox();
    final operation = operations
        .where((candidate) => candidate.id == operationId)
        .firstOrNull;
    if (operation == null) return UndoPendingResult.notFound;
    if (operation.state != OutboxState.pending) {
      return UndoPendingResult.alreadyUploading;
    }
    if (operations.any(
      (candidate) => candidate.dependsOnOperationId == operationId,
    )) {
      return UndoPendingResult.hasDependentChanges;
    }
    final current = _requireBootstrap();
    final entityId = operation.payload['clientId']?.toString() ?? '';
    if (entityId.isEmpty) return UndoPendingResult.notFound;

    late BootstrapData updated;
    final changedEntities = <EntityCacheWrite>[];
    switch (operation.kind) {
      case OutboxKind.createParty:
        updated = current.copyWith(
          parties: current.parties
              .where((party) => party.id != entityId)
              .toList(growable: false),
        );
      case OutboxKind.createEntry:
        final entry = current.entries
            .where((candidate) => candidate.id == entityId)
            .firstOrNull;
        if (entry == null) return UndoPendingResult.notFound;
        final parties = [...current.parties];
        final partyIndex = parties.indexWhere(
          (party) => party.id == entry.partyId,
        );
        if (partyIndex >= 0) {
          final party = parties[partyIndex];
          final reverted = party.copyWith(
            balancePaise: party.balancePaise - entry.balanceEffectPaise,
            transactionCount: max(0, party.transactionCount - 1),
          );
          parties[partyIndex] = reverted;
          changedEntities.add(_partyWrite(reverted));
        }
        updated = current.copyWith(
          parties: parties,
          entries: current.entries
              .where((candidate) => candidate.id != entityId)
              .toList(growable: false),
        );
    }
    final undone = await _storage.undoPendingOutbox(
      id: operation.id,
      bootstrap: updated.toJson(),
      optimisticEntityType: operation.kind == OutboxKind.createParty
          ? 'party'
          : 'entry',
      optimisticEntityId: entityId,
      changedEntities: changedEntities,
    );
    return undone
        ? UndoPendingResult.undone
        : UndoPendingResult.alreadyUploading;
  }

  Future<DiscardNeedsAttentionResult> discardNeedsAttention(
    String operationId,
  ) async {
    final operations = await _storage.readOutbox();
    final operation = operations
        .where((candidate) => candidate.id == operationId)
        .firstOrNull;
    if (operation == null) return DiscardNeedsAttentionResult.notFound;
    if (operation.state != OutboxState.needsAttention) {
      return DiscardNeedsAttentionResult.wrongState;
    }
    if (operations.any(
      (candidate) => candidate.dependsOnOperationId == operationId,
    )) {
      return DiscardNeedsAttentionResult.hasDependentChanges;
    }
    final current = _requireBootstrap();
    final entityId = operation.payload['clientId']?.toString() ?? '';
    if (entityId.isEmpty) return DiscardNeedsAttentionResult.notFound;

    late BootstrapData updated;
    final changedEntities = <EntityCacheWrite>[];
    switch (operation.kind) {
      case OutboxKind.createParty:
        updated = current.copyWith(
          parties: current.parties
              .where((party) => party.id != entityId)
              .toList(growable: false),
        );
      case OutboxKind.createEntry:
        final entry = current.entries
            .where((candidate) => candidate.id == entityId)
            .firstOrNull;
        if (entry == null) return DiscardNeedsAttentionResult.notFound;
        final parties = [...current.parties];
        final partyIndex = parties.indexWhere(
          (party) => party.id == entry.partyId,
        );
        if (partyIndex >= 0) {
          final party = parties[partyIndex];
          final reverted = party.copyWith(
            balancePaise: party.balancePaise - entry.balanceEffectPaise,
            transactionCount: max(0, party.transactionCount - 1),
          );
          parties[partyIndex] = reverted;
          changedEntities.add(_partyWrite(reverted));
        }
        updated = current.copyWith(
          parties: parties,
          entries: current.entries
              .where((candidate) => candidate.id != entityId)
              .toList(growable: false),
        );
    }
    final discarded = await _storage.discardNeedsAttentionOutbox(
      id: operation.id,
      bootstrap: updated.toJson(),
      optimisticEntityType: operation.kind == OutboxKind.createParty
          ? 'party'
          : 'entry',
      optimisticEntityId: entityId,
      changedEntities: changedEntities,
    );
    return discarded
        ? DiscardNeedsAttentionResult.discarded
        : DiscardNeedsAttentionResult.wrongState;
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
    final operation = await _storage.readOutboxOperation(operationId);
    if (operation == null) return ReviseNeedsAttentionResult.notFound;
    if (operation.state != OutboxState.needsAttention) {
      return ReviseNeedsAttentionResult.wrongState;
    }
    if (operation.kind != OutboxKind.createParty) {
      return ReviseNeedsAttentionResult.kindMismatch;
    }

    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw const ApiFailure('Enter a name with at least 2 characters.');
    }
    final current = _requireBootstrap();
    final entityId = operation.payload['clientId']?.toString() ?? '';
    final partyIndex = current.parties.indexWhere(
      (party) => party.id == entityId,
    );
    if (entityId.isEmpty || partyIndex < 0) {
      return ReviseNeedsAttentionResult.notFound;
    }
    final groupName = current.groups
        .where((group) => group.id == groupId)
        .map((group) => group.name)
        .firstOrNull;
    if (groupId != null && groupName == null) {
      throw const ApiFailure('Choose a valid party group.');
    }

    final existing = current.parties[partyIndex];
    final now = _now().toUtc();
    final revisedParty = Party(
      id: existing.id,
      reference: existing.reference,
      name: cleanName,
      shortName: shortName.trim(),
      phone: phone.trim(),
      phoneE164: phone.trim() == existing.phone ? existing.phoneE164 : null,
      notes: notes.trim(),
      groupId: groupId,
      groupName: groupName,
      balancePaise: existing.balancePaise,
      transactionCount: existing.transactionCount,
      archivedAt: existing.archivedAt,
      createdAt: existing.createdAt,
      version: existing.version,
      updatedAt: now,
      localSyncStatus: LocalSyncStatus.pending,
      clientOperationId: operation.id,
    );
    final parties = [...current.parties]..[partyIndex] = revisedParty;
    final changedEntities = <EntityCacheWrite>[_partyWrite(revisedParty)];
    final entries = current.entries
        .map((entry) {
          if (entry.partyId != entityId || entry.partyName == cleanName) {
            return entry;
          }
          final revisedEntry = entry.copyWith(
            partyName: cleanName,
            updatedAt: now,
          );
          changedEntities.add(_entryWrite(revisedEntry));
          return revisedEntry;
        })
        .toList(growable: false);
    final updated = current.copyWith(parties: parties, entries: entries);
    final payload = Map<String, dynamic>.from(operation.payload)
      ..['name'] = revisedParty.name
      ..['phone'] = revisedParty.phone
      ..['shortName'] = revisedParty.shortName
      ..['notes'] = revisedParty.notes
      ..['groupId'] = groupId
      ..['confirmDuplicate'] = confirmDuplicate;
    final revised = await _storage.reviseNeedsAttentionOutbox(
      operation: operation,
      bootstrap: updated.toJson(),
      payload: payload,
      changedEntities: changedEntities,
    );
    return revised
        ? ReviseNeedsAttentionResult.revised
        : ReviseNeedsAttentionResult.wrongState;
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
    _validateEntryAmount(amountPaise);
    if (action == EntryAction.openingBalance) {
      throw const ApiFailure('Choose whether you gave or got money.');
    }
    final parsedEntryDate = _parseDateOnly(entryDate);
    if (parsedEntryDate == null) {
      throw const ApiFailure('Choose a valid date.');
    }
    if (setPaymentAccount &&
        paymentAccount != null &&
        paymentAccount != 'cash' &&
        paymentAccount != 'bank') {
      throw const ApiFailure('Choose Cash or Bank.');
    }

    final operation = await _storage.readOutboxOperation(operationId);
    if (operation == null) return ReviseNeedsAttentionResult.notFound;
    if (operation.state != OutboxState.needsAttention) {
      return ReviseNeedsAttentionResult.wrongState;
    }
    if (operation.kind != OutboxKind.createEntry) {
      return ReviseNeedsAttentionResult.kindMismatch;
    }
    final current = _requireBootstrap();
    final entityId = operation.payload['clientId']?.toString() ?? '';
    final entryIndex = current.entries.indexWhere(
      (entry) => entry.id == entityId,
    );
    if (entityId.isEmpty || entryIndex < 0) {
      return ReviseNeedsAttentionResult.notFound;
    }
    final existing = current.entries[entryIndex];
    final partyIndex = current.parties.indexWhere(
      (party) => party.id == existing.partyId,
    );
    if (partyIndex < 0) return ReviseNeedsAttentionResult.notFound;

    final balanceEffect = action == EntryAction.gave
        ? amountPaise
        : -amountPaise;
    final now = _now().toUtc();
    final revisedEntry = existing.copyWith(
      action: action,
      amountPaise: amountPaise,
      balanceEffectPaise: balanceEffect,
      narration: narration.trim(),
      entryDate: parsedEntryDate,
      paymentAccount: setPaymentAccount ? paymentAccount : null,
      clearPaymentAccount: setPaymentAccount && paymentAccount == null,
      updatedAt: now,
      localSyncStatus: LocalSyncStatus.pending,
      clientOperationId: operation.id,
    );
    final entries = [...current.entries]..[entryIndex] = revisedEntry;
    final existingParty = current.parties[partyIndex];
    final revisedParty = existingParty.copyWith(
      balancePaise:
          existingParty.balancePaise -
          existing.balanceEffectPaise +
          balanceEffect,
      updatedAt: now,
    );
    final parties = [...current.parties]..[partyIndex] = revisedParty;
    final updated = current.copyWith(parties: parties, entries: entries);
    final payload = Map<String, dynamic>.from(operation.payload)
      ..['action'] = action == EntryAction.gave ? 'gave' : 'received'
      ..['amountPaise'] = amountPaise
      ..['narration'] = revisedEntry.narration
      ..['entryDate'] = _dateOnly(parsedEntryDate);
    if (setPaymentAccount) payload['paymentAccount'] = paymentAccount;
    final revised = await _storage.reviseNeedsAttentionOutbox(
      operation: operation,
      bootstrap: updated.toJson(),
      payload: payload,
      changedEntities: [_entryWrite(revisedEntry), _partyWrite(revisedParty)],
    );
    return revised
        ? ReviseNeedsAttentionResult.revised
        : ReviseNeedsAttentionResult.wrongState;
  }

  /// Flushes the persisted outbox, then incrementally pulls remote changes.
  ///
  /// The caller must serialize invocations. [SyncCoordinator] and
  /// [LedgerController] both enforce that at their respective boundaries.
  Future<SyncRunResult> syncPending({bool pullRemoteChanges = true}) async {
    final lease = _storage.activeScopeLease;
    if (lease == null) return const SyncRunResult.inactive();
    final stopwatch = Stopwatch()..start();
    var uploaded = 0;
    var pulled = 0;
    DateTime? nextAttemptAt;
    var authenticationRequired = false;
    var retryBlocked = false;
    ApiFailure? lastFailure;

    var operations = await _storage.readOutbox();
    operations = [...operations]
      ..sort((left, right) {
        if (left.dependsOnOperationId == right.id) return 1;
        if (right.dependsOnOperationId == left.id) return -1;
        return left.createdAt.compareTo(right.createdAt);
      });
    final unresolved = {
      for (final operation in operations) operation.id: operation,
    };
    for (final operation in operations) {
      if (!_storage.isCurrentLease(lease)) {
        return const SyncRunResult.inactive();
      }
      if (operation.state != OutboxState.pending) continue;
      final now = _now().toUtc();
      if (operation.nextAttemptAt?.isAfter(now) ?? false) {
        nextAttemptAt = _earlier(nextAttemptAt, operation.nextAttemptAt);
        continue;
      }
      final dependencyId = operation.dependsOnOperationId;
      if (dependencyId != null && unresolved.containsKey(dependencyId)) {
        continue;
      }

      await _storage.markOutboxSyncing(operation);
      final operationStopwatch = Stopwatch()..start();
      try {
        final response = switch (operation.kind) {
          OutboxKind.createParty => await _api.post(
            '/api/parties',
            data: operation.payload,
          ),
          OutboxKind.createEntry => await _api.post(
            '/api/entries',
            data: operation.payload,
          ),
        };
        if (!_storage.isCurrentLease(lease)) {
          await _storage.markOutboxOperationPending(operation);
          return const SyncRunResult.inactive();
        }
        final canonical = _map(response.data);
        final update = _reconcileOutboxSuccess(
          operation,
          canonical,
          outstandingOperations: unresolved.values,
        );
        final completed = await _storage.completeOutbox(
          operation: operation,
          lease: lease,
          bootstrap: update.bootstrap.toJson(),
          changedEntities: update.changedEntities,
        );
        if (!completed) {
          await _storage.markOutboxOperationPending(operation);
          return const SyncRunResult.inactive();
        }
        unresolved.remove(operation.id);
        uploaded += 1;
        await _record(
          DiagnosticEvent.syncOperation,
          DiagnosticStatus.succeeded,
          duration: operationStopwatch.elapsed,
          itemCount: 1,
        );
      } on ApiFailure catch (failure) {
        if (!_storage.isCurrentLease(lease)) {
          await _storage.markOutboxOperationPending(operation);
          return const SyncRunResult.inactive();
        }
        lastFailure = failure;
        final attempts = operation.attempts + 1;
        if (failure.isUnauthorized) {
          authenticationRequired = true;
          await _storage.markOutboxOperationPending(operation);
          await _record(
            DiagnosticEvent.syncOperation,
            DiagnosticStatus.authenticationRequired,
            duration: operationStopwatch.elapsed,
          );
          break;
        }
        if (failure.needsUserAttention) {
          await _markOperationNeedsAttention(
            operation,
            failure,
            attempts: attempts,
          );
          await _record(
            DiagnosticEvent.syncOperation,
            DiagnosticStatus.needsAttention,
            duration: operationStopwatch.elapsed,
          );
          continue;
        }
        final delay = failure.retryAfter ?? _retryDelay(attempts);
        final retryAt = now.add(delay);
        nextAttemptAt = _earlier(nextAttemptAt, retryAt);
        await _storage.markOutboxFailure(
          operation: operation,
          needsAttention: false,
          attempts: attempts,
          statusCode: failure.statusCode,
          errorCode: failure.code,
          errorCategory: failure.diagnosticCategory,
          nextAttemptAt: retryAt,
        );
        await _record(
          DiagnosticEvent.syncOperation,
          DiagnosticStatus.retryScheduled,
          duration: operationStopwatch.elapsed,
        );
        retryBlocked = true;
        // A connection/server failure is likely shared by every request. Avoid
        // a burst while retaining all remaining operations for the next run.
        break;
      }
    }

    final remainingBeforePull = await outboxSummary();
    nextAttemptAt = _earlier(nextAttemptAt, remainingBeforePull.nextAttemptAt);
    final outboxDrained =
        remainingBeforePull.pendingCount == 0 &&
        remainingBeforePull.needsAttentionCount == 0;
    final checkpoint = (await _storage.readSyncMetadata()).syncCursor;
    if (!authenticationRequired &&
        !retryBlocked &&
        outboxDrained &&
        pullRemoteChanges) {
      try {
        if (_isSyncCursor(checkpoint)) {
          pulled = await _pullChanges(lease);
        } else {
          // Pre-Drift caches have no contiguous checkpoint. Once their outbox
          // is drained, replace them with one checkpoint-safe full bootstrap
          // rather than pretending a pull from zero is complete.
          await bootstrap(expectedLease: lease);
        }
      } on ApiFailure catch (failure) {
        lastFailure = failure;
        if (failure.isUnauthorized) {
          authenticationRequired = true;
        } else {
          final retryAt = _now().toUtc().add(
            failure.retryAfter ?? _retryDelay(1),
          );
          nextAttemptAt = _earlier(nextAttemptAt, retryAt);
        }
      }
    }

    final metadata = await _storage.readSyncMetadata();
    final summary = await outboxSummary();
    nextAttemptAt = _earlier(nextAttemptAt, summary.nextAttemptAt);
    final result = SyncRunResult(
      uploadedCount: uploaded,
      pulledCount: pulled,
      pendingCount: summary.pendingCount,
      needsAttentionCount: summary.needsAttentionCount,
      authenticationRequired: authenticationRequired,
      nextAttemptAt: nextAttemptAt,
      lastSyncedAt: metadata.lastSyncedAt,
      failure: lastFailure,
      bootstrap: cachedBootstrap(),
    );
    await _record(
      DiagnosticEvent.syncRun,
      authenticationRequired
          ? DiagnosticStatus.authenticationRequired
          : lastFailure == null
          ? DiagnosticStatus.succeeded
          : nextAttemptAt != null
          ? DiagnosticStatus.retryScheduled
          : DiagnosticStatus.failed,
      duration: stopwatch.elapsed,
      itemCount: uploaded + pulled,
    );
    return result;
  }

  Future<int> _pullChanges(StorageScopeLease lease) async {
    final metadata = await _storage.readSyncMetadata();
    final checkpoint = metadata.syncCursor;
    if (!_isSyncCursor(checkpoint)) {
      throw StateError(
        'Incremental sync requires a checkpoint from a full bootstrap.',
      );
    }
    var cursor = checkpoint!;
    var pulled = 0;
    var hasMore = true;
    while (hasMore) {
      final response = await _api.get(
        '/api/sync/pull',
        queryParameters: {'cursor': cursor, 'limit': 500},
      );
      if (!_storage.isCurrentLease(lease)) return pulled;
      final page = SyncPullPage.fromJson(_map(response.data));
      final current = _requireBootstrap();
      final outstanding = await _storage.readOutbox();
      final pendingIds = _pendingEntityIds(outstanding);
      final applied = _applySyncChanges(
        current,
        page.changes,
        pendingIds,
        outstanding,
      );
      cursor = page.nextCursor ?? cursor;
      final updated = applied.bootstrap.copyWith(syncCursor: cursor);
      final saved = await _storage.saveCanonicalUpdate(
        bootstrap: updated.toJson(),
        changedEntities: applied.changedEntities,
        expectedLease: lease,
      );
      if (!saved) return pulled;
      await _storage.updateSyncMetadata(
        lastSyncedAt: _now().toUtc(),
        syncCursor: cursor,
        expectedLease: lease,
      );
      pulled += page.changes.length;
      hasMore = page.hasMore;
      if (page.changes.isEmpty) break;
    }
    return pulled;
  }

  Set<String> _pendingEntityIds(Iterable<StoredOutboxOperation> operations) {
    final ids = <String>{};
    for (final operation in operations) {
      final clientId = operation.payload['clientId']?.toString() ?? '';
      if (clientId.isNotEmpty) ids.add(clientId);
    }
    return ids;
  }

  _CanonicalUpdate _reconcileOutboxSuccess(
    StoredOutboxOperation operation,
    Map<String, dynamic> response, {
    required Iterable<StoredOutboxOperation> outstandingOperations,
  }) {
    final current = _requireBootstrap();
    final changed = <EntityCacheWrite>[];
    var updated = current;
    switch (operation.kind) {
      case OutboxKind.createParty:
        final rawParty = _map(response['party']);
        final localId = operation.payload['clientId']?.toString() ?? '';
        final local = current.parties
            .where((party) => party.id == localId)
            .firstOrNull;
        final canonical = rawParty.isNotEmpty
            ? Party.fromJson(rawParty)
            : local?.copyWith(
                reference: response['reference']?.toString() ?? local.reference,
                localSyncStatus: LocalSyncStatus.synced,
                clearClientOperationId: true,
              );
        if (canonical != null) {
          final synced = _overlayPendingEntries(
            canonical.copyWith(
              localSyncStatus: LocalSyncStatus.synced,
              clearClientOperationId: true,
            ),
            outstandingOperations.where(
              (candidate) => candidate.id != operation.id,
            ),
          );
          updated = updated.copyWith(
            parties: _replaceById(updated.parties, synced, (item) => item.id),
          );
          changed.add(_partyWrite(synced));
        }
      case OutboxKind.createEntry:
        final rawEntry = _map(response['entry']);
        final rawParty = _map(response['party']);
        final localId = operation.payload['clientId']?.toString() ?? '';
        final local = current.entries
            .where((entry) => entry.id == localId)
            .firstOrNull;
        final canonicalEntry = rawEntry.isNotEmpty
            ? _preserveEntryTimestamps(
                current.entries,
                LedgerEntry.fromJson(rawEntry),
                localClientId: localId,
              )
            : local?.copyWith(
                sequence: _integer(response['sequence']) ?? local.sequence,
                localSyncStatus: LocalSyncStatus.synced,
                clearClientOperationId: true,
              );
        if (canonicalEntry != null) {
          final synced = canonicalEntry.copyWith(
            localSyncStatus: LocalSyncStatus.synced,
            clearClientOperationId: true,
          );
          updated = updated.copyWith(
            entries: _replaceById(updated.entries, synced, (item) => item.id),
          );
          changed.add(_entryWrite(synced));
        }
        if (rawParty.isNotEmpty) {
          final party = _overlayPendingEntries(
            Party.fromJson(rawParty),
            outstandingOperations.where(
              (candidate) => candidate.id != operation.id,
            ),
          );
          updated = updated.copyWith(
            parties: _replaceById(updated.parties, party, (item) => item.id),
          );
          changed.add(_partyWrite(party));
        }
    }
    return _CanonicalUpdate(updated, changed);
  }

  Future<void> _markOperationNeedsAttention(
    StoredOutboxOperation operation,
    ApiFailure failure, {
    required int attempts,
  }) async {
    final current = _requireBootstrap();
    final entityId = operation.payload['clientId']?.toString() ?? '';
    final changed = <EntityCacheWrite>[];
    var updated = current;
    if (operation.kind == OutboxKind.createParty) {
      final parties = current.parties
          .map((party) {
            if (party.id != entityId) return party;
            final next = party.copyWith(
              localSyncStatus: LocalSyncStatus.needsAttention,
            );
            changed.add(_partyWrite(next));
            return next;
          })
          .toList(growable: false);
      updated = current.copyWith(parties: parties);
    } else {
      final entries = current.entries
          .map((entry) {
            if (entry.id != entityId) return entry;
            final next = entry.copyWith(
              localSyncStatus: LocalSyncStatus.needsAttention,
            );
            changed.add(_entryWrite(next));
            return next;
          })
          .toList(growable: false);
      updated = current.copyWith(entries: entries);
    }
    if (changed.isNotEmpty) {
      await _storage.saveCanonicalUpdate(
        bootstrap: updated.toJson(),
        changedEntities: changed,
      );
    }
    await _storage.markOutboxFailure(
      operation: operation,
      needsAttention: true,
      attempts: attempts,
      statusCode: failure.statusCode,
      errorCode: failure.code,
      errorCategory: failure.diagnosticCategory,
    );
  }

  _CanonicalUpdate _applySyncChanges(
    BootstrapData current,
    List<SyncChange> changes,
    Set<String> pendingIds,
    List<StoredOutboxOperation> outstandingOperations,
  ) {
    var updated = current;
    final writes = <EntityCacheWrite>[];
    for (final change in changes) {
      if (pendingIds.contains(change.entityId)) continue;
      final localVersion = _entityVersion(
        updated,
        change.entityType,
        change.entityId,
      );
      if (localVersion != null && localVersion > change.version) continue;
      if (change.changeType == SyncChangeType.tombstone) {
        updated = switch (change.entityType) {
          'party' => updated.copyWith(
            parties: updated.parties
                .where((item) => item.id != change.entityId)
                .toList(growable: false),
          ),
          'entry' => updated.copyWith(
            entries: updated.entries
                .where((item) => item.id != change.entityId)
                .toList(growable: false),
          ),
          'group' => updated.copyWith(
            groups: updated.groups
                .where((item) => item.id != change.entityId)
                .toList(growable: false),
          ),
          _ => updated,
        };
        writes.add(
          EntityCacheWrite(
            entityType: change.entityType,
            entityId: change.entityId,
            payloadJson: jsonEncode({
              'id': change.entityId,
              '_tombstone': true,
            }),
            version: change.version,
            serverUpdatedAt: change.changedAt,
            isTombstone: true,
          ),
        );
        continue;
      }

      switch (change.entityType) {
        case 'party':
          final raw = _payloadEntity(change.payload, 'party');
          if (raw.isEmpty) continue;
          final party = _overlayPendingEntries(
            Party.fromJson(raw),
            outstandingOperations,
          );
          updated = updated.copyWith(
            parties: _replaceById(updated.parties, party, (item) => item.id),
          );
          writes.add(_partyWrite(party));
        case 'entry':
          final raw = _payloadEntity(change.payload, 'entry');
          if (raw.isEmpty) continue;
          final entry = LedgerEntry.fromJson(raw);
          updated = updated.copyWith(
            entries: _replaceById(updated.entries, entry, (item) => item.id),
          );
          writes.add(_entryWrite(entry));
        case 'group':
          final raw = _payloadEntity(change.payload, 'group');
          if (raw.isEmpty) continue;
          final group = PartyGroup.fromJson(raw);
          updated = updated.copyWith(
            groups: _replaceById(updated.groups, group, (item) => item.id),
          );
          writes.add(_groupWrite(group));
        case 'company':
          final raw = _payloadEntity(change.payload, 'company');
          if (raw.isEmpty) continue;
          final company = Company.fromJson(raw);
          updated = updated.copyWith(
            company: company,
            companies: _replaceById(
              updated.companies,
              company,
              (item) => item.id,
            ),
          );
          writes.add(_companyWrite(company));
        case 'user_settings':
          final settings = _payloadEntity(change.payload, 'userSettings');
          if (settings.isEmpty) continue;
          updated = updated.copyWith(
            user: updated.user.copyWith(
              language: settings['language']?.toString(),
              accessibilityMode: settings['accessibilityMode'] as bool?,
              contactDiscoverable: settings['contactDiscoverable'] as bool?,
              version: _integer(settings['version']),
              updatedAt: change.changedAt,
            ),
          );
          writes.add(_userWrite(updated.user));
      }
    }
    return _CanonicalUpdate(updated, writes);
  }

  Future<void> _applyCanonicalResponse(
    Map<String, dynamic> response, {
    StorageScopeLease? expectedLease,
  }) async {
    if (expectedLease != null && !_storage.isCurrentLease(expectedLease)) {
      return;
    }
    final current = cachedBootstrap();
    if (current == null) return;
    final changes = <EntityCacheWrite>[];
    var updated = current;
    final rawEntry = _map(response['entry']);
    if (rawEntry.isNotEmpty) {
      var entry = LedgerEntry.fromJson(rawEntry);
      entry = _preserveEntryTimestamps(current.entries, entry);
      updated = updated.copyWith(
        entries: _replaceById(updated.entries, entry, (item) => item.id),
      );
      changes.add(_entryWrite(entry));
    }
    final rawParty = _map(response['party']);
    if (rawParty.isNotEmpty) {
      final party = Party.fromJson(rawParty);
      updated = updated.copyWith(
        parties: _replaceById(updated.parties, party, (item) => item.id),
      );
      changes.add(_partyWrite(party));
    }
    final affectedParties = response['affectedParties'];
    if (affectedParties is List) {
      for (final raw in affectedParties.whereType<Map>()) {
        final party = Party.fromJson(Map<String, dynamic>.from(raw));
        updated = updated.copyWith(
          parties: _replaceById(updated.parties, party, (item) => item.id),
        );
        changes.add(_partyWrite(party));
      }
    }
    if (changes.isNotEmpty) {
      await _storage.saveCanonicalUpdate(
        bootstrap: updated.toJson(),
        changedEntities: changes,
        expectedLease: expectedLease,
      );
    }
  }

  Future<void> _applySettingsResponse(
    Map<String, dynamic> response, {
    StorageScopeLease? expectedLease,
  }) async {
    if (expectedLease != null && !_storage.isCurrentLease(expectedLease)) {
      return;
    }
    final current = cachedBootstrap();
    if (current == null) return;
    var user = current.user;
    var company = current.company;
    final rawCompany = _map(response['company']);
    if (rawCompany.isNotEmpty) company = Company.fromJson(rawCompany);
    final settings = _map(response['userSettings']);
    if (settings.isNotEmpty) {
      user = user.copyWith(
        language: settings['language']?.toString(),
        accessibilityMode: settings['accessibilityMode'] as bool?,
        contactDiscoverable: settings['contactDiscoverable'] as bool?,
        version: _integer(settings['version']),
        updatedAt: _now().toUtc(),
      );
    }
    final updated = current.copyWith(
      user: user,
      company: company,
      companies: _replaceById(current.companies, company, (item) => item.id),
    );
    await _storage.saveCanonicalUpdate(
      bootstrap: updated.toJson(),
      changedEntities: [
        if (rawCompany.isNotEmpty) _companyWrite(company),
        if (settings.isNotEmpty) _userWrite(user),
      ],
      expectedLease: expectedLease,
    );
  }

  String _stableOperationId({
    required String scope,
    required Map<String, dynamic> intent,
    String? provided,
  }) {
    final scopedKey = _stableScopeKey(scope);
    if (provided != null) {
      if (!Uuid.isValidUUID(fromString: provided)) {
        throw const ApiFailure('This change has an invalid identifier.');
      }
      return provided;
    }
    final fingerprint = jsonEncode(intent);
    final existing = _stableMutations[scopedKey];
    if (existing != null && existing.fingerprint == fingerprint) {
      return existing.operationId;
    }
    final operation = _StableMutation(
      fingerprint: fingerprint,
      operationId: _uuid.v4(),
    );
    _stableMutations[scopedKey] = operation;
    return operation.operationId;
  }

  void _completeStableOperation(String scope, String operationId) {
    final scopedKey = _stableScopeKey(scope);
    if (_stableMutations[scopedKey]?.operationId == operationId) {
      _stableMutations.remove(scopedKey);
    }
  }

  String _stableScopeKey(String scope) {
    final active = _storage.activeScope;
    return active == null
        ? 'inactive:$scope'
        : '${active.accountId}:${active.companyId}:$scope';
  }

  BootstrapData _requireBootstrap() {
    final value = cachedBootstrap();
    if (value == null || _storage.activeScope == null) {
      throw StateError(
        'A signed-in account/company cache is required for this operation.',
      );
    }
    return value;
  }

  Duration _retryDelay(int attempts) {
    final exponent = min(max(attempts - 1, 0), 8);
    final baseSeconds = min(300, 2 << exponent);
    final jitterMilliseconds = _random.nextInt(1000);
    return Duration(seconds: baseSeconds, milliseconds: jitterMilliseconds);
  }

  Future<void> _record(
    DiagnosticEvent event,
    DiagnosticStatus status, {
    Duration? duration,
    int? itemCount,
  }) async {
    final scope = _storage.activeScope;
    try {
      await _storage.diagnostics.record(
        accountId: scope?.accountId,
        companyId: scope?.companyId,
        event: event,
        status: status,
        duration: duration,
        itemCount: itemCount,
      );
    } on StateError {
      // Diagnostics are best-effort during very early initialization only.
    }
  }

  /// Keeps a locally known create/update time when the API omits timestamps
  /// (parsed as epoch), so the UI can show "just now" instead of midnight.
  LedgerEntry _preserveEntryTimestamps(
    List<LedgerEntry> existing,
    LedgerEntry incoming, {
    String? localClientId,
  }) {
    final prior = existing
        .where(
          (entry) =>
              entry.id == incoming.id ||
              (localClientId != null &&
                  localClientId.isNotEmpty &&
                  entry.id == localClientId),
        )
        .firstOrNull;
    if (prior == null) return incoming;

    final keepCreated =
        !_hasRealTimestamp(incoming.createdAt) &&
        _hasRealTimestamp(prior.createdAt);
    final keepUpdated =
        incoming.updatedAt == null && prior.updatedAt != null;
    if (!keepCreated && !keepUpdated) return incoming;
    return incoming.copyWith(
      createdAt: keepCreated ? prior.createdAt : null,
      updatedAt: keepUpdated ? prior.updatedAt : null,
    );
  }

  bool _hasRealTimestamp(DateTime value) =>
      value.millisecondsSinceEpoch > 0 && value.year >= 1971;
}

class OptimisticMutationResult {
  const OptimisticMutationResult({
    required this.operationId,
    required this.entityId,
    required this.bootstrap,
    required this.undoUntil,
  });

  final String operationId;
  final String entityId;
  final BootstrapData bootstrap;
  final DateTime undoUntil;
}

class OutboxSummary {
  const OutboxSummary({
    required this.pendingCount,
    required this.needsAttentionCount,
    required this.nextAttemptAt,
  });

  final int pendingCount;
  final int needsAttentionCount;
  final DateTime? nextAttemptAt;
}

class SyncRunResult {
  const SyncRunResult({
    required this.uploadedCount,
    required this.pulledCount,
    required this.pendingCount,
    required this.needsAttentionCount,
    required this.authenticationRequired,
    required this.nextAttemptAt,
    required this.lastSyncedAt,
    required this.failure,
    required this.bootstrap,
  });

  const SyncRunResult.inactive()
    : uploadedCount = 0,
      pulledCount = 0,
      pendingCount = 0,
      needsAttentionCount = 0,
      authenticationRequired = false,
      nextAttemptAt = null,
      lastSyncedAt = null,
      failure = null,
      bootstrap = null;

  final int uploadedCount;
  final int pulledCount;
  final int pendingCount;
  final int needsAttentionCount;
  final bool authenticationRequired;
  final DateTime? nextAttemptAt;
  final DateTime? lastSyncedAt;
  final ApiFailure? failure;
  final BootstrapData? bootstrap;

  bool get succeeded => !authenticationRequired && failure == null;
}

enum UndoPendingResult {
  undone,
  notFound,
  alreadyUploading,
  hasDependentChanges,
}

enum DiscardNeedsAttentionResult {
  discarded,
  notFound,
  wrongState,
  hasDependentChanges,
}

enum ReviseNeedsAttentionResult { revised, notFound, wrongState, kindMismatch }

enum LedgerExportFormat { json, csv }

class ExportedLedgerFile {
  const ExportedLedgerFile({
    required this.filename,
    required this.bytes,
    required this.mimeType,
  });

  final String filename;
  final Uint8List bytes;
  final String mimeType;
}

class _CanonicalUpdate {
  const _CanonicalUpdate(this.bootstrap, this.changedEntities);

  final BootstrapData bootstrap;
  final List<EntityCacheWrite> changedEntities;
}

class _StableMutation {
  const _StableMutation({required this.fingerprint, required this.operationId});

  final String fingerprint;
  final String operationId;
}

EntityCacheWrite _partyWrite(Party party) => EntityCacheWrite(
  entityType: 'party',
  entityId: party.id,
  payloadJson: jsonEncode(party.toJson()),
  version: party.version,
  serverUpdatedAt: party.updatedAt,
);

EntityCacheWrite _entryWrite(LedgerEntry entry) => EntityCacheWrite(
  entityType: 'entry',
  entityId: entry.id,
  payloadJson: jsonEncode(entry.toJson()),
  version: entry.version,
  serverUpdatedAt: entry.updatedAt,
);

EntityCacheWrite _groupWrite(PartyGroup group) => EntityCacheWrite(
  entityType: 'group',
  entityId: group.id,
  payloadJson: jsonEncode(group.toJson()),
  version: group.version,
);

EntityCacheWrite _companyWrite(Company company) => EntityCacheWrite(
  entityType: 'company',
  entityId: company.id,
  payloadJson: jsonEncode(company.toJson()),
  version: company.version,
  serverUpdatedAt: company.updatedAt,
);

EntityCacheWrite _userWrite(AppUser user) => EntityCacheWrite(
  entityType: 'user_settings',
  entityId: user.id,
  payloadJson: jsonEncode(user.toJson()),
  version: user.version,
  serverUpdatedAt: user.updatedAt,
);

Party _overlayPendingEntries(
  Party canonical,
  Iterable<StoredOutboxOperation> operations,
) {
  var balance = canonical.balancePaise;
  var count = canonical.transactionCount;
  for (final operation in operations) {
    if (operation.kind != OutboxKind.createEntry ||
        operation.payload['partyId']?.toString() != canonical.id) {
      continue;
    }
    final amount = _integer(operation.payload['amountPaise']);
    if (amount == null || amount <= 0) continue;
    balance += operation.payload['action'] == 'received' ? -amount : amount;
    count += 1;
  }
  if (balance == canonical.balancePaise &&
      count == canonical.transactionCount) {
    return canonical;
  }
  return canonical.copyWith(balancePaise: balance, transactionCount: count);
}

List<T> _replaceById<T>(
  List<T> values,
  T replacement,
  String Function(T item) idOf,
) {
  final targetId = idOf(replacement);
  var found = false;
  final result = values
      .map((item) {
        if (idOf(item) != targetId) return item;
        found = true;
        return replacement;
      })
      .toList(growable: true);
  if (!found) result.insert(0, replacement);
  return result;
}

Map<String, dynamic> _payloadEntity(Map<String, dynamic> payload, String key) {
  final nested = _map(payload[key]);
  return nested.isEmpty ? payload : nested;
}

int? _entityVersion(BootstrapData data, String entityType, String entityId) {
  return switch (entityType) {
    'party' =>
      data.parties
          .where((item) => item.id == entityId)
          .map((item) => item.version)
          .firstOrNull,
    'entry' =>
      data.entries
          .where((item) => item.id == entityId)
          .map((item) => item.version)
          .firstOrNull,
    'group' =>
      data.groups
          .where((item) => item.id == entityId)
          .map((item) => item.version)
          .firstOrNull,
    'company' when data.company.id == entityId => data.company.version,
    'user_settings' when data.user.id == entityId => data.user.version,
    _ => null,
  };
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _dateOnly(DateTime? date) {
  if (date == null) return null;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime? _parseDateOnly(String value) {
  final text = value.trim();
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day
      ? parsed
      : null;
}

DateTime? _earlier(DateTime? left, DateTime? right) {
  if (left == null) return right;
  if (right == null) return left;
  return left.isBefore(right) ? left : right;
}

ApiFailure _localIdempotencyConflict() => const ApiFailure(
  'This saved change identifier was already used for different details.',
  statusCode: 409,
  code: 'LOCAL_IDEMPOTENCY_CONFLICT',
);

void _validateEntryAmount(int amountPaise) {
  if (amountPaise < 1 || amountPaise > 99_99_99_99_900) {
    throw const ApiFailure('Enter a valid amount.');
  }
}

bool _isSyncCursor(String? value) {
  if (value == null || !RegExp(r'^\d{1,19}$').hasMatch(value)) return false;
  final parsed = BigInt.tryParse(value);
  return parsed != null &&
      parsed >= BigInt.zero &&
      parsed <= BigInt.parse('9223372036854775807');
}
