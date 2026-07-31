import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/app_storage.dart';
import 'api_failure.dart';

class ApiClient {
  ApiClient(this._storage)
    : dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.normalizedApiBaseUrl,
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
  final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();
  bool _unauthorizedSignalled = false;

  Stream<void> get unauthorizedEvents => _unauthorizedController.stream;

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
