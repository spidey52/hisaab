import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/entry_detail_sheet.dart';
import '../../shared/widget/business_header.dart';
import '../../shared/widget/filter_chip_row.dart';
import '../controllers/entries_controller.dart';
import '../widget/entries_list_row.dart';

class EntriesView extends GetView<EntriesController> {
  const EntriesView({super.key});

  Future<void> _openFilters(BuildContext context) async {
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EntriesFilterSheet(
        initialDirection: controller.direction.value,
        initialPeriod: controller.period.value,
      ),
    );
    if (result == null) return;
    controller.setDirection(result.$1);
    controller.setPeriod(result.$2);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => BusinessHeader(businessName: controller.businessName)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.reloadLedger,
              child: Obx(() {
                final groups = controller.groupedEntries;
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          children: [
                            SearchFilterBar(
                              hintText: 'Search...'.tr,
                              controller: controller.searchController,
                              onChanged: controller.setSearch,
                              onFilterTap: () => _openFilters(context),
                            ),
                            const SizedBox(height: 12),
                            FilterChipRow(
                              selected: controller.direction.value,
                              onSelected: controller.setDirection,
                              options: [
                                for (final entry
                                    in EntriesController.chipFilters.entries)
                                  FilterChipOption(
                                    value: entry.key,
                                    label: entry.value.tr,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (controller.isLoading.value && groups.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (groups.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: controller.hasActiveFilter
                            ? EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No matching entries',
                                message:
                                    'Nothing matches this search or filter. Clear '
                                    'it to see every entry.',
                                actionLabel: 'Clear filters',
                                onAction: controller.clearFilters,
                              )
                            : EmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'No entries yet',
                                message:
                                    'Every entry you record will appear here with '
                                    'its entry number.',
                                actionLabel: 'Record first entry',
                                onAction: () =>
                                    controller.addEntry(EntryAction.received),
                              ),
                      )
                    else
                      for (final group in groups)
                        // Keep the date header sticky only while this group is
                        // on screen — the next date pushes the previous one off.
                        SliverMainAxisGroup(
                          slivers: [
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _EntriesGroupHeaderDelegate(
                                label: group.label,
                                background: colors.page,
                                foreground: colors.ink,
                              ),
                            ),
                            SliverList.separated(
                              itemCount: group.entries.length,
                              separatorBuilder: (_, _) =>
                                  Divider(height: 0.75, color: colors.page),
                              itemBuilder: (context, index) {
                                final entry = group.entries[index];
                                return EntriesListRow(
                                  entry: entry,
                                  onTap: () =>
                                      showEntryDetailSheet(context, entry),
                                );
                              },
                            ),
                          ],
                        ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntriesFilterSheet extends StatefulWidget {
  const _EntriesFilterSheet({
    required this.initialDirection,
    required this.initialPeriod,
  });

  final String initialDirection;
  final String initialPeriod;

  @override
  State<_EntriesFilterSheet> createState() => _EntriesFilterSheetState();
}

class _EntriesFilterSheetState extends State<_EntriesFilterSheet> {
  static const _types = <(String, String)>[
    ('all', 'All'),
    ('gave', 'You gave'),
    ('received', 'You got'),
  ];

  static const _periods = <(String, String)>[
    ('all', 'All time'),
    ('7', '7 days'),
    ('30', '30 days'),
    ('90', '90 days'),
  ];

  late String _direction;
  late String _period;

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
    _period = widget.initialPeriod;
  }

  bool get _hasFilters => _direction != 'all' || _period != 'all';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.page,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter entries',
                          style: displayStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Narrow by type and time period',
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: colors.settledSoft,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _FilterSection(
                title: 'Type',
                child: FilterChipRow(
                  selected: _direction,
                  onSelected: (value) => setState(() => _direction = value),
                  options: [
                    for (final item in _types)
                      FilterChipOption(value: item.$1, label: item.$2),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FilterSection(
                title: 'Period',
                child: FilterChipRow(
                  selected: _period,
                  onSelected: (value) => setState(() => _period = value),
                  options: [
                    for (final item in _periods)
                      FilterChipOption(value: item.$1, label: item.$2),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.pop(context, (_direction, _period)),
                child: const Text('Apply filter'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _hasFilters
                    ? () => Navigator.pop(context, ('all', 'all'))
                    : null,
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _EntriesGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  _EntriesGroupHeaderDelegate({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  static const double _height = 40;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: background,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _EntriesGroupHeaderDelegate oldDelegate) {
    return label != oldDelegate.label ||
        background != oldDelegate.background ||
        foreground != oldDelegate.foreground;
  }
}
