import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_utils.dart';
import '../../services/party_communication_service.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/party_tile.dart';
import '../ledger/ledger_controller.dart';

class PartiesPage extends GetView<LedgerController> {
  const PartiesPage({super.key});

  PartyCommunicationService get _communication =>
      Get.isRegistered<PartyCommunicationService>()
      ? Get.find<PartyCommunicationService>()
      : const DevicePartyCommunicationService();

  static const _filters = <String, String>{
    'active': 'All active',
    'receive': 'To receive',
    'pay': 'To pay',
    'settled': 'Settled',
    'archived': 'Archived',
  };

  Future<void> _openFilters(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Show parties',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final filter in _filters.entries)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(filter.value),
                  trailing: controller.partyFilter.value == filter.key
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.green,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, filter.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) controller.partyFilter.value = selected;
  }

  Future<void> _call(BuildContext context, String phone) async {
    try {
      await _communication.openDialer(phone);
    } on CommunicationException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Parties'.tr,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.reload(showLoader: false),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          controller.partySearch.value = value,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search name or phone'.tr,
                        prefixIcon: const Icon(Icons.search_rounded),
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
                        controller.partyFilter.value == 'active'
                            ? 'Filter'.tr
                            : _filters[controller.partyFilter.value]!,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                final parties = controller.filteredParties;
                if (parties.isEmpty) {
                  final searching = controller.partySearch.value.isNotEmpty;
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      EmptyState(
                        icon: searching
                            ? Icons.search_off_rounded
                            : Icons.people_outline_rounded,
                        title: searching
                            ? 'No matching parties'
                            : 'No parties here',
                        message: searching
                            ? 'Try another name or clear the filter.'
                            : 'Add a customer or supplier to start their Hisaab.',
                        actionLabel: searching ? null : 'Add party',
                        onAction: searching
                            ? null
                            : () => Get.toNamed(AppRoutes.addParty),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: parties.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final party = parties[index];
                    return PartyTile(
                      party: party,
                      showTransactionCount: true,
                      onTap: () => Get.toNamed(
                        AppRoutes.party,
                        arguments: {'partyId': party.id},
                      ),
                      onCall: normalizePhoneE164(party.phone).isEmpty
                          ? null
                          : () => _call(context, party.phone),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.addParty),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add party'.tr),
      ),
    );
  }
}
