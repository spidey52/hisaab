import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app.dart';
import '../../app/modules/shared/widget/ledger_activity_row.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../features/ledger/ledger_controller.dart';
import 'app_snackbar.dart';

/// One entry detail sheet for the whole app: the same fields and actions
/// whether the entry was opened from Home, the Entries tab, or a statement.
Future<void> showEntryDetailSheet(
  BuildContext context,
  LedgerEntry entry, {
  String? titleOverride,
  bool useDirectionAvatar = false,
  Future<void> Function()? onChanged,
}) async {
  final controller = Get.find<LedgerController>();
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    // Theme enables a drag handle globally; we draw our own inside the sheet.
    showDragHandle: false,
    builder: (context) => _EntryDetailSheet(
      entry: entry,
      titleOverride: titleOverride,
      useDirectionAvatar: useDirectionAvatar,
    ),
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    await Get.toNamed(AppRoutes.addEntry, arguments: {'entryId': entry.id});
    await onChanged?.call();
    return;
  }
  if (action != 'cancel') return;
  if (!context.mounted) return;

  final colors = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Cancel this entry?'.tr,
        style: displayStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: colors.ink,
          letterSpacing: -0.2,
        ),
      ),
      content: Text(
        'It will no longer affect the balance, but will remain visible in '
        'the history.',
        style: TextStyle(color: colors.muted, height: 1.35, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Keep entry'.tr),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text('Cancel entry'.tr),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await controller.cancelEntry(entry.id);
    await onChanged?.call();
  } on ApiFailure catch (error) {
    AppSnackbar.error(
      title: 'Could not cancel entry',
      message: error.message,
      position: SnackbarPosition.bottom,
    );
  }
}

class _EntryDetailSheet extends StatelessWidget {
  const _EntryDetailSheet({
    required this.entry,
    this.titleOverride,
    this.useDirectionAvatar = false,
  });

  final LedgerEntry entry;
  final String? titleOverride;
  final bool useDirectionAvatar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gave = entry.action == EntryAction.gave;
    final received = entry.action == EntryAction.received;
    final cancelled = entry.status == EntryStatus.cancelled;
    final synced = entry.localSyncStatus == LocalSyncStatus.synced;
    final canMutate =
        synced && entry.status == EntryStatus.posted && !entry.isOpeningBalance;

    final title =
        titleOverride ??
        (entry.partyName.trim().isEmpty ? 'Entry' : entry.partyName);
    final (badgeLabel, badgeFg, badgeBg) = entry.isOpeningBalance
        ? ('OPENING', colors.amber, colors.amberSoft)
        : gave
        ? ('PAID', colors.muted, colors.settledSoft)
        : ('RECEIVED', colors.green, colors.greenSoft);
    final amountColor = gave
        ? colors.red
        : received
        ? colors.green
        : colors.amber;
    final avatarBackground = gave
        ? colors.redSoft
        : received
        ? colors.greenSoft
        : colors.amberSoft;
    final avatarForeground = gave
        ? colors.red
        : received
        ? colors.green
        : colors.amber;
    final avatarLetter = useDirectionAvatar
        ? (entry.isOpeningBalance ? 'O' : (gave ? '−' : '+'))
        : avatarInitial(title);
    final amountText = entry.isOpeningBalance
        ? formatMoney(entry.amountPaise, absolute: true)
        : formatSignedScreenshotMoney(entry.amountPaise, negative: gave);

    final statusLabel = switch (entry.localSyncStatus) {
      LocalSyncStatus.pending => 'Pending sync',
      LocalSyncStatus.needsAttention => 'Needs review',
      LocalSyncStatus.synced => cancelled ? 'Cancelled' : 'Synced',
    };
    final statusColor = switch (entry.localSyncStatus) {
      LocalSyncStatus.pending => colors.amber,
      LocalSyncStatus.needsAttention => colors.red,
      LocalSyncStatus.synced => cancelled ? colors.muted : colors.greenDark,
    };
    final statusSoft = switch (entry.localSyncStatus) {
      LocalSyncStatus.pending => colors.amberSoft,
      LocalSyncStatus.needsAttention => colors.redSoft,
      LocalSyncStatus.synced =>
        cancelled ? colors.settledSoft : colors.greenSoft,
    };

    final rows = <(String, String)>[
      ('Date', formatShortDate(entry.entryDate)),
      ('Entry #', entry.sequence > 0 ? '${entry.sequence}' : 'On this phone'),
      if (entry.narration.trim().isNotEmpty) ('Note', entry.narration.trim()),
      if ((entry.paymentAccount ?? '').isNotEmpty)
        ('Account', entry.paymentAccount == 'cash' ? 'Cash' : 'Bank'),
      if (entry.createdByName.isNotEmpty) ('Added by', entry.createdByName),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: cancelled ? 0.7 : 1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: avatarBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        avatarLetter,
                        style: displayStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: avatarForeground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                              fontSize: 15,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    color: badgeFg,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amountText,
                      style: displayStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, thickness: 1, color: colors.line),
              const SizedBox(height: 4),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text(
                          row.$1,
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.$2,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (canMutate) ...[
                const SizedBox(height: 8),
                Divider(height: 1, thickness: 1, color: colors.line),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, 'edit'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text('Edit'.tr),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.ink,
                          side: BorderSide(color: colors.line),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, 'cancel'),
                        icon: const Icon(Icons.block_outlined, size: 18),
                        label: Text('Cancel'.tr),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.red,
                          side: BorderSide(
                            color: Color.alphaBlend(
                              colors.red.withValues(alpha: 0.28),
                              colors.line,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
