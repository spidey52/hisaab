import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../app/app.dart';
import '../../app/modules/entries/widget/entries_list_row.dart';
import '../../app/modules/shared/widget/ledger_activity_row.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/models.dart';
import '../../data/models/statement_models.dart';
import '../../services/party_communication_service.dart';
import '../../shared/widgets/balance_widgets.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/direction_action_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/entry_detail_sheet.dart';
import '../ledger/ledger_controller.dart';

class PartyDetailPage extends StatefulWidget {
  const PartyDetailPage({super.key});

  @override
  State<PartyDetailPage> createState() => _PartyDetailPageState();
}

class _PartyDetailPageState extends State<PartyDetailPage> {
  static const _pageSize = 100;
  static const _maximumPdfEntries = 2000;

  final _ledger = Get.find<LedgerController>();
  final _scrollController = ScrollController();
  late final PartyCommunicationService _communication =
      Get.isRegistered<PartyCommunicationService>()
      ? Get.find<PartyCommunicationService>()
      : const DevicePartyCommunicationService();

  late final String _partyId;
  String _period = 'all';
  DateTimeRange? _customRange;
  PartyStatementPage? _firstPage;
  final List<StatementEntry> _remoteEntries = [];
  String? _nextCursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _usingLocalFallback = false;
  bool _sharing = false;
  String? _statementError;
  int _requestVersion = 0;
  final Map<String, String> _operationKeys = {};

  /// Local entry ids shown optimistically until the remote statement includes them.
  final Set<String> _pinnedOverlayIds = {};
  Worker? _syncWorker;
  LedgerSyncStatus? _lastSyncStatus;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    _partyId = arguments is Map
        ? arguments['partyId']?.toString() ?? ''
        : arguments?.toString() ?? '';
    _scrollController.addListener(_onScroll);
    _lastSyncStatus = _ledger.syncStatus.value;
    _syncWorker = ever(_ledger.syncStatus, _onSyncStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatement());
  }

  @override
  void dispose() {
    _syncWorker?.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onSyncStatusChanged(LedgerSyncStatus status) {
    final wasSyncing = _lastSyncStatus == LedgerSyncStatus.syncing;
    _lastSyncStatus = status;
    if (!mounted || !wasSyncing) return;
    if (status == LedgerSyncStatus.idle ||
        status == LedgerSyncStatus.waitingToRetry) {
      unawaited(_loadStatement(silent: true));
    }
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 420) {
      unawaited(_loadMore());
    }
  }

  (DateTime?, DateTime?) get _selectedRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      'month' => (DateTime(now.year, now.month), today),
      '30' => (today.subtract(const Duration(days: 29)), today),
      'custom' when _customRange != null => (
        _startOf(_customRange!.start),
        _startOf(_customRange!.end),
      ),
      _ => (null, null),
    };
  }

  Future<void> _loadStatement({bool silent = false}) async {
    final request = ++_requestVersion;
    if (mounted && !silent) {
      setState(() {
        _loading = true;
        _statementError = null;
      });
    }
    final range = _selectedRange;
    try {
      final page = await _ledger.fetchPartyStatement(
        partyId: _partyId,
        from: range.$1,
        to: range.$2,
        limit: _pageSize,
      );
      if (!mounted || request != _requestVersion) return;
      setState(() {
        _firstPage = page;
        _remoteEntries
          ..clear()
          ..addAll(page.entries);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _usingLocalFallback = false;
        _loading = false;
        _statementError = null;
        _pinnedOverlayIds.removeWhere(
          (id) => page.entries.any((item) => item.entry.id == id),
        );
      });
    } on ApiFailure catch (error) {
      if (!mounted || request != _requestVersion) return;
      if (silent && _firstPage != null) {
        // Keep the last good remote page; overlay still covers optimistic rows.
        return;
      }
      setState(() {
        _firstPage = null;
        _remoteEntries.clear();
        _nextCursor = null;
        _hasMore = false;
        _usingLocalFallback = true;
        _statementError = error.isConnectionError ? null : error.message;
        _loading = false;
      });
    }
  }

  Future<void> _openAddEntry({
    required EntryAction action,
    required String partyId,
    int? amountPaise,
  }) async {
    final result = await Get.toNamed(
      AppRoutes.addEntry,
      arguments: {
        'action': action,
        'partyId': partyId,
        'amountPaise': ?amountPaise,
      },
    );
    if (!mounted) return;
    if (result == true) await _loadStatement();
  }

  Future<void> _openOpeningBalance(Party party) async {
    await Get.toNamed(
      AppRoutes.openingBalance,
      arguments: {'partyId': party.id},
    );
    if (mounted) await _loadStatement();
  }

  Future<void> _loadMore() async {
    if (_loading ||
        _loadingMore ||
        _usingLocalFallback ||
        !_hasMore ||
        _nextCursor == null) {
      return;
    }
    final request = _requestVersion;
    final cursor = _nextCursor;
    final range = _selectedRange;
    setState(() => _loadingMore = true);
    try {
      final page = await _ledger.fetchPartyStatement(
        partyId: _partyId,
        from: range.$1,
        to: range.$2,
        limit: _pageSize,
        cursor: cursor,
      );
      if (!mounted || request != _requestVersion) return;
      final known = _remoteEntries.map((item) => item.entry.id).toSet();
      setState(() {
        _remoteEntries.addAll(
          page.entries.where((item) => known.add(item.entry.id)),
        );
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on ApiFailure catch (error) {
      if (!mounted || request != _requestVersion) return;
      if (error.code == 'STATEMENT_CHANGED') {
        _message('The statement changed while loading. Starting again.');
        await _loadStatement();
      } else {
        _message(error.message);
      }
    } finally {
      if (mounted && request == _requestVersion) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _chooseFilter() async {
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
                'Statement period'.tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final item in [
                ('all', 'All time'.tr),
                ('month', 'This month'.tr),
                ('30', 'Last 30 days'.tr),
                ('custom', 'Custom dates'.tr),
              ])
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(item.$2),
                  trailing: _period == item.$1
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.green,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, item.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == 'custom') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        initialDateRange: _customRange,
      );
      if (range == null || !mounted) return;
      setState(() {
        _customRange = range;
        _period = 'custom';
      });
    } else {
      setState(() => _period = selected);
    }
    await _loadStatement();
  }

  Future<void> _showPartyOptions(Party party) async {
    final canMerge =
        !party.isArchived &&
        party.localSyncStatus == LocalSyncStatus.synced &&
        _mergeCandidates(party).isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _PartyOptionsSheet(party: party, canMerge: canMerge),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await Get.toNamed(AppRoutes.addParty, arguments: {'partyId': party.id});
      case 'opening':
        await _openOpeningBalance(party);
      case 'archive':
        await _archive(party);
      case 'merge':
        await _mergeParty(party);
    }
  }

  Future<void> _call(Party party) async {
    try {
      await _communication.openDialer(party.phone);
    } on CommunicationException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _showShareSheet(Party party) async {
    final validPhone = normalizePhoneE164(party.phone).isNotEmpty;
    var includeNotes = false;
    final choice = await showModalBottomSheet<_ShareChoice>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share statement'.tr,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: includeNotes,
                onChanged: (value) => setSheetState(() => includeNotes = value),
                title: Text('Include private notes'.tr),
                subtitle: Text('Private notes stay excluded by default.'.tr),
              ),
              const Divider(height: 1),
              if (validPhone) ...[
                ListTile(
                  leading: const Icon(Icons.chat_outlined),
                  title: Text('WhatsApp'.tr),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _ShareChoice(_ShareAction.whatsApp, includeNotes),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.sms_outlined),
                  title: Text('SMS'.tr),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _ShareChoice(_ShareAction.sms, includeNotes),
                  ),
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Add a valid mobile number'),
                  subtitle: const Text(
                    'Edit this party to enable WhatsApp and SMS.',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Get.toNamed(
                      AppRoutes.addParty,
                      arguments: {'partyId': party.id},
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text('Share PDF'.tr),
                subtitle: const Text('Up to 2,000 entries in one statement'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _ShareChoice(_ShareAction.pdf, includeNotes),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: Text('More sharing options'.tr),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _ShareChoice(_ShareAction.system, includeNotes),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: Text('Copy summary'.tr),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _ShareChoice(_ShareAction.copy, includeNotes),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _performShare(party, choice);
  }

  Future<void> _performShare(Party party, _ShareChoice choice) async {
    setState(() => _sharing = true);
    try {
      final snapshot = choice.action == _ShareAction.pdf
          ? await _completeStatementForPdf()
          : _currentSnapshot(party);
      if (snapshot == null) {
        throw const CommunicationException(
          'Wait for the statement to finish loading.',
        );
      }
      final data = _shareData(party, snapshot);
      final summary = buildStatementMessage(
        data,
        includeNotes: choice.includeNotes,
        maxEntries: choice.action == _ShareAction.sms ? 3 : 6,
      );
      switch (choice.action) {
        case _ShareAction.whatsApp:
          await _communication.openWhatsApp(party.phone, summary);
        case _ShareAction.sms:
          final notice = await _communication.openSmsComposer(
            party.phone,
            summary,
          );
          if (notice != null) _message(notice);
        case _ShareAction.pdf:
          await _communication.shareStatementPdf(
            data,
            includeNotes: choice.includeNotes,
            shareOrigin: _shareOrigin,
          );
        case _ShareAction.system:
          await _communication.shareText(
            summary,
            subject: '${party.name} · Hisaab statement',
            shareOrigin: _shareOrigin,
          );
        case _ShareAction.copy:
          await _communication.copyText(summary);
          _message('Statement summary copied.');
      }
    } on ApiFailure catch (error) {
      _message(error.message);
    } on CommunicationException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<_StatementSnapshot> _completeStatementForPdf() async {
    final party = _ledger.partyById(_partyId);
    if (party == null) {
      throw const CommunicationException('Party not found.');
    }
    if (_usingLocalFallback) {
      final local = _localSnapshot(party);
      if (local.totalCount > _maximumPdfEntries) {
        throw const CommunicationException(
          'This statement has more than 2,000 entries. Choose a shorter period.',
        );
      }
      return local;
    }

    final range = _selectedRange;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final first = await _ledger.fetchPartyStatement(
          partyId: _partyId,
          from: range.$1,
          to: range.$2,
          limit: 200,
        );
        if (first.totalCount > _maximumPdfEntries) {
          throw const CommunicationException(
            'This statement has more than 2,000 entries. Choose a shorter period.',
          );
        }
        final entries = <StatementEntry>[...first.entries];
        var cursor = first.nextCursor;
        var hasMore = first.hasMore;
        while (hasMore) {
          if (entries.length >= _maximumPdfEntries || cursor == null) {
            throw const CommunicationException(
              'This statement is too large. Choose a shorter period.',
            );
          }
          final page = await _ledger.fetchPartyStatement(
            partyId: _partyId,
            from: range.$1,
            to: range.$2,
            limit: 200,
            cursor: cursor,
          );
          entries.addAll(page.entries);
          cursor = page.nextCursor;
          hasMore = page.hasMore;
        }
        return _remoteSnapshot(party, first, entries);
      } on ApiFailure catch (error) {
        if (error.code == 'STATEMENT_CHANGED' && attempt == 0) continue;
        rethrow;
      }
    }
    throw const CommunicationException(
      'The statement kept changing. Try sharing again.',
    );
  }

  Future<void> _openEntry(LedgerEntry entry) async {
    await showEntryDetailSheet(
      context,
      entry,
      titleOverride: _entryTitle(entry),
      useDirectionAvatar: true,
      onChanged: _loadStatement,
    );
  }

  Future<void> _archive(Party party) async {
    final nextArchived = !party.isArchived;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextArchived ? 'Archive this party?' : 'Restore party?'),
        content: Text(
          nextArchived
              ? 'Their statement stays safe, but new entries will be disabled.'
              : 'This party will return to the active list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(nextArchived ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final intent = 'archive:${party.id}:$nextArchived';
      await _ledger.archiveParty(
        party,
        archived: nextArchived,
        idempotencyKey: _operationKey(intent),
      );
      _operationKeys.remove(intent);
    } on ApiFailure catch (error) {
      _message(error.message);
    }
  }

  List<Party> _mergeCandidates(Party source) =>
      _ledger.parties
          .where(
            (party) =>
                party.id != source.id &&
                !party.isArchived &&
                party.localSyncStatus == LocalSyncStatus.synced,
          )
          .toList()
        ..sort((left, right) => left.name.compareTo(right.name));

  Future<void> _mergeParty(Party source) async {
    if (source.localSyncStatus != LocalSyncStatus.synced) {
      _message('Sync this party before merging it.');
      return;
    }
    if (_ledger.pendingCount.value > 0 ||
        _ledger.needsAttentionCount.value > 0) {
      _message('Sync or review saved changes before merging parties.');
      return;
    }
    final candidates = _mergeCandidates(source);
    if (candidates.isEmpty) {
      _message('Add another active party before using merge.');
      return;
    }
    final target = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _MergePartyPicker(source: source, candidates: candidates),
    );
    if (target == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Merge ${source.name} into ${target.name}?'),
        content: Text(
          'Every entry from ${source.name} will move to ${target.name}, and '
          '${source.name} will be removed from the party list. This cannot be '
          'undone.\n\nIf both parties have an opening balance, consolidate or '
          'cancel one of them first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Merge permanently'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final intent = 'merge:${source.id}:${target.id}';
    try {
      await _ledger.mergeParties(
        source: source,
        target: target,
        idempotencyKey: _operationKey(intent),
      );
      _operationKeys.remove(intent);
      if (!mounted) return;
      Get.offNamed(AppRoutes.party, arguments: {'partyId': target.id});
      AppSnackbar.success(
        title: 'Parties merged',
        message: 'All entries are now under ${target.name}.',
        position: SnackbarPosition.bottom,
      );
    } on ApiFailure catch (error) {
      _message(error.message);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _operationKey(String intent) =>
      _operationKeys.putIfAbsent(intent, () => const Uuid().v4());

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final party = _ledger.partyById(_partyId);
      if (party == null) {
        return Scaffold(
          backgroundColor: context.colors.page,
          appBar: AppBar(),
          body: const EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Party not found',
            message: 'This party may have been merged or removed.',
          ),
        );
      }
      final validPhone = normalizePhoneE164(party.phone).isNotEmpty;
      final snapshot = _currentSnapshot(party);
      final colors = context.colors;
      return Scaffold(
        backgroundColor: colors.page,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PartyDetailHeader(
              party: party,
              validPhone: validPhone,
              sharing: _sharing,
              onBack: () => Navigator.maybePop(context),
              onCall: validPhone ? () => _call(party) : null,
              onShare: _loading || _sharing
                  ? null
                  : () => _showShareSheet(party),
              onMarkSettled: !party.isArchived && party.balancePaise != 0
                  ? () => _openAddEntry(
                      action: party.balancePaise > 0
                          ? EntryAction.received
                          : EntryAction.gave,
                      partyId: party.id,
                      amountPaise: party.balancePaise.abs(),
                    )
                  : null,
              onMore: () => unawaited(_showPartyOptions(party)),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadStatement,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!validPhone) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.amberSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Color.alphaBlend(
                                      colors.amber.withValues(alpha: 0.16),
                                      colors.amberSoft,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Add a valid mobile number to call or share '
                                        'directly by WhatsApp or SMS.',
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Get.toNamed(
                                        AppRoutes.addParty,
                                        arguments: {'partyId': party.id},
                                      ),
                                      child: const Text('Edit'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (party.isArchived)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.settledSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colors.line),
                                ),
                                child: Text(
                                  'Archived party — restore it before adding a new entry.',
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DirectionActionButton(
                                      action: EntryAction.gave,
                                      compact: true,
                                      onPressed: () => _openAddEntry(
                                        action: EntryAction.gave,
                                        partyId: party.id,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DirectionActionButton(
                                      action: EntryAction.received,
                                      compact: true,
                                      onPressed: () => _openAddEntry(
                                        action: EntryAction.received,
                                        partyId: party.id,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Statement'.tr,
                                    style: displayStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: colors.ink,
                                    ),
                                  ),
                                ),
                                Material(
                                  color: colors.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: colors.line),
                                  ),
                                  child: InkWell(
                                    onTap: _chooseFilter,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.tune_rounded,
                                            size: 18,
                                            color: colors.muted,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _periodLabel,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: colors.ink,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_usingLocalFallback)
                              const _StatementNotice(
                                icon: Icons.cloud_off_outlined,
                                message:
                                    'Provisional saved statement — pending entries and '
                                    'older server records may change after sync.',
                              ),
                            if (_statementError != null) ...[
                              if (_usingLocalFallback)
                                const SizedBox(height: 8),
                              _StatementNotice(
                                icon: Icons.info_outline_rounded,
                                message: _statementError!,
                              ),
                            ],
                            if (snapshot != null && !_loading) ...[
                              if (_usingLocalFallback ||
                                  _statementError != null ||
                                  !snapshot.authoritative)
                                const SizedBox(height: 10),
                              _StatementSummary(snapshot: snapshot),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (snapshot == null || snapshot.entries.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No entries in this period'.tr,
                          message: 'Try another period or add a new entry.'.tr,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        sliver: SliverList.separated(
                          itemCount: snapshot.entries.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 0.75, color: colors.page),
                          itemBuilder: (context, index) {
                            final item = snapshot.entries[index];
                            return EntriesListRow(
                              entry: item.entry,
                              titleOverride: _entryTitle(item.entry),
                              useDirectionAvatar: true,
                              onTap: () => _openEntry(item.entry),
                            );
                          },
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        child: _loadingMore
                            ? const Center(child: CircularProgressIndicator())
                            : _hasMore
                            ? OutlinedButton(
                                onPressed: _loadMore,
                                child: const Text('Load more'),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  _StatementSnapshot? _currentSnapshot(Party party) {
    if (_loading) return null;
    if (_usingLocalFallback || _firstPage == null) return _localSnapshot(party);
    return _remoteSnapshot(party, _firstPage!, _remoteEntries);
  }

  _StatementSnapshot _remoteSnapshot(
    Party party,
    PartyStatementPage page,
    List<StatementEntry> entries,
  ) {
    final known = entries.map((item) => item.entry.id).toSet();
    _pinnedOverlayIds.removeWhere(known.contains);
    final overlay = _overlayEntries(
      party,
    ).where((item) => !known.contains(item.entry.id)).toList();
    for (final item in overlay) {
      _pinnedOverlayIds.add(item.entry.id);
    }
    final combined = [...overlay, ...entries]..sort(_newestFirst);
    final overlayEffect = overlay
        .where((item) => item.entry.status == EntryStatus.posted)
        .fold<int>(0, (sum, item) => sum + item.entry.balanceEffectPaise);
    final range = _statementDates(party, page.period, combined);
    return _StatementSnapshot(
      from: range.$1,
      to: range.$2,
      openingBalancePaise: page.openingBalancePaise,
      closingBalancePaise: page.closingBalancePaise + overlayEffect,
      entries: combined,
      totalCount: page.totalCount + overlay.length,
      authoritative: overlay.isEmpty,
    );
  }

  _StatementSnapshot _localSnapshot(Party party) {
    final range = _selectedRange;
    final chronological =
        _ledger.entries.where((entry) => entry.partyId == party.id).toList()
          ..sort(_oldestFirstEntries);
    var balance = 0;
    final visible = <StatementEntry>[];
    for (final entry in chronological) {
      final before = range.$1 != null && entry.entryDate.isBefore(range.$1!);
      final after =
          range.$2 != null && entry.entryDate.isAfter(_endOf(range.$2!));
      if (before) {
        if (entry.status == EntryStatus.posted) {
          balance += entry.balanceEffectPaise;
        }
        continue;
      }
      if (after) continue;
      if (entry.status == EntryStatus.posted) {
        balance += entry.balanceEffectPaise;
      }
      visible.add(StatementEntry(entry: entry, runningBalancePaise: balance));
    }
    final opening = chronological
        .where(
          (entry) =>
              range.$1 != null &&
              entry.entryDate.isBefore(range.$1!) &&
              entry.status == EntryStatus.posted,
        )
        .fold<int>(0, (sum, entry) => sum + entry.balanceEffectPaise);
    visible.sort(_newestFirst);
    final dates = _statementDates(
      party,
      StatementPeriod(from: range.$1, to: range.$2),
      visible,
    );
    return _StatementSnapshot(
      from: dates.$1,
      to: dates.$2,
      openingBalancePaise: opening,
      closingBalancePaise: balance,
      entries: visible,
      totalCount: visible.length,
      authoritative: false,
    );
  }

  /// Local rows missing from the remote page: still-pending mutations, plus
  /// ids pinned while waiting for the statement API to catch up after sync.
  List<StatementEntry> _overlayEntries(Party party) {
    final range = _selectedRange;
    final running = <String, int>{};
    final chronological =
        _ledger.entries.where((entry) => entry.partyId == party.id).toList()
          ..sort(_oldestFirstEntries);
    var balance = 0;
    for (final entry in chronological) {
      if (entry.status == EntryStatus.posted) {
        balance += entry.balanceEffectPaise;
      }
      running[entry.id] = balance;
    }
    return chronological
        .where(
          (entry) =>
              (entry.localSyncStatus != LocalSyncStatus.synced ||
                  _pinnedOverlayIds.contains(entry.id)) &&
              (range.$1 == null || !entry.entryDate.isBefore(range.$1!)) &&
              (range.$2 == null || !entry.entryDate.isAfter(_endOf(range.$2!))),
        )
        .map(
          (entry) => StatementEntry(
            entry: entry,
            runningBalancePaise: running[entry.id] ?? 0,
          ),
        )
        .toList();
  }

  (DateTime, DateTime) _statementDates(
    Party party,
    StatementPeriod period,
    List<StatementEntry> entries,
  ) {
    final today = _startOf(DateTime.now());
    var earliest = period.from;
    if (earliest == null && entries.isNotEmpty) {
      earliest = entries
          .map((item) => item.entry.entryDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);
    }
    earliest ??= _startOf(party.createdAt);
    return (_startOf(earliest), _startOf(period.to ?? today));
  }

  StatementShareData _shareData(Party party, _StatementSnapshot snapshot) =>
      StatementShareData(
        ledgerName: _ledger.data.value?.company.name ?? 'Hisaab',
        partyName: party.name,
        from: snapshot.from,
        to: snapshot.to,
        openingBalancePaise: snapshot.openingBalancePaise,
        closingBalancePaise: snapshot.closingBalancePaise,
        entries: snapshot.entries
            .map(
              (item) => StatementShareEntry(
                entry: item.entry,
                runningBalancePaise: item.runningBalancePaise,
                provisional:
                    item.entry.localSyncStatus != LocalSyncStatus.synced,
              ),
            )
            .toList(),
        totalEntryCount: snapshot.totalCount,
        authoritative: snapshot.authoritative,
      );

  Rect? get _shareOrigin {
    final render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize) return null;
    return render.localToGlobal(Offset.zero) & render.size;
  }

  int _newestFirst(StatementEntry a, StatementEntry b) {
    final date = b.entry.entryDate.compareTo(a.entry.entryDate);
    return date != 0 ? date : b.entry.sequence.compareTo(a.entry.sequence);
  }

  int _oldestFirstEntries(LedgerEntry a, LedgerEntry b) {
    final date = a.entryDate.compareTo(b.entryDate);
    return date != 0 ? date : a.sequence.compareTo(b.sequence);
  }

  String _entryTitle(LedgerEntry entry) {
    final note = entry.narration.trim();
    if (note.isNotEmpty) return note;
    if (entry.isOpeningBalance) return 'Opening balance';
    return entry.action == EntryAction.gave ? 'You gave' : 'You got';
  }

  String get _periodLabel => switch (_period) {
    'month' => 'This month'.tr,
    '30' => 'Last 30 days'.tr,
    'custom' => 'Custom dates'.tr,
    _ => 'Filter'.tr,
  };

  DateTime _startOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _endOf(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}

enum _ShareAction { whatsApp, sms, pdf, system, copy }

/// Green party header + white balance card, matching Home / Entries chrome.
class _PartyDetailHeader extends StatelessWidget {
  const _PartyDetailHeader({
    required this.party,
    required this.validPhone,
    required this.sharing,
    required this.onBack,
    required this.onCall,
    required this.onShare,
    required this.onMarkSettled,
    required this.onMore,
  });

  final Party party;
  final bool validPhone;
  final bool sharing;
  final VoidCallback onBack;
  final VoidCallback? onCall;
  final VoidCallback? onShare;
  final VoidCallback? onMarkSettled;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kind = party.balanceKind;
    final amountColor = kind == BalanceKind.pay
        ? colors.red
        : kind == BalanceKind.receive
        ? colors.green
        : colors.muted;
    final label = kind == BalanceKind.pay
        ? "You'll Pay"
        : kind == BalanceKind.receive
        ? "You'll Receive"
        : 'Settled';
    final avatar = avatarColorsForName(party.name, colors);
    final phoneDisplay = party.phone.trim().isEmpty
        ? null
        : formatPhoneForDisplay(party.phone);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        width: double.infinity,
        color: colors.brand,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Row(
                  children: [
                    _HeaderIconButton(
                      tooltip: 'Back',
                      onPressed: onBack,
                      icon: Icons.arrow_back_rounded,
                    ),
                    Expanded(
                      child: Text(
                        party.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: displayStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.onBrand,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (onCall != null)
                      _HeaderIconButton(
                        tooltip: '${'Call'.tr} ${party.name}',
                        onPressed: onCall,
                        icon: Icons.call_outlined,
                      ),
                    _HeaderIconButton(
                      tooltip: 'Share statement'.tr,
                      onPressed: onShare,
                      icon: Icons.ios_share_rounded,
                      busy: sharing,
                    ),
                    _HeaderIconButton(
                      tooltip: 'Party options',
                      onPressed: onMore,
                      icon: Icons.more_vert_rounded,
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.ink.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: avatar.background,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        avatarInitial(party.name),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: avatar.foreground,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatMoney(party.balancePaise, absolute: true),
                              style: displayStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: amountColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          if (phoneDisplay != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              phoneDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onMarkSettled != null) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: avatar.background,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: onMarkSettled,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.task_alt_rounded,
                                  size: 15,
                                  color: avatar.foreground,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Settle'.tr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: avatar.foreground,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _PartyOptionsSheet extends StatelessWidget {
  const _PartyOptionsSheet({required this.party, required this.canMerge});

  final Party party;
  final bool canMerge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final archived = party.isArchived;
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
                          'Party options'.tr,
                          style: displayStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colors.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          party.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 16),
              _PartyOptionsCard(
                children: [
                  _PartyOptionTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit party'.tr,
                    subtitle: 'Name, phone, group, or notes',
                    onTap: () => Navigator.pop(context, 'edit'),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 62,
                    color: colors.line,
                  ),
                  _PartyOptionTile(
                    icon: Icons.flag_outlined,
                    title: 'Opening balance'.tr,
                    subtitle: archived
                        ? 'Restore this party to set an opening balance'
                        : 'Set or update the starting balance',
                    enabled: !archived,
                    onTap: archived
                        ? null
                        : () => Navigator.pop(context, 'opening'),
                  ),
                  if (canMerge) ...[
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 62,
                      color: colors.line,
                    ),
                    _PartyOptionTile(
                      icon: Icons.merge_outlined,
                      title: 'Merge duplicate party'.tr,
                      subtitle: 'Move entries into another party',
                      onTap: () => Navigator.pop(context, 'merge'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _PartyOptionsCard(
                children: [
                  _PartyOptionTile(
                    icon: archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    title: archived ? 'Restore party'.tr : 'Archive party'.tr,
                    subtitle: archived
                        ? 'Bring this party back for new entries'
                        : 'Hide from Home without deleting history',
                    iconBackground: archived
                        ? colors.greenSoft
                        : colors.amberSoft,
                    iconColor: archived ? colors.greenDark : colors.amber,
                    onTap: () => Navigator.pop(context, 'archive'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyOptionsCard extends StatelessWidget {
  const _PartyOptionsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _PartyOptionTile extends StatelessWidget {
  const _PartyOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.iconBackground,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? iconBackground;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = enabled ? colors.ink : colors.muted;
    final muted = colors.muted.withValues(alpha: enabled ? 1 : 0.7);
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackground ?? colors.greenSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: iconColor ?? colors.greenDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.muted.withValues(alpha: enabled ? 1 : 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.busy = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: colors.onBrand.withValues(alpha: 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onBrand,
                        ),
                      )
                    : Icon(icon, size: 18, color: colors.onBrand),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MergePartyPicker extends StatefulWidget {
  const _MergePartyPicker({required this.source, required this.candidates});

  final Party source;
  final List<Party> candidates;

  @override
  State<_MergePartyPicker> createState() => _MergePartyPickerState();
}

class _MergePartyPickerState extends State<_MergePartyPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final digits = query.replaceAll(RegExp(r'\D'), '');
    final parties = widget.candidates.where((party) {
      if (query.isEmpty || party.name.toLowerCase().contains(query)) {
        return true;
      }
      return digits.isNotEmpty &&
          party.phone.replaceAll(RegExp(r'\D'), '').contains(digits);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merge ${widget.source.name} into…',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the party record you want to keep.',
                  style: TextStyle(color: context.colors.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search name or phone',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: parties.isEmpty
                ? const Center(child: Text('No matching active party'))
                : ListView.separated(
                    controller: controller,
                    itemCount: parties.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final party = parties[index];
                      return ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.colors.greenSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            initials(party.name),
                            style: displayStyle(
                              fontSize: 15,
                              color: context.colors.greenDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          party.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          party.phone.isNotEmpty
                              ? formatPhoneForDisplay(party.phone)
                              : party.reference,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, party),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShareChoice {
  const _ShareChoice(this.action, this.includeNotes);

  final _ShareAction action;
  final bool includeNotes;
}

class _StatementSnapshot {
  const _StatementSnapshot({
    required this.from,
    required this.to,
    required this.openingBalancePaise,
    required this.closingBalancePaise,
    required this.entries,
    required this.totalCount,
    required this.authoritative,
  });

  final DateTime from;
  final DateTime to;
  final int openingBalancePaise;
  final int closingBalancePaise;
  final List<StatementEntry> entries;
  final int totalCount;
  final bool authoritative;
}

class _StatementSummary extends StatelessWidget {
  const _StatementSummary({required this.snapshot});

  final _StatementSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${formatShortDate(snapshot.from)} – ${formatShortDate(snapshot.to)}',
              style: TextStyle(
                color: colors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BalanceBox(
                  label: 'Opening balance'.tr,
                  balancePaise: snapshot.openingBalancePaise,
                ),
              ),
              Container(width: 1, height: 64, color: colors.line),
              Expanded(
                child: _BalanceBox(
                  label: 'Closing balance'.tr,
                  balancePaise: snapshot.closingBalancePaise,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceBox extends StatelessWidget {
  const _BalanceBox({required this.label, required this.balancePaise});

  final String label;
  final int balancePaise;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kind = balancePaise > 0
        ? BalanceKind.receive
        : balancePaise < 0
        ? BalanceKind.pay
        : BalanceKind.settled;
    final amountColor = kind == BalanceKind.pay
        ? colors.red
        : kind == BalanceKind.receive
        ? colors.green
        : colors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(balancePaise, absolute: true),
              style: displayStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: amountColor,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            balanceSentenceText(balancePaise),
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementNotice extends StatelessWidget {
  const _StatementNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.amberSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color.alphaBlend(
            colors.amber.withValues(alpha: 0.16),
            colors.amberSoft,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.amber),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
