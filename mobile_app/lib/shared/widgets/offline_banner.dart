import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message = 'You can keep working. Saved changes sync automatically.',
    this.isOffline = false,
    this.pendingCount = 0,
    this.needsAttentionCount = 0,
    this.isSyncing = false,
    this.lastSyncedAt,
    this.onRetry,
    this.onReview,
  });

  final String message;
  final bool isOffline;
  final int pendingCount;
  final int needsAttentionCount;
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final VoidCallback? onRetry;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final displayMessage = message.tr;
    final pendingText = pendingCount > 0
        ? (pendingCount == 1
                  ? '@count saved change is waiting to sync.'
                  : '@count saved changes are waiting to sync.')
              .trParams({'count': '$pendingCount'})
        : null;
    final title = needsAttentionCount > 0
        ? 'Sync needs attention'.tr
        : isSyncing
        ? 'Syncing saved changes'.tr
        : isOffline
        ? 'Offline'.tr
        : 'Saved on this phone'.tr;
    final attentionText = needsAttentionCount > 0
        ? (needsAttentionCount == 1
                  ? '@count change needs review.'
                  : '@count changes need review.')
              .trParams({'count': '$needsAttentionCount'})
        : null;
    final syncedText = lastSyncedAt == null
        ? null
        : 'Last synced @time'.trParams({'time': _relativeTime(lastSyncedAt!)});

    return Semantics(
      liveRegion: true,
      label:
          '$title. $displayMessage'
          '${pendingText == null ? '' : ' $pendingText'}'
          '${attentionText == null ? '' : ' $attentionText'}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: colors.amberSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Color.alphaBlend(
              colors.amber.withValues(alpha: 0.28),
              colors.amberSoft,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                needsAttentionCount > 0
                    ? Icons.error_outline_rounded
                    : isSyncing
                    ? Icons.cloud_sync_outlined
                    : isOffline
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_upload_outlined,
                size: 22,
                color: colors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                      height: 1.4,
                    ),
                  ),
                  if (pendingText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      pendingText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (attentionText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      attentionText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (syncedText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      syncedText,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: colors.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (needsAttentionCount > 0 && onReview != null) ...[
              const SizedBox(width: 6),
              TextButton(onPressed: onReview, child: Text('Review'.tr)),
            ] else if (onRetry != null) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: isSyncing ? null : onRetry,
                child: Text('Retry sync'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime value) {
  final elapsed = DateTime.now().difference(value.toLocal());
  if (elapsed.inMinutes < 1) return 'just now'.tr;
  if (elapsed.inHours < 1) {
    return '@count min ago'.trParams({'count': '${elapsed.inMinutes}'});
  }
  if (elapsed.inDays < 1) {
    return '@count hr ago'.trParams({'count': '${elapsed.inHours}'});
  }
  return '@count days ago'.trParams({'count': '${elapsed.inDays}'});
}
