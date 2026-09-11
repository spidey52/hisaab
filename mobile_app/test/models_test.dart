import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/data/models/models.dart';

void main() {
  group('Party.fromJson', () {
    test('parses backend fields and nullable optional values', () {
      final party = Party.fromJson(
        _partyJson(
          balancePaise: '125000',
          transactionCount: 3.0,
          groupId: null,
          groupName: null,
          archivedAt: null,
        ),
      );

      expect(party.id, 'party-1');
      expect(party.reference, 'HSB-1234ABCD');
      expect(party.name, 'Asha Stores');
      expect(party.balancePaise, 125000);
      expect(party.transactionCount, 3);
      expect(party.groupId, isNull);
      expect(party.groupName, isNull);
      expect(party.archivedAt, isNull);
      expect(party.isArchived, isFalse);
      expect(party.createdAt, DateTime.parse('2026-07-30 12:33:43+00'));
    });

    test('maps signed balances to the correct backend meaning', () {
      final receive = Party.fromJson(_partyJson(balancePaise: 25000));
      final pay = Party.fromJson(_partyJson(balancePaise: -25000));
      final settled = Party.fromJson(_partyJson(balancePaise: 0));

      expect(receive.balanceKind, BalanceKind.receive);
      expect(pay.balanceKind, BalanceKind.pay);
      expect(settled.balanceKind, BalanceKind.settled);
    });

    test('recognizes an archived party', () {
      final party = Party.fromJson(
        _partyJson(archivedAt: '2026-07-31T08:00:00.000Z'),
      );

      expect(party.isArchived, isTrue);
      expect(party.archivedAt, DateTime.utc(2026, 7, 31, 8));
    });
  });

  group('LedgerEntry.fromJson', () {
    test(
      'maps gave and received actions with their backend balance effects',
      () {
        final gave = LedgerEntry.fromJson(
          _entryJson(
            action: 'gave',
            amountPaise: '25000',
            balanceEffectPaise: 25000,
          ),
        );
        final received = LedgerEntry.fromJson(
          _entryJson(
            action: 'received',
            amountPaise: 10000.0,
            balanceEffectPaise: '-10000',
          ),
        );

        expect(gave.action, EntryAction.gave);
        expect(gave.isGave, isTrue);
        expect(gave.balanceEffectPaise, 25000);
        expect(received.action, EntryAction.received);
        expect(received.isGave, isFalse);
        expect(received.balanceEffectPaise, -10000);
      },
    );

    test('maps opening balances, cancellation, and nullable fields', () {
      final entry = LedgerEntry.fromJson(
        _entryJson(
          action: 'opening_balance',
          status: 'cancelled',
          paymentAccount: null,
          editedAt: null,
          cancelledAt: '2026-07-31T09:15:00.000Z',
        ),
      );

      expect(entry.action, EntryAction.openingBalance);
      expect(entry.isOpeningBalance, isTrue);
      expect(entry.status, EntryStatus.cancelled);
      expect(entry.paymentAccount, isNull);
      expect(entry.editedAt, isNull);
      expect(entry.cancelledAt, DateTime.utc(2026, 7, 31, 9, 15));
      expect(entry.entryDate, DateTime(2026, 7, 30));
    });

    test('parses Node Date.toString timestamps used by older API payloads', () {
      final entry = LedgerEntry.fromJson({
        ..._entryJson(),
        'createdAt':
            'Thu Sep 10 2026 08:17:53 GMT+0000 (Coordinated Universal Time)',
        'updatedAt':
            'Thu Sep 10 2026 08:17:53 GMT+0000 (Coordinated Universal Time)',
      });

      expect(entry.createdAt, DateTime.utc(2026, 9, 10, 8, 17, 53));
      expect(entry.updatedAt, DateTime.utc(2026, 9, 10, 8, 17, 53));
    });
  });

  group('BootstrapData.fromJson', () {
    test('parses the complete backend bootstrap structure', () {
      final data = BootstrapData.fromJson({
        'user': {
          'id': 'user-1',
          'phoneE164': '+919876543210',
          'fullName': 'Asha Gupta',
          'language': 'hi',
          'accessibilityMode': true,
        },
        'company': {
          'id': 'company-1',
          'name': 'Asha Stores',
          'currency': 'INR',
          'timezone': 'Asia/Kolkata',
        },
        'companies': [
          {
            'id': 'company-1',
            'name': 'Asha Stores',
            'currency': 'INR',
            'timezone': 'Asia/Kolkata',
          },
        ],
        'groups': [
          {'id': 'group-1', 'name': 'Suppliers'},
        ],
        'parties': [_partyJson(balancePaise: 0)],
        'entries': [_entryJson(action: 'received')],
        'serverTime': '2026-07-30T12:33:43.000Z',
      });

      expect(data.user.phoneE164, '+919876543210');
      expect(data.user.language, 'hi');
      expect(data.user.accessibilityMode, isTrue);
      expect(data.company.currency, 'INR');
      expect(data.companies, hasLength(1));
      expect(data.groups.single.name, 'Suppliers');
      expect(data.parties, hasLength(1));
      expect(data.entries.single.action, EntryAction.received);
      expect(data.serverTime, DateTime.utc(2026, 7, 30, 12, 33, 43));
    });

    test('treats null collection fields as empty lists', () {
      final data = BootstrapData.fromJson({
        'user': null,
        'company': null,
        'companies': null,
        'groups': null,
        'parties': null,
        'entries': null,
        'serverTime': '2026-07-30T00:00:00.000Z',
      });

      expect(data.user.id, isEmpty);
      expect(data.user.language, 'en');
      expect(data.company.name, 'My Hisaab');
      expect(data.company.currency, 'INR');
      expect(data.companies, isEmpty);
      expect(data.groups, isEmpty);
      expect(data.parties, isEmpty);
      expect(data.entries, isEmpty);
    });
  });
}

Map<String, dynamic> _partyJson({
  Object? balancePaise = 0,
  Object? transactionCount = 0,
  Object? groupId,
  Object? groupName,
  Object? archivedAt,
}) => {
  'id': 'party-1',
  'reference': 'HSB-1234ABCD',
  'name': 'Asha Stores',
  'shortName': 'Asha',
  'phone': '+91 98765 43210',
  'notes': '',
  'groupId': groupId,
  'groupName': groupName,
  'balancePaise': balancePaise,
  'transactionCount': transactionCount,
  'archivedAt': archivedAt,
  'createdAt': '2026-07-30 12:33:43+00',
};

Map<String, dynamic> _entryJson({
  Object? action = 'gave',
  Object? amountPaise = 25000,
  Object? balanceEffectPaise = 25000,
  Object? paymentAccount = 'cash',
  Object? status = 'posted',
  Object? editedAt = '2026-07-30T13:00:00.000Z',
  Object? cancelledAt,
}) => {
  'id': 'entry-1',
  'partyId': 'party-1',
  'partyName': 'Asha Stores',
  'sequence': '42',
  'action': action,
  'amountPaise': amountPaise,
  'balanceEffectPaise': balanceEffectPaise,
  'narration': '',
  'entryDate': '2026-07-30',
  'paymentAccount': paymentAccount,
  'status': status,
  'createdByName': 'Asha Gupta',
  'createdAt': '2026-07-30 12:33:43+00',
  'editedAt': editedAt,
  'cancelledAt': cancelledAt,
  'revisionCount': '2',
};
