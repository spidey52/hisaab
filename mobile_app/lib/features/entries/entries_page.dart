import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/direction_action_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/entry_tile.dart';
import '../ledger/ledger_controller.dart';

class EntriesPage extends GetView<LedgerController> {
  const EntriesPage({super.key});

  Future<void> _openFilters(BuildContext context) async {
    var direction = controller.entryDirection.value;
    var period = controller.entryPeriod.value;
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter entries',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final item in const [
                      ('all', 'All'),
                      ('gave', 'You gave'),
                      ('received', 'You got'),
                    ])
                      ChoiceChip(
                        label: Text(item.$2),
                        selected: direction == item.$1,
                        onSelected: (_) =>
                            setSheetState(() => direction = item.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Period',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in const [
                      ('all', 'All time'),
                      ('7', '7 days'),
                      ('30', '30 days'),
                      ('90', '90 days'),
                    ])
                      ChoiceChip(
                        label: Text(item.$2),
                        selected: period == item.$1,
                        onSelected: (_) =>
                            setSheetState(() => period = item.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => Navigator.pop(context, (direction, period)),
                  child: const Text('Apply filter'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, ('all', 'all')),
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == null) return;
    controller.entryDirection.value = result.$1;
    controller.entryPeriod.value = result.$2;
  }

  Future<void> _openEntry(BuildContext context, LedgerEntry entry) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
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
              _EntryDetailRow('Date', formatShortDate(entry.entryDate)),
              _EntryDetailRow('Entry number', '${entry.sequence}'),
              if (entry.narration.trim().isNotEmpty)
                _EntryDetailRow('Note', entry.narration.trim()),
              if (entry.createdByName.isNotEmpty)
                _EntryDetailRow('Added by', entry.createdByName),
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
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Cancel this entry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'edit') {
      await Get.toNamed(AppRoutes.addEntry, arguments: {'entryId': entry.id});
      return;
    }
    if (action != 'cancel') return;
    if (!context.mounted) return;
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
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

  void _add(EntryAction action) {
    if (controller.parties.where((party) => !party.isArchived).isEmpty) {
      Get.toNamed(AppRoutes.addParty);
      Get.snackbar(
        'Add a party first',
        'Choose who this entry is for.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.toNamed(AppRoutes.addEntry, arguments: {'action': action});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Entries',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.reload(showLoader: false),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DirectionActionButton(
                          action: EntryAction.gave,
                          compact: true,
                          onPressed: () => _add(EntryAction.gave),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DirectionActionButton(
                          action: EntryAction.received,
                          compact: true,
                          onPressed: () => _add(EntryAction.received),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) =>
                              controller.entrySearch.value = value,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'Search entries',
                            prefixIcon: Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Obx(
                        () => OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: () => _openFilters(context),
                          icon: const Icon(Icons.tune_rounded, size: 20),
                          label: Text(
                            controller.entryDirection.value == 'all' &&
                                    controller.entryPeriod.value == 'all'
                                ? 'Filter'
                                : 'Filtered',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                final entries = controller.filteredEntries;
                if (entries.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No matching entries',
                        message:
                            'Try clearing the filter or record a new entry.',
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => EntryTile(
                    entry: entries[index],
                    onTap: () => _openEntry(context, entries[index]),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryDetailRow extends StatelessWidget {
  const _EntryDetailRow(this.label, this.value);

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
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
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
