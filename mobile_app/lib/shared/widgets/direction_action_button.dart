import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

class DirectionActionButton extends StatelessWidget {
  const DirectionActionButton({
    super.key,
    required this.action,
    required this.onPressed,
    this.selected = false,
    this.emphasized = false,
    this.compact = false,
  }) : assert(
         action != EntryAction.openingBalance,
         'Opening balance is not a normal entry action.',
       );

  final EntryAction action;
  final VoidCallback? onPressed;
  final bool selected;
  final bool emphasized;
  final bool compact;

  bool get _gave => action == EntryAction.gave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = _gave ? colors.red : colors.green;
    final accentDeep = _gave ? colors.red : colors.greenDark;
    final soft = _gave ? colors.redSoft : colors.greenSoft;
    final useSolid = selected || emphasized;
    final label = (_gave ? 'You gave' : 'You got').tr;
    final sign = _gave ? '−' : '+';
    final disabled = onPressed == null;

    final background = disabled
        ? colors.settledSoft
        : useSolid
        ? accent
        : colors.surface;

    final borderColor = disabled
        ? colors.line
        : useSolid
        ? accent
        : Color.alphaBlend(accent.withValues(alpha: 0.16), colors.line);

    final labelColor = disabled
        ? colors.muted
        : useSolid
        ? Colors.white
        : colors.ink;

    final iconBackground = disabled
        ? colors.page
        : useSolid
        ? Colors.white.withValues(alpha: 0.2)
        : soft;

    final iconForeground = disabled
        ? colors.muted
        : useSolid
        ? Colors.white
        : accentDeep;

    final iconSize = compact ? 30.0 : 36.0;
    final radius = BorderRadius.circular(16);

    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: '$sign $label',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          boxShadow: disabled || useSolid
              ? null
              : [
                  BoxShadow(
                    color: colors.ink.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            splashColor: accent.withValues(alpha: disabled ? 0 : 0.12),
            highlightColor: accent.withValues(alpha: disabled ? 0 : 0.06),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 50 : 58),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 14,
                  vertical: compact ? 10 : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        sign,
                        style: TextStyle(
                          color: iconForeground,
                          fontSize: compact ? 18 : 20,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: compact ? 14 : 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
