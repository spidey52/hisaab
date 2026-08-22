import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../features/ledger/ledger_controller.dart';
import 'entry_tile.dart';

/// One entry detail sheet for the whole app: the same fields and actions
/// whether the entry was opened from Home, the Entries tab, or a statement.
Future<void> showEntryDetailSheet(
  BuildContext context,
  LedgerEntry entry,
) async {
  final controller = Get.find<LedgerController>();
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) {
      final colors = context.colors;
      final statusLabel = switch (entry.localSyncStatus) {
        LocalSyncStatus.pending => 'Saved on this phone, waiting to sync',
        LocalSyncStatus.needsAttention => 'Needs review before it can sync',
        LocalSyncStatus.synced =>
          entry.status == EntryStatus.cancelled ? 'Cancelled' : 'Saved',
      };
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntryTile(
                entry: entry,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              const Divider(height: 24),
              _DetailRow('Date', formatShortDate(entry.entryDate)),
              if (entry.sequence > 0)
                _DetailRow('Entry number', '${entry.sequence}')
              else
                const _DetailRow('Entry number', 'On this phone'),
              if (entry.narration.trim().isNotEmpty)
                _DetailRow('Note', entry.narration.trim()),
              if ((entry.paymentAccount ?? '').isNotEmpty)
                _DetailRow(
                  'Account',
                  entry.paymentAccount == 'cash' ? 'Cash' : 'Bank',
                ),
              if (entry.createdByName.isNotEmpty)
                _DetailRow('Added by', entry.createdByName),
              _DetailRow('Status', statusLabel),
              if (entry.status == EntryStatus.posted &&
                  !entry.isOpeningBalance) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit entry'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.red,
                    side: BorderSide(
                      color: Color.alphaBlend(
                        colors.red.withValues(alpha: 0.3),
                        colors.line,
                      ),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Cancel this entry'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    await Get.toNamed(AppRoutes.addEntry, arguments: {'entryId': entry.id});
    return;
  }
  if (action != 'cancel') return;
  if (!context.mounted) return;
  final colors = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel this entry?'),
      content: const Text(
        'It will no longer affect the balance, but will remain visible in '
        'the history.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep entry'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Cancel entry'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await controller.cancelEntry(entry.id);
  } on ApiFailure catch (error) {
    Get.snackbar(
      'Could not cancel entry',
      error.message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: TextStyle(color: context.colors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
