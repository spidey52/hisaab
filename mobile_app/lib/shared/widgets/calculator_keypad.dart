import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/calculator.dart';
import '../../core/utils/formatters.dart';

class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.expression,
    required this.onExpressionChanged,
    required this.onUseAmount,
  });

  final String expression;
  final ValueChanged<String> onExpressionChanged;
  final ValueChanged<int> onUseAmount;

  static const _rows = [
    ['C', '⌫', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['00', '0', '.', '='],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final evaluation = evaluateCalculatorExpression(expression);
    return Semantics(
      container: true,
      label: 'Amount calculator'.tr,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Calculation'.tr,
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Semantics(
              liveRegion: true,
              excludeSemantics: true,
              label: expression.isEmpty
                  ? 'Calculation is empty'
                  : 'Expression $expression',
              child: Text(
                expression.isEmpty ? 'Tap the keys below'.tr : expression,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Semantics(
              liveRegion: true,
              excludeSemantics: true,
              label: evaluation.isValid
                  ? 'Result ${evaluation.displayValue} rupees'
                  : evaluation.error,
              child: Text(
                evaluation.isValid
                    ? '= ₹${evaluation.displayValue}'
                    : expression.isEmpty
                    ? ' '
                    : evaluation.error ?? ' ',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: evaluation.isValid ? colors.greenDark : colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final row in _rows) ...[
              Row(
                children: [
                  for (final key in row) ...[
                    Expanded(
                      child: _CalculatorKey(
                        label: key,
                        onPressed: () => _press(key, evaluation),
                      ),
                    ),
                    if (key != row.last) const SizedBox(width: 8),
                  ],
                ],
              ),
              if (row != _rows.last) const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: evaluation.paise == null
                  ? null
                  : () => onUseAmount(evaluation.paise!),
              icon: const Icon(Icons.check_rounded),
              label: Text(
                evaluation.paise == null
                    ? 'Use amount'.tr
                    : 'Use @amount'.trParams({
                        'amount': formatMoney(evaluation.paise!),
                      }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _press(String key, CalculatorEvaluation evaluation) {
    HapticFeedback.selectionClick();
    switch (key) {
      case 'C':
        onExpressionChanged('');
      case '⌫':
        if (expression.isNotEmpty) {
          onExpressionChanged(expression.substring(0, expression.length - 1));
        }
      case '=':
        if (evaluation.isValid) {
          onExpressionChanged(evaluation.displayValue);
        }
      case '−':
        _append('−');
      default:
        _append(key);
    }
  }

  void _append(String value) {
    if (expression.length >= 80) return;
    onExpressionChanged('$expression$value');
  }
}

class _CalculatorKey extends StatelessWidget {
  const _CalculatorKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final operation = const {'+', '−', '×', '÷', '%', '='}.contains(label);
    final spokenLabel = (switch (label) {
      '⌫' => 'Backspace',
      'C' => 'Clear',
      '−' => 'Minus',
      '×' => 'Multiply',
      '÷' => 'Divide',
      '%' => 'Percent',
      '=' => 'Equals',
      '.' => 'Decimal point',
      _ => label,
    }).tr;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: spokenLabel,
      child: Material(
        color: operation ? colors.greenSoft : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: operation
                ? Color.alphaBlend(
                    colors.greenDark.withValues(alpha: 0.16),
                    colors.greenSoft,
                  )
                : colors.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: operation ? colors.greenDark : colors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
