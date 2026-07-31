import 'package:intl/intl.dart';

const maximumLedgerAmountPaise = 99_99_99_99_900;

String formatMoney(int paise, {bool absolute = false}) {
  final negative = paise < 0 && !absolute;
  final magnitude = paise.abs();
  final whole = magnitude ~/ 100;
  final fraction = magnitude % 100;
  final suffix = fraction == 0 ? '' : '.${fraction.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}₹${_indianGroupedInteger(whole)}$suffix';
}

String formatSignedEntryMoney(int paise, {required bool gave}) =>
    '${gave ? '−' : '+'}${formatMoney(paise, absolute: true)}';

String formatShortDate(DateTime date) =>
    DateFormat('d MMM yyyy', Intl.getCurrentLocale()).format(date);

String dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

void setFormattingLocale(String languageCode) {
  Intl.defaultLocale = languageCode.toLowerCase().startsWith('hi')
      ? 'hi_IN'
      : 'en_IN';
}

int? rupeesTextToPaise(String input) {
  final cleaned = input.replaceAll(',', '').trim();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  if (whole == null) return null;
  final fractionText = match.group(2) ?? '';
  final fraction = fractionText.isEmpty
      ? 0
      : int.parse(fractionText.padRight(2, '0'));
  final paise = whole * 100 + fraction;
  return paise > 0 && paise <= maximumLedgerAmountPaise ? paise : null;
}

String _indianGroupedInteger(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final lastThree = digits.substring(digits.length - 3);
  final prefix = digits.substring(0, digits.length - 3);
  final firstGroupLength = prefix.length.isOdd ? 1 : 2;
  final groups = <String>[prefix.substring(0, firstGroupLength)];
  for (var index = firstGroupLength; index < prefix.length; index += 2) {
    groups.add(prefix.substring(index, index + 2));
  }
  return '${groups.join(',')},$lastThree';
}

String initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .toList();
  if (words.isEmpty) return '?';
  return words.map((word) => word[0].toUpperCase()).join();
}
