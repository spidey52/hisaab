import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Compact Hisaab identity that works as either an icon or a wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 40,
    this.showName = false,
    this.name = 'Hisaab',
  });

  final double size;
  final bool showName;
  final String name;

  @override
  Widget build(BuildContext context) {
    final mark = Semantics(
      label: showName ? null : name,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.green,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.currency_rupee_rounded,
          size: size * 0.58,
          color: Colors.white,
        ),
      ),
    );

    if (!showName) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.greenDark,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}
