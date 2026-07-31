import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/core/network/api_failure.dart';
import 'package:hisaab_mobile/core/storage/app_storage.dart';
import 'package:hisaab_mobile/data/models/models.dart';
import 'package:hisaab_mobile/data/repositories/ledger_repository.dart';
import 'package:hisaab_mobile/features/ledger/ledger_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockLedgerRepository extends Mock implements LedgerRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockLedgerRepository repository;
  late LedgerController controller;

  setUp(() {
    repository = _MockLedgerRepository();
    controller = LedgerController(repository);
    controller.data.value = _bootstrap();
  });

  test('party search keeps names with spaces discoverable', () {
    controller.partySearch.value = 'Asha Retail';
    expect(controller.filteredParties.single.name, 'Asha Retail');
  });

  test('party balance filters follow backend signed balance semantics', () {
    controller.partyFilter.value = 'receive';
    expect(controller.filteredParties.map((party) => party.name), [
      'Asha Retail',
    ]);

    controller.partyFilter.value = 'pay';
    expect(controller.filteredParties.map((party) => party.name), ['Supplier']);
  });

  test('entry direction filter derives meaning from action', () {
    controller.entryDirection.value = 'gave';
    expect(
      controller.filteredEntries.every(
        (entry) => entry.action == EntryAction.gave,
      ),
      isTrue,
    );

    controller.entryDirection.value = 'received';
    expect(
      controller.filteredEntries.every(
        (entry) => entry.action == EntryAction.received,
      ),
      isTrue,
    );
  });

  test('full reload and incremental sync never overlap', () async {
    final bootstrapResponse = Completer<BootstrapData>();
    when(() => repository.outboxSummary()).thenAnswer(
      (_) async => const OutboxSummary(
        pendingCount: 0,
        needsAttentionCount: 0,
        nextAttemptAt: null,
      ),
    );
    when(
      () => repository.bootstrap(),
    ).thenAnswer((_) => bootstrapResponse.future);
    when(
      () => repository.syncMetadata(),
    ).thenAnswer((_) async => const LocalSyncMetadata(syncCursor: '4'));
    when(
      () => repository.syncPending(
        pullRemoteChanges: any(named: 'pullRemoteChanges'),
      ),
    ).thenAnswer(
      (_) async => SyncRunResult(
        uploadedCount: 0,
        pulledCount: 0,
        pendingCount: 0,
        needsAttentionCount: 0,
        authenticationRequired: false,
        nextAttemptAt: null,
        lastSyncedAt: DateTime.utc(2026, 7, 30, 12),
        failure: null,
        bootstrap: _bootstrap(),
      ),
    );

    final reload = controller.reload();
    await untilCalled(() => repository.bootstrap());
    final syncing = controller.syncNow();
    verifyNever(
      () => repository.syncPending(
        pullRemoteChanges: any(named: 'pullRemoteChanges'),
      ),
    );

    bootstrapResponse.complete(_bootstrap());
    await reload;
    await syncing;

    verify(() => repository.syncPending(pullRemoteChanges: true)).called(1);
  });

  test(
    'export refuses an incomplete server copy while changes are queued',
    () async {
      when(() => repository.outboxSummary()).thenAnswer(
        (_) async => const OutboxSummary(
          pendingCount: 1,
          needsAttentionCount: 0,
          nextAttemptAt: null,
        ),
      );

      await expectLater(controller.exportLedger(), throwsA(isA<ApiFailure>()));
      verifyNever(
        () => repository.exportLedger(format: LedgerExportFormat.json),
      );
    },
  );
}

BootstrapData _bootstrap() => BootstrapData(
  user: const AppUser(
    id: 'user',
    phoneE164: '+919999999999',
    fullName: 'Tester',
    language: 'en',
    accessibilityMode: false,
  ),
  company: const Company(
    id: 'company',
    name: 'My Hisaab',
    currency: 'INR',
    timezone: 'Asia/Kolkata',
  ),
  companies: const [],
  groups: const [],
  parties: [
    _party('receive', 'Asha Retail', 50000),
    _party('pay', 'Supplier', -25000),
  ],
  entries: [
    _entry('gave', EntryAction.gave),
    _entry('got', EntryAction.received),
  ],
  serverTime: DateTime(2026, 7, 30),
);

Party _party(String id, String name, int balancePaise) => Party(
  id: id,
  reference: 'HSB-$id',
  name: name,
  shortName: '',
  phone: '',
  notes: '',
  groupId: null,
  groupName: null,
  balancePaise: balancePaise,
  transactionCount: 0,
  archivedAt: null,
  createdAt: DateTime(2026, 7, 30),
);

LedgerEntry _entry(String id, EntryAction action) => LedgerEntry(
  id: id,
  partyId: 'receive',
  partyName: 'Asha Retail',
  sequence: action == EntryAction.gave ? 1 : 2,
  action: action,
  amountPaise: 10000,
  balanceEffectPaise: action == EntryAction.gave ? 10000 : -10000,
  narration: '',
  entryDate: DateTime.now(),
  paymentAccount: null,
  status: EntryStatus.posted,
  createdByName: 'Tester',
  createdAt: DateTime.now(),
  editedAt: null,
  cancelledAt: null,
  revisionCount: 0,
);
