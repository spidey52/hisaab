import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_failure.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../services/calculator_preference_service.dart';
import '../../services/form_draft_service.dart';
import '../../app/modules/shared/widget/ledger_activity_row.dart';
import '../../shared/widgets/amount_entry_field.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/async_action_button.dart';
import '../../shared/widgets/balance_widgets.dart';
import '../../shared/widgets/calculator_keypad.dart';
import '../../shared/widgets/direction_action_button.dart';
import '../ledger/ledger_controller.dart';

class AddEntryPage extends StatefulWidget {
  const AddEntryPage({super.key});

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage>
    with WidgetsBindingObserver {
  final _ledger = Get.find<LedgerController>();
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _idempotencyKey = const Uuid().v4();
  late final CalculatorPreferenceService _calculatorPreference =
      Get.isRegistered<CalculatorPreferenceService>()
      ? Get.find<CalculatorPreferenceService>()
      : const SharedPreferencesCalculatorPreferenceService();
  late final FormDraftService _drafts = Get.isRegistered<FormDraftService>()
      ? Get.find<FormDraftService>()
      : EncryptedFormDraftService(Get.find<AppStorage>());

  static const _notePresets = ['Goods', 'Payment', 'Previous balance'];

  late EntryAction _action;
  String? _partyId;
  DateTime _date = DateTime.now();
  String? _paymentAccount;
  bool _optional = false;
  bool _calculatorVisible = false;
  String _calculatorExpression = '';
  LedgerEntry? _editingEntry;
  late String _draftId;
  Timer? _draftTimer;
  bool _restoringDraft = false;
  bool _dirty = false;
  bool _leavingAfterSave = false;
  bool _requestAttempted = false;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    final entryId = arguments is Map ? arguments['entryId']?.toString() : null;
    _draftId = entryId == null ? 'new-entry' : 'edit-entry-$entryId';
    if (entryId != null) {
      for (final entry in _ledger.entries) {
        if (entry.id != entryId) continue;
        _editingEntry = entry;
        _action = entry.action;
        _partyId = entry.partyId;
        _amount.text = _rupeesForInput(entry.amountPaise);
        _note.text = entry.narration;
        _date = entry.entryDate;
        _paymentAccount = entry.paymentAccount;
        _optional = entry.narration.isNotEmpty || entry.paymentAccount != null;
        _calculatorExpression = _amount.text;
        _loadCalculatorPreference();
        _initializeDrafts();
        return;
      }
    }
    _action = arguments is Map && arguments['action'] is EntryAction
        ? arguments['action'] as EntryAction
        : EntryAction.gave;
    _partyId = arguments is Map ? arguments['partyId']?.toString() : null;
    final active = _ledger.parties.where((party) => !party.isArchived).toList();
    if (_partyId == null && active.length == 1) _partyId = active.first.id;
    final prefillPaise = arguments is Map ? arguments['amountPaise'] : null;
    if (prefillPaise is int && prefillPaise > 0) {
      // A fresh create started from "Mark settled" arrives with the party
      // balance pre-filled. A restored draft (below) still wins if one exists.
      _amount.text = _rupeesForInput(prefillPaise);
      _calculatorExpression = _amount.text;
    }
    _loadCalculatorPreference();
    _initializeDrafts();
  }

  void _initializeDrafts() {
    WidgetsBinding.instance.addObserver(this);
    _amount.addListener(_markDirty);
    _note.addListener(_markDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  Future<void> _loadCalculatorPreference() async {
    final enabled = await _calculatorPreference.calculatorEnabled();
    if (!mounted || !enabled) return;
    setState(() {
      _calculatorVisible = true;
      _calculatorExpression = _amount.text;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    if (_dirty && !_leavingAfterSave) unawaited(_saveDraft());
    _amount.removeListener(_markDirty);
    _note.removeListener(_markDirty);
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveDraft());
    }
  }

  void _markDirty() {
    if (_restoringDraft || _leavingAfterSave) return;
    if (_requestAttempted) {
      _idempotencyKey = const Uuid().v4();
      _requestAttempted = false;
    }
    _dirty = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_saveDraft());
    });
  }

  Future<void> _restoreDraft() async {
    Map<String, dynamic>? draft;
    try {
      draft = await _drafts.read(kind: 'entry', id: _draftId);
    } catch (_) {
      return;
    }
    if (draft == null || !mounted) return;
    _restoringDraft = true;
    final actionName = draft['action']?.toString();
    final date = DateTime.tryParse(draft['date']?.toString() ?? '');
    final partyId = draft['partyId']?.toString();
    final idempotencyKey = draft['idempotencyKey']?.toString();
    setState(() {
      _amount.text = draft!['amount']?.toString() ?? _amount.text;
      _note.text = draft['note']?.toString() ?? _note.text;
      if (actionName == EntryAction.received.name) {
        _action = EntryAction.received;
      } else if (actionName == EntryAction.gave.name) {
        _action = EntryAction.gave;
      }
      if (partyId != null && _ledger.partyById(partyId) != null) {
        _partyId = partyId;
      }
      if (date != null && !date.isAfter(DateTime.now())) _date = date;
      _paymentAccount = switch (draft['paymentAccount']) {
        'cash' => 'cash',
        'bank' => 'bank',
        _ => null,
      };
      _optional = draft['optional'] == true;
      _calculatorVisible = draft['calculatorVisible'] == true;
      _calculatorExpression =
          draft['calculatorExpression']?.toString() ?? _amount.text;
      if (_isUuid(idempotencyKey)) {
        _idempotencyKey = idempotencyKey!;
      }
    });
    _restoringDraft = false;
    _dirty = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your saved entry draft was restored.')),
    );
  }

  Future<void> _saveDraft() async {
    if (!_dirty || _leavingAfterSave) return;
    _draftTimer?.cancel();
    try {
      await _drafts.save(
        kind: 'entry',
        id: _draftId,
        payload: {
          'amount': _amount.text,
          'note': _note.text,
          'action': _action.name,
          'partyId': _partyId,
          'date': _date.toIso8601String(),
          'paymentAccount': _paymentAccount,
          'optional': _optional,
          'calculatorVisible': _calculatorVisible,
          'calculatorExpression': _calculatorExpression,
          'idempotencyKey': _idempotencyKey,
        },
      );
    } catch (_) {
      // A missing authenticated storage scope should not block entry editing.
    }
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    try {
      await _drafts.clear(kind: 'entry', id: _draftId);
    } catch (_) {
      // The form can still finish when local draft cleanup is unavailable.
    }
    _dirty = false;
  }

  Future<void> _handleBackNavigation() async {
    if (!_dirty || _leavingAfterSave) {
      await _popSafely();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep this entry draft?'),
        content: const Text(
          'You can safely leave and continue later, or discard the draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('Keep draft'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'discard') {
      await _clearDraft();
    } else {
      await _saveDraft();
    }
    await _popSafely();
  }

  Future<void> _popSafely([Object? result]) async {
    if (!mounted) return;
    setState(() => _leavingAfterSave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, result);
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (value != null) {
      setState(() => _date = value);
      _markDirty();
    }
  }

  void _setDate(DateTime value) {
    setState(() => _date = value);
    _markDirty();
  }

  Future<void> _toggleCalculator() async {
    final next = !_calculatorVisible;
    if (next) FocusScope.of(context).unfocus();
    setState(() {
      _calculatorVisible = next;
      if (next && _calculatorExpression.isEmpty) {
        _calculatorExpression = _amount.text;
      }
    });
    _markDirty();
    await _calculatorPreference.setCalculatorEnabled(next);
  }

  void _useCalculatedAmount(int paise) {
    setState(() {
      _amount.text = _rupeesForInput(paise);
      _calculatorExpression = _amount.text;
    });
    FocusScope.of(context).unfocus();
  }

  void _applyNotePreset(String preset) {
    setState(() {
      _note.text = preset;
      _note.selection = TextSelection.collapsed(offset: preset.length);
    });
  }

  Future<String?> _chooseParty(List<Party> parties) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) =>
            _SearchablePartySheet(parties: parties, selectedPartyId: _partyId),
      );

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final amountPaise = rupeesTextToPaise(_amount.text);
    if (amountPaise == null) return;

    try {
      _requestAttempted = true;
      OptimisticMutationResult? queued;
      if (_editingEntry != null) {
        await _ledger.updateEntry(
          id: _editingEntry!.id,
          partyId: _partyId!,
          action: _action,
          amountPaise: amountPaise,
          narration: _note.text.trim(),
          entryDate: dateOnly(_date),
          paymentAccount: _paymentAccount,
          idempotencyKey: _idempotencyKey,
        );
      } else {
        queued = await _ledger.createEntry(
          partyId: _partyId!,
          action: _action,
          amountPaise: amountPaise,
          narration: _note.text.trim(),
          entryDate: dateOnly(_date),
          idempotencyKey: _idempotencyKey,
          paymentAccount: _paymentAccount,
        );
      }
      if (!mounted) return;
      await _clearDraft();
      if (!mounted) return;
      await _popSafely(true);
      if (queued != null) {
        _showQueuedEntry(queued);
      } else {
        AppSnackbar.success(
          title: 'Entry updated',
          message: 'The corrected entry is now in the statement.',
          position: SnackbarPosition.bottom,
        );
      }
    } on ApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showQueuedEntry(OptimisticMutationResult result) {
    final remaining = result.undoUntil.difference(DateTime.now().toUtc());
    AppSnackbar.success(
      title: 'Entry saved on this phone',
      message:
          '${_action == EntryAction.gave ? 'Recorded as You gave.' : 'Recorded as You got.'} '
          'It will sync automatically.',
      duration: remaining.isNegative ? const Duration(seconds: 1) : remaining,
      position: SnackbarPosition.bottom,
      actionLabel: remaining.isNegative ? null : 'Undo',
      onAction: remaining.isNegative
          ? null
          : () async {
              final outcome = await _ledger.undoPending(result.operationId);
              if (outcome == UndoPendingResult.undone) {
                AppSnackbar.success(
                  title: 'Entry undone',
                  message: 'The pending entry was removed.',
                  position: SnackbarPosition.bottom,
                );
              } else {
                AppSnackbar.warning(
                  title: 'Entry is already syncing',
                  message:
                      'A posted or uploading entry is never cancelled silently.',
                  position: SnackbarPosition.bottom,
                );
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeParties = _ledger.parties
        .where((party) => !party.isArchived)
        .toList();
    final fixedParty = _partyId == null ? null : _ledger.partyById(_partyId!);
    final amountPaise = rupeesTextToPaise(_amount.text) ?? 0;
    final previewBalance = fixedParty == null
        ? null
        : fixedParty.balancePaise +
              (_action == EntryAction.gave ? amountPaise : -amountPaise);
    final gave = _action == EntryAction.gave;
    final title = _editingEntry != null
        ? 'Edit entry'.tr
        : gave
        ? 'You gave'.tr
        : 'You got'.tr;

    return PopScope<Object?>(
      canPop: !_dirty || _leavingAfterSave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBackNavigation());
      },
      child: Scaffold(
        backgroundColor: colors.page,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            title,
            style: displayStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: colors.ink,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: colors.line),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DirectionActionButton(
                        action: EntryAction.gave,
                        compact: true,
                        selected: gave,
                        onPressed: () {
                          setState(() => _action = EntryAction.gave);
                          _markDirty();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DirectionActionButton(
                        action: EntryAction.received,
                        compact: true,
                        selected: !gave,
                        onPressed: () {
                          setState(() => _action = EntryAction.received);
                          _markDirty();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (Get.arguments is Map &&
                    (Get.arguments as Map)['partyId'] != null &&
                    fixedParty != null)
                  _PartySummaryCard(party: fixedParty)
                else
                  FormField<String>(
                    key: ValueKey(_partyId),
                    initialValue: _partyId,
                    validator: (value) =>
                        value == null ? 'Choose a party'.tr : null,
                    builder: (field) => _PartyPickerField(
                      party: _partyId == null
                          ? null
                          : _ledger.partyById(_partyId!),
                      errorText: field.errorText,
                      onTap: () async {
                        final selected = await _chooseParty(activeParties);
                        if (selected == null || !mounted) return;
                        setState(() => _partyId = selected);
                        field.didChange(selected);
                        _markDirty();
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                AmountEntryField(
                  controller: _amount,
                  autofocus: _partyId != null && !_calculatorVisible,
                  calculatorVisible: _calculatorVisible,
                  gave: gave,
                  onToggleCalculator: _toggleCalculator,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                _DateChipRow(
                  date: _date,
                  onToday: () => _setDate(DateTime.now()),
                  onYesterday: () => _setDate(
                    DateTime.now().subtract(const Duration(days: 1)),
                  ),
                  onPickDate: _pickDate,
                ),
                if (_calculatorVisible) ...[
                  const SizedBox(height: 14),
                  CalculatorKeypad(
                    expression: _calculatorExpression,
                    onExpressionChanged: (value) {
                      setState(() => _calculatorExpression = value);
                      _markDirty();
                    },
                    onUseAmount: _useCalculatedAmount,
                  ),
                ],
                const SizedBox(height: 14),
                _OptionalDetailsCard(
                  expanded: _optional,
                  onToggle: () {
                    setState(() => _optional = !_optional);
                    _markDirty();
                  },
                  notePresets: _notePresets,
                  onPreset: _applyNotePreset,
                  noteController: _note,
                  paymentAccount: _paymentAccount,
                  onPaymentAccountChanged: (value) {
                    setState(() => _paymentAccount = value);
                    _markDirty();
                  },
                ),
                if (previewBalance != null && amountPaise > 0) ...[
                  const SizedBox(height: 14),
                  BalanceSentence(
                    balancePaise: previewBalance,
                    partyName: fixedParty!.name,
                  ),
                ],
                const SizedBox(height: 24),
                Obx(
                  () => AsyncActionButton(
                    busy: _ledger.mutating.value,
                    onPressed: _save,
                    label: amountPaise > 0
                        ? _editingEntry == null
                              ? 'Save ${formatSignedEntryMoney(amountPaise, gave: gave)}'
                              : 'Save changes'.tr
                        : _editingEntry == null
                        ? 'Save entry'.tr
                        : 'Save changes'.tr,
                    backgroundColor: gave ? colors.red : colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _rupeesForInput(int paise) {
    final whole = paise ~/ 100;
    final fraction = paise % 100;
    return fraction == 0
        ? '$whole'
        : '$whole.${fraction.toString().padLeft(2, '0')}';
  }

  bool _isUuid(String? value) =>
      value != null && Uuid.isValidUUID(fromString: value);
}

/// One-tap entry-date choices: Today, Yesterday, or the full calendar.
class _DateChipRow extends StatelessWidget {
  const _DateChipRow({
    required this.date,
    required this.onToday,
    required this.onYesterday,
    required this.onPickDate,
  });

  final DateTime date;
  final VoidCallback onToday;
  final VoidCallback onYesterday;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = dateOnly(DateTime.now());
    final yesterday = dateOnly(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final selected = dateOnly(date);
    final isToday = selected == today;
    final isYesterday = selected == yesterday;
    final isCustom = !isToday && !isYesterday;

    return Semantics(
      container: true,
      label: 'Entry date',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date'.tr,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _DatePill(label: 'Today', selected: isToday, onTap: onToday),
                const SizedBox(width: 8),
                _DatePill(
                  label: 'Yesterday',
                  selected: isYesterday,
                  onTap: onYesterday,
                ),
                const SizedBox(width: 8),
                _DatePill(
                  label: isCustom ? formatShortDate(date) : 'Pick a date',
                  selected: isCustom,
                  icon: Icons.calendar_today_outlined,
                  onTap: onPickDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.brand : colors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? colors.brand : colors.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? colors.onBrand : colors.muted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.onBrand : colors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartySummaryCard extends StatelessWidget {
  const _PartySummaryCard({required this.party});

  final Party party;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          _PartyAvatarTile(name: party.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Party'.tr,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  party.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                    letterSpacing: -0.15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionalDetailsCard extends StatelessWidget {
  const _OptionalDetailsCard({
    required this.expanded,
    required this.onToggle,
    required this.notePresets,
    required this.onPreset,
    required this.noteController,
    required this.paymentAccount,
    required this.onPaymentAccountChanged,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<String> notePresets;
  final ValueChanged<String> onPreset;
  final TextEditingController noteController;
  final String? paymentAccount;
  final ValueChanged<String?> onPaymentAccountChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.settledSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.notes_rounded,
                        size: 18,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Optional details'.tr,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            expanded
                                ? 'Note and cash or bank'
                                : 'Add a note or payment account',
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: colors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, thickness: 1, color: colors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in notePresets)
                        _NotePresetChip(
                          label: preset,
                          onTap: () => onPreset(preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLength: 240,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)'.tr,
                      hintText: 'Example: Goods or payment',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: paymentAccount,
                    decoration: InputDecoration(
                      labelText: 'Payment account (optional)'.tr,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        child: Text('Not specified'.tr),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'cash',
                        child: Text('Cash'.tr),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'bank',
                        child: Text('Bank'.tr),
                      ),
                    ],
                    onChanged: onPaymentAccountChanged,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotePresetChip extends StatelessWidget {
  const _NotePresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.settledSoft,
      shape: StadiumBorder(side: BorderSide(color: colors.line)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular pastel initials tile matching Home / Entries avatars.
class _PartyAvatarTile extends StatelessWidget {
  const _PartyAvatarTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final avatar = avatarColorsForName(name, colors);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatar.background,
        shape: BoxShape.circle,
      ),
      child: Text(
        avatarInitial(name),
        style: TextStyle(
          fontSize: 16,
          color: avatar.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PartyPickerField extends StatelessWidget {
  const _PartyPickerField({
    required this.party,
    required this.onTap,
    this.errorText,
  });

  final Party? party;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasError = errorText != null;
    return Semantics(
      button: true,
      label: party == null
          ? 'Choose a customer or supplier'.tr
          : '${'Party'.tr}, ${party!.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: colors.surface,
            elevation: 0,
            shadowColor: colors.ink.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: hasError ? colors.red : colors.line,
                width: hasError ? 1.4 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    if (party == null)
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.settledSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: colors.muted,
                        ),
                      )
                    else
                      _PartyAvatarTile(name: party!.name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Party'.tr,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            party?.name ?? 'Choose a customer or supplier'.tr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              letterSpacing: -0.15,
                              color: party == null ? colors.muted : colors.ink,
                              fontWeight: party == null
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.search_rounded, color: colors.muted, size: 22),
                  ],
                ),
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 6),
              child: Text(
                errorText!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.red),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchablePartySheet extends StatefulWidget {
  const _SearchablePartySheet({
    required this.parties,
    required this.selectedPartyId,
  });

  final List<Party> parties;
  final String? selectedPartyId;

  @override
  State<_SearchablePartySheet> createState() => _SearchablePartySheetState();
}

class _SearchablePartySheetState extends State<_SearchablePartySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = _query.trim().toLowerCase();
    final parties = query.isEmpty
        ? widget.parties
        : widget.parties.where((party) {
            return party.name.toLowerCase().contains(query) ||
                party.shortName.toLowerCase().contains(query) ||
                party.phone
                    .replaceAll(' ', '')
                    .contains(query.replaceAll(' ', ''));
          }).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose a party'.tr,
                  style: displayStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name or phone'.tr,
                    prefixIcon: Icon(Icons.search_rounded, color: colors.muted),
                    filled: true,
                    fillColor: colors.page,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: parties.isEmpty
                ? Center(
                    child: Text(
                      'No matching parties',
                      style: TextStyle(color: colors.muted),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: parties.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.line),
                    itemBuilder: (context, index) {
                      final party = parties[index];
                      final selected = party.id == widget.selectedPartyId;
                      return Material(
                        color: selected
                            ? Color.alphaBlend(
                                colors.brand.withValues(alpha: 0.06),
                                colors.surface,
                              )
                            : colors.surface,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: _PartyAvatarTile(name: party.name),
                          title: Text(
                            party.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                          subtitle: party.phone.trim().isEmpty
                              ? null
                              : Text(
                                  party.phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: colors.muted),
                                ),
                          trailing: selected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: colors.green,
                                )
                              : Icon(
                                  Icons.chevron_right_rounded,
                                  color: colors.muted,
                                ),
                          onTap: () => Navigator.pop(context, party.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
