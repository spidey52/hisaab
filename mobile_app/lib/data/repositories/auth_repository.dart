import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/storage/app_storage.dart';

class OtpChallenge {
  const OtpChallenge({
    required this.challengeId,
    required this.phoneE164,
    required this.maskedPhone,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
    required this.developmentCode,
  });

  final String challengeId;
  final String phoneE164;
  final String maskedPhone;
  final int expiresInSeconds;
  final int resendAfterSeconds;
  final String? developmentCode;
}

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final AppStorage _storage;

  Future<OtpChallenge> requestOtp(String phone) async {
    final response = await _api.post(
      '/api/auth/request-otp',
      data: {'phone': phone},
    );
    final data = _responseMap(response.data);
    return OtpChallenge(
      challengeId: data['challengeId']?.toString() ?? '',
      phoneE164: data['phoneE164']?.toString() ?? phone,
      maskedPhone: data['maskedPhone']?.toString() ?? phone,
      expiresInSeconds: _int(data['expiresInSeconds'], 600),
      resendAfterSeconds: _int(data['resendAfterSeconds'], 60),
      developmentCode: data['developmentCode']?.toString(),
    );
  }

  Future<void> verifyOtp({
    required String challengeId,
    required String phone,
    required String code,
  }) async {
    final response = await _api.post(
      '/api/auth/verify-otp',
      data: {'challengeId': challengeId, 'phone': phone, 'code': code},
    );
    final data = _responseMap(response.data);
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const ApiFailure('Login response was missing a session token.');
    }
    await _storage.writeSessionToken(token);
  }

  Future<void> logout() => _api.post('/api/auth/logout');
}

Map<String, dynamic> _responseMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const ApiFailure('The server returned an unexpected response.');
}

int _int(Object? value, int fallback) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
