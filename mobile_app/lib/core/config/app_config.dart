import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment('HISAAB_API_URL');
  static const _developmentApiBaseUrl = 'http://127.0.0.1:3000';

  static const connectTimeout = Duration(seconds: 12);
  static const receiveTimeout = Duration(seconds: 20);

  static String get apiBaseUrl {
    final configured = _configuredApiBaseUrl.trim();
    if (configured.isNotEmpty) return configured;
    if (kReleaseMode) {
      throw StateError(
        'Release builds require '
        '--dart-define=HISAAB_API_URL=https://your-production-host',
      );
    }
    return _developmentApiBaseUrl;
  }

  static String get normalizedApiBaseUrl =>
      apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  static void validateForCurrentBuild() {
    if (!kReleaseMode) return;
    if (!isPublicHttpsApiOrigin(apiBaseUrl)) {
      throw StateError(
        'HISAAB_API_URL must be a public HTTPS origin for release builds.',
      );
    }
  }

  static bool isPublicHttpsApiOrigin(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    return !_isDevelopmentOrPrivateHost(uri.host);
  }

  static bool _isDevelopmentOrPrivateHost(String value) {
    final host = value.toLowerCase();
    final isIpv6Literal = host.contains(':');
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.ts.net') ||
        host == '::' ||
        host == '::1' ||
        host.startsWith('::ffff:') ||
        (isIpv6Literal &&
            (host.startsWith('fc') ||
                host.startsWith('fd') ||
                RegExp(r'^fe[89ab]').hasMatch(host) ||
                host.startsWith('ff')))) {
      return true;
    }

    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = parts.map(int.tryParse).toList(growable: false);
    if (octets.any((part) => part == null)) return false;
    final first = octets[0]!;
    final second = octets[1]!;
    return first == 0 ||
        first == 10 ||
        first == 127 ||
        (first == 100 && second >= 64 && second <= 127) ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        first >= 224;
  }
}
