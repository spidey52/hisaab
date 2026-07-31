import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/core/network/api_client.dart';
import 'package:hisaab_mobile/core/storage/app_storage.dart';
import 'package:hisaab_mobile/data/models/models.dart';
import 'package:hisaab_mobile/data/repositories/ledger_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockStorage extends Mock implements AppStorage {}

void main() {
  late _MockApiClient api;
  late LedgerRepository repository;

  setUp(() {
    api = _MockApiClient();
    repository = LedgerRepository(api, _MockStorage());
  });

  test('create entry sends paise, blank note, and idempotency key', () async {
    when(
      () => api.post(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => _response(201));

    await repository.createEntry(
      partyId: 'party-1',
      action: EntryAction.gave,
      amountPaise: 12345,
      narration: '',
      entryDate: '2026-07-30',
      idempotencyKey: 'mobile-test-idempotency-key',
    );

    final captured =
        verify(
              () => api.post('/api/entries', data: captureAny(named: 'data')),
            ).captured.single
            as Map<String, dynamic>;
    expect(captured['action'], 'gave');
    expect(captured['amountPaise'], 12345);
    expect(captured['narration'], '');
    expect(captured['idempotencyKey'], 'mobile-test-idempotency-key');
  });

  test('party edit explicitly sends null to clear a group', () async {
    when(
      () => api.patch(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => _response(200));

    await repository.updateParty(
      id: 'party-1',
      name: 'Asha Retail',
      phone: '',
      shortName: '',
      notes: '',
      groupId: null,
      setGroupId: true,
    );

    final captured =
        verify(
              () => api.patch(
                '/api/parties/party-1',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(captured.containsKey('groupId'), isTrue);
    expect(captured['groupId'], isNull);
  });

  test('entry edit uses the audited operation payload', () async {
    when(
      () => api.patch(any(), data: any(named: 'data')),
    ).thenAnswer((_) async => _response(200));

    await repository.updateEntry(
      id: 'entry-1',
      partyId: 'party-1',
      action: EntryAction.received,
      amountPaise: 5000,
      narration: '',
      entryDate: '2026-07-30',
      paymentAccount: 'cash',
    );

    final captured =
        verify(
              () => api.patch(
                '/api/entries/entry-1',
                data: captureAny(named: 'data'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(captured['operation'], 'edit');
    expect(captured['partyId'], 'party-1');
    expect(captured['action'], 'received');
    expect(captured['amountPaise'], 5000);
    expect(captured['narration'], '');
    expect(captured['entryDate'], '2026-07-30');
    expect(captured['paymentAccount'], 'cash');
    expect(
      Uuid.isValidUUID(fromString: captured['idempotencyKey'] as String),
      isTrue,
    );
  });
}

Response<dynamic> _response(int statusCode) => Response<dynamic>(
  requestOptions: RequestOptions(),
  statusCode: statusCode,
  data: const <String, dynamic>{'ok': true},
);
