import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/app.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../shared/widget/business_header.dart';
import '../../shared/widget/filter_chip_row.dart';
import '../controllers/home_controller.dart';
import '../widget/home_party_row.dart';
import '../widget/home_summary_card.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  Future<void> _openAdvancedFilters(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HomeFilterSheet(selected: controller.filter.value),
    );
    if (selected != null) controller.setFilter(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(
            () => BusinessHeader(
              businessName: controller.businessName,
              bottom: HomeSummaryCard(
                receivePaise: controller.totalReceive,
                payPaise: controller.totalPay,
                receivePeople: controller.receivePeopleCount,
                payPeople: controller.payPeopleCount,
                onReceiveTap: () => controller.setFilter('receive'),
                onPayTap: () => controller.setFilter('pay'),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.reloadLedger,
              child: Obx(() {
                final parties = controller.parties;
                final chipValue =
                    HomeController.chipFilters.containsKey(
                      controller.filter.value,
                    )
                    ? controller.filter.value
                    : 'active';

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          children: [
                            SearchFilterBar(
                              hintText: 'Search...'.tr,
                              controller: controller.searchController,
                              onChanged: controller.setSearch,
                              onFilterTap: () => _openAdvancedFilters(context),
                            ),
                            const SizedBox(height: 12),
                            FilterChipRow(
                              selected: chipValue,
                              onSelected: controller.setFilter,
                              options: [
                                for (final entry
                                    in HomeController.chipFilters.entries)
                                  FilterChipOption(
                                    value: entry.key,
                                    label: entry.value.tr,
                                  ),
                              ],
                              trailing: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.brand,
                                  side: BorderSide(color: colors.brand),
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () =>
                                    Get.toNamed(AppRoutes.addParty),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(
                                  'Party'.tr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (controller.isLoading.value && parties.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (parties.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: controller.search.value.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.people_outline_rounded,
                          title: controller.search.value.isNotEmpty
                              ? 'No matching parties'
                              : 'No parties here',
                          message: controller.search.value.isNotEmpty
                              ? 'Try another name or clear the filter.'
                              : 'Add a customer or supplier to start their Hisaab.',
                          actionLabel: controller.search.value.isNotEmpty
                              ? null
                              : 'Add party',
                          onAction: controller.search.value.isNotEmpty
                              ? null
                              : () => Get.toNamed(AppRoutes.addParty),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        sliver: SliverList.separated(
                          itemCount: parties.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 0.75, color: colors.page),
                          itemBuilder: (context, index) {
                            final party = parties[index];
                            return HomePartyRow(
                              party: party,
                              lastEntry: controller.lastEntryFor(party),
                              onTap: () => Get.toNamed(
                                AppRoutes.party,
                                arguments: {'partyId': party.id},
                              ),
                            );
                          },
                        ),
                      ),
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

class _HomeFilterSheet extends StatelessWidget {
  const _HomeFilterSheet({required this.selected});

  final String selected;

  static const _icons = <String, IconData>{
    'active': Icons.people_alt_outlined,
    'receive': Icons.south_west_rounded,
    'pay': Icons.north_east_rounded,
    'settled': Icons.task_alt_rounded,
    'archived': Icons.inventory_2_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filters = HomeController.advancedFilters.entries.toList();

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
                          'Show parties',
                          style: displayStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose which parties appear on Home',
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
              Container(
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
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < filters.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: colors.line),
                      _HomeFilterTile(
                        label: filters[i].value,
                        icon:
                            _icons[filters[i].key] ?? Icons.filter_list_rounded,
                        selected: selected == filters[i].key,
                        onTap: () => Navigator.pop(context, filters[i].key),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeFilterTile extends StatelessWidget {
  const _HomeFilterTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected
          ? Color.alphaBlend(
              colors.brand.withValues(alpha: 0.06),
              colors.surface,
            )
          : colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colors.greenSoft : colors.settledSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? colors.greenDark : colors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: colors.green, size: 22)
              else
                Icon(Icons.circle_outlined, color: colors.line, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
