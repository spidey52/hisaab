import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/app.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/balance_widgets.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/direction_action_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/entry_detail_sheet.dart';
import '../../shared/widgets/entry_tile.dart';
import '../ledger/ledger_controller.dart';
import '../shell/navigation_controller.dart';

class HomePage extends GetView<LedgerController> {
  const HomePage({super.key});

  void _addEntry(EntryAction action) {
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

  void _openParties(String filter) {
    controller.partyFilter.value = filter;
    Get.find<NavigationController>().select(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => controller.reload(showLoader: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              titleSpacing: 16,
              title: Row(
                children: [
                  const BrandMark(size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Obx(
                      () => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.data.value?.company.name ?? 'My Hisaab',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: displayStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'EEEE, d MMMM',
                              Intl.getCurrentLocale(),
                            ).format(DateTime.now()),
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => Get.toNamed(AppRoutes.settings),
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 6),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Obx(
                    () => KhataHeroCard(
                      receivePaise: controller.totalReceive,
                      payPaise: controller.totalPay,
                      onReceiveTap: () => _openParties('receive'),
                      onPayTap: () => _openParties('pay'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DirectionActionButton(
                          action: EntryAction.gave,
                          onPressed: () => _addEntry(EntryAction.gave),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DirectionActionButton(
                          action: EntryAction.received,
                          onPressed: () => _addEntry(EntryAction.received),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Recent activity',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            Get.find<NavigationController>().select(2),
                        child: const Text('All entries'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    final entries = controller.entries
                        .where((entry) => entry.status == EntryStatus.posted)
                        .take(5)
                        .toList();
                    if (entries.isEmpty) {
                      return EmptyState(
                        icon: Icons.auto_stories_outlined,
                        title: 'Your khata is ready',
                        message:
                            'Tap “You gave” or “You got” above to record your '
                            'first entry.',
                        actionLabel: 'Add a party',
                        onAction: () => Get.toNamed(AppRoutes.addParty),
                      );
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < entries.length;
                              index++
                            ) ...[
                              EntryTile(
                                entry: entries[index],
                                onTap: () => showEntryDetailSheet(
                                  context,
                                  entries[index],
                                ),
                              ),
                              if (index != entries.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
