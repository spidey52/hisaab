import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../features/ledger/ledger_controller.dart';
import '../../features/sync/sync_review_sheet.dart';

/// Ambient connectivity strip shown on every tab, directly above the
/// navigation bar. Quiet when everything is synced; one line + one action
/// when something needs the user's eye.
class SyncStrip extends StatelessWidget {
  const SyncStrip({super.key});

  Future<void> _retry(LedgerController controller) async {
    try {
      await controller.retryPending();
    } on Object catch (_) {
      // The strip itself reflects the failure state; no snackbar spam here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LedgerController>();
    final colors = context.colors;

    return Obx(() {
      final syncing = controller.syncStatus.value == LedgerSyncStatus.syncing;
      final offline = controller.isOffline.value;
      final pending = controller.pendingCount.value;
      final attention = controller.needsAttentionCount.value;
      final visible = offline || syncing || pending > 0 || attention > 0;
      final reduceMotion = MediaQuery.disableAnimationsOf(context);

      final Color fg;
      final Color bg;
      final IconData icon;
      final String label;
      final String? actionLabel;
      final VoidCallback? onAction;

      if (attention > 0) {
        fg = colors.red;
        bg = colors.redSoft;
        icon = Icons.error_outline_rounded;
        label = attention == 1
            ? '1 change needs review'
            : '$attention changes need review';
        actionLabel = 'Review'.tr;
        onAction = () => showSyncReviewSheet(context);
      } else if (syncing) {
        fg = colors.greenDark;
        bg = colors.greenSoft;
        icon = Icons.cloud_sync_outlined;
        label = pending > 0
            ? 'Syncing $pending saved ${pending == 1 ? 'change' : 'changes'}…'
            : 'Syncing…';
        actionLabel = null;
        onAction = null;
      } else if (offline) {
        fg = colors.amber;
        bg = colors.amberSoft;
        icon = Icons.cloud_off_outlined;
        label = pending > 0
            ? 'Offline · $pending saved on this phone'
            : 'Offline · your ledger still works';
        actionLabel = 'Retry'.tr;
        onAction = () => _retry(controller);
      } else {
        fg = colors.amber;
        bg = colors.amberSoft;
        icon = Icons.cloud_upload_outlined;
        label = '$pending ${pending == 1 ? 'change' : 'changes'} waiting to sync';
        actionLabel = 'Sync now'.tr;
        onAction = () => _retry(controller);
      }

      final strip = !visible
          ? const SizedBox.shrink()
          : Semantics(
              liveRegion: true,
              label: label,
              child: Material(
                color: bg,
                child: InkWell(
                  onTap: onAction,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        if (syncing)
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: fg,
                            ),
                          )
                        else
                          Icon(icon, size: 17, color: fg),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (actionLabel != null)
                          Text(
                            actionLabel,
                            style: TextStyle(
                              color: fg,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                              decorationColor: fg,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );

      if (reduceMotion) return strip;
      return AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: strip,
      );
    });
  }
}
