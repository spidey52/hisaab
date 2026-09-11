import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

/// Premium amount input used on Add / Edit entry.
class AmountEntryField extends StatelessWidget {
  const AmountEntryField({
    super.key,
    required this.controller,
    required this.calculatorVisible,
    required this.gave,
    required this.onToggleCalculator,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool calculatorVisible;
  final bool gave;
  final VoidCallback onToggleCalculator;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = gave ? colors.red : colors.green;
    final accentDeep = gave ? colors.red : colors.greenDark;

    return Semantics(
      textField: true,
      label: 'Transaction amount in rupees'.tr,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.line),
          boxShadow: [
            BoxShadow(
              color: colors.ink.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount'.tr,
              style: TextStyle(
                color: colors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    autofocus: autofocus && !calculatorVisible,
                    readOnly: calculatorVisible,
                    showCursor: !calculatorVisible,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    style:
                        displayStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: accentDeep,
                          letterSpacing: -0.8,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d{0,9}(\.\d{0,2})?'),
                      ),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0',
                      hintStyle: displayStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: colors.muted.withValues(alpha: 0.35),
                        letterSpacing: -0.8,
                      ),
                      prefixText: '₹ ',
                      prefixStyle: displayStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: -0.4,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    validator: (value) {
                      final paise = rupeesTextToPaise(value ?? '');
                      if (paise == null) {
                        return 'Enter an amount greater than zero';
                      }
                      return null;
                    },
                    onChanged: onChanged,
                    onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                ),
                Material(
                  color: calculatorVisible
                      ? Color.alphaBlend(
                          accent.withValues(alpha: 0.12),
                          colors.surface,
                        )
                      : colors.settledSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: onToggleCalculator,
                    borderRadius: BorderRadius.circular(12),
                    child: Tooltip(
                      message:
                          (calculatorVisible
                                  ? 'Use number keyboard'
                                  : 'Open calculator')
                              .tr,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          calculatorVisible
                              ? Icons.keyboard_alt_outlined
                              : Icons.calculate_outlined,
                          size: 22,
                          color: calculatorVisible ? accentDeep : colors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
