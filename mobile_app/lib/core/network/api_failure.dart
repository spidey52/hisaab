import 'dart:io';

import 'package:dio/dio.dart';

class ApiFailure implements Exception {
  const ApiFailure(
    this.message, {
    this.statusCode,
    this.code,
    this.data,
    this.isConnectionError = false,
    this.retryAfter,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? data;
  final bool isConnectionError;
  final Duration? retryAfter;

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;
  bool get isValidationError => statusCode == 400 || statusCode == 422;
  bool get isRateLimited => statusCode == 429;
  bool get isPermanentClientFailure =>
      statusCode != null &&
      statusCode! >= 400 &&
      statusCode! < 500 &&
      !isUnauthorized &&
      statusCode != 408 &&
      statusCode != 425 &&
      !isRateLimited;

  bool get isRetryable =>
      isConnectionError ||
      statusCode == 408 ||
      statusCode == 425 ||
      statusCode == 429 ||
      (statusCode != null && statusCode! >= 500);

  bool get needsUserAttention => isPermanentClientFailure;

  String get diagnosticCategory {
    if (isUnauthorized) return 'unauthorized';
    if (isRateLimited) return 'rate_limited';
    if (isConflict) return 'conflict';
    if (isValidationError) return 'validation';
    if (statusCode == 403) return 'forbidden';
    if (statusCode == 413) return 'payload_too_large';
    if (isPermanentClientFailure) return 'rejected';
    if (isConnectionError) return 'connection';
    if (statusCode != null && statusCode! >= 500) return 'server';
    return 'unexpected';
  }

  factory ApiFailure.fromDio(DioException error) {
    final responseData = error.response?.data;
    final map = responseData is Map
        ? Map<String, dynamic>.from(responseData)
        : null;
    final connectionError =
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.error is SocketException;

    return ApiFailure(
      map?['error']?.toString() ??
          (connectionError
              ? 'Cannot reach Hisaab. Check your connection and try again.'
              : 'Something went wrong. Please try again.'),
      statusCode: error.response?.statusCode,
      code: map?['code']?.toString(),
      data: map,
      isConnectionError: connectionError,
      retryAfter: _retryAfter(error.response?.headers),
    );
  }

  @override
  String toString() => message;
}

Duration? _retryAfter(Headers? headers) {
  final raw = headers?.value('retry-after')?.trim();
  if (raw == null || raw.isEmpty) return null;
  final seconds = int.tryParse(raw);
  if (seconds != null) return Duration(seconds: seconds.clamp(1, 86400));
  DateTime date;
  try {
    date = HttpDate.parse(raw);
  } on FormatException {
    return null;
  }
  final difference = date.difference(DateTime.now().toUtc());
  return difference.isNegative ? const Duration(seconds: 1) : difference;
}
