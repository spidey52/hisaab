import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/party_tile.dart';
import '../ledger/ledger_controller.dart';

class PartiesPage extends GetView<LedgerController> {
  const PartiesPage({super.key});

  static const _filters = <String, String>{
    'active': 'All active',
    'receive': 'To receive',
    'pay': 'To pay',
    'settled': 'Settled',
    'archived': 'Archived',
  };

  static const _sorts = <String, String>{
    'name': 'Name',
    'balance': 'Highest balance',
    'recent': 'Recent',
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
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final filter in _filters.entries)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(filter.value),
                  trailing: controller.partyFilter.value == filter.key
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.green,
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

  List<Party> _sortedParties() {
    final parties = [...controller.filteredParties];
    switch (controller.partySort.value) {
      case 'balance':
        parties.sort(
          (a, b) => b.balancePaise.abs().compareTo(a.balancePaise.abs()),
        );
      case 'recent':
        final lastActivity = <String, DateTime>{};
        for (final entry in controller.entries) {
          final current = lastActivity[entry.partyId];
          if (current == null || entry.createdAt.isAfter(current)) {
            lastActivity[entry.partyId] = entry.createdAt;
          }
        }
        DateTime activityOf(Party party) =>
            lastActivity[party.id] ?? party.createdAt;
        parties.sort((a, b) => activityOf(b).compareTo(activityOf(a)));
      default:
        parties.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return parties;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Parties'.tr)),
      body: RefreshIndicator(
        onRefresh: () => controller.reload(showLoader: false),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _PartySearchField(search: controller.partySearch),
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
            SizedBox(
              height: 52,
              child: Obx(
                () => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  children: [
                    for (final sort in _sorts.entries) ...[
                      ChoiceChip(
                        label: Text(sort.value.tr),
                        visualDensity: VisualDensity.compact,
                        selected: controller.partySort.value == sort.key,
                        onSelected: (_) =>
                            controller.partySort.value = sort.key,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                final parties = _sortedParties();
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

/// Search box for the party list with a clear (×) button that appears only
/// while the query is non-empty. Keeps [search] in sync with the field.
class _PartySearchField extends StatefulWidget {
  const _PartySearchField({required this.search});

  final RxString search;

  @override
  State<_PartySearchField> createState() => _PartySearchFieldState();
}

class _PartySearchFieldState extends State<_PartySearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.search.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.search.value = '';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) => TextField(
        controller: _controller,
        onChanged: (text) => widget.search.value = text,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search name or phone'.tr,
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search'.tr,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: _clear,
                ),
        ),
      ),
    );
  }
}
