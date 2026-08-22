import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/direction_action_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/entry_detail_sheet.dart';
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
                  style: Theme.of(context).textTheme.titleLarge,
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

  void _add(EntryAction action) {
    if (controller.parties.where((party) => !party.isArchived).isEmpty) {
      Get.snackbar(
        'First, add a party',
        'An entry needs a customer or supplier. Add one now.',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.toNamed(AppRoutes.addParty);
      return;
    }
    Get.toNamed(AppRoutes.addEntry, arguments: {'action': action});
  }

  bool get _hasActiveFilter =>
      controller.entryDirection.value != 'all' ||
      controller.entryPeriod.value != 'all' ||
      controller.entrySearch.value.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entries')),
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
                            hintText: 'Search party, note or number',
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
                  final filtered = _hasActiveFilter;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (filtered)
                        EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No matching entries',
                          message:
                              'Nothing matches this search or filter. Clear '
                              'it to see every entry.',
                          actionLabel: 'Clear filters',
                          onAction: () {
                            controller.entryDirection.value = 'all';
                            controller.entryPeriod.value = 'all';
                            controller.entrySearch.value = '';
                          },
                        )
                      else
                        EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No entries yet',
                          message:
                              'Every entry you record will appear here with '
                              'its entry number.',
                          actionLabel: 'Record first entry',
                          onAction: () => _add(EntryAction.received),
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
                    onTap: () => showEntryDetailSheet(context, entries[index]),
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
