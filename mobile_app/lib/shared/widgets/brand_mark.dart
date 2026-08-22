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
    final colors = context.colors;
    final mark = Semantics(
      label: showName ? null : name,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.heroTop, colors.heroBottom],
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        alignment: Alignment.center,
        child: Text(
          '₹',
          style: TextStyle(
            fontSize: size * 0.52,
            height: 1,
            fontWeight: FontWeight.w800,
            color: colors.onBrand,
          ),
        ),
      ),
    );

    if (!showName) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.3),
        Text(
          name,
          style: displayStyle(
            fontSize: size * 0.62,
            fontWeight: FontWeight.w700,
            color: colors.ink,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
