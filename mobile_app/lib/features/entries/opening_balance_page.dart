import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/async_action_button.dart';
import '../../shared/widgets/balance_widgets.dart';
import '../ledger/ledger_controller.dart';

class OpeningBalancePage extends StatefulWidget {
  const OpeningBalancePage({super.key});

  @override
  State<OpeningBalancePage> createState() => _OpeningBalancePageState();
}

class _OpeningBalancePageState extends State<OpeningBalancePage> {
  final _ledger = Get.find<LedgerController>();
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String _idempotencyKey = const Uuid().v4();

  late final String _partyId;
  String _direction = 'receive';
  DateTime _date = DateTime.now();
  bool _editing = false;
  bool _requestAttempted = false;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    _partyId = arguments is Map ? arguments['partyId']?.toString() ?? '' : '';
    for (final entry in _ledger.entries) {
      if (entry.partyId != _partyId ||
          !entry.isOpeningBalance ||
          entry.status != EntryStatus.posted) {
        continue;
      }
      _editing = true;
      _amount.text = _rupeesForInput(entry.amountPaise);
      _direction = entry.balanceEffectPaise >= 0 ? 'receive' : 'pay';
      _date = entry.entryDate;
      break;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _markIntentChanged();
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final amount = _openingAmountPaise();
    if (amount == null) return;
    try {
      _requestAttempted = true;
      await _ledger.saveOpeningBalance(
        partyId: _partyId,
        amountPaise: amount,
        direction: _direction,
        entryDate: dateOnly(_date),
        idempotencyKey: _idempotencyKey,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      AppSnackbar.success(
        title: 'Opening balance saved',
        message: 'The party statement has been updated.',
        position: SnackbarPosition.bottom,
      );
    } on ApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _markIntentChanged() {
    if (!_requestAttempted) return;
    _idempotencyKey = const Uuid().v4();
    _requestAttempted = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final party = _ledger.partyById(_partyId);
    final parsedAmount = _openingAmountPaise();
    final amount = parsedAmount ?? 0;
    final effect = _direction == 'receive' ? amount : -amount;
    if (party == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Party not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit opening balance' : 'Opening balance'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.amberSoft,
                  borderRadius: BorderRadius.circular(14),
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
                    Icon(Icons.flag_outlined, color: colors.amber),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Use this only for money already due before you started '
                        'recording entries in Hisaab.',
                        style: TextStyle(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(party.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _DirectionChoice(
                selected: _direction == 'receive',
                icon: Icons.south_west_rounded,
                title: 'They owe you',
                subtitle: 'You will receive this amount',
                kind: BalanceKind.receive,
                onTap: () {
                  setState(() => _direction = 'receive');
                  _markIntentChanged();
                },
              ),
              const SizedBox(height: 10),
              _DirectionChoice(
                selected: _direction == 'pay',
                icon: Icons.north_east_rounded,
                title: 'You owe them',
                subtitle: 'You will pay this amount',
                kind: BalanceKind.pay,
                onTap: () {
                  setState(() => _direction = 'pay');
                  _markIntentChanged();
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: !_editing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: displayStyle(fontSize: 28, fontWeight: FontWeight.w700)
                    .copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,9}(\.\d{0,2})?'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                ),
                validator: (_) => _openingAmountPaise() == null
                    ? _editing
                          ? 'Enter zero or a valid amount'
                          : 'Enter an amount greater than zero'
                    : null,
                onChanged: (_) {
                  setState(() {});
                  _markIntentChanged();
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  dateOnly(_date) == dateOnly(DateTime.now())
                      ? 'Date: Today'
                      : 'Date: ${formatShortDate(_date)}',
                ),
              ),
              if (parsedAmount != null) ...[
                const SizedBox(height: 14),
                BalanceSentence(
                  balancePaise:
                      party.balancePaise -
                      (_existingOpeningEffect() ?? 0) +
                      effect,
                  partyName: party.name,
                ),
              ],
              const SizedBox(height: 22),
              Obx(
                () => AsyncActionButton(
                  label: _editing
                      ? 'Save opening balance'
                      : 'Set opening balance',
                  busy: _ledger.mutating.value,
                  onPressed: _save,
                  backgroundColor: colors.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _existingOpeningEffect() {
    for (final entry in _ledger.entries) {
      if (entry.partyId == _partyId &&
          entry.isOpeningBalance &&
          entry.status == EntryStatus.posted) {
        return entry.balanceEffectPaise;
      }
    }
    return null;
  }

  String _rupeesForInput(int paise) {
    final whole = paise ~/ 100;
    final fraction = paise % 100;
    return fraction == 0
        ? '$whole'
        : '$whole.${fraction.toString().padLeft(2, '0')}';
  }

  int? _openingAmountPaise() {
    final cleaned = _amount.text.replaceAll(',', '').trim();
    if (_editing && RegExp(r'^0+(?:\.0{1,2})?$').hasMatch(cleaned)) return 0;
    return rupeesTextToPaise(cleaned);
  }
}

class _DirectionChoice extends StatelessWidget {
  const _DirectionChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final BalanceKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tones = balanceTones(context, kind);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: Material(
        color: selected ? tones.background : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? tones.foreground : colors.line,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? tones.foreground : colors.muted,
                ),
                const SizedBox(width: 12),
                Icon(icon, color: tones.foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? tones.foreground : colors.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: selected ? tones.foreground : colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
