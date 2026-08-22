import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../app/app.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/models.dart';
import '../../data/models/statement_models.dart';
import '../../services/party_communication_service.dart';
import '../../shared/widgets/balance_widgets.dart';
import '../../shared/widgets/direction_action_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/entry_tile.dart';
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

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    _partyId = arguments is Map
        ? arguments['partyId']?.toString() ?? ''
        : arguments?.toString() ?? '';
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatement());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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

  Future<void> _loadStatement() async {
    final request = ++_requestVersion;
    if (mounted) {
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
      });
    } on ApiFailure catch (error) {
      if (!mounted || request != _requestVersion) return;
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
    final pending = entry.localSyncStatus != LocalSyncStatus.synced;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EntryTile(
                entry: entry,
                showPartyName: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              const Divider(height: 24),
              _DetailRow('Date', formatShortDate(entry.entryDate)),
              if (entry.sequence > 0)
                _DetailRow('Entry number', '${entry.sequence}'),
              if (pending) const _DetailRow('Status', 'Pending sync'),
              if (entry.narration.trim().isNotEmpty)
                _DetailRow('Note', entry.narration.trim()),
              if (entry.paymentAccount != null)
                _DetailRow(
                  'Account',
                  entry.paymentAccount == 'bank' ? 'Bank' : 'Cash',
                ),
              if (!pending &&
                  entry.status == EntryStatus.posted &&
                  !entry.isOpeningBalance) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text('Edit entry'.tr),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'cancel'),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Cancel this entry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await Get.toNamed(AppRoutes.addEntry, arguments: {'entryId': entry.id});
    } else if (action == 'cancel') {
      await _confirmCancel(entry);
    }
  }

  Future<void> _confirmCancel(LedgerEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this entry?'),
        content: const Text(
          'Its amount will stop affecting the balance. The cancelled entry '
          'will remain visible for a clear history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep entry'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel entry'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final intent = 'cancel:${entry.id}';
      await _ledger.cancelEntry(
        entry.id,
        idempotencyKey: _operationKey(intent),
      );
      _operationKeys.remove(intent);
      await _loadStatement();
    } on ApiFailure catch (error) {
      _message(error.message);
    }
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
      Get.snackbar(
        'Parties merged',
        'All entries are now under ${target.name}.',
        snackPosition: SnackPosition.BOTTOM,
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
      return Scaffold(
        appBar: AppBar(
          title: Text(party.name),
          actions: [
            if (validPhone)
              IconButton(
                tooltip: '${'Call'.tr} ${party.name}',
                onPressed: () => _call(party),
                icon: const Icon(Icons.call_outlined),
              ),
            IconButton(
              tooltip: 'Share statement'.tr,
              onPressed: _loading || _sharing
                  ? null
                  : () => _showShareSheet(party),
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'Party options',
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    Get.toNamed(
                      AppRoutes.addParty,
                      arguments: {'partyId': party.id},
                    );
                  case 'opening':
                    Get.toNamed(
                      AppRoutes.openingBalance,
                      arguments: {'partyId': party.id},
                    );
                  case 'archive':
                    _archive(party);
                  case 'merge':
                    _mergeParty(party);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit party'),
                  ),
                ),
                PopupMenuItem(
                  value: 'opening',
                  enabled: !party.isArchived,
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.flag_outlined),
                    title: Text('Opening balance'),
                  ),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      party.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    title: Text(
                      party.isArchived ? 'Restore party' : 'Archive party',
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'merge',
                  enabled:
                      !party.isArchived &&
                      party.localSyncStatus == LocalSyncStatus.synced &&
                      _mergeCandidates(party).isNotEmpty,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.merge_outlined),
                    title: Text('Merge duplicate party'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadStatement,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                sliver: SliverList.list(
                  children: [
                    _PartyHeader(party: party, validPhone: validPhone),
                    const SizedBox(height: 14),
                    BalanceSentence(
                      balancePaise: party.balancePaise,
                      partyName: party.name,
                    ),
                    if (!validPhone) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.amberSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color.alphaBlend(
                              context.colors.amber.withValues(alpha: 0.16),
                              context.colors.amberSoft,
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
                    ],
                    const SizedBox(height: 16),
                    if (party.isArchived)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.settledSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.line),
                        ),
                        child: Text(
                          'Archived party — restore it before adding a new entry.',
                          style: TextStyle(
                            color: context.colors.muted,
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
                              onPressed: () => Get.toNamed(
                                AppRoutes.addEntry,
                                arguments: {
                                  'action': EntryAction.gave,
                                  'partyId': party.id,
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DirectionActionButton(
                              action: EntryAction.received,
                              compact: true,
                              onPressed: () => Get.toNamed(
                                AppRoutes.addEntry,
                                arguments: {
                                  'action': EntryAction.received,
                                  'partyId': party.id,
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (party.balancePaise != 0) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Get.toNamed(
                            AppRoutes.addEntry,
                            arguments: {
                              'action': party.balancePaise > 0
                                  ? EntryAction.received
                                  : EntryAction.gave,
                              'partyId': party.id,
                              'amountPaise': party.balancePaise.abs(),
                            },
                          ),
                          icon: const Icon(Icons.task_alt_rounded),
                          label: Text('Mark settled'.tr),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Statement'.tr,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: _chooseFilter,
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: Text(_periodLabel),
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
                    if (_statementError != null)
                      _StatementNotice(
                        icon: Icons.info_outline_rounded,
                        message: _statementError!,
                      ),
                    if (snapshot != null && !_loading) ...[
                      if (_usingLocalFallback || !snapshot.authoritative)
                        const SizedBox(height: 10),
                      _StatementSummary(snapshot: snapshot),
                      const SizedBox(height: 12),
                    ],
                  ],
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList.builder(
                    itemCount: snapshot.entries.length,
                    itemBuilder: (context, index) {
                      final item = snapshot.entries[index];
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: context.colors.line),
                          ),
                        ),
                        child: EntryTile(
                          entry: item.entry,
                          showPartyName: false,
                          runningBalancePaise: item.runningBalancePaise,
                          onTap: () => _openEntry(item.entry),
                        ),
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
    final pending = _pendingEntries(
      party,
    ).where((item) => !known.contains(item.entry.id)).toList();
    final combined = [...pending, ...entries]..sort(_newestFirst);
    final pendingEffect = pending
        .where((item) => item.entry.status == EntryStatus.posted)
        .fold<int>(0, (sum, item) => sum + item.entry.balanceEffectPaise);
    final range = _statementDates(party, page.period, combined);
    return _StatementSnapshot(
      from: range.$1,
      to: range.$2,
      openingBalancePaise: page.openingBalancePaise,
      closingBalancePaise: page.closingBalancePaise + pendingEffect,
      entries: combined,
      totalCount: page.totalCount + pending.length,
      authoritative: pending.isEmpty,
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

  List<StatementEntry> _pendingEntries(Party party) {
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
              entry.localSyncStatus != LocalSyncStatus.synced &&
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

/// Header identity block: rounded-square avatar toned by the balance
/// direction, party name, and the phone number when one is saved.
class _PartyHeader extends StatelessWidget {
  const _PartyHeader({required this.party, required this.validPhone});

  final Party party;
  final bool validPhone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tones = balanceTones(context, party.balanceKind);
    return Semantics(
      container: true,
      label:
          '${party.name}'
          '${party.phone.isEmpty ? '' : ', ${formatPhoneForDisplay(party.phone)}'}',
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tones.background,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: tones.border),
            ),
            child: Text(
              initials(party.name),
              style: displayStyle(
                fontSize: 18,
                color: tones.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  party.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (party.phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        validPhone
                            ? Icons.phone_outlined
                            : Icons.phone_disabled_outlined,
                        size: 16,
                        color: colors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          formatPhoneForDisplay(party.phone),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.35;
    final opening = _BalanceBox(
      label: 'Opening balance'.tr,
      balancePaise: snapshot.openingBalancePaise,
    );
    final closing = _BalanceBox(
      label: 'Closing balance'.tr,
      balancePaise: snapshot.closingBalancePaise,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatShortDate(snapshot.from)} – ${formatShortDate(snapshot.to)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.muted),
        ),
        const SizedBox(height: 8),
        if (largeText)
          Column(children: [opening, const SizedBox(height: 8), closing])
        else
          Row(
            children: [
              Expanded(child: opening),
              const SizedBox(width: 8),
              Expanded(child: closing),
            ],
          ),
      ],
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
    final tones = balanceTones(context, kind);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tones.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tones.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tones.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            formatMoney(balancePaise, absolute: true),
            style: displayStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: tones.foreground,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            balanceSentenceText(balancePaise),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.muted,
              fontSize: 12,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: TextStyle(color: context.colors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
