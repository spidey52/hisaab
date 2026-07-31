import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/balance_widgets.dart';
import '../../shared/widgets/direction_action_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/entry_tile.dart';
import '../../shared/widgets/offline_banner.dart';
import '../ledger/ledger_controller.dart';
import '../shell/navigation_controller.dart';
import '../sync/sync_review_sheet.dart';

class HomePage extends GetView<LedgerController> {
  const HomePage({super.key});

  Future<void> _retrySync() async {
    try {
      await controller.retryPending();
      if (controller.pendingCount.value == 0 &&
          controller.needsAttentionCount.value == 0) {
        Get.snackbar(
          'Sync complete',
          'Saved changes are up to date.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } on Object catch (error) {
      Get.snackbar(
        'Could not sync',
        error.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _addEntry(EntryAction action) {
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
      body: RefreshIndicator(
        onRefresh: () => controller.reload(showLoader: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              title: Obx(
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.data.value?.company.name ?? 'My Hisaab',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'Your ledger at a glance',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
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
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Obx(() {
                    final syncing =
                        controller.syncStatus.value == LedgerSyncStatus.syncing;
                    final visible =
                        controller.isOffline.value ||
                        syncing ||
                        controller.pendingCount.value > 0 ||
                        controller.needsAttentionCount.value > 0;
                    if (!visible) return const SizedBox.shrink();
                    final message =
                        controller.message.value ??
                        (syncing
                            ? 'Uploading changes saved on this phone.'
                            : controller.needsAttentionCount.value > 0
                            ? 'Some saved changes need review before they can sync.'
                            : controller.pendingCount.value > 0
                            ? 'Saved on this phone. Hisaab will retry automatically.'
                            : 'You can keep working. Saved changes will sync when Hisaab reconnects.');
                    return Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: OfflineBanner(
                        message: message,
                        pendingCount: controller.pendingCount.value,
                        needsAttentionCount:
                            controller.needsAttentionCount.value,
                        isSyncing: syncing,
                        isOffline: controller.isOffline.value,
                        lastSyncedAt: controller.lastSyncedAt.value,
                        onRetry: _retrySync,
                        onReview: () => showSyncReviewSheet(context),
                      ),
                    );
                  }),
                  Obx(
                    () => Row(
                      children: [
                        Expanded(
                          child: BalanceCard(
                            label: 'You will receive',
                            amountPaise: controller.totalReceive,
                            kind: BalanceKind.receive,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: BalanceCard(
                            label: 'You will pay',
                            amountPaise: controller.totalPay,
                            kind: BalanceKind.pay,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Text(
                        'Recent activity',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            Get.find<NavigationController>().select(1),
                        child: const Text('View parties'),
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
                        icon: Icons.receipt_long_outlined,
                        title: 'No entries yet',
                        message:
                            'Tap “You gave” or “You got” to record your first entry.',
                        actionLabel: 'Add a party',
                        onAction: () => Get.toNamed(AppRoutes.addParty),
                      );
                    }
                    return Card(
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < entries.length;
                            index++
                          ) ...[
                            EntryTile(entry: entries[index]),
                            if (index != entries.length - 1)
                              const Divider(height: 1),
                          ],
                        ],
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
