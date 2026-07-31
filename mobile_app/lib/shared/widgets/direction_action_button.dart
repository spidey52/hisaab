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
    final color = _gave ? AppColors.red : AppColors.green;
    final soft = _gave ? AppColors.redSoft : AppColors.greenSoft;
    final useSolid = selected || emphasized;
    final label = (_gave ? 'You gave' : 'You got').tr;
    final sign = _gave ? '−' : '+';

    return Semantics(
      button: true,
      selected: selected,
      label: '$sign $label',
      child: Material(
        color: onPressed == null
            ? AppColors.line
            : useSolid
            ? color
            : soft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: onPressed == null ? AppColors.line : color,
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
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      sign,
                      style: TextStyle(
                        color: useSolid ? Colors.white : color,
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
                        color: useSolid ? Colors.white : color,
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
