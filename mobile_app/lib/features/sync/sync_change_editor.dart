import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/models.dart';
import '../../shared/widgets/direction_action_button.dart';

class SyncChangeRevision {
  const SyncChangeRevision({required this.kind, required this.fields});

  final OutboxKind kind;
  final Map<String, dynamic> fields;
}

Future<SyncChangeRevision?> showSyncChangeEditor(
  BuildContext context,
  StoredOutboxOperation operation,
) {
  return Navigator.of(context).push<SyncChangeRevision>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SyncChangeEditorPage(operation: operation),
    ),
  );
}

class _SyncChangeEditorPage extends StatefulWidget {
  const _SyncChangeEditorPage({required this.operation});

  final StoredOutboxOperation operation;

  @override
  State<_SyncChangeEditorPage> createState() => _SyncChangeEditorPageState();
}

class _SyncChangeEditorPageState extends State<_SyncChangeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late EntryAction _action;
  late DateTime _date;

  bool get _isParty => widget.operation.kind == OutboxKind.createParty;

  @override
  void initState() {
    super.initState();
    final payload = widget.operation.payload;
    _name = TextEditingController(text: payload['name']?.toString() ?? '');
    _phone = TextEditingController(text: payload['phone']?.toString() ?? '');
    _amount = TextEditingController(
      text: _rupeesForInput(_asInt(payload['amountPaise'])),
    );
    _note = TextEditingController(text: payload['narration']?.toString() ?? '');
    _action = payload['action'] == 'received'
        ? EntryAction.received
        : EntryAction.gave;
    _date =
        DateTime.tryParse(payload['entryDate']?.toString() ?? '') ??
        DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(DateTime.now()) ? DateTime.now() : _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isParty) {
      Navigator.pop(
        context,
        SyncChangeRevision(
          kind: OutboxKind.createParty,
          fields: {'name': _name.text.trim(), 'phone': _phone.text.trim()},
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      SyncChangeRevision(
        kind: OutboxKind.createEntry,
        fields: {
          'action': _action == EntryAction.gave ? 'gave' : 'received',
          'amountPaise': rupeesTextToPaise(_amount.text)!,
          'narration': _note.text.trim(),
          'entryDate': dateOnly(_date),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text((_isParty ? 'Correct party' : 'Correct entry').tr),
        actions: [TextButton(onPressed: _save, child: Text('Save'.tr))],
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
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
                child: Text(
                  'Fix the rejected details below. The existing saved change '
                          'will be updated—no duplicate will be created.'
                      .tr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.ink,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_isParty) ..._partyFields() else ..._entryFields(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: Text('Save correction and retry'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _partyFields() => [
    TextFormField(
      controller: _name,
      autofocus: true,
      maxLength: 100,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Name'.tr,
        counterText: '',
        prefixIcon: const Icon(Icons.person_outline_rounded),
      ),
      validator: (value) => (value?.trim().length ?? 0) < 2
          ? 'Enter at least 2 characters'.tr
          : null,
    ),
    const SizedBox(height: 14),
    TextFormField(
      controller: _phone,
      maxLength: 30,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
      ],
      decoration: InputDecoration(
        labelText: 'Phone number (optional)'.tr,
        counterText: '',
        prefixIcon: const Icon(Icons.phone_outlined),
      ),
      validator: (value) {
        final phone = value?.trim() ?? '';
        if (phone.isEmpty || normalizePhoneE164(phone).isNotEmpty) return null;
        return 'Enter a valid phone number or leave it blank'.tr;
      },
    ),
  ];

  List<Widget> _entryFields() => [
    Row(
      children: [
        Expanded(
          child: DirectionActionButton(
            action: EntryAction.gave,
            compact: true,
            selected: _action == EntryAction.gave,
            onPressed: () => setState(() => _action = EntryAction.gave),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DirectionActionButton(
            action: EntryAction.received,
            compact: true,
            selected: _action == EntryAction.received,
            onPressed: () => setState(() => _action = EntryAction.received),
          ),
        ),
      ],
    ),
    const SizedBox(height: 18),
    TextFormField(
      controller: _amount,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?')),
      ],
      style: displayStyle(fontSize: 28, fontWeight: FontWeight.w700).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(labelText: 'Amount'.tr, prefixText: '₹ '),
      validator: (value) => rupeesTextToPaise(value ?? '') == null
          ? 'Enter an amount greater than zero'.tr
          : null,
    ),
    const SizedBox(height: 14),
    TextFormField(
      controller: _note,
      maxLength: 240,
      minLines: 1,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Note (optional)'.tr,
        counterText: '',
      ),
    ),
    const SizedBox(height: 14),
    OutlinedButton.icon(
      onPressed: _pickDate,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(
        dateOnly(_date) == dateOnly(DateTime.now())
            ? 'Date: Today'.tr
            : formatShortDate(_date),
      ),
    ),
  ];
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _rupeesForInput(int paise) {
  if (paise <= 0) return '';
  final whole = paise ~/ 100;
  final fraction = paise % 100;
  return fraction == 0
      ? '$whole'
      : '$whole.${fraction.toString().padLeft(2, '0')}';
}
