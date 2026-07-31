import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hisaab_mobile/core/storage/app_storage.dart';
import 'package:hisaab_mobile/features/sync/sync_change_editor.dart';
import 'package:hisaab_mobile/services/app_translations.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('corrects a rejected party without creating a new intent', (
    tester,
  ) async {
    SyncChangeRevision? revision;
    await tester.pumpWidget(
      _EditorHarness(
        operation: _operation(
          kind: OutboxKind.createParty,
          payload: const {'name': 'A', 'phone': ''},
        ),
        onResult: (value) => revision = value,
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save correction and retry'));
    await tester.pump();
    expect(find.text('Enter at least 2 characters'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Anita Traders',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number (optional)'),
      '+91 98765 43210',
    );
    await tester.tap(find.text('Save correction and retry'));
    await tester.pumpAndSettle();

    expect(revision?.kind, OutboxKind.createParty);
    expect(revision?.fields['name'], 'Anita Traders');
    expect(revision?.fields['phone'], '+91 98765 43210');
  });

  testWidgets('corrects the editable fields of a rejected entry', (
    tester,
  ) async {
    SyncChangeRevision? revision;
    await tester.pumpWidget(
      _EditorHarness(
        operation: _operation(
          kind: OutboxKind.createEntry,
          payload: const {
            'action': 'gave',
            'amountPaise': 10000,
            'narration': 'Old note',
            'entryDate': '2026-07-30',
          },
        ),
        onResult: (value) => revision = value,
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('You got'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '250');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Note (optional)'),
      'Corrected note',
    );
    await tester.tap(find.text('Save correction and retry'));
    await tester.pumpAndSettle();

    expect(revision?.kind, OutboxKind.createEntry);
    expect(revision?.fields, {
      'action': 'received',
      'amountPaise': 25000,
      'narration': 'Corrected note',
      'entryDate': '2026-07-30',
    });
  });
}

class _EditorHarness extends StatelessWidget {
  const _EditorHarness({required this.operation, required this.onResult});

  final StoredOutboxOperation operation;
  final ValueChanged<SyncChangeRevision?> onResult;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      translations: HisaabTranslations(),
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async =>
                  onResult(await showSyncChangeEditor(context, operation)),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
  }
}

StoredOutboxOperation _operation({
  required OutboxKind kind,
  required Map<String, dynamic> payload,
}) {
  final now = DateTime.utc(2026, 7, 30);
  return StoredOutboxOperation(
    id: '00000000-0000-4000-8000-000000000001',
    kind: kind,
    payload: payload,
    state: OutboxState.needsAttention,
    attempts: 1,
    createdAt: now,
    updatedAt: now,
    accountId: 'account-1',
    companyId: 'company-1',
  );
}
