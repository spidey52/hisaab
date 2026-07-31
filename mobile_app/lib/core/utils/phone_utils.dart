import 'package:phone_numbers_parser/phone_numbers_parser.dart';

String normalizePhoneE164(String input, {IsoCode defaultRegion = IsoCode.IN}) {
  final parsed = _tryParse(input, defaultRegion: defaultRegion);
  return parsed?.isValid() == true ? parsed!.international : '';
}

String phoneMatchKey(String input, {IsoCode defaultRegion = IsoCode.IN}) {
  final normalized = normalizePhoneE164(input, defaultRegion: defaultRegion);
  if (normalized.isNotEmpty) return normalized;
  return input.replaceAll(RegExp(r'\D'), '');
}

String phoneDigitsForExternalApp(
  String input, {
  IsoCode defaultRegion = IsoCode.IN,
}) {
  final normalized = normalizePhoneE164(input, defaultRegion: defaultRegion);
  return normalized.replaceAll(RegExp(r'\D'), '');
}

String formatPhoneForDisplay(
  String input, {
  IsoCode defaultRegion = IsoCode.IN,
}) {
  final parsed = _tryParse(input, defaultRegion: defaultRegion);
  if (parsed?.isValid() != true) return input.trim();
  return '+${parsed!.countryCode} '
      '${parsed.formatNsn(format: NsnFormat.international)}';
}

PhoneNumber? _tryParse(String input, {required IsoCode defaultRegion}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final hasInternationalPrefix =
      trimmed.startsWith('+') || trimmed.startsWith('00');
  try {
    return PhoneNumber.parse(
      trimmed,
      destinationCountry: hasInternationalPrefix ? null : defaultRegion,
    );
  } on PhoneNumberException {
    return null;
  } on FormatException {
    return null;
  }
}
