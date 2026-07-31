import 'package:decimal/decimal.dart';

import 'formatters.dart';

class CalculatorEvaluation {
  const CalculatorEvaluation._({
    required this.expression,
    this.value,
    this.paise,
    this.error,
  });

  factory CalculatorEvaluation.success(
    String expression,
    Decimal value,
    int paise,
  ) => CalculatorEvaluation._(
    expression: expression,
    value: value,
    paise: paise,
  );

  factory CalculatorEvaluation.failure(String expression, String error) =>
      CalculatorEvaluation._(expression: expression, error: error);

  final String expression;
  final Decimal? value;
  final int? paise;
  final String? error;

  bool get isValid => value != null && paise != null && error == null;
  String get displayValue => value == null ? '' : decimalDisplay(value!);
}

CalculatorEvaluation evaluateCalculatorExpression(
  String expression, {
  int maximumPaise = maximumLedgerAmountPaise,
}) {
  final source = expression.trim().replaceAll('−', '-');
  if (source.isEmpty) {
    return CalculatorEvaluation.failure(expression, 'Enter a calculation');
  }
  if (source.length > 200) {
    return CalculatorEvaluation.failure(expression, 'Calculation is too long');
  }
  try {
    final parser = _CalculatorParser(source);
    final exact = parser.parse().value;
    if (exact.compareTo(_ExactNumber.zero) <= 0) {
      return CalculatorEvaluation.failure(
        expression,
        'The result must be greater than zero',
      );
    }
    final paise = exact.roundedPaise;
    if (paise <= BigInt.zero) {
      return CalculatorEvaluation.failure(
        expression,
        'The result must be at least ₹0.01',
      );
    }
    if (paise > BigInt.from(maximumPaise)) {
      return CalculatorEvaluation.failure(expression, 'Amount is too large');
    }
    final paiseInt = paise.toInt();
    final value = Decimal.fromInt(paiseInt) / Decimal.fromInt(100);
    return CalculatorEvaluation.success(
      expression,
      value.toDecimal(scaleOnInfinitePrecision: 2),
      paiseInt,
    );
  } on CalculatorExpressionException catch (error) {
    return CalculatorEvaluation.failure(expression, error.message);
  } on FormatException {
    return CalculatorEvaluation.failure(expression, 'Check the calculation');
  }
}

String decimalDisplay(Decimal value) {
  final rounded = value.round(scale: 2).toString();
  if (!rounded.contains('.')) return rounded;
  return rounded.replaceFirst(RegExp(r'\.?0+$'), '');
}

class CalculatorExpressionException implements Exception {
  const CalculatorExpressionException(this.message);

  final String message;
}

class _CalculatorParser {
  _CalculatorParser(String source) : _tokens = _tokenize(source);

  final List<_Token> _tokens;
  int _position = 0;

  _CalculationValue parse() {
    final value = _expression();
    if (!_check(_TokenType.end)) {
      throw const CalculatorExpressionException('Check the calculation');
    }
    return value;
  }

  _CalculationValue _expression() {
    var value = _term();
    while (_match('+') || _match('-')) {
      final operator = _previous.lexeme;
      final right = _term();
      final adjustment = right.isPercent
          ? value.value * right.value
          : right.value;
      value = _CalculationValue(
        operator == '+' ? value.value + adjustment : value.value - adjustment,
      );
    }
    return value;
  }

  _CalculationValue _term() {
    var value = _factor();
    while (_match('×') || _match('*') || _match('÷') || _match('/')) {
      final operator = _previous.lexeme;
      final right = _factor();
      if (operator == '×' || operator == '*') {
        value = _CalculationValue(value.value * right.value);
      } else {
        if (right.value == _ExactNumber.zero) {
          throw const CalculatorExpressionException('Cannot divide by zero');
        }
        value = _CalculationValue(value.value / right.value);
      }
    }
    return value;
  }

  _CalculationValue _factor() {
    if (_match('+')) return _factor();
    if (_match('-')) {
      final value = _factor();
      return _CalculationValue(-value.value, isPercent: value.isPercent);
    }

    _CalculationValue value;
    if (_match('(')) {
      value = _expression();
      if (!_match(')')) {
        throw const CalculatorExpressionException(
          'Close the bracket to continue',
        );
      }
    } else if (_check(_TokenType.number)) {
      value = _CalculationValue(_ExactNumber.parse(_advance().lexeme));
    } else {
      throw const CalculatorExpressionException(
        'Complete the calculation first',
      );
    }

    while (_match('%')) {
      value = _CalculationValue(
        value.value / _ExactNumber.fromInt(100),
        isPercent: true,
      );
    }
    return value;
  }

  bool _match(String lexeme) {
    if (_current.lexeme != lexeme) return false;
    _advance();
    return true;
  }

  bool _check(_TokenType type) => _current.type == type;

  _Token _advance() {
    if (!_check(_TokenType.end)) _position++;
    return _previous;
  }

  _Token get _current => _tokens[_position];
  _Token get _previous => _tokens[_position - 1];
}

class _CalculationValue {
  const _CalculationValue(this.value, {this.isPercent = false});

  final _ExactNumber value;
  final bool isPercent;
}

class _ExactNumber implements Comparable<_ExactNumber> {
  _ExactNumber(BigInt numerator, BigInt denominator)
    : assert(denominator != BigInt.zero),
      numerator = _normalizedNumerator(numerator, denominator),
      denominator = _normalizedDenominator(numerator, denominator);

  factory _ExactNumber.fromInt(int value) =>
      _ExactNumber(BigInt.from(value), BigInt.one);

  factory _ExactNumber.parse(String source) {
    final parts = source.split('.');
    if (parts.length == 1) {
      return _ExactNumber(BigInt.parse(parts.single), BigInt.one);
    }
    final fraction = parts[1];
    final denominator = BigInt.from(10).pow(fraction.length);
    final whole = parts[0].isEmpty ? BigInt.zero : BigInt.parse(parts[0]);
    final numerator =
        whole * denominator +
        (fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction));
    return _ExactNumber(numerator, denominator);
  }

  static final zero = _ExactNumber.fromInt(0);

  final BigInt numerator;
  final BigInt denominator;

  _ExactNumber operator +(_ExactNumber other) => _ExactNumber(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  _ExactNumber operator -(_ExactNumber other) => this + (-other);

  _ExactNumber operator *(_ExactNumber other) => _ExactNumber(
    numerator * other.numerator,
    denominator * other.denominator,
  );

  _ExactNumber operator /(_ExactNumber other) {
    if (other.numerator == BigInt.zero) {
      throw const CalculatorExpressionException('Cannot divide by zero');
    }
    return _ExactNumber(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  _ExactNumber operator -() => _ExactNumber(-numerator, denominator);

  BigInt get roundedPaise {
    final scaled = numerator * BigInt.from(100);
    final whole = scaled ~/ denominator;
    final remainder = scaled.remainder(denominator).abs();
    if (remainder * BigInt.two < denominator.abs()) return whole;
    return whole + (scaled.isNegative ? -BigInt.one : BigInt.one);
  }

  @override
  int compareTo(_ExactNumber other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  static BigInt _normalizedNumerator(BigInt numerator, BigInt denominator) {
    final divisor = numerator.gcd(denominator);
    final value = numerator ~/ divisor;
    return denominator.isNegative ? -value : value;
  }

  static BigInt _normalizedDenominator(BigInt numerator, BigInt denominator) {
    final divisor = numerator.gcd(denominator);
    final value = denominator ~/ divisor;
    return value.isNegative ? -value : value;
  }
}

enum _TokenType { number, symbol, end }

class _Token {
  const _Token(this.type, this.lexeme);

  final _TokenType type;
  final String lexeme;
}

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var index = 0;
  while (index < source.length) {
    final character = source[index];
    if (character.trim().isEmpty) {
      index++;
      continue;
    }
    if ('+-−×*÷/%()'.contains(character)) {
      tokens.add(_Token(_TokenType.symbol, character));
      index++;
      continue;
    }
    if (RegExp(r'\d|\.').hasMatch(character)) {
      final start = index;
      var decimalPoints = 0;
      while (index < source.length &&
          RegExp(r'\d|\.').hasMatch(source[index])) {
        if (source[index] == '.') decimalPoints++;
        index++;
      }
      final number = source.substring(start, index);
      if (decimalPoints > 1 ||
          number == '.' ||
          number.length > 32 ||
          !RegExp(r'^\d*(?:\.\d*)?$').hasMatch(number)) {
        throw const CalculatorExpressionException('Check the number format');
      }
      tokens.add(_Token(_TokenType.number, number));
      continue;
    }
    throw CalculatorExpressionException('“$character” is not a calculator key');
  }
  tokens.add(const _Token(_TokenType.end, ''));
  return tokens;
}
