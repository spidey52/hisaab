import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/models.dart';
import '../../../../features/ledger/ledger_controller.dart';
import '../../shared/widget/ledger_activity_row.dart';

/// Home dashboard state: party list + summary, backed by [LedgerController].
class HomeController extends GetxController {
  LedgerController get ledger => Get.find<LedgerController>();

  late final TextEditingController searchController;

  static const chipFilters = <String, String>{
    'active': 'All',
    'receive': 'To Receive',
    'pay': 'To Pay',
  };

  static const advancedFilters = <String, String>{
    'active': 'All active',
    'receive': 'To receive',
    'pay': 'To pay',
    'settled': 'Settled',
    'archived': 'Archived',
  };

  @override
  void onInit() {
    super.onInit();
    searchController = TextEditingController(text: ledger.partySearch.value);
    // Activity-first ordering matches the redesigned Home list.
    if (ledger.partySort.value == 'name') {
      ledger.partySort.value = 'recent';
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  RxBool get isLoading => ledger.loading;
  Rxn<BootstrapData> get data => ledger.data;
  RxString get search => ledger.partySearch;
  RxString get filter => ledger.partyFilter;

  String get businessName => data.value?.company.name ?? 'My Hisaab';

  int get totalReceive => ledger.totalReceive;
  int get totalPay => ledger.totalPay;

  int get receivePeopleCount => ledger.parties
      .where((party) => !party.isArchived && party.balancePaise > 0)
      .length;

  int get payPeopleCount => ledger.parties
      .where((party) => !party.isArchived && party.balancePaise < 0)
      .length;

  List<Party> get parties {
    final parties = [...ledger.filteredParties];
    switch (ledger.partySort.value) {
      case 'balance':
        parties.sort(
          (a, b) => b.balancePaise.abs().compareTo(a.balancePaise.abs()),
        );
      case 'recent':
        final lastActivity = <String, DateTime>{};
        for (final entry in ledger.entries) {
          final at = activityTimeOfEntry(entry);
          if (at == null) continue;
          final current = lastActivity[entry.partyId];
          if (current == null || at.isAfter(current)) {
            lastActivity[entry.partyId] = at;
          }
        }
        DateTime activityOf(Party party) =>
            lastActivity[party.id] ??
            usableDateTime(party.updatedAt) ??
            usableDateTime(party.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        parties.sort((a, b) => activityOf(b).compareTo(activityOf(a)));
      default:
        parties.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return parties;
  }

  LedgerEntry? lastEntryFor(Party party) {
    LedgerEntry? latest;
    DateTime? latestAt;
    for (final entry in ledger.entries) {
      if (entry.partyId != party.id) continue;
      if (entry.status == EntryStatus.cancelled) continue;
      final at = activityTimeOfEntry(entry);
      if (at == null) {
        latest ??= entry;
        continue;
      }
      if (latestAt == null || at.isAfter(latestAt)) {
        latest = entry;
        latestAt = at;
      }
    }
    return latest;
  }

  void setSearch(String value) => ledger.partySearch.value = value;

  void setFilter(String value) => ledger.partyFilter.value = value;

  Future<void> reloadLedger() => ledger.reload(showLoader: false);
}
