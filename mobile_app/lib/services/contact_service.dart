import 'package:flutter_contacts/flutter_contacts.dart';

import '../core/network/api_client.dart';
import '../core/utils/phone_utils.dart';

enum ContactAccessStatus {
  notDetermined,
  granted,
  limited,
  denied,
  permanentlyDenied,
  restricted,
}

enum ContactDirectoryKind { alreadyInLedger, onHisaab, other }

class ContactPickResult {
  ContactPickResult({
    required this.name,
    required List<String> phones,
    required this.preferredPhone,
    this.kind = ContactDirectoryKind.other,
  }) : phones = List.unmodifiable(phones);

  final String name;
  final List<String> phones;
  final String preferredPhone;
  final ContactDirectoryKind kind;

  String get phone => preferredPhone;
  String get normalizedPhone => normalizePhoneE164(preferredPhone);
}

class ContactDirectory {
  ContactDirectory({
    required List<ContactPickResult> alreadyInLedger,
    required List<ContactPickResult> onHisaab,
    required List<ContactPickResult> other,
    required this.hisaabMatchingAvailable,
    this.discoveryCheckedCount = 0,
    this.discoveryTruncated = false,
  }) : alreadyInLedger = List.unmodifiable(alreadyInLedger),
       onHisaab = List.unmodifiable(onHisaab),
       other = List.unmodifiable(other);

  final List<ContactPickResult> alreadyInLedger;
  final List<ContactPickResult> onHisaab;
  final List<ContactPickResult> other;
  final bool hisaabMatchingAvailable;
  final int discoveryCheckedCount;
  final bool discoveryTruncated;

  bool get isEmpty =>
      alreadyInLedger.isEmpty && onHisaab.isEmpty && other.isEmpty;
}

class ContactDiscoveryResult {
  const ContactDiscoveryResult({
    required this.available,
    this.registeredPhones = const {},
    this.checkedPhoneCount = 0,
    this.truncated = false,
  });

  final bool available;
  final Set<String> registeredPhones;
  final int checkedPhoneCount;
  final bool truncated;
}

/// Privacy boundary for account discovery.
///
/// The default adapter never uploads contacts. A backend implementation should
/// only be installed after the product has an explicit opt-in, abuse controls,
/// and a privacy-reviewed matching protocol.
abstract class ContactDiscoveryAdapter {
  Future<ContactDiscoveryResult> matchRegisteredPhones(
    Set<String> normalizedPhones,
  );
}

class UnavailableContactDiscoveryAdapter implements ContactDiscoveryAdapter {
  const UnavailableContactDiscoveryAdapter();

  @override
  Future<ContactDiscoveryResult> matchRegisteredPhones(
    Set<String> normalizedPhones,
  ) async => const ContactDiscoveryResult(available: false);
}

class ApiContactDiscoveryAdapter implements ContactDiscoveryAdapter {
  const ApiContactDiscoveryAdapter(this._api);

  final ApiClient _api;

  @override
  Future<ContactDiscoveryResult> matchRegisteredPhones(
    Set<String> normalizedPhones,
  ) async {
    final allPhones = normalizedPhones
        .map(normalizePhoneE164)
        .where((phone) => phone.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final phones = allPhones.take(2500).toList(growable: false);
    if (phones.isEmpty) {
      return const ContactDiscoveryResult(
        available: true,
        registeredPhones: {},
      );
    }
    final registered = <String>{};
    for (final batch in contactDiscoveryBatches(phones)) {
      final response = await _api.post(
        '/api/contact-discovery',
        data: {'phones': batch},
      );
      final payload = response.data;
      final matches = payload is Map ? payload['matches'] : null;
      if (matches is List) {
        registered.addAll(
          matches
              .map((value) => phoneMatchKey(value.toString()))
              .where((phone) => phone.isNotEmpty),
        );
      }
    }
    return ContactDiscoveryResult(
      available: true,
      registeredPhones: registered,
      checkedPhoneCount: phones.length,
      truncated: allPhones.length > phones.length,
    );
  }
}

List<List<String>> contactDiscoveryBatches(
  Iterable<String> phones, {
  int batchSize = 500,
}) {
  if (batchSize <= 0) {
    throw ArgumentError.value(batchSize, 'batchSize', 'Must be positive.');
  }
  final values = phones.toList(growable: false);
  return [
    for (var start = 0; start < values.length; start += batchSize)
      values.sublist(start, (start + batchSize).clamp(0, values.length)),
  ];
}

class ContactPermissionDenied implements Exception {
  const ContactPermissionDenied();
}

class ContactPermissionPermanentlyDenied implements Exception {
  const ContactPermissionPermanentlyDenied();
}

class ContactPermissionRestricted implements Exception {
  const ContactPermissionRestricted();
}

abstract class ContactService {
  Future<ContactAccessStatus> permissionStatus();

  Future<ContactDirectory> directory({
    required Set<String> ledgerPhones,
    bool discoverOnHisaab = false,
  });

  Future<ContactPickResult?> pick();

  Future<void> openSettings();
}

class DeviceContactService implements ContactService {
  DeviceContactService({
    this.discovery = const UnavailableContactDiscoveryAdapter(),
  });

  final ContactDiscoveryAdapter discovery;

  @override
  Future<ContactAccessStatus> permissionStatus() async => _contactAccessStatus(
    await FlutterContacts.permissions.check(PermissionType.read),
  );

  @override
  Future<ContactDirectory> directory({
    required Set<String> ledgerPhones,
    bool discoverOnHisaab = false,
  }) async {
    await _ensurePermission();
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final results = contacts
        .map(_fromDeviceContact)
        .where((contact) => contact.phones.isNotEmpty)
        .toList();
    final allPhones = results
        .expand((contact) => contact.phones)
        .map(normalizePhoneE164)
        .where((phone) => phone.isNotEmpty)
        .toSet();
    var discoveryResult = const ContactDiscoveryResult(available: false);
    if (discoverOnHisaab) {
      try {
        discoveryResult = await discovery.matchRegisteredPhones(allPhones);
      } catch (_) {
        // Contact enumeration remains useful offline. Account discovery is an
        // optional, privacy-gated enhancement and must not hide local contacts.
      }
    }
    return groupContactDirectory(
      results,
      ledgerPhones: ledgerPhones,
      registeredPhones: discoveryResult.registeredPhones,
      hisaabMatchingAvailable: discoveryResult.available,
      discoveryCheckedCount: discoveryResult.checkedPhoneCount,
      discoveryTruncated: discoveryResult.truncated,
    );
  }

  @override
  Future<ContactPickResult?> pick() async {
    await _ensurePermission();
    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.phone},
    );
    return contact == null ? null : _fromDeviceContact(contact);
  }

  Future<void> _ensurePermission() async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    switch (permission) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return;
      case PermissionStatus.permanentlyDenied:
        throw const ContactPermissionPermanentlyDenied();
      case PermissionStatus.restricted:
        throw const ContactPermissionRestricted();
      case PermissionStatus.denied:
      case PermissionStatus.notDetermined:
        throw const ContactPermissionDenied();
    }
  }

  @override
  Future<void> openSettings() => FlutterContacts.permissions.openSettings();
}

ContactDirectory groupContactDirectory(
  Iterable<ContactPickResult> contacts, {
  required Set<String> ledgerPhones,
  Set<String> registeredPhones = const {},
  bool hisaabMatchingAvailable = false,
  int discoveryCheckedCount = 0,
  bool discoveryTruncated = false,
}) {
  final ledgerKeys = ledgerPhones.map(phoneMatchKey).toSet()..remove('');
  final registeredKeys = registeredPhones.map(phoneMatchKey).toSet()
    ..remove('');
  final already = <ContactPickResult>[];
  final onHisaab = <ContactPickResult>[];
  final other = <ContactPickResult>[];

  for (final contact in contacts) {
    final phoneKeys = contact.phones.map(phoneMatchKey).toSet()..remove('');
    final kind = phoneKeys.any(ledgerKeys.contains)
        ? ContactDirectoryKind.alreadyInLedger
        : phoneKeys.any(registeredKeys.contains)
        ? ContactDirectoryKind.onHisaab
        : ContactDirectoryKind.other;
    final grouped = ContactPickResult(
      name: contact.name,
      phones: contact.phones,
      preferredPhone: contact.preferredPhone,
      kind: kind,
    );
    switch (kind) {
      case ContactDirectoryKind.alreadyInLedger:
        already.add(grouped);
      case ContactDirectoryKind.onHisaab:
        onHisaab.add(grouped);
      case ContactDirectoryKind.other:
        other.add(grouped);
    }
  }

  int byName(ContactPickResult a, ContactPickResult b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  already.sort(byName);
  onHisaab.sort(byName);
  other.sort(byName);
  return ContactDirectory(
    alreadyInLedger: already,
    onHisaab: onHisaab,
    other: other,
    hisaabMatchingAvailable: hisaabMatchingAvailable,
    discoveryCheckedCount: discoveryCheckedCount,
    discoveryTruncated: discoveryTruncated,
  );
}

ContactPickResult _fromDeviceContact(Contact contact) {
  final phones = <String>[];
  final seen = <String>{};
  String? primaryPhone;
  for (final phone in contact.phones) {
    final number = phone.number.trim();
    final key = phoneMatchKey(number);
    if (number.isEmpty || key.isEmpty || !seen.add(key)) continue;
    phones.add(number);
    if (phone.isPrimary == true && primaryPhone == null) {
      primaryPhone = number;
    }
  }
  return ContactPickResult(
    name: contact.displayName?.trim() ?? '',
    phones: phones,
    preferredPhone: primaryPhone ?? (phones.isEmpty ? '' : phones.first),
  );
}

ContactAccessStatus _contactAccessStatus(PermissionStatus status) =>
    switch (status) {
      PermissionStatus.granted => ContactAccessStatus.granted,
      PermissionStatus.limited => ContactAccessStatus.limited,
      PermissionStatus.denied => ContactAccessStatus.denied,
      PermissionStatus.permanentlyDenied =>
        ContactAccessStatus.permanentlyDenied,
      PermissionStatus.restricted => ContactAccessStatus.restricted,
      PermissionStatus.notDetermined => ContactAccessStatus.notDetermined,
    };
