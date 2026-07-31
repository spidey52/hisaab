import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/data/models/models.dart';
import 'package:hisaab_mobile/services/party_communication_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('en_IN'));

  test('builds safe phone and WhatsApp composer URIs', () {
    expect(buildDialerUri('98765 43210').toString(), 'tel:+919876543210');
    expect(buildDialerUri('12345'), isNull);

    final uri = buildWhatsAppUri('+91 98765 43210', 'Hello & नमस्ते');
    expect(uri?.scheme, 'https');
    expect(uri?.host, 'wa.me');
    expect(uri?.path, '/919876543210');
    expect(uri?.queryParameters['text'], 'Hello & नमस्ते');

    final sms = buildSmsUri('+91 98765 43210', 'Balance: ₹10 & paid');
    expect(sms?.scheme, 'sms');
    expect(sms?.path, '+919876543210');
    expect(sms?.queryParameters['body'], 'Balance: ₹10 & paid');
  });

  test(
    'statement summary excludes notes by default and marks pending data',
    () {
      final data = _statement(
        authoritative: false,
        entries: [
          StatementShareEntry(entry: _entry(note: 'Private stock note')),
          StatementShareEntry(
            entry: _entry(id: 'pending', sequence: 2),
            provisional: true,
          ),
        ],
      );

      final summary = buildStatementMessage(data);

      expect(summary, contains('Provisional copy'));
      expect(summary, contains('Pending sync'));
      expect(summary, isNot(contains('Private stock note')));
      expect(
        buildStatementMessage(data, includeNotes: true),
        contains('Private stock note'),
      );
    },
  );

  test('generates a real multi-page PDF for a long statement', () async {
    final entries = List.generate(
      180,
      (index) => StatementShareEntry(
        entry: _entry(
          id: 'entry-$index',
          sequence: index + 1,
          note: 'Line $index',
        ),
        runningBalancePaise: (index + 1) * 100,
        provisional: index == 179,
      ),
    );

    final bytes = await buildStatementPdf(
      _statement(authoritative: false, entries: entries),
    );

    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(10000));
  });

  test('embeds offline fonts for Hindi party names and notes', () async {
    final data = StatementShareData(
      ledgerName: 'मेरा हिसाब',
      partyName: 'मोहन किराना',
      from: DateTime(2026, 7),
      to: DateTime(2026, 7, 30),
      openingBalancePaise: 0,
      closingBalancePaise: 15000,
      entries: [
        StatementShareEntry(
          entry: _entry(note: 'सामान की बिक्री'),
          runningBalancePaise: 15000,
        ),
      ],
    );

    final bytes = await buildStatementPdf(data, includeNotes: true);

    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(5000));
  });
}

StatementShareData _statement({
  required bool authoritative,
  required List<StatementShareEntry> entries,
}) => StatementShareData(
  ledgerName: 'Asha Stores',
  partyName: 'Mohan Traders',
  from: DateTime(2026, 7),
  to: DateTime(2026, 7, 30),
  openingBalancePaise: 10000,
  closingBalancePaise: 25000,
  entries: entries,
  authoritative: authoritative,
);

LedgerEntry _entry({
  String id = 'entry-1',
  int sequence = 1,
  String note = '',
}) => LedgerEntry(
  id: id,
  partyId: 'party-1',
  partyName: 'Mohan Traders',
  sequence: sequence,
  action: EntryAction.gave,
  amountPaise: 15000,
  balanceEffectPaise: 15000,
  narration: note,
  entryDate: DateTime(2026, 7, 10),
  paymentAccount: null,
  status: EntryStatus.posted,
  createdByName: 'Asha',
  createdAt: DateTime(2026, 7, 10),
  editedAt: null,
  cancelledAt: null,
  revisionCount: 0,
);
