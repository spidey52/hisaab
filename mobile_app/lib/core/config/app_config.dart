import 'package:flutter/foundation.dart';

enum ServerMode {
  cloud,
  selfHosted;

  static ServerMode parse(String? value) {
    switch (value?.trim()) {
      case 'selfHosted':
        return ServerMode.selfHosted;
      default:
        return ServerMode.cloud;
    }
  }

  String get storageValue => name;
}

abstract final class AppConfig {
  /// Hisaab Cloud API origin used for Cloud sign-in.
  static const cloudApiBaseUrl = 'https://hisaab.imsat.dev';

  static const connectTimeout = Duration(seconds: 12);
  static const receiveTimeout = Duration(seconds: 20);

  static String resolveApiBaseUrl({
    required ServerMode mode,
    String? customApiBaseUrl,
  }) {
    if (mode == ServerMode.selfHosted) {
      final custom = normalizeApiBaseUrl(customApiBaseUrl ?? '');
      if (custom.isEmpty) {
        throw StateError('A self-hosted server URL is required.');
      }
      return custom;
    }
    return normalizeApiBaseUrl(cloudApiBaseUrl);
  }

  static String get normalizedApiBaseUrl =>
      normalizeApiBaseUrl(cloudApiBaseUrl);

  static String normalizeApiBaseUrl(String value) {
    var trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.contains('://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  static bool isPublicHttpsApiOrigin(String value) {
    final uri = Uri.tryParse(normalizeApiBaseUrl(value));
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

  /// Accepts a full http(s) server URL (scheme + host, optional port/path).
  /// HTTP is allowed for local/private hosts, or in non-release builds.
  static bool isValidSelfHostedApiOrigin(String value) {
    final uri = Uri.tryParse(normalizeApiBaseUrl(value));
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    if (uri.scheme == 'https') return true;
    if (uri.scheme != 'http') return false;
    return !kReleaseMode || _isDevelopmentOrPrivateHost(uri.host);
  }

  static String? selfHostedApiOriginError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter your Hisaab server URL';
    if (!isValidSelfHostedApiOrigin(trimmed)) {
      return 'Enter the full server URL, e.g. https://hisaab.example.com';
    }
    return null;
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
