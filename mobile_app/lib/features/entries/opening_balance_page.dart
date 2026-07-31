import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_failure.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
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
      Get.snackbar(
        'Opening balance saved',
        'The party statement has been updated.',
        snackPosition: SnackPosition.BOTTOM,
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
        title: Text(
          _editing ? 'Edit opening balance' : 'Opening balance',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
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
                  color: const Color(0xFFFFF3E7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0CFAC)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flag_outlined, color: AppColors.amber),
                    SizedBox(width: 10),
                    Expanded(
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
              Text(
                party.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _DirectionChoice(
                selected: _direction == 'receive',
                icon: Icons.south_west_rounded,
                title: 'They owe you',
                subtitle: 'You will receive this amount',
                color: AppColors.green,
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
                color: AppColors.red,
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
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
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
                  backgroundColor: AppColors.amber,
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
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.09) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? color : AppColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
