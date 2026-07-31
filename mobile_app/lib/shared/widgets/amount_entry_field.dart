import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

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
    return Semantics(
      textField: true,
      label: 'Transaction amount in rupees'.tr,
      child: TextFormField(
        controller: controller,
        autofocus: autofocus && !calculatorVisible,
        readOnly: calculatorVisible,
        showCursor: !calculatorVisible,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?')),
        ],
        decoration: InputDecoration(
          labelText: 'Amount'.tr,
          hintText: '0',
          prefixText: '₹ ',
          prefixStyle: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: gave ? AppColors.red : AppColors.green,
          ),
          suffixIcon: IconButton(
            tooltip:
                (calculatorVisible ? 'Use number keyboard' : 'Open calculator')
                    .tr,
            onPressed: onToggleCalculator,
            icon: Icon(
              calculatorVisible
                  ? Icons.keyboard_alt_outlined
                  : Icons.calculate_outlined,
            ),
          ),
        ),
        validator: (value) {
          final paise = rupeesTextToPaise(value ?? '');
          if (paise == null) return 'Enter an amount greater than zero';
          return null;
        },
        onChanged: onChanged,
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }
}
