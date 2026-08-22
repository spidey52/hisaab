import 'package:flutter/material.dart';

class AsyncActionButton extends StatelessWidget {
  const AsyncActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.icon,
    this.expanded = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? busyLabel;
  final IconData? icon;
  final bool expanded;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = busy ? (busyLabel ?? 'Please wait…') : label;
    final style = FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
    final button = FilledButton(
      style: style,
      onPressed: busy ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Row(
          key: ValueKey(busy),
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              Builder(
                builder: (context) => SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if (busy || icon != null) const SizedBox(width: 9),
            Flexible(
              child: Text(
                effectiveLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: !busy && onPressed != null,
      label: effectiveLabel,
      child: expanded
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}
