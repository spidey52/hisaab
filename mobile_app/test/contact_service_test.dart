import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/services/contact_service.dart';

void main() {
  test('groups and sorts contacts without hiding non-Hisaab contacts', () {
    final directory = groupContactDirectory(
      [
        ContactPickResult(
          name: 'Zoya',
          phones: const ['9876543210'],
          preferredPhone: '9876543210',
        ),
        ContactPickResult(
          name: 'Asha',
          phones: const ['9123456789'],
          preferredPhone: '9123456789',
        ),
        ContactPickResult(
          name: 'Bhavna',
          phones: const ['9988776655'],
          preferredPhone: '9988776655',
        ),
      ],
      ledgerPhones: const {'+919123456789'},
      registeredPhones: const {'+919988776655'},
      hisaabMatchingAvailable: true,
    );

    expect(directory.alreadyInLedger.map((contact) => contact.name), ['Asha']);
    expect(directory.onHisaab.map((contact) => contact.name), ['Bhavna']);
    expect(directory.other.map((contact) => contact.name), ['Zoya']);
    expect(directory.hisaabMatchingAvailable, isTrue);
  });

  test('ledger membership takes precedence over Hisaab discovery', () {
    final contact = ContactPickResult(
      name: 'Asha',
      phones: const ['+91 91234 56789'],
      preferredPhone: '+91 91234 56789',
    );

    final directory = groupContactDirectory(
      [contact],
      ledgerPhones: const {'9123456789'},
      registeredPhones: const {'+919123456789'},
      hisaabMatchingAvailable: true,
    );

    expect(directory.alreadyInLedger, hasLength(1));
    expect(directory.onHisaab, isEmpty);
  });

  test('batches discovery requests at the server limit', () {
    final phones = List.generate(1201, (index) => '+9190000$index');
    final batches = contactDiscoveryBatches(phones);

    expect(batches.map((batch) => batch.length), [500, 500, 201]);
    expect(batches.expand((batch) => batch), phones);
  });
}
