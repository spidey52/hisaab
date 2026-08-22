import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hisaab_mobile/core/theme/app_theme.dart';
import 'package:hisaab_mobile/core/utils/formatters.dart';
import 'package:hisaab_mobile/data/models/models.dart';
import 'package:hisaab_mobile/shared/widgets/app_widgets.dart';
import 'package:hisaab_mobile/services/app_translations.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));

  testWidgets('gave entry uses red minus and plain-language label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        EntryTile(entry: _entry(action: EntryAction.gave, amountPaise: 125000)),
      ),
    );

    expect(find.text('−₹1,250'), findsOneWidget);
    expect(find.text('You gave'), findsOneWidget);
    final amount = tester.widget<Text>(find.text('−₹1,250'));
    expect(amount.style?.color, HisaabColors.light.red);
  });

  testWidgets('received entry uses green plus and plain-language label', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        EntryTile(
          entry: _entry(action: EntryAction.received, amountPaise: 5000),
        ),
      ),
    );

    expect(find.text('+₹50'), findsOneWidget);
    expect(find.text('You got'), findsOneWidget);
    final amount = tester.widget<Text>(find.text('+₹50'));
    expect(amount.style?.color, HisaabColors.light.greenDark);
  });

  testWidgets('blank note does not produce an empty narration row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        EntryTile(entry: _entry(action: EntryAction.gave, amountPaise: 10000)),
      ),
    );

    expect(find.text('No note'), findsNothing);
    expect(find.text('You gave'), findsOneWidget);
  });

  testWidgets('party tile explains both balance directions', (tester) async {
    await tester.pumpWidget(
      _testApp(
        Column(
          children: [
            PartyTile(party: _party(balancePaise: 25000)),
            PartyTile(
              party: _party(id: 'p2', name: 'Supplier', balancePaise: -9000),
            ),
          ],
        ),
      ),
    );

    expect(find.text('To receive'), findsOneWidget);
    expect(find.text('To pay'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    expect(find.text('₹90'), findsOneWidget);
  });

  testWidgets('party row reflows at 200 percent text without overflow', (
    tester,
  ) async {
    var rowTaps = 0;
    await tester.pumpWidget(
      _testApp(
        PartyTile(
          party: _party(
            name: 'Asha Retail and Wholesale Supplies',
            balancePaise: maximumLedgerAmountPaise,
          ),
          onTap: () => rowTaps++,
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(
      find.text('Asha Retail and Wholesale Supplies'),
      warnIfMissed: false,
    );
    expect(rowTaps, 1);
  });

  testWidgets('add-entry amount controls remain usable at 200 percent text', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1250.50');
    addTearDown(controller.dispose);
    var calculatorTaps = 0;
    await tester.pumpWidget(
      _testApp(
        Form(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AmountEntryField(
              controller: controller,
              calculatorVisible: false,
              gave: true,
              onToggleCalculator: () => calculatorTaps++,
              onChanged: (_) {},
            ),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Open calculator'), findsOneWidget);
    await tester.tap(find.byTooltip('Open calculator'));
    expect(calculatorTaps, 1);
  });

  testWidgets('calculator keys expose spoken semantics and use exact result', (
    tester,
  ) async {
    var expression = '10−3';
    int? usedPaise;
    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) => CalculatorKeypad(
            expression: expression,
            onExpressionChanged: (value) => setState(() => expression = value),
            onUseAmount: (value) => usedPaise = value,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Minus'), findsOneWidget);
    expect(find.bySemanticsLabel('Result 7 rupees'), findsOneWidget);
    await tester.tap(find.text('Use ₹7'));
    expect(usedPaise, 700);
  });

  testWidgets('direction buttons are independent and tappable', (tester) async {
    var selected = EntryAction.gave;
    await tester.pumpWidget(
      _testApp(
        Row(
          children: [
            Expanded(
              child: DirectionActionButton(
                action: EntryAction.gave,
                onPressed: () => selected = EntryAction.gave,
              ),
            ),
            Expanded(
              child: DirectionActionButton(
                action: EntryAction.received,
                onPressed: () => selected = EntryAction.received,
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('You got'));
    expect(selected, EntryAction.received);
  });

  testWidgets('Hindi locale changes a core transaction action', (tester) async {
    addTearDown(Get.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: HisaabTranslations(),
        locale: const Locale('hi'),
        home: Scaffold(
          body: DirectionActionButton(
            action: EntryAction.gave,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('आपने दिए'), findsOneWidget);
    expect(find.text('You gave'), findsNothing);
  });
}

Widget _testApp(Widget child, {TextScaler? textScaler}) => MaterialApp(
  theme: AppTheme.light,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: textScaler ?? TextScaler.noScaling),
      child: Scaffold(body: child),
    ),
  ),
);

LedgerEntry _entry({required EntryAction action, required int amountPaise}) =>
    LedgerEntry(
      id: 'entry-1',
      partyId: 'party-1',
      partyName: 'Asha Retail',
      sequence: 4,
      action: action,
      amountPaise: amountPaise,
      balanceEffectPaise: action == EntryAction.gave
          ? amountPaise
          : -amountPaise,
      narration: '',
      entryDate: DateTime(2026, 7, 30),
      paymentAccount: null,
      status: EntryStatus.posted,
      createdByName: 'Tester',
      createdAt: DateTime(2026, 7, 30),
      editedAt: null,
      cancelledAt: null,
      revisionCount: 0,
    );

Party _party({
  String id = 'p1',
  String name = 'Asha Retail',
  required int balancePaise,
}) => Party(
  id: id,
  reference: 'HSB-123',
  name: name,
  shortName: '',
  phone: '',
  notes: '',
  groupId: null,
  groupName: null,
  balancePaise: balancePaise,
  transactionCount: 1,
  archivedAt: null,
  createdAt: DateTime(2026, 7, 30),
);
