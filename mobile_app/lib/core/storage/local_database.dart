import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/common.dart';

part 'local_database.g.dart';

class LocalScopes extends Table {
  TextColumn get accountId => text()();
  TextColumn get companyId => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  TextColumn get syncCursor => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {accountId, companyId};
}

class BootstrapSnapshots extends Table {
  TextColumn get accountId => text()();
  TextColumn get companyId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {accountId, companyId};
}

class CachedEntities extends Table {
  TextColumn get accountId => text()();
  TextColumn get companyId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();
  BoolColumn get isTombstone => boolean().withDefault(const Constant(false))();
  TextColumn get payloadJson => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {
    accountId,
    companyId,
    entityType,
    entityId,
  };
}

@TableIndex(
  name: 'outbox_scope_state_created',
  columns: {#accountId, #companyId, #state, #createdAt},
)
class OutboxRecords extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get companyId => text()();
  TextColumn get kind => text()();
  TextColumn get payloadJson => text()();
  TextColumn get dependsOnOperationId => text().nullable()();
  IntColumn get baseVersion => integer().nullable()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get lastStatusCode => integer().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  TextColumn get lastErrorCategory => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DiagnosticRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountId => text().nullable()();
  TextColumn get companyId => text().nullable()();
  TextColumn get event => text()();
  TextColumn get status => text()();
  IntColumn get durationMilliseconds => integer().nullable()();
  IntColumn get itemCount => integer().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
}

class DraftRecords extends Table {
  TextColumn get accountId => text()();
  TextColumn get companyId => text()();
  TextColumn get kind => text()();
  TextColumn get draftId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {accountId, companyId, kind, draftId};
}

@DriftDatabase(
  tables: [
    LocalScopes,
    BootstrapSnapshots,
    CachedEntities,
    OutboxRecords,
    DiagnosticRecords,
    DraftRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.encrypted({required String keyHex}) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(keyHex)) {
      throw ArgumentError.value(
        keyHex.length,
        'keyHex',
        'The local database key must be 256 bits encoded as lowercase hex.',
      );
    }

    return AppDatabase(
      driftDatabase(
        name: 'hisaab_local_v1',
        native: DriftNativeOptions(
          shareAcrossIsolates: true,
          setup: (database) => _configureEncryptedDatabase(database, keyHex),
        ),
      ),
    );
  }

  @override
  int get schemaVersion => 1;

  Future<void> ensureReady() async {
    await customSelect('SELECT 1').getSingle();
  }

  Future<LocalScope?> activeScope() {
    return (select(localScopes)
          ..where((row) => row.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> activateScope({
    required String accountId,
    required String companyId,
  }) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await (update(
        localScopes,
      )..where((row) => row.isActive.equals(true))).write(
        LocalScopesCompanion(
          isActive: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await into(localScopes).insertOnConflictUpdate(
        LocalScopesCompanion.insert(
          accountId: accountId,
          companyId: companyId,
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await (update(outboxRecords)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId) &
                row.state.equals('syncing'),
          ))
          .write(
            OutboxRecordsCompanion(
              state: const Value('pending'),
              nextAttemptAt: const Value(null),
              updatedAt: Value(now),
            ),
          );
    });
  }

  Future<void> quarantineActiveScope() async {
    final now = DateTime.now().toUtc();
    await (update(
      localScopes,
    )..where((row) => row.isActive.equals(true))).write(
      LocalScopesCompanion(isActive: const Value(false), updatedAt: Value(now)),
    );
  }

  Future<String?> readSnapshot(String accountId, String companyId) async {
    final row =
        await (select(bootstrapSnapshots)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.companyId.equals(companyId),
            ))
            .getSingleOrNull();
    return row?.payloadJson;
  }

  Future<void> writeSnapshot({
    required String accountId,
    required String companyId,
    required String payloadJson,
  }) async {
    await into(bootstrapSnapshots).insertOnConflictUpdate(
      BootstrapSnapshotsCompanion.insert(
        accountId: accountId,
        companyId: companyId,
        payloadJson: payloadJson,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> replaceSnapshotAndEntities({
    required String accountId,
    required String companyId,
    required String payloadJson,
    required List<EntityCacheWrite> entities,
  }) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      final countExpression = outboxRecords.id.count();
      final queued =
          await (selectOnly(outboxRecords)
                ..addColumns([countExpression])
                ..where(
                  outboxRecords.accountId.equals(accountId) &
                      outboxRecords.companyId.equals(companyId),
                ))
              .getSingle();
      if ((queued.read(countExpression) ?? 0) > 0) {
        throw const PendingOutboxConflict();
      }
      await into(bootstrapSnapshots).insertOnConflictUpdate(
        BootstrapSnapshotsCompanion.insert(
          accountId: accountId,
          companyId: companyId,
          payloadJson: payloadJson,
          updatedAt: now,
        ),
      );
      for (final entityType in const [
        'party',
        'entry',
        'group',
        'company',
        'user_settings',
      ]) {
        await (delete(cachedEntities)..where(
              (row) =>
                  row.accountId.equals(accountId) &
                  row.companyId.equals(companyId) &
                  row.entityType.equals(entityType),
            ))
            .go();
      }
      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          cachedEntities,
          entities
              .map(
                (entity) => CachedEntitiesCompanion.insert(
                  accountId: accountId,
                  companyId: companyId,
                  entityType: entity.entityType,
                  entityId: entity.entityId,
                  version: Value(entity.version),
                  serverUpdatedAt: Value(entity.serverUpdatedAt),
                  isTombstone: Value(entity.isTombstone),
                  payloadJson: entity.payloadJson,
                  cachedAt: now,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }

  Future<void> writeSnapshotAndEnqueue({
    required String accountId,
    required String companyId,
    required String payloadJson,
    required String operationId,
    required String kind,
    required String operationPayloadJson,
    String? dependsOnOperationId,
    int? baseVersion,
    DateTime? notBefore,
    List<EntityCacheWrite> changedEntities = const [],
  }) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await into(bootstrapSnapshots).insertOnConflictUpdate(
        BootstrapSnapshotsCompanion.insert(
          accountId: accountId,
          companyId: companyId,
          payloadJson: payloadJson,
          updatedAt: now,
        ),
      );
      await into(outboxRecords).insert(
        OutboxRecordsCompanion.insert(
          id: operationId,
          accountId: accountId,
          companyId: companyId,
          kind: kind,
          payloadJson: operationPayloadJson,
          dependsOnOperationId: Value(dependsOnOperationId),
          baseVersion: Value(baseVersion),
          nextAttemptAt: Value(notBefore),
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insert,
      );
      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          cachedEntities,
          changedEntities
              .map(
                (entity) => CachedEntitiesCompanion.insert(
                  accountId: accountId,
                  companyId: companyId,
                  entityType: entity.entityType,
                  entityId: entity.entityId,
                  version: Value(entity.version),
                  serverUpdatedAt: Value(entity.serverUpdatedAt),
                  isTombstone: Value(entity.isTombstone),
                  payloadJson: entity.payloadJson,
                  cachedAt: now,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }

  Future<List<CachedEntity>> scopedEntities({
    required String accountId,
    required String companyId,
    required String entityType,
  }) {
    return (select(cachedEntities)..where(
          (row) =>
              row.accountId.equals(accountId) &
              row.companyId.equals(companyId) &
              row.entityType.equals(entityType),
        ))
        .get();
  }

  Future<void> upsertEntities({
    required String accountId,
    required String companyId,
    required List<EntityCacheWrite> entities,
  }) async {
    final now = DateTime.now().toUtc();
    await batch((batch) {
      batch.insertAllOnConflictUpdate(
        cachedEntities,
        entities
            .map(
              (entity) => CachedEntitiesCompanion.insert(
                accountId: accountId,
                companyId: companyId,
                entityType: entity.entityType,
                entityId: entity.entityId,
                version: Value(entity.version),
                serverUpdatedAt: Value(entity.serverUpdatedAt),
                isTombstone: Value(entity.isTombstone),
                payloadJson: entity.payloadJson,
                cachedAt: now,
              ),
            )
            .toList(growable: false),
      );
    });
  }

  Future<void> writeSnapshotAndUpsertEntities({
    required String accountId,
    required String companyId,
    required String payloadJson,
    required List<EntityCacheWrite> entities,
  }) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await into(bootstrapSnapshots).insertOnConflictUpdate(
        BootstrapSnapshotsCompanion.insert(
          accountId: accountId,
          companyId: companyId,
          payloadJson: payloadJson,
          updatedAt: now,
        ),
      );
      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          cachedEntities,
          entities
              .map(
                (entity) => CachedEntitiesCompanion.insert(
                  accountId: accountId,
                  companyId: companyId,
                  entityType: entity.entityType,
                  entityId: entity.entityId,
                  version: Value(entity.version),
                  serverUpdatedAt: Value(entity.serverUpdatedAt),
                  isTombstone: Value(entity.isTombstone),
                  payloadJson: entity.payloadJson,
                  cachedAt: now,
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }

  Future<List<OutboxRecord>> scopedOutbox({
    required String accountId,
    required String companyId,
    Set<String>? states,
  }) {
    final query = select(outboxRecords)
      ..where(
        (row) =>
            row.accountId.equals(accountId) & row.companyId.equals(companyId),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    if (states != null && states.isNotEmpty) {
      query.where((row) => row.state.isIn(states));
    }
    return query.get();
  }

  Future<OutboxRecord?> outboxById(String id) {
    return (select(
      outboxRecords,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> markOutboxPending(
    String id, {
    required String accountId,
    required String companyId,
    String? payloadJson,
    DateTime? nextAttemptAt,
  }) {
    return (update(outboxRecords)..where(
          (row) =>
              row.id.equals(id) &
              row.accountId.equals(accountId) &
              row.companyId.equals(companyId),
        ))
        .write(
          OutboxRecordsCompanion(
            payloadJson: payloadJson == null
                ? const Value.absent()
                : Value(payloadJson),
            state: const Value('pending'),
            lastStatusCode: const Value(null),
            lastErrorCode: const Value(null),
            lastErrorCategory: const Value(null),
            nextAttemptAt: Value(nextAttemptAt),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> markOutboxSyncing({
    required String id,
    required String accountId,
    required String companyId,
  }) {
    return (update(outboxRecords)..where(
          (row) =>
              row.id.equals(id) &
              row.accountId.equals(accountId) &
              row.companyId.equals(companyId),
        ))
        .write(
          OutboxRecordsCompanion(
            state: const Value('syncing'),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> resetInterruptedOutbox() {
    return (update(
      outboxRecords,
    )..where((row) => row.state.equals('syncing'))).write(
      OutboxRecordsCompanion(
        state: const Value('pending'),
        nextAttemptAt: const Value(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markOutboxFailure({
    required String id,
    required String accountId,
    required String companyId,
    required bool needsAttention,
    required int attempts,
    int? statusCode,
    String? errorCode,
    required String errorCategory,
    DateTime? nextAttemptAt,
  }) {
    return (update(outboxRecords)..where(
          (row) =>
              row.id.equals(id) &
              row.accountId.equals(accountId) &
              row.companyId.equals(companyId),
        ))
        .write(
          OutboxRecordsCompanion(
            state: Value(needsAttention ? 'needs_attention' : 'pending'),
            attempts: Value(attempts),
            lastStatusCode: Value(statusCode),
            lastErrorCode: Value(errorCode),
            lastErrorCategory: Value(errorCategory),
            nextAttemptAt: Value(nextAttemptAt),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> completeOutbox({
    required String id,
    required String accountId,
    required String companyId,
    required String payloadJson,
    List<EntityCacheWrite> changedEntities = const [],
  }) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await into(bootstrapSnapshots).insertOnConflictUpdate(
        BootstrapSnapshotsCompanion.insert(
          accountId: accountId,
          companyId: companyId,
          payloadJson: payloadJson,
          updatedAt: now,
        ),
      );
      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          cachedEntities,
          changedEntities
              .map(
                (entity) => CachedEntitiesCompanion.insert(
                  accountId: accountId,
                  companyId: companyId,
                  entityType: entity.entityType,
                  entityId: entity.entityId,
                  version: Value(entity.version),
                  serverUpdatedAt: Value(entity.serverUpdatedAt),
                  isTombstone: Value(entity.isTombstone),
                  payloadJson: entity.payloadJson,
                  cachedAt: now,
                ),
              )
              .toList(growable: false),
        );
      });
      await (delete(outboxRecords)..where(
            (row) =>
                row.id.equals(id) &
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId),
          ))
          .go();
    });
  }

  Future<bool> undoPendingOutbox({
    required String id,
    required String accountId,
    required String companyId,
    required String payloadJson,
    required List<EntityCacheWrite> changedEntities,
    required String optimisticEntityType,
    required String optimisticEntityId,
    String requiredState = 'pending',
  }) async {
    return transaction(() async {
      final operation =
          await (select(outboxRecords)..where(
                (row) =>
                    row.id.equals(id) &
                    row.accountId.equals(accountId) &
                    row.companyId.equals(companyId),
              ))
              .getSingleOrNull();
      if (operation == null || operation.state != requiredState) return false;
      final dependent =
          await (select(outboxRecords)
                ..where(
                  (row) =>
                      row.accountId.equals(accountId) &
                      row.companyId.equals(companyId) &
                      row.dependsOnOperationId.equals(id),
                )
                ..limit(1))
              .getSingleOrNull();
      if (dependent != null) return false;

      final now = DateTime.now().toUtc();
      await into(bootstrapSnapshots).insertOnConflictUpdate(
        BootstrapSnapshotsCompanion.insert(
          accountId: accountId,
          companyId: companyId,
          payloadJson: payloadJson,
          updatedAt: now,
        ),
      );
      await (delete(cachedEntities)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId) &
                row.entityType.equals(optimisticEntityType) &
                row.entityId.equals(optimisticEntityId),
          ))
          .go();
      await batch((batch) {
        batch.insertAllOnConflictUpdate(
          cachedEntities,
          changedEntities
              .map(
                (entity) => CachedEntitiesCompanion.insert(
                  accountId: accountId,
                  companyId: companyId,
                  entityType: entity.entityType,
                  entityId: entity.entityId,
                  version: Value(entity.version),
                  serverUpdatedAt: Value(entity.serverUpdatedAt),
                  isTombstone: Value(entity.isTombstone),
                  payloadJson: entity.payloadJson,
                  cachedAt: now,
                ),
              )
              .toList(growable: false),
        );
      });
      await (delete(outboxRecords)..where(
            (row) =>
                row.id.equals(id) &
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId),
          ))
          .go();
      return true;
    });
  }

  Future<bool> reviseNeedsAttentionOutbox({
    required String id,
    required String accountId,
    required String companyId,
    required String payloadJson,
    required String operationPayloadJson,
    required List<EntityCacheWrite> changedEntities,
  }) {
    return transaction(() async {
      final operation =
          await (select(outboxRecords)..where(
                (row) =>
                    row.id.equals(id) &
                    row.accountId.equals(accountId) &
                    row.companyId.equals(companyId),
              ))
              .getSingleOrNull();
      if (operation == null || operation.state != 'needs_attention') {
        return false;
      }

      final now = DateTime.now().toUtc();
      await into(bootstrapSnapshots).insertOnConflictUpdate(
        BootstrapSnapshotsCompanion.insert(
          accountId: accountId,
          companyId: companyId,
          payloadJson: payloadJson,
          updatedAt: now,
        ),
      );
      if (changedEntities.isNotEmpty) {
        await batch((batch) {
          batch.insertAllOnConflictUpdate(
            cachedEntities,
            changedEntities
                .map(
                  (entity) => CachedEntitiesCompanion.insert(
                    accountId: accountId,
                    companyId: companyId,
                    entityType: entity.entityType,
                    entityId: entity.entityId,
                    version: Value(entity.version),
                    serverUpdatedAt: Value(entity.serverUpdatedAt),
                    isTombstone: Value(entity.isTombstone),
                    payloadJson: entity.payloadJson,
                    cachedAt: now,
                  ),
                )
                .toList(growable: false),
          );
        });
      }
      final changed =
          await (update(outboxRecords)..where(
                (row) =>
                    row.id.equals(id) &
                    row.accountId.equals(accountId) &
                    row.companyId.equals(companyId) &
                    row.state.equals('needs_attention'),
              ))
              .write(
                OutboxRecordsCompanion(
                  payloadJson: Value(operationPayloadJson),
                  state: const Value('pending'),
                  attempts: const Value(0),
                  lastStatusCode: const Value(null),
                  lastErrorCode: const Value(null),
                  lastErrorCategory: const Value(null),
                  nextAttemptAt: const Value(null),
                  updatedAt: Value(now),
                ),
              );
      if (changed != 1) {
        throw StateError('Outbox revision lost its state lock.');
      }
      return true;
    });
  }

  Future<void> saveDraft({
    required String accountId,
    required String companyId,
    required String kind,
    required String draftId,
    required String payloadJson,
  }) {
    return into(draftRecords).insertOnConflictUpdate(
      DraftRecordsCompanion.insert(
        accountId: accountId,
        companyId: companyId,
        kind: kind,
        draftId: draftId,
        payloadJson: payloadJson,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<DraftRecord?> readDraft({
    required String accountId,
    required String companyId,
    required String kind,
    required String draftId,
  }) {
    return (select(draftRecords)..where(
          (row) =>
              row.accountId.equals(accountId) &
              row.companyId.equals(companyId) &
              row.kind.equals(kind) &
              row.draftId.equals(draftId),
        ))
        .getSingleOrNull();
  }

  Future<void> deleteDraft({
    required String accountId,
    required String companyId,
    required String kind,
    required String draftId,
  }) {
    return (delete(draftRecords)..where(
          (row) =>
              row.accountId.equals(accountId) &
              row.companyId.equals(companyId) &
              row.kind.equals(kind) &
              row.draftId.equals(draftId),
        ))
        .go();
  }

  Future<void> updateSyncMetadata({
    required String accountId,
    required String companyId,
    DateTime? lastSyncedAt,
    String? syncCursor,
  }) {
    return (update(localScopes)..where(
          (row) =>
              row.accountId.equals(accountId) & row.companyId.equals(companyId),
        ))
        .write(
          LocalScopesCompanion(
            lastSyncedAt: Value(lastSyncedAt),
            syncCursor: syncCursor == null
                ? const Value.absent()
                : Value(syncCursor),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> clearScope(String accountId, String companyId) async {
    await transaction(() async {
      await (delete(outboxRecords)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId),
          ))
          .go();
      await (delete(bootstrapSnapshots)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId),
          ))
          .go();
      await (delete(cachedEntities)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId),
          ))
          .go();
      await (delete(localScopes)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId),
          ))
          .go();
      await (delete(draftRecords)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId),
          ))
          .go();
      await (delete(diagnosticRecords)..where(
            (row) =>
                row.accountId.equals(accountId) &
                row.companyId.equals(companyId),
          ))
          .go();
    });
  }

  Future<void> recordDiagnostic({
    String? accountId,
    String? companyId,
    required String event,
    required String status,
    int? durationMilliseconds,
    int? itemCount,
  }) async {
    await transaction(() async {
      await into(diagnosticRecords).insert(
        DiagnosticRecordsCompanion.insert(
          accountId: Value(accountId),
          companyId: Value(companyId),
          event: event,
          status: status,
          durationMilliseconds: Value(durationMilliseconds),
          itemCount: Value(itemCount),
          occurredAt: DateTime.now().toUtc(),
        ),
      );
      await customStatement(
        'DELETE FROM diagnostic_records '
        'WHERE id NOT IN '
        '(SELECT id FROM diagnostic_records ORDER BY id DESC LIMIT 200)',
      );
    });
  }

  Future<List<DiagnosticRecord>> recentDiagnostics({int limit = 100}) {
    final safeLimit = limit.clamp(1, 200);
    return (select(diagnosticRecords)
          ..orderBy([(row) => OrderingTerm.desc(row.id)])
          ..limit(safeLimit))
        .get();
  }
}

class PendingOutboxConflict implements Exception {
  const PendingOutboxConflict();

  @override
  String toString() =>
      'A full snapshot cannot replace locally queued or attention-required changes.';
}

class EntityCacheWrite {
  const EntityCacheWrite({
    required this.entityType,
    required this.entityId,
    required this.payloadJson,
    this.version,
    this.serverUpdatedAt,
    this.isTombstone = false,
  });

  final String entityType;
  final String entityId;
  final String payloadJson;
  final int? version;
  final DateTime? serverUpdatedAt;
  final bool isTombstone;
}

void _configureEncryptedDatabase(CommonDatabase database, String keyHex) {
  // keyHex is validated before this callback is created, so interpolation
  // cannot alter the PRAGMA statement.
  database.execute("PRAGMA key = '$keyHex'");
  final cipher = database.select('PRAGMA cipher');
  if (cipher.isEmpty ||
      cipher.first.values.every((value) => value?.toString().isEmpty ?? true)) {
    throw StateError(
      'Encrypted local storage is unavailable: sqlite3mc was not bundled.',
    );
  }
  database.execute('PRAGMA foreign_keys = ON');
  database.execute('PRAGMA journal_mode = WAL');
  database.execute('PRAGMA synchronous = NORMAL');
}
