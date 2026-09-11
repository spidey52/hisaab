import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';

/// Where [AppSnackbar] appears on screen.
enum SnackbarPosition { top, bottom }

enum _AppSnackbarKind { success, error, warning, info }

/// Centralized, premium snackbars for Hisaab.
///
/// Prefer typed helpers ([success], [error], [warning], [info]) so styling
/// stays consistent. Pass [position] to place the bar at top or bottom.
class AppSnackbar {
  AppSnackbar._();

  static const _defaultDuration = Duration(seconds: 3);

  static void success({
    required String title,
    required String message,
    SnackbarPosition position = SnackbarPosition.bottom,
    Duration? duration,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) => _show(
    kind: _AppSnackbarKind.success,
    title: title,
    message: message,
    position: position,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void error({
    required String title,
    required String message,
    SnackbarPosition position = SnackbarPosition.bottom,
    Duration? duration,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) => _show(
    kind: _AppSnackbarKind.error,
    title: title,
    message: message,
    position: position,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void warning({
    required String title,
    required String message,
    SnackbarPosition position = SnackbarPosition.bottom,
    Duration? duration,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) => _show(
    kind: _AppSnackbarKind.warning,
    title: title,
    message: message,
    position: position,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void info({
    required String title,
    required String message,
    SnackbarPosition position = SnackbarPosition.bottom,
    Duration? duration,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) => _show(
    kind: _AppSnackbarKind.info,
    title: title,
    message: message,
    position: position,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// Dismiss the currently visible snackbar, if any.
  static void dismiss() {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
  }

  static void _show({
    required _AppSnackbarKind kind,
    required String title,
    required String message,
    required SnackbarPosition position,
    Duration? duration,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();

    final context = Get.context ?? Get.overlayContext;
    final colors = context != null
        ? Theme.of(context).extension<HisaabColors>() ?? HisaabColors.light
        : HisaabColors.light;
    final media = context != null ? MediaQuery.maybeOf(context) : null;
    final padding = media?.padding ?? EdgeInsets.zero;
    final width = media?.size.width ?? 400;
    final horizontal = width >= 560 ? (width - 480) / 2 : 16.0;

    final accent = switch (kind) {
      _AppSnackbarKind.success => colors.green,
      _AppSnackbarKind.error => colors.red,
      _AppSnackbarKind.warning => colors.amber,
      _AppSnackbarKind.info => colors.brand,
    };
    final soft = switch (kind) {
      _AppSnackbarKind.success => colors.greenSoft,
      _AppSnackbarKind.error => colors.redSoft,
      _AppSnackbarKind.warning => colors.amberSoft,
      _AppSnackbarKind.info => Color.alphaBlend(
        colors.brand.withValues(alpha: 0.1),
        colors.surface,
      ),
    };
    final icon = switch (kind) {
      _AppSnackbarKind.success => Icons.check_circle_rounded,
      _AppSnackbarKind.error => Icons.error_rounded,
      _AppSnackbarKind.warning => Icons.warning_amber_rounded,
      _AppSnackbarKind.info => Icons.info_rounded,
    };

    final isTop = position == SnackbarPosition.top;
    final margin = EdgeInsets.fromLTRB(
      horizontal,
      isTop ? padding.top + 8 : 0,
      horizontal,
      isTop ? 0 : padding.bottom + 12,
    );

    Get.showSnackbar(
      GetSnackBar(
        snackPosition: isTop ? SnackPosition.TOP : SnackPosition.BOTTOM,
        snackStyle: SnackStyle.FLOATING,
        backgroundColor: Colors.transparent,
        margin: margin,
        padding: EdgeInsets.zero,
        borderRadius: 16,
        duration: duration ?? _defaultDuration,
        animationDuration: const Duration(milliseconds: 320),
        forwardAnimationCurve: Curves.easeOutCubic,
        reverseAnimationCurve: Curves.easeInCubic,
        isDismissible: true,
        dismissDirection: isTop ? DismissDirection.up : DismissDirection.down,
        overlayBlur: 0,
        barBlur: 0,
        messageText: _AppSnackbarCard(
          title: title,
          message: message,
          accent: accent,
          soft: soft,
          icon: icon,
          surface: colors.surface,
          ink: colors.ink,
          muted: colors.muted,
          line: colors.line,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () async {
                  dismiss();
                  await onAction();
                },
        ),
      ),
    );
  }
}

class _AppSnackbarCard extends StatelessWidget {
  const _AppSnackbarCard({
    required this.title,
    required this.message,
    required this.accent,
    required this.soft,
    required this.icon,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final Color accent;
  final Color soft;
  final IconData icon;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final String? actionLabel;
  final FutureOr<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: line),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: accent, child: const SizedBox(width: 4)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: soft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: displayStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: ink,
                                letterSpacing: -0.15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              message,
                              style: TextStyle(
                                color: muted,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: onAction == null
                              ? null
                              : () => onAction!(),
                          style: TextButton.styleFrom(
                            foregroundColor: accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          child: Text(actionLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
