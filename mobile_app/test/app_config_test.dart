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
}
