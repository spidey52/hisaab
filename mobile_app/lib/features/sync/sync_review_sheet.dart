import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ledger_repository.dart';
import '../ledger/ledger_controller.dart';
import 'sync_change_editor.dart';

Future<void> showSyncReviewSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SyncReviewSheet(),
    );

class _SyncReviewSheet extends StatefulWidget {
  const _SyncReviewSheet();

  @override
  State<_SyncReviewSheet> createState() => _SyncReviewSheetState();
}

class _SyncReviewSheetState extends State<_SyncReviewSheet> {
  final _storage = Get.find<AppStorage>();
  final _ledger = Get.find<LedgerController>();

  List<StoredOutboxOperation> _operations = const [];
  bool _loading = true;
  String? _workingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final operations = await _storage.readOutbox(
      states: const {OutboxState.needsAttention},
    );
    operations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _operations = operations;
      _loading = false;
      _workingId = null;
    });
  }

  Future<void> _retry(StoredOutboxOperation operation) async {
    setState(() => _workingId = operation.id);
    try {
      await _ledger.retryPending(operationId: operation.id);
      await _load();
      if (!mounted) return;
      _message(
        _operations.any((item) => item.id == operation.id)
            ? 'This change still needs review. Check its details and try editing the record.'
                  .tr
            : 'The saved change synced successfully.'.tr,
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() => _workingId = null);
        _message(error.toString());
      }
    }
  }

  Future<void> _retryAll() async {
    setState(() => _workingId = 'all');
    try {
      await _ledger.retryPending();
      await _load();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _workingId = null);
        _message(error.toString());
      }
    }
  }

  Future<void> _edit(StoredOutboxOperation operation) async {
    final revision = await showSyncChangeEditor(context, operation);
    if (revision == null || !mounted) return;
    setState(() => _workingId = operation.id);
    try {
      final ReviseNeedsAttentionResult result;
      if (revision.kind == OutboxKind.createParty) {
        result = await _ledger.reviseNeedsAttentionParty(
          operationId: operation.id,
          name: revision.fields['name']?.toString() ?? '',
          phone: revision.fields['phone']?.toString() ?? '',
          shortName: operation.payload['shortName']?.toString() ?? '',
          notes: operation.payload['notes']?.toString() ?? '',
          groupId: _nullableString(operation.payload['groupId']),
          confirmDuplicate: operation.payload['confirmDuplicate'] == true,
        );
      } else {
        result = await _ledger.reviseNeedsAttentionEntry(
          operationId: operation.id,
          action: revision.fields['action'] == 'received'
              ? EntryAction.received
              : EntryAction.gave,
          amountPaise: _int(revision.fields['amountPaise']),
          narration: revision.fields['narration']?.toString() ?? '',
          entryDate: revision.fields['entryDate']?.toString() ?? '',
        );
      }
      await _load();
      if (!mounted) return;
      _message(
        (switch (result) {
          ReviseNeedsAttentionResult.revised =>
            'Correction saved. Hisaab will retry automatically.',
          ReviseNeedsAttentionResult.notFound =>
            'This change is no longer on the phone.',
          ReviseNeedsAttentionResult.wrongState =>
            'This change is already retrying or has synced.',
          ReviseNeedsAttentionResult.kindMismatch =>
            'This saved change cannot be edited here.',
        }).tr,
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _workingId = null);
      _message(error.toString());
    }
  }

  Future<void> _discard(StoredOutboxOperation operation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discard this unsynced change?'.tr),
        content: Text(
          '@change will be removed from this phone. A party or entry that '
                  'already reached the server will not be deleted.'
              .trParams({'change': _operationTitle(operation)}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep change'.tr),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Discard unsynced change'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _workingId = operation.id);
    final result = await _ledger.discardNeedsAttention(operation.id);
    if (!mounted) return;
    switch (result) {
      case DiscardNeedsAttentionResult.discarded:
        await _load();
        _message('The unsynced change was discarded.'.tr);
      case DiscardNeedsAttentionResult.hasDependentChanges:
        setState(() => _workingId = null);
        _message(
          'This party has dependent unsynced entries. Review or discard those entries first.'
              .tr,
        );
      case DiscardNeedsAttentionResult.wrongState:
        setState(() => _workingId = null);
        _message('This change is no longer waiting for review.'.tr);
      case DiscardNeedsAttentionResult.notFound:
        await _load();
        _message('This change is no longer on the phone.'.tr);
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review sync changes'.tr,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'These changes are safe on this phone but need action before they can sync.'
                            .tr,
                        style: TextStyle(color: context.colors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close'.tr,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (_operations.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: OutlinedButton.icon(
                onPressed: _workingId == null ? _retryAll : null,
                icon: const Icon(Icons.sync_rounded),
                label: Text('Retry all'.tr),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _operations.isEmpty
                ? const _NoSyncIssues()
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: _operations.length,
                    itemBuilder: (context, index) {
                      final operation = _operations[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OperationCard(
                          operation: operation,
                          title: _operationTitle(operation),
                          summary: _operationSummary(operation),
                          busy: _workingId == operation.id,
                          onRetry: _workingId == null
                              ? () => _retry(operation)
                              : null,
                          onEdit: _workingId == null
                              ? () => _edit(operation)
                              : null,
                          onDiscard: _workingId == null
                              ? () => _discard(operation)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _operationTitle(StoredOutboxOperation operation) {
    if (operation.kind == OutboxKind.createParty) {
      final name = operation.payload['name']?.toString().trim() ?? '';
      return name.isEmpty
          ? 'New party'.tr
          : 'New party: @name'.trParams({'name': name});
    }
    final action = operation.payload['action'] == 'received'
        ? 'You got'
        : 'You gave';
    final amount = _int(operation.payload['amountPaise']);
    return '${action.tr} ${formatMoney(amount, absolute: true)}';
  }

  String _operationSummary(StoredOutboxOperation operation) {
    if (operation.kind == OutboxKind.createParty) {
      final phone = operation.payload['phone']?.toString().trim() ?? '';
      return phone.isEmpty
          ? 'Party created on this phone'.tr
          : 'Phone @phone'.trParams({'phone': phone});
    }
    final partyId = operation.payload['partyId']?.toString() ?? '';
    final party = _ledger.partyById(partyId);
    final date = operation.payload['entryDate']?.toString() ?? '';
    return '${party?.name ?? 'Party'.tr}${date.isEmpty ? '' : ' · $date'}';
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({
    required this.operation,
    required this.title,
    required this.summary,
    required this.busy,
    required this.onRetry,
    required this.onEdit,
    required this.onDiscard,
  });

  final StoredOutboxOperation operation;
  final String title;
  final String summary;
  final bool busy;
  final VoidCallback? onRetry;
  final VoidCallback? onEdit;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final category = _errorCategory(operation.lastErrorCategory);
    final needsAttention = operation.state == OutboxState.needsAttention;
    return Semantics(
      container: true,
      label: '$title. $category. $summary',
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: needsAttention ? colors.red : colors.amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(summary, style: TextStyle(color: colors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(
                    label: (needsAttention
                            ? 'Needs attention'
                            : 'Retry scheduled')
                        .tr,
                    foreground: needsAttention ? colors.red : colors.amber,
                    background: needsAttention
                        ? colors.redSoft
                        : colors.amberSoft,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.redSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Color.alphaBlend(
                      colors.red.withValues(alpha: 0.16),
                      colors.redSoft,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        color: colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (operation.lastErrorCode?.isNotEmpty ?? false)
                          'Code ${operation.lastErrorCode}',
                        if (operation.lastStatusCode != null)
                          'HTTP ${operation.lastStatusCode}',
                        'Attempt ${operation.attempts}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                        letterSpacing: 0.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text('Edit correction'.tr),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDiscard,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text('Discard'.tr),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text('Retry'.tr),
                    ),
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

class _NoSyncIssues extends StatelessWidget {
  const _NoSyncIssues();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_outlined, size: 48, color: colors.green),
            const SizedBox(height: 12),
            Text(
              'No changes need review'.tr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _errorCategory(String? value) => (switch (value) {
  'validation' => 'Check the saved details',
  'conflict' => 'Conflicts with newer server data',
  'authentication' || 'unauthorized' => 'Sign-in required',
  'authorization' || 'forbidden' => 'Permission required',
  'rate_limit' || 'rate_limited' => 'Server asked Hisaab to wait',
  'payload_too_large' => 'The saved change is too large',
  'duplicate' => 'Possible duplicate',
  'rejected' => 'The server rejected this change',
  'server' => 'Server could not accept the change',
  _ => 'Could not sync this change',
}).tr;

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
