import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/core/utils/phone_utils.dart';

void main() {
  group('phone normalization', () {
    test('normalizes an Indian local number to E.164', () {
      expect(normalizePhoneE164('98765 43210'), '+919876543210');
      expect(phoneDigitsForExternalApp('98765-43210'), '919876543210');
    });

    test('preserves a valid international country code', () {
      expect(normalizePhoneE164('+1 (415) 555-2671'), '+14155552671');
    });

    test('never fabricates an E.164 value for an invalid number', () {
      expect(normalizePhoneE164('12345'), isEmpty);
      expect(phoneDigitsForExternalApp('12345'), isEmpty);
      expect(phoneMatchKey('12345'), '12345');
    });
  });
}
