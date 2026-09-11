import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app.dart';
import '../../../../data/models/models.dart';
import '../../../../features/ledger/ledger_controller.dart';
import '../../../../shared/widgets/app_snackbar.dart';

class EntryDateGroup {
  const EntryDateGroup({required this.label, required this.entries});

  final String label;
  final List<LedgerEntry> entries;
}

/// Entries tab state: search/filter + date-grouped list via [LedgerController].
class EntriesController extends GetxController {
  LedgerController get ledger => Get.find<LedgerController>();

  late final TextEditingController searchController;

  /// Chip values map to [LedgerController.entryDirection].
  static const chipFilters = <String, String>{
    'all': 'All',
    'received': 'To Receive',
    'gave': 'To Pay',
  };

  @override
  void onInit() {
    super.onInit();
    searchController = TextEditingController(text: ledger.entrySearch.value);
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  RxBool get isLoading => ledger.loading;
  Rxn get data => ledger.data;
  RxString get search => ledger.entrySearch;
  RxString get direction => ledger.entryDirection;
  RxString get period => ledger.entryPeriod;

  String get businessName => ledger.data.value?.company.name ?? 'My Hisaab';

  bool get hasActiveFilter =>
      direction.value != 'all' ||
      period.value != 'all' ||
      search.value.trim().isNotEmpty;

  List<LedgerEntry> get entries => ledger.filteredEntries;

  List<EntryDateGroup> get groupedEntries {
    final groups = <String, List<LedgerEntry>>{};
    final labels = <String, String>{};
    for (final entry in entries) {
      final key = DateFormat('yyyy-MM-dd').format(entry.entryDate.toLocal());
      labels.putIfAbsent(
        key,
        () => DateFormat(
          'd MMMM yyyy',
          Intl.getCurrentLocale(),
        ).format(entry.entryDate.toLocal()),
      );
      groups.putIfAbsent(key, () => []).add(entry);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys)
        EntryDateGroup(label: labels[key]!, entries: groups[key]!),
    ];
  }

  void setSearch(String value) => ledger.entrySearch.value = value;

  void setDirection(String value) => ledger.entryDirection.value = value;

  void setPeriod(String value) => ledger.entryPeriod.value = value;

  void clearFilters() {
    ledger.entryDirection.value = 'all';
    ledger.entryPeriod.value = 'all';
    ledger.entrySearch.value = '';
    searchController.clear();
  }

  void addEntry(EntryAction action) {
    if (ledger.parties.where((party) => !party.isArchived).isEmpty) {
      AppSnackbar.warning(
        title: 'First, add a party',
        message: 'An entry needs a customer or supplier. Add one now.',
        position: SnackbarPosition.bottom,
      );
      Get.toNamed(AppRoutes.addParty);
      return;
    }
    Get.toNamed(AppRoutes.addEntry, arguments: {'action': action});
  }

  Future<void> reloadLedger() => ledger.reload(showLoader: false);
}
