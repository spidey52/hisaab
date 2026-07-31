import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_mobile/core/utils/calculator.dart';

void main() {
  group('calculator exact arithmetic', () {
    test('accepts the Unicode minus used by the keypad', () {
      final result = evaluateCalculatorExpression('10−3');

      expect(result.error, isNull);
      expect(result.paise, 700);
      expect(result.displayValue, '7');
    });

    test('keeps division exact until the final amount is rounded', () {
      expect(evaluateCalculatorExpression('1÷3×3').paise, 100);
      expect(evaluateCalculatorExpression('10÷6×3').paise, 500);
      expect(evaluateCalculatorExpression('1÷8').paise, 13);
    });

    test('rounds half up to the nearest paisa only at the end', () {
      expect(evaluateCalculatorExpression('1.005').paise, 101);
      expect(evaluateCalculatorExpression('1.0049').paise, 100);
    });

    test('uses familiar calculator percentage semantics', () {
      expect(evaluateCalculatorExpression('200×10%').paise, 2000);
      expect(evaluateCalculatorExpression('100+10%').paise, 11000);
      expect(evaluateCalculatorExpression('100−10%').paise, 9000);
      expect(evaluateCalculatorExpression('100÷10%').paise, 100000);
    });

    test('rejects incomplete, zero, divide-by-zero, and overflow results', () {
      expect(evaluateCalculatorExpression('10+').isValid, isFalse);
      expect(
        evaluateCalculatorExpression('10÷0').error,
        'Cannot divide by zero',
      );
      expect(evaluateCalculatorExpression('0').isValid, isFalse);
      expect(
        evaluateCalculatorExpression('1000000000').error,
        'Amount is too large',
      );
    });
  });
}
