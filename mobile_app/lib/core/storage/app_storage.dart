import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_database.dart';
import 'local_diagnostics.dart';

class AppStorage {
  // ignore: prefer_initializing_formals
  AppStorage({FlutterSecureStorage? secureStorage, AppDatabase? database})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      // ignore: prefer_initializing_formals
      _database = database;

  static const _sessionCookieKey = 'hisaab_session_cookie_v1';
  static const _databaseKeyKey = 'hisaab_local_database_key_v1';
  static const _legacyBootstrapCacheKey = 'hisaab_bootstrap_cache_v1';

  final FlutterSecureStorage _secureStorage;
  AppDatabase? _database;
  late final SharedPreferences _preferences;
  late final LocalDiagnostics diagnostics;

  StorageScope? _activeScope;
  StorageScope? _quarantinedScope;
  Map<String, dynamic>? _cachedBootstrap;
  int _scopeGeneration = 0;

  AppDatabase get database {
    final value = _database;
    if (value == null) {
      throw StateError('AppStorage.init() must complete before use.');
    }
    return value;
  }

  StorageScope? get activeScope => _activeScope;
  StorageScopeLease? get activeScopeLease {
    final scope = _activeScope;
    return scope == null
        ? null
        : StorageScopeLease(scope: scope, generation: _scopeGeneration);
  }

  bool isCurrentLease(StorageScopeLease lease) =>
      lease.generation == _scopeGeneration && lease.scope == _activeScope;

  Future<AppStorage> init() async {
    _preferences = await SharedPreferences.getInstance();
    _database ??= AppDatabase.encrypted(
      keyHex: await _readOrCreateDatabaseKey(),
    );
    await database.ensureReady();
    await database.resetInterruptedOutbox();
    diagnostics = LocalDiagnostics(database);
    await _loadActiveScope();
    await _migrateLegacyBootstrap();
    return this;
  }

  Future<String?> readSessionCookie() =>
      _secureStorage.read(key: _sessionCookieKey);

  Future<void> writeSessionCookie(String value) =>
      _secureStorage.write(key: _sessionCookieKey, value: value);

  Future<void> clearSessionCookie() =>
      _secureStorage.delete(key: _sessionCookieKey);

  Future<void> cacheBootstrap(Map<String, dynamic> value) async {
    final scope = _scopeFromBootstrap(value);
    if (scope == null) {
      throw const FormatException(
        'Bootstrap data must include non-empty user and company identifiers.',
      );
    }

    final switchesScope = _activeScope != scope;
    await database.activateScope(
      accountId: scope.accountId,
      companyId: scope.companyId,
    );
    _activeScope = scope;
    _quarantinedScope = null;
    if (switchesScope) _scopeGeneration += 1;
    try {
      await database.replaceSnapshotAndEntities(
        accountId: scope.accountId,
        companyId: scope.companyId,
        payloadJson: jsonEncode(value),
        entities: _entityWrites(value),
      );
    } on PendingOutboxConflict {
      final existing = await database.readSnapshot(
        scope.accountId,
        scope.companyId,
      );
      _cachedBootstrap = existing == null ? null : _decodeMap(existing);
      rethrow;
    }
    _cachedBootstrap = _copyMap(value);
  }

  Map<String, dynamic>? readCachedBootstrap() {
    final value = _cachedBootstrap;
    return value == null ? null : _copyMap(value);
  }

  Future<void> saveOptimisticMutation({
    required Map<String, dynamic> bootstrap,
    required StoredOutboxDraft operation,
    List<EntityCacheWrite>? changedEntities,
  }) async {
    final scope = _requireScope();
    await database.writeSnapshotAndEnqueue(
      accountId: scope.accountId,
      companyId: scope.companyId,
      payloadJson: jsonEncode(bootstrap),
      operationId: operation.id,
      kind: operation.kind.name,
      operationPayloadJson: jsonEncode(operation.payload),
      dependsOnOperationId: operation.dependsOnOperationId,
      baseVersion: operation.baseVersion,
      notBefore: operation.notBefore,
      changedEntities: changedEntities ?? _entityWrites(bootstrap),
    );
    _cachedBootstrap = _copyMap(bootstrap);
  }

  Future<List<StoredOutboxOperation>> readOutbox({
    Set<OutboxState>? states,
  }) async {
    final scope = _activeScope;
    if (scope == null) return const [];
    final rows = await database.scopedOutbox(
      accountId: scope.accountId,
      companyId: scope.companyId,
      states: states?.map((state) => state.databaseValue).toSet(),
    );
    return rows.map(StoredOutboxOperation.fromRow).toList(growable: false);
  }

  Future<StoredOutboxOperation?> readOutboxOperation(String id) async {
    final scope = _activeScope;
    if (scope == null) return null;
    final row = await database.outboxById(id);
    if (row == null ||
        row.accountId != scope.accountId ||
        row.companyId != scope.companyId) {
      return null;
    }
    return StoredOutboxOperation.fromRow(row);
  }

  Future<void> markOutboxSyncing(StoredOutboxOperation operation) {
    return database.markOutboxSyncing(
      id: operation.id,
      accountId: operation.accountId,
      companyId: operation.companyId,
    );
  }

  Future<void> markOutboxPending(
    String id, {
    Map<String, dynamic>? payload,
    DateTime? nextAttemptAt,
  }) {
    final scope = _requireScope();
    return database.markOutboxPending(
      id,
      accountId: scope.accountId,
      companyId: scope.companyId,
      payloadJson: payload == null ? null : jsonEncode(payload),
      nextAttemptAt: nextAttemptAt,
    );
  }

  Future<void> markOutboxOperationPending(
    StoredOutboxOperation operation, {
    Map<String, dynamic>? payload,
    DateTime? nextAttemptAt,
  }) {
    return database.markOutboxPending(
      operation.id,
      accountId: operation.accountId,
      companyId: operation.companyId,
      payloadJson: payload == null ? null : jsonEncode(payload),
      nextAttemptAt: nextAttemptAt,
    );
  }

  Future<void> markOutboxFailure({
    required StoredOutboxOperation operation,
    required bool needsAttention,
    required int attempts,
    int? statusCode,
    String? errorCode,
    required String errorCategory,
    DateTime? nextAttemptAt,
  }) {
    return database.markOutboxFailure(
      id: operation.id,
      accountId: operation.accountId,
      companyId: operation.companyId,
      needsAttention: needsAttention,
      attempts: attempts,
      statusCode: statusCode,
      errorCode: errorCode,
      errorCategory: errorCategory,
      nextAttemptAt: nextAttemptAt,
    );
  }

  Future<bool> completeOutbox({
    required StoredOutboxOperation operation,
    required StorageScopeLease lease,
    required Map<String, dynamic> bootstrap,
    List<EntityCacheWrite>? changedEntities,
  }) async {
    if (!isCurrentLease(lease) ||
        lease.scope.accountId != operation.accountId ||
        lease.scope.companyId != operation.companyId) {
      return false;
    }
    await database.completeOutbox(
      id: operation.id,
      accountId: operation.accountId,
      companyId: operation.companyId,
      payloadJson: jsonEncode(bootstrap),
      changedEntities: changedEntities ?? _entityWrites(bootstrap),
    );
    if (isCurrentLease(lease)) _cachedBootstrap = _copyMap(bootstrap);
    return true;
  }

  Future<bool> saveCanonicalUpdate({
    required Map<String, dynamic> bootstrap,
    required List<EntityCacheWrite> changedEntities,
    StorageScopeLease? expectedLease,
  }) async {
    final lease = expectedLease ?? activeScopeLease;
    if (lease == null || !isCurrentLease(lease)) return false;
    final scope = lease.scope;
    await database.writeSnapshotAndUpsertEntities(
      accountId: scope.accountId,
      companyId: scope.companyId,
      payloadJson: jsonEncode(bootstrap),
      entities: changedEntities,
    );
    if (isCurrentLease(lease)) _cachedBootstrap = _copyMap(bootstrap);
    return true;
  }

  Future<bool> undoPendingOutbox({
    required String id,
    required Map<String, dynamic> bootstrap,
    required String optimisticEntityType,
    required String optimisticEntityId,
    List<EntityCacheWrite> changedEntities = const [],
  }) async {
    final scope = _requireScope();
    final undone = await database.undoPendingOutbox(
      id: id,
      accountId: scope.accountId,
      companyId: scope.companyId,
      payloadJson: jsonEncode(bootstrap),
      changedEntities: changedEntities,
      optimisticEntityType: optimisticEntityType,
      optimisticEntityId: optimisticEntityId,
    );
    if (undone) _cachedBootstrap = _copyMap(bootstrap);
    return undone;
  }

  Future<bool> discardNeedsAttentionOutbox({
    required String id,
    required Map<String, dynamic> bootstrap,
    required String optimisticEntityType,
    required String optimisticEntityId,
    List<EntityCacheWrite> changedEntities = const [],
  }) async {
    final scope = _requireScope();
    final discarded = await database.undoPendingOutbox(
      id: id,
      accountId: scope.accountId,
      companyId: scope.companyId,
      payloadJson: jsonEncode(bootstrap),
      changedEntities: changedEntities,
      optimisticEntityType: optimisticEntityType,
      optimisticEntityId: optimisticEntityId,
      requiredState: 'needs_attention',
    );
    if (discarded) _cachedBootstrap = _copyMap(bootstrap);
    return discarded;
  }

  Future<bool> reviseNeedsAttentionOutbox({
    required StoredOutboxOperation operation,
    required Map<String, dynamic> bootstrap,
    required Map<String, dynamic> payload,
    required List<EntityCacheWrite> changedEntities,
  }) async {
    final scope = _activeScope;
    if (scope == null ||
        scope.accountId != operation.accountId ||
        scope.companyId != operation.companyId) {
      return false;
    }
    final revised = await database.reviseNeedsAttentionOutbox(
      id: operation.id,
      accountId: operation.accountId,
      companyId: operation.companyId,
      payloadJson: jsonEncode(bootstrap),
      operationPayloadJson: jsonEncode(payload),
      changedEntities: changedEntities,
    );
    if (revised &&
        _activeScope == scope &&
        scope.accountId == operation.accountId &&
        scope.companyId == operation.companyId) {
      _cachedBootstrap = _copyMap(bootstrap);
    }
    return revised;
  }

  Future<void> saveDraft({
    required String kind,
    required String draftId,
    required Map<String, dynamic> payload,
  }) {
    final scope = _requireScope();
    return database.saveDraft(
      accountId: scope.accountId,
      companyId: scope.companyId,
      kind: kind,
      draftId: draftId,
      payloadJson: jsonEncode(payload),
    );
  }

  Future<Map<String, dynamic>?> readDraft({
    required String kind,
    required String draftId,
  }) async {
    final scope = _activeScope;
    if (scope == null) return null;
    final row = await database.readDraft(
      accountId: scope.accountId,
      companyId: scope.companyId,
      kind: kind,
      draftId: draftId,
    );
    return row == null ? null : _decodeMap(row.payloadJson);
  }

  Future<void> clearDraft({required String kind, required String draftId}) {
    final scope = _requireScope();
    return database.deleteDraft(
      accountId: scope.accountId,
      companyId: scope.companyId,
      kind: kind,
      draftId: draftId,
    );
  }

  Future<LocalSyncMetadata> readSyncMetadata() async {
    final scope = _activeScope;
    if (scope == null) return const LocalSyncMetadata();
    final row = await database.activeScope();
    return LocalSyncMetadata(
      lastSyncedAt: row?.lastSyncedAt,
      syncCursor: row?.syncCursor,
    );
  }

  Future<void> updateSyncMetadata({
    DateTime? lastSyncedAt,
    String? syncCursor,
    StorageScopeLease? expectedLease,
  }) async {
    final lease = expectedLease ?? activeScopeLease;
    if (lease == null || !isCurrentLease(lease)) return;
    final scope = lease.scope;
    await database.updateSyncMetadata(
      accountId: scope.accountId,
      companyId: scope.companyId,
      lastSyncedAt: lastSyncedAt,
      syncCursor: syncCursor,
    );
  }

  /// Makes cached data inaccessible without destroying pending changes.
  ///
  /// Use this for an unauthorized session or an account switch. Only an
  /// explicit, confirmed logout should call [clearAll].
  Future<void> quarantineActiveScope() async {
    _quarantinedScope = _activeScope;
    _scopeGeneration += 1;
    await database.quarantineActiveScope();
    _activeScope = null;
    _cachedBootstrap = null;
  }

  Future<void> clearAll() async {
    await clearSessionCookie();
    final scope = _activeScope ?? _quarantinedScope;
    if (scope != null) {
      await database.clearScope(scope.accountId, scope.companyId);
    }
    await _preferences.remove(_legacyBootstrapCacheKey);
    _activeScope = null;
    _quarantinedScope = null;
    _cachedBootstrap = null;
    _scopeGeneration += 1;
  }

  Future<void> close() => database.close();

  Future<void> _loadActiveScope() async {
    final row = await database.activeScope();
    if (row == null) return;
    _activeScope = StorageScope(
      accountId: row.accountId,
      companyId: row.companyId,
    );
    _scopeGeneration += 1;
    final raw = await database.readSnapshot(row.accountId, row.companyId);
    if (raw == null) return;
    _cachedBootstrap = _decodeMap(raw);
  }

  Future<void> _migrateLegacyBootstrap() async {
    final raw = _preferences.getString(_legacyBootstrapCacheKey);
    if (raw == null) return;
    if (_cachedBootstrap == null) {
      final legacy = _decodeMap(raw);
      if (legacy != null && _scopeFromBootstrap(legacy) != null) {
        await cacheBootstrap(legacy);
      }
    }
    await _preferences.remove(_legacyBootstrapCacheKey);
  }

  Future<String> _readOrCreateDatabaseKey() async {
    final existing = await _secureStorage.read(key: _databaseKeyKey);
    if (existing != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(existing)) {
      return existing;
    }
    if (existing != null) {
      throw StateError('The encrypted local database key is malformed.');
    }
    final random = Random.secure();
    final key = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    await _secureStorage.write(key: _databaseKeyKey, value: key);
    return key;
  }

  StorageScope _requireScope() {
    final scope = _activeScope;
    if (scope == null) {
      throw StateError('No account/company storage scope is active.');
    }
    return scope;
  }
}

class StorageScope {
  const StorageScope({required this.accountId, required this.companyId});

  final String accountId;
  final String companyId;

  @override
  bool operator ==(Object other) =>
      other is StorageScope &&
      other.accountId == accountId &&
      other.companyId == companyId;

  @override
  int get hashCode => Object.hash(accountId, companyId);
}

class StorageScopeLease {
  const StorageScopeLease({required this.scope, required this.generation});

  final StorageScope scope;
  final int generation;
}

enum OutboxKind { createParty, createEntry }

enum OutboxState {
  pending('pending'),
  syncing('syncing'),
  needsAttention('needs_attention');

  const OutboxState(this.databaseValue);
  final String databaseValue;

  static OutboxState parse(String value) => switch (value) {
    'syncing' => syncing,
    'needs_attention' => needsAttention,
    _ => pending,
  };
}

class StoredOutboxDraft {
  const StoredOutboxDraft({
    required this.id,
    required this.kind,
    required this.payload,
    this.dependsOnOperationId,
    this.baseVersion,
    this.notBefore,
  });

  final String id;
  final OutboxKind kind;
  final Map<String, dynamic> payload;
  final String? dependsOnOperationId;
  final int? baseVersion;
  final DateTime? notBefore;
}

class StoredOutboxOperation extends StoredOutboxDraft {
  const StoredOutboxOperation({
    required super.id,
    required super.kind,
    required super.payload,
    required this.state,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    required this.accountId,
    required this.companyId,
    super.dependsOnOperationId,
    super.baseVersion,
    super.notBefore,
    this.lastStatusCode,
    this.lastErrorCode,
    this.lastErrorCategory,
    this.nextAttemptAt,
  });

  factory StoredOutboxOperation.fromRow(OutboxRecord row) {
    return StoredOutboxOperation(
      id: row.id,
      kind: OutboxKind.values.firstWhere(
        (kind) => kind.name == row.kind,
        orElse: () =>
            throw FormatException('Unknown outbox operation kind: ${row.kind}'),
      ),
      payload: _decodeMap(row.payloadJson) ?? const {},
      state: OutboxState.parse(row.state),
      attempts: row.attempts,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      accountId: row.accountId,
      companyId: row.companyId,
      dependsOnOperationId: row.dependsOnOperationId,
      baseVersion: row.baseVersion,
      notBefore: row.nextAttemptAt,
      lastStatusCode: row.lastStatusCode,
      lastErrorCode: row.lastErrorCode,
      lastErrorCategory: row.lastErrorCategory,
      nextAttemptAt: row.nextAttemptAt,
    );
  }

  final OutboxState state;
  final int attempts;
  final int? lastStatusCode;
  final String? lastErrorCode;
  final String? lastErrorCategory;
  final DateTime? nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String accountId;
  final String companyId;

  StorageScope get scope =>
      StorageScope(accountId: accountId, companyId: companyId);
}

class LocalSyncMetadata {
  const LocalSyncMetadata({this.lastSyncedAt, this.syncCursor});

  final DateTime? lastSyncedAt;
  final String? syncCursor;
}

StorageScope? _scopeFromBootstrap(Map<String, dynamic> value) {
  final user = value['user'];
  final company = value['company'];
  if (user is! Map || company is! Map) return null;
  final accountId = user['id']?.toString().trim() ?? '';
  final companyId = company['id']?.toString().trim() ?? '';
  if (accountId.isEmpty || companyId.isEmpty) return null;
  return StorageScope(accountId: accountId, companyId: companyId);
}

List<EntityCacheWrite> _entityWrites(Map<String, dynamic> bootstrap) {
  final writes = <EntityCacheWrite>[];
  for (final definition in const [
    (jsonKey: 'parties', type: 'party'),
    (jsonKey: 'entries', type: 'entry'),
    (jsonKey: 'groups', type: 'group'),
  ]) {
    final values = bootstrap[definition.jsonKey];
    if (values is! List) continue;
    for (final raw in values) {
      if (raw is! Map) continue;
      final value = Map<String, dynamic>.from(raw);
      final id = value['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      writes.add(
        EntityCacheWrite(
          entityType: definition.type,
          entityId: id,
          payloadJson: jsonEncode(value),
          version: _intOrNull(value['version']),
          serverUpdatedAt: _dateOrNull(
            value['updatedAt'] ?? value['editedAt'] ?? value['createdAt'],
          ),
          isTombstone: value['_tombstone'] == true,
        ),
      );
    }
  }
  for (final definition in const [
    (jsonKey: 'company', type: 'company'),
    (jsonKey: 'user', type: 'user_settings'),
  ]) {
    final raw = bootstrap[definition.jsonKey];
    if (raw is! Map) continue;
    final value = Map<String, dynamic>.from(raw);
    final id = value['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    writes.add(
      EntityCacheWrite(
        entityType: definition.type,
        entityId: id,
        payloadJson: jsonEncode(value),
        version: _intOrNull(value['version']),
        serverUpdatedAt: _dateOrNull(value['updatedAt']),
      ),
    );
  }
  return writes;
}

Map<String, dynamic> _copyMap(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, dynamic>? _decodeMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } on FormatException {
    return null;
  }
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _dateOrNull(Object? value) =>
    DateTime.tryParse(value?.toString() ?? '');
