import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/core/config/app_config.dart';

void main() {
  group('release API origin validation', () {
    test('accepts a public HTTPS origin', () {
      expect(
        AppConfig.isPublicHttpsApiOrigin('https://api.hisaab.example'),
        isTrue,
      );
      expect(
        AppConfig.isPublicHttpsApiOrigin('https://fc-ledger.example'),
        isTrue,
      );
      expect(
        AppConfig.isPublicHttpsApiOrigin('https://api.hisaab.example:8443/'),
        isTrue,
      );
    });

    test('rejects private, insecure, credentialed, and path URLs', () {
      for (final value in [
        'http://api.hisaab.example',
        'https://localhost:3000',
        'https://127.0.0.1',
        'https://0.0.0.0',
        'https://10.0.2.2',
        'https://100.64.0.1',
        'https://192.168.1.2',
        'https://172.16.0.2',
        'https://[::1]',
        'https://[::ffff:127.0.0.1]',
        'https://[fd00::1]',
        'https://[fe80::1]',
        'https://device.example.ts.net',
        'https://user:password@api.hisaab.example',
        'https://api.hisaab.example/v1',
        'https://api.hisaab.example?debug=true',
      ]) {
        expect(AppConfig.isPublicHttpsApiOrigin(value), isFalse, reason: value);
      }
    });
  });

  group('self-hosted API origin validation', () {
    test('accepts full HTTPS URLs including paths', () {
      for (final value in [
        'https://api.hisaab.example',
        'https://hisaab.example.com:8443/',
        'https://192.168.1.2',
        'https://10.0.0.5:3000',
        'https://ledger.local',
        'https://hisaab.example.com/hisaab',
        'https://hisaab.example.com/app/',
        'hisaab.example.com',
      ]) {
        expect(
          AppConfig.isValidSelfHostedApiOrigin(value),
          isTrue,
          reason: value,
        );
      }
    });

    test('rejects credentialed, query, fragment, and non-http URLs', () {
      for (final value in [
        'https://user:password@api.hisaab.example',
        'https://api.hisaab.example?debug=true',
        'https://api.hisaab.example#section',
        'ftp://api.hisaab.example',
        '',
      ]) {
        expect(
          AppConfig.isValidSelfHostedApiOrigin(value),
          isFalse,
          reason: value,
        );
      }
    });

    test('allows HTTP for private hosts', () {
      expect(
        AppConfig.isValidSelfHostedApiOrigin('http://192.168.1.10:3000'),
        isTrue,
      );
      expect(
        AppConfig.isValidSelfHostedApiOrigin('http://localhost:3000'),
        isTrue,
      );
    });
  });

  group('resolveApiBaseUrl', () {
    test('uses cloud origin for cloud mode', () {
      expect(
        AppConfig.resolveApiBaseUrl(mode: ServerMode.cloud),
        AppConfig.normalizeApiBaseUrl(AppConfig.cloudApiBaseUrl),
      );
    });

    test('keeps the full self-hosted URL', () {
      expect(
        AppConfig.resolveApiBaseUrl(
          mode: ServerMode.selfHosted,
          customApiBaseUrl: 'https://ledger.example.com/hisaab/',
        ),
        'https://ledger.example.com/hisaab',
      );
    });

    test('normalizes host-only self-hosted values', () {
      expect(
        AppConfig.normalizeApiBaseUrl('ledger.example.com'),
        'https://ledger.example.com',
      );
    });
  });
}
