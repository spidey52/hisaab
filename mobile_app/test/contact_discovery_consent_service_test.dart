import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/core/storage/app_storage.dart';
import 'package:hisaab_mobile/services/contact_discovery_consent_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = _ScopedStorage();
  final service = SharedPreferencesContactDiscoveryConsentService(storage);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage.scope = const StorageScope(
      accountId: 'account-a',
      companyId: 'company-1',
    );
  });

  test('starts unasked and persists grant or revocation', () async {
    expect(await service.status(), ContactDiscoveryConsent.notAsked);

    await service.setGranted(true);
    expect(await service.status(), ContactDiscoveryConsent.granted);

    await service.setGranted(false);
    expect(await service.status(), ContactDiscoveryConsent.declined);
  });

  test('old consent versions are asked again', () async {
    SharedPreferences.setMockInitialValues({
      'contact_discovery_consent_version.account-a.company-1': 0,
      'contact_discovery_consent_granted.account-a.company-1': true,
    });

    expect(await service.status(), ContactDiscoveryConsent.notAsked);
  });

  test('does not leak consent between accounts or logged-out state', () async {
    await service.setGranted(true);
    expect(await service.status(), ContactDiscoveryConsent.granted);

    storage.scope = const StorageScope(
      accountId: 'account-b',
      companyId: 'company-1',
    );
    expect(await service.status(), ContactDiscoveryConsent.notAsked);
    await service.setGranted(false);

    storage.scope = const StorageScope(
      accountId: 'account-a',
      companyId: 'company-1',
    );
    expect(await service.status(), ContactDiscoveryConsent.granted);

    storage.scope = null;
    expect(await service.status(), ContactDiscoveryConsent.notAsked);
    await expectLater(service.setGranted(true), throwsStateError);
  });
}

class _ScopedStorage extends AppStorage {
  StorageScope? scope;

  @override
  StorageScope? get activeScope => scope;
}
