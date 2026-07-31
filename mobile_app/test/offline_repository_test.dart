import 'dart:async';

import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/core/network/api_client.dart';
import 'package:hisaab_mobile/core/network/api_failure.dart';
import 'package:hisaab_mobile/core/storage/app_storage.dart';
import 'package:hisaab_mobile/core/storage/local_database.dart';
import 'package:hisaab_mobile/data/models/models.dart';
import 'package:hisaab_mobile/data/repositories/ledger_repository.dart';
import 'package:hisaab_mobile/features/ledger/ledger_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'repeat entry intent reuses its persisted entity without duplication',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      addTearDown(storage.close);
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      final repository = LedgerRepository(_MockApiClient(), storage);
      const operationId = '11111111-1111-4111-8111-111111111111';

      final first = await repository.queueEntryCreation(
        partyId: 'party-1',
        action: EntryAction.gave,
        amountPaise: 1200,
        narration: 'Tea',
        entryDate: '2026-07-30',
        idempotencyKey: operationId,
      );
      final replay = await repository.queueEntryCreation(
        partyId: 'party-1',
        action: EntryAction.gave,
        amountPaise: 1200,
        narration: 'Tea',
        entryDate: '2026-07-30',
        idempotencyKey: operationId,
      );

      expect(replay.entityId, first.entityId);
      expect(first.entityId, isNot(operationId));
      expect(repository.cachedBootstrap()!.entries, hasLength(1));
      expect(await storage.readOutbox(), hasLength(1));

      await expectLater(
        repository.queueEntryCreation(
          partyId: 'party-1',
          action: EntryAction.gave,
          amountPaise: 1300,
          narration: 'Tea',
          entryDate: '2026-07-30',
          idempotencyKey: operationId,
        ),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.code,
            'code',
            'LOCAL_IDEMPOTENCY_CONFLICT',
          ),
        ),
      );
    },
  );

  test(
    'queued party survives a restart and blocks snapshot replacement',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      const operationId = '22222222-2222-4222-8222-222222222222';
      final firstRepository = LedgerRepository(_MockApiClient(), storage);
      final queued = await firstRepository.queuePartyCreation(
        name: 'Offline Party',
        phone: '',
        idempotencyKey: operationId,
      );

      final restartedStorage = await AppStorage(database: database).init();
      addTearDown(restartedStorage.close);
      final api = _MockApiClient();
      final restartedRepository = LedgerRepository(api, restartedStorage);
      final restored = await restartedRepository.bootstrap();

      expect(
        restored.parties.any((party) => party.id == queued.entityId),
        isTrue,
      );
      expect(await restartedStorage.readOutbox(), hasLength(1));
      verifyNever(() => api.get('/api/bootstrap'));
    },
  );

  test(
    'mutation response cursor never skips a contiguous pull checkpoint',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      addTearDown(storage.close);
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      await storage.updateSyncMetadata(syncCursor: '4');
      final api = _MockApiClient();
      var now = DateTime.utc(2026, 7, 30, 12);
      final repository = LedgerRepository(api, storage, now: () => now);
      await repository.queueEntryCreation(
        partyId: 'party-1',
        action: EntryAction.received,
        amountPaise: 2500,
        narration: '',
        entryDate: '2026-07-30',
        idempotencyKey: '33333333-3333-4333-8333-333333333333',
      );
      now = now.add(const Duration(seconds: 9));
      final optimistic = repository.cachedBootstrap()!;
      final entry = optimistic.entries.single;
      final party = optimistic.parties.single;
      when(() => api.post('/api/entries', data: any(named: 'data'))).thenAnswer(
        (_) async => apiResponse({
          'entry': entry
              .copyWith(
                version: 1,
                localSyncStatus: LocalSyncStatus.synced,
                clearClientOperationId: true,
              )
              .toJson(),
          'party': party.copyWith(version: 2).toJson(),
          'changeCursor': '9',
          // A stale server still returning the old field must also be ignored.
          'syncCursor': '9',
        }),
      );
      when(
        () => api.get(
          '/api/sync/pull',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => apiResponse({
          'changes': <Object>[],
          'nextCursor': '4',
          'hasMore': false,
        }),
      );

      await repository.syncPending();

      final query =
          verify(
                () => api.get(
                  '/api/sync/pull',
                  queryParameters: captureAny(named: 'queryParameters'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(query['cursor'], '4');
      expect((await storage.readSyncMetadata()).syncCursor, '4');
      expect(repository.cachedBootstrap()!.syncCursor, '4');
    },
  );

  test(
    'entry amount is validated before an offline intent is persisted',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      addTearDown(storage.close);
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      final repository = LedgerRepository(_MockApiClient(), storage);

      await expectLater(
        repository.queueEntryCreation(
          partyId: 'party-1',
          action: EntryAction.gave,
          amountPaise: 0,
          narration: '',
          entryDate: '2026-07-30',
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(await storage.readOutbox(), isEmpty);
    },
  );

  test('legacy cache without a checkpoint performs a full bootstrap', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final storage = await AppStorage(database: database).init();
    addTearDown(storage.close);
    await storage.cacheBootstrap(_bootstrap(syncCursor: null));
    final api = _MockApiClient();
    when(
      () => api.get('/api/bootstrap'),
    ).thenAnswer((_) async => apiResponse(_bootstrap(syncCursor: '7')));
    final controller = LedgerController(LedgerRepository(api, storage));

    await controller.initializeLocalFirst();

    expect(controller.data.value?.syncCursor, '7');
    verify(() => api.get('/api/bootstrap')).called(1);
  });

  test(
    'settings retry reuses its key and sends only relevant base version',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      addTearDown(storage.close);
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      final api = _MockApiClient();
      var calls = 0;
      when(
        () => api.patch('/api/settings', data: any(named: 'data')),
      ).thenAnswer((_) async {
        calls += 1;
        if (calls == 1) {
          throw const ApiFailure('Connection lost', isConnectionError: true);
        }
        return apiResponse({
          'ok': true,
          'userSettings': {
            'language': 'hi',
            'accessibilityMode': false,
            'contactDiscoverable': false,
            'version': 2,
          },
          'changeCursor': '8',
        });
      });
      final repository = LedgerRepository(api, storage);

      await expectLater(
        repository.updateSettings(language: 'hi'),
        throwsA(isA<ApiFailure>()),
      );
      await repository.updateSettings(language: 'hi');

      final payloads = verify(
        () => api.patch('/api/settings', data: captureAny(named: 'data')),
      ).captured.cast<Map<String, dynamic>>();
      expect(payloads, hasLength(2));
      expect(payloads[0]['idempotencyKey'], payloads[1]['idempotencyKey']);
      expect(payloads[0]['baseUserVersion'], 1);
      expect(payloads[0].containsKey('baseCompanyVersion'), isFalse);
      expect((await storage.readSyncMetadata()).syncCursor, isNull);
    },
  );

  test(
    'opening balance retry keeps a stable generated client identifier',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      addTearDown(storage.close);
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      final api = _MockApiClient();
      var calls = 0;
      when(
        () => api.post('/api/opening-balance', data: any(named: 'data')),
      ).thenAnswer((_) async {
        calls += 1;
        if (calls == 1) {
          throw const ApiFailure('Connection lost', isConnectionError: true);
        }
        return apiResponse(const <String, dynamic>{'ok': true});
      });
      final repository = LedgerRepository(api, storage);
      const operationId = '44444444-4444-4444-8444-444444444444';

      Future<void> save() => repository.saveOpeningBalance(
        partyId: 'party-1',
        amountPaise: 5000,
        direction: 'receive',
        entryDate: '2026-07-30',
        idempotencyKey: operationId,
      );
      await expectLater(save(), throwsA(isA<ApiFailure>()));
      await save();

      final payloads = verify(
        () => api.post('/api/opening-balance', data: captureAny(named: 'data')),
      ).captured.cast<Map<String, dynamic>>();
      expect(payloads[0]['clientId'], payloads[1]['clientId']);
      expect(payloads[0]['clientId'], isNot(operationId));
      expect(
        Uuid.isValidUUID(fromString: payloads[0]['clientId'] as String),
        isTrue,
      );
    },
  );

  test(
    'canonical party create keeps dependent optimistic entry balance',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      addTearDown(storage.close);
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      final api = _MockApiClient();
      var now = DateTime.utc(2026, 7, 30, 12);
      final repository = LedgerRepository(api, storage, now: () => now);
      final partyMutation = await repository.queuePartyCreation(
        name: 'New party',
        phone: '',
        idempotencyKey: '55555555-5555-4555-8555-555555555555',
      );
      now = now.add(const Duration(seconds: 5));
      await repository.queueEntryCreation(
        partyId: partyMutation.entityId,
        action: EntryAction.gave,
        amountPaise: 1200,
        narration: '',
        entryDate: '2026-07-30',
        idempotencyKey: '66666666-6666-4666-8666-666666666666',
      );
      final optimisticParty = repository.cachedBootstrap()!.parties.firstWhere(
        (party) => party.id == partyMutation.entityId,
      );
      final canonical = optimisticParty.copyWith(
        reference: 'HSB-NEW',
        balancePaise: 0,
        transactionCount: 0,
        version: 1,
        localSyncStatus: LocalSyncStatus.synced,
        clearClientOperationId: true,
      );
      when(
        () => api.post('/api/parties', data: any(named: 'data')),
      ).thenAnswer((_) async => apiResponse({'party': canonical.toJson()}));
      now = DateTime.utc(2026, 7, 30, 12, 0, 9);

      await repository.syncPending(pullRemoteChanges: false);

      final reconciled = repository.cachedBootstrap()!.parties.firstWhere(
        (party) => party.id == partyMutation.entityId,
      );
      expect(reconciled.balancePaise, 1200);
      expect(reconciled.transactionCount, 1);
      expect(await storage.readOutbox(), hasLength(1));
    },
  );

  test('pending entry blocks remote pull and checkpoint advancement', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final storage = await AppStorage(database: database).init();
    addTearDown(storage.close);
    await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
    await storage.updateSyncMetadata(syncCursor: '4');
    final api = _MockApiClient();
    final now = DateTime.utc(2026, 7, 30, 12);
    final repository = LedgerRepository(api, storage, now: () => now);
    await repository.queueEntryCreation(
      partyId: 'party-1',
      action: EntryAction.gave,
      amountPaise: 1200,
      narration: '',
      entryDate: '2026-07-30',
      idempotencyKey: '77777777-7777-4777-8777-777777777777',
    );

    await repository.syncPending();

    final party = repository.cachedBootstrap()!.parties.single;
    expect(party.balancePaise, 1200);
    expect(party.transactionCount, 1);
    expect((await storage.readSyncMetadata()).syncCursor, '4');
    verifyNever(
      () => api.get(
        '/api/sync/pull',
        queryParameters: any(named: 'queryParameters'),
      ),
    );
  });

  test(
    'restart during lost-response backoff does not pull and double-overlay',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      await storage.updateSyncMetadata(syncCursor: '4');
      var now = DateTime.utc(2026, 7, 30, 12);
      final firstApi = _MockApiClient();
      final firstRepository = LedgerRepository(
        firstApi,
        storage,
        now: () => now,
      );
      await firstRepository.queueEntryCreation(
        partyId: 'party-1',
        action: EntryAction.gave,
        amountPaise: 900,
        narration: '',
        entryDate: '2026-07-30',
        idempotencyKey: '78787878-7878-4787-8787-787878787878',
      );
      now = now.add(const Duration(seconds: 9));
      when(
        () => firstApi.post('/api/entries', data: any(named: 'data')),
      ).thenThrow(
        const ApiFailure(
          'The server committed the request but its response was lost.',
          isConnectionError: true,
        ),
      );
      await firstRepository.syncPending();
      final persisted = await storage.readOutbox();
      expect(persisted.single.state, OutboxState.pending);
      expect(persisted.single.nextAttemptAt, isNotNull);
      expect(persisted.single.nextAttemptAt!.isAfter(now), isTrue);

      final restartedStorage = await AppStorage(database: database).init();
      addTearDown(restartedStorage.close);
      final restartedApi = _MockApiClient();
      final restartedRepository = LedgerRepository(
        restartedApi,
        restartedStorage,
        now: () => now,
      );

      await restartedRepository.syncPending();

      final party = restartedRepository.cachedBootstrap()!.parties.single;
      expect(party.balancePaise, 900);
      expect(party.transactionCount, 1);
      expect((await restartedStorage.readSyncMetadata()).syncCursor, '4');
      verifyNever(
        () => restartedApi.get(
          '/api/sync/pull',
          queryParameters: any(named: 'queryParameters'),
        ),
      );
    },
  );

  test(
    'late upload response cannot contaminate a newly active account',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      addTearDown(storage.close);
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      final api = _MockApiClient();
      var now = DateTime.utc(2026, 7, 30, 12);
      final repository = LedgerRepository(api, storage, now: () => now);
      await repository.queueEntryCreation(
        partyId: 'party-1',
        action: EntryAction.gave,
        amountPaise: 900,
        narration: '',
        entryDate: '2026-07-30',
        idempotencyKey: '88888888-8888-4888-8888-888888888888',
      );
      now = now.add(const Duration(seconds: 9));
      final response = Completer<Response<dynamic>>();
      when(
        () => api.post('/api/entries', data: any(named: 'data')),
      ).thenAnswer((_) => response.future);
      final syncing = repository.syncPending(pullRemoteChanges: false);
      await untilCalled(
        () => api.post('/api/entries', data: any(named: 'data')),
      );

      await storage.cacheBootstrap(
        _bootstrap(
          syncCursor: '10',
          userId: 'user-2',
          companyId: 'company-2',
          partyId: 'party-2',
        ),
      );
      response.complete(apiResponse(const <String, dynamic>{'ok': true}));
      await syncing;

      final active = repository.cachedBootstrap()!;
      expect(active.user.id, 'user-2');
      expect(active.company.id, 'company-2');
      expect(active.entries, isEmpty);
      final oldRows = await database.scopedOutbox(
        accountId: 'user-1',
        companyId: 'company-1',
      );
      expect(oldRows.single.state, 'pending');
    },
  );

  test(
    'discard needs-attention entry atomically reverses optimistic totals',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      addTearDown(storage.close);
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      var now = DateTime.utc(2026, 7, 30, 12);
      final api = _MockApiClient();
      final repository = LedgerRepository(api, storage, now: () => now);
      final mutation = await repository.queueEntryCreation(
        partyId: 'party-1',
        action: EntryAction.gave,
        amountPaise: 900,
        narration: '',
        entryDate: '2026-07-30',
        idempotencyKey: '99999999-9999-4999-8999-999999999999',
      );
      now = now.add(const Duration(seconds: 9));
      when(
        () => api.post('/api/entries', data: any(named: 'data')),
      ).thenThrow(const ApiFailure('Forbidden', statusCode: 403));
      await repository.syncPending(pullRemoteChanges: false);

      final result = await repository.discardNeedsAttention(
        mutation.operationId,
      );

      expect(result, DiscardNeedsAttentionResult.discarded);
      expect(repository.cachedBootstrap()!.entries, isEmpty);
      expect(repository.cachedBootstrap()!.parties.single.balancePaise, 0);
      expect(repository.cachedBootstrap()!.parties.single.transactionCount, 0);
      expect(await storage.readOutbox(), isEmpty);
    },
  );

  test(
    'needs-attention entry revision is scoped, atomic, and identifier-stable',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final storage = await AppStorage(database: database).init();
      addTearDown(storage.close);
      await storage.cacheBootstrap(_bootstrap(syncCursor: '4'));
      var now = DateTime.utc(2026, 7, 30, 12);
      final api = _MockApiClient();
      final repository = LedgerRepository(api, storage, now: () => now);
      final mutation = await repository.queueEntryCreation(
        partyId: 'party-1',
        action: EntryAction.gave,
        amountPaise: 900,
        narration: 'Wrong',
        entryDate: '2026-07-30',
        idempotencyKey: '90909090-9090-4090-8090-909090909090',
      );
      now = now.add(const Duration(seconds: 9));
      when(
        () => api.post('/api/entries', data: any(named: 'data')),
      ).thenThrow(const ApiFailure('Forbidden', statusCode: 403));
      await repository.syncPending(pullRemoteChanges: false);
      final failed = (await storage.readOutbox()).single;
      expect(failed.state, OutboxState.needsAttention);

      await storage.cacheBootstrap(
        _bootstrap(
          syncCursor: '10',
          userId: 'user-2',
          companyId: 'company-2',
          partyId: 'party-2',
        ),
      );
      expect(
        await repository.reviseNeedsAttentionEntry(
          operationId: mutation.operationId,
          action: EntryAction.received,
          amountPaise: 1500,
          narration: 'Corrected',
          entryDate: '2026-07-31',
        ),
        ReviseNeedsAttentionResult.notFound,
      );
      final untouched = await database.scopedOutbox(
        accountId: 'user-1',
        companyId: 'company-1',
      );
      expect(untouched.single.state, 'needs_attention');

      await expectLater(
        storage.cacheBootstrap(_bootstrap(syncCursor: '4')),
        throwsA(isA<PendingOutboxConflict>()),
      );
      final result = await repository.reviseNeedsAttentionEntry(
        operationId: mutation.operationId,
        action: EntryAction.received,
        amountPaise: 1500,
        narration: 'Corrected',
        entryDate: '2026-07-31',
      );

      expect(result, ReviseNeedsAttentionResult.revised);
      final revised = (await storage.readOutbox()).single;
      expect(revised.id, failed.id);
      expect(revised.payload['clientId'], failed.payload['clientId']);
      expect(
        revised.payload['idempotencyKey'],
        failed.payload['idempotencyKey'],
      );
      expect(revised.dependsOnOperationId, failed.dependsOnOperationId);
      expect(revised.state, OutboxState.pending);
      expect(revised.attempts, 0);
      expect(revised.lastStatusCode, isNull);
      expect(revised.lastErrorCode, isNull);
      expect(revised.lastErrorCategory, isNull);
      expect(revised.nextAttemptAt, isNull);
      expect(revised.payload['action'], 'received');
      expect(revised.payload['amountPaise'], 1500);
      expect(revised.payload['narration'], 'Corrected');
      expect(revised.payload['entryDate'], '2026-07-31');

      final snapshot = repository.cachedBootstrap()!;
      expect(snapshot.entries.single.id, mutation.entityId);
      expect(snapshot.entries.single.action, EntryAction.received);
      expect(snapshot.entries.single.amountPaise, 1500);
      expect(snapshot.entries.single.balanceEffectPaise, -1500);
      expect(snapshot.entries.single.localSyncStatus, LocalSyncStatus.pending);
      expect(snapshot.parties.single.balancePaise, -1500);
      expect(snapshot.parties.single.transactionCount, 1);
    },
  );
}

Map<String, dynamic> _bootstrap({
  required String? syncCursor,
  String userId = 'user-1',
  String companyId = 'company-1',
  String partyId = 'party-1',
}) => {
  'user': {
    'id': userId,
    'phoneE164': '+919999999999',
    'fullName': 'Tester',
    'language': 'en',
    'accessibilityMode': false,
    'version': 1,
  },
  'company': {
    'id': companyId,
    'name': 'My Hisaab',
    'currency': 'INR',
    'timezone': 'Asia/Kolkata',
    'version': 1,
  },
  'companies': <Object>[],
  'groups': <Object>[],
  'parties': [
    {
      'id': partyId,
      'reference': 'HSB-PARTY1',
      'name': 'Asha',
      'shortName': '',
      'phone': '',
      'notes': '',
      'groupId': null,
      'groupName': null,
      'balancePaise': 0,
      'transactionCount': 0,
      'archivedAt': null,
      'createdAt': '2026-07-30T00:00:00.000Z',
      'version': 1,
      'updatedAt': '2026-07-30T00:00:00.000Z',
    },
  ],
  'entries': <Object>[],
  'serverTime': '2026-07-30T00:00:00.000Z',
  'syncCursor': ?syncCursor,
};

Response<dynamic> apiResponse(Object data) => Response<dynamic>(
  requestOptions: RequestOptions(),
  statusCode: 200,
  data: data,
);
