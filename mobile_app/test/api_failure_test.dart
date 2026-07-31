import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/core/network/api_failure.dart';

void main() {
  test('forbidden outbox operation requires attention instead of retrying', () {
    const failure = ApiFailure('Forbidden', statusCode: 403);

    expect(failure.needsUserAttention, isTrue);
    expect(failure.isRetryable, isFalse);
    expect(failure.diagnosticCategory, 'forbidden');
  });

  test('oversized outbox operation requires attention instead of retrying', () {
    const failure = ApiFailure('Too large', statusCode: 413);

    expect(failure.needsUserAttention, isTrue);
    expect(failure.isRetryable, isFalse);
    expect(failure.diagnosticCategory, 'payload_too_large');
  });
}
