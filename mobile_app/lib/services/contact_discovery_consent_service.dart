import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/app_storage.dart';

enum ContactDiscoveryConsent { notAsked, declined, granted }

abstract class ContactDiscoveryConsentService {
  Future<ContactDiscoveryConsent> status();

  Future<void> setGranted(bool granted);
}

class SharedPreferencesContactDiscoveryConsentService
    implements ContactDiscoveryConsentService {
  const SharedPreferencesContactDiscoveryConsentService(this._storage);

  final AppStorage _storage;

  static const currentVersion = 1;
  static const _versionKey = 'contact_discovery_consent_version';
  static const _grantedKey = 'contact_discovery_consent_granted';

  @override
  Future<ContactDiscoveryConsent> status() async {
    final scope = _storage.activeScope;
    if (scope == null) return ContactDiscoveryConsent.notAsked;
    final preferences = await SharedPreferences.getInstance();
    final versionKey = _scopedKey(_versionKey, scope);
    final grantedKey = _scopedKey(_grantedKey, scope);
    if (preferences.getInt(versionKey) != currentVersion ||
        !preferences.containsKey(grantedKey)) {
      return ContactDiscoveryConsent.notAsked;
    }
    return preferences.getBool(grantedKey) == true
        ? ContactDiscoveryConsent.granted
        : ContactDiscoveryConsent.declined;
  }

  @override
  Future<void> setGranted(bool granted) async {
    final scope = _storage.activeScope;
    if (scope == null) {
      throw StateError(
        'Contact discovery consent requires an authenticated account scope.',
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_scopedKey(_versionKey, scope), currentVersion);
    await preferences.setBool(_scopedKey(_grantedKey, scope), granted);
  }

  String _scopedKey(String key, StorageScope scope) =>
      '$key.${scope.accountId}.${scope.companyId}';
}
