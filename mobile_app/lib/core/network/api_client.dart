import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/app_storage.dart';
import 'api_failure.dart';

class ApiClient {
  ApiClient(this._storage, {String? baseUrl})
    : _configuredBaseUrl = AppConfig.normalizeApiBaseUrl(
        baseUrl ?? AppConfig.cloudApiBaseUrl,
      ),
      dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.normalizeApiBaseUrl(
            baseUrl ?? AppConfig.cloudApiBaseUrl,
          ),
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          sendTimeout: AppConfig.connectTimeout,
          headers: const {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          _applyBaseUrlWithPath(options);
          final token = await _storage.readSessionToken();
          if (token != null && token.isNotEmpty) {
            options.headers['authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final AppStorage _storage;
  final Dio dio;
  String _configuredBaseUrl;
  final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();
  bool _unauthorizedSignalled = false;

  String get baseUrl => _configuredBaseUrl;

  Stream<void> get unauthorizedEvents => _unauthorizedController.stream;

  void updateBaseUrl(String value) {
    _configuredBaseUrl = AppConfig.normalizeApiBaseUrl(value);
    dio.options.baseUrl = _configuredBaseUrl;
  }

  void _applyBaseUrlWithPath(RequestOptions options) {
    final baseUri = Uri.tryParse(_configuredBaseUrl);
    if (baseUri == null || !baseUri.hasAuthority || baseUri.host.isEmpty) {
      return;
    }

    final prefix = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final requestPath = options.path;
    if (prefix.isNotEmpty &&
        requestPath.startsWith('/') &&
        !requestPath.startsWith('$prefix/')) {
      // Dio drops base paths when the request path is absolute (`/api/...`).
      options
        ..baseUrl = '${baseUri.scheme}://${baseUri.authority}'
        ..path = '$prefix$requestPath';
      return;
    }

    options.baseUrl = _configuredBaseUrl;
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _guard(
    () => dio.get(path, queryParameters: queryParameters),
    signalUnauthorized: !_isAuthenticationPath(path),
  );

  Future<Response<dynamic>> post(String path, {Object? data}) => _guard(
    () => dio.post(path, data: data),
    signalUnauthorized: !_isAuthenticationPath(path),
  );

  Future<Response<dynamic>> patch(String path, {Object? data}) => _guard(
    () => dio.patch(path, data: data),
    signalUnauthorized: !_isAuthenticationPath(path),
  );

  Future<Response<dynamic>> delete(String path, {Object? data}) => _guard(
    () => dio.delete(path, data: data),
    signalUnauthorized: !_isAuthenticationPath(path),
  );

  Future<Response<dynamic>> _guard(
    Future<Response<dynamic>> Function() request, {
    required bool signalUnauthorized,
  }) async {
    try {
      return await request();
    } on DioException catch (error) {
      final failure = ApiFailure.fromDio(error);
      if (signalUnauthorized &&
          failure.isUnauthorized &&
          !_unauthorizedSignalled) {
        _unauthorizedSignalled = true;
        _unauthorizedController.add(null);
      }
      throw failure;
    }
  }

  void resetUnauthorizedSignal() {
    _unauthorizedSignalled = false;
  }

  Future<void> close() async {
    dio.close(force: true);
    await _unauthorizedController.close();
  }
}

bool _isAuthenticationPath(String path) => path.startsWith('/api/auth/');
