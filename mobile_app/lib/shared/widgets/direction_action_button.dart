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
    final color = _gave ? colors.red : colors.green;
    final deep = _gave ? colors.red : colors.greenDark;
    final soft = _gave ? colors.redSoft : colors.greenSoft;
    final useSolid = selected || emphasized;
    final label = (_gave ? 'You gave' : 'You got').tr;
    final sign = _gave ? '−' : '+';
    final disabled = onPressed == null;

    final foreground = disabled
        ? colors.muted
        : useSolid
        ? Colors.white
        : deep;

    return Semantics(
      button: true,
      selected: selected,
      label: '$sign $label',
      child: Material(
        color: disabled
            ? colors.settledSoft
            : useSolid
            ? color
            : soft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: disabled
                ? colors.line
                : useSolid
                ? color
                : Color.alphaBlend(deep.withValues(alpha: 0.22), soft),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 50 : 62),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: compact ? 10 : 14,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: compact ? 28 : 34,
                    height: compact ? 28 : 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: useSolid
                          ? Colors.white.withValues(alpha: 0.18)
                          : colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      sign,
                      style: TextStyle(
                        color: disabled
                            ? colors.muted
                            : useSolid
                            ? Colors.white
                            : deep,
                        fontSize: compact ? 20 : 24,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
