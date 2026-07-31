import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/core/utils/formatters.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_IN'));

  group('money formatting', () {
    test('uses the Indian numbering system and rupee symbol', () {
      expect(formatMoney(12345600), '₹1,23,456');
      expect(formatMoney(-12345600), '-₹1,23,456');
      expect(formatMoney(-12345600, absolute: true), '₹1,23,456');
      expect(formatMoney(1), '₹0.01');
      expect(formatMoney(150), '₹1.50');
      expect(formatMoney(12345678), '₹1,23,456.78');
      expect(formatMoney(-150), '-₹1.50');
      expect(formatMoney(-150, absolute: true), '₹1.50');
    });

    test('shows the product entry signs for gave and received', () {
      expect(formatSignedEntryMoney(125000, gave: true), '−₹1,250');
      expect(formatSignedEntryMoney(125000, gave: false), '+₹1,250');
    });
  });

  group('rupeesTextToPaise', () {
    test('converts whole, grouped, and decimal rupee values', () {
      expect(rupeesTextToPaise('125'), 12500);
      expect(rupeesTextToPaise(' 1,234.56 '), 123456);
      expect(rupeesTextToPaise('0.01'), 1);
      expect(rupeesTextToPaise('10.999'), isNull);
      expect(rupeesTextToPaise('999999999'), maximumLedgerAmountPaise);
      expect(rupeesTextToPaise('1000000000'), isNull);
    });

    test('rejects empty, invalid, zero, and negative amounts', () {
      expect(rupeesTextToPaise(''), isNull);
      expect(rupeesTextToPaise('not money'), isNull);
      expect(rupeesTextToPaise('0'), isNull);
      expect(rupeesTextToPaise('-50'), isNull);
    });
  });

  group('date formatting', () {
    test('formats display and API dates', () {
      final date = DateTime(2026, 7, 5);

      expect(formatShortDate(date), '5 Jul 2026');
      expect(dateOnly(date), '2026-07-05');
    });
  });

  group('initials', () {
    test('uses at most the first two words', () {
      expect(initials('asha gupta'), 'AG');
      expect(initials('Mohan'), 'M');
      expect(initials('Ravi Kumar Sharma'), 'RK');
    });

    test('normalizes whitespace and handles an empty name', () {
      expect(initials('  Asha   Gupta  '), 'AG');
      expect(initials('   '), '?');
    });
  });
}
