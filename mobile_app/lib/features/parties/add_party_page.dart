import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../app/app.dart';
import '../../core/network/api_failure.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../services/contact_discovery_consent_service.dart';
import '../../services/contact_service.dart';
import '../../services/form_draft_service.dart';
import '../../shared/widgets/async_action_button.dart';
import '../ledger/ledger_controller.dart';

class AddPartyPage extends StatefulWidget {
  const AddPartyPage({super.key});

  @override
  State<AddPartyPage> createState() => _AddPartyPageState();
}

class _AddPartyPageState extends State<AddPartyPage>
    with WidgetsBindingObserver {
  final _ledger = Get.find<LedgerController>();
  final _contacts = Get.find<ContactService>();
  late final ContactDiscoveryConsentService _contactConsent =
      Get.isRegistered<ContactDiscoveryConsentService>()
      ? Get.find<ContactDiscoveryConsentService>()
      : SharedPreferencesContactDiscoveryConsentService(Get.find<AppStorage>());
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _shortName = TextEditingController();
  final _notes = TextEditingController();
  late final FormDraftService _drafts = Get.isRegistered<FormDraftService>()
      ? Get.find<FormDraftService>()
      : EncryptedFormDraftService(Get.find<AppStorage>());

  bool _advanced = false;
  bool _choosingContact = false;
  String? _groupId;
  String? _editingPartyId;
  late String _draftId;
  Timer? _draftTimer;
  bool _restoringDraft = false;
  bool _dirty = false;
  bool _leavingAfterSave = false;
  String _idempotencyKey = const Uuid().v4();
  bool _requestAttempted = false;

  bool get _editing => _editingPartyId != null;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    _editingPartyId = arguments is Map
        ? arguments['partyId']?.toString()
        : null;
    _draftId = _editingPartyId == null
        ? 'new-party'
        : 'edit-party-$_editingPartyId';
    if (_editingPartyId != null) {
      final party = _ledger.partyById(_editingPartyId!);
      if (party != null) {
        _name.text = party.name;
        _phone.text = party.phone;
        _shortName.text = party.shortName;
        _notes.text = party.notes;
        _groupId = party.groupId;
        _advanced =
            party.shortName.isNotEmpty ||
            party.notes.isNotEmpty ||
            party.groupId != null;
      }
    }
    _initializeDrafts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    if (_dirty && !_leavingAfterSave) unawaited(_saveDraft());
    _name.removeListener(_markDirty);
    _phone.removeListener(_markDirty);
    _shortName.removeListener(_markDirty);
    _notes.removeListener(_markDirty);
    _name.dispose();
    _phone.dispose();
    _shortName.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _initializeDrafts() {
    WidgetsBinding.instance.addObserver(this);
    _name.addListener(_markDirty);
    _phone.addListener(_markDirty);
    _shortName.addListener(_markDirty);
    _notes.addListener(_markDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
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
    _draftTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_saveDraft()),
    );
  }

  Future<void> _restoreDraft() async {
    Map<String, dynamic>? draft;
    try {
      draft = await _drafts.read(kind: 'party', id: _draftId);
    } catch (_) {
      return;
    }
    if (draft == null || !mounted) return;
    _restoringDraft = true;
    final groupId = draft['groupId']?.toString();
    final idempotencyKey = draft['idempotencyKey']?.toString();
    setState(() {
      _name.text = draft!['name']?.toString() ?? _name.text;
      _phone.text = draft['phone']?.toString() ?? _phone.text;
      _shortName.text = draft['shortName']?.toString() ?? _shortName.text;
      _notes.text = draft['notes']?.toString() ?? _notes.text;
      _groupId =
          groupId != null && _ledger.groups.any((group) => group.id == groupId)
          ? groupId
          : null;
      _advanced = draft['advanced'] == true;
      if (_isUuid(idempotencyKey)) _idempotencyKey = idempotencyKey!;
    });
    _restoringDraft = false;
    _dirty = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your saved party draft was restored.')),
    );
  }

  Future<void> _saveDraft() async {
    if (!_dirty || _leavingAfterSave) return;
    _draftTimer?.cancel();
    try {
      await _drafts.save(
        kind: 'party',
        id: _draftId,
        payload: {
          'name': _name.text,
          'phone': _phone.text,
          'shortName': _shortName.text,
          'notes': _notes.text,
          'groupId': _groupId,
          'advanced': _advanced,
          'idempotencyKey': _idempotencyKey,
        },
      );
    } catch (_) {
      // A missing authenticated scope should not block manual party entry.
    }
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    try {
      await _drafts.clear(kind: 'party', id: _draftId);
    } catch (_) {
      // The server mutation can still finish if draft cleanup is unavailable.
    }
    _dirty = false;
  }

  Future<void> _createGroup() async {
    final name = TextEditingController();
    final groupName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Create a party group'.tr),
        content: TextField(
          controller: name,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Group name'.tr,
            hintText: 'For example: Wholesale'.tr,
            counterText: '',
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.length >= 2) Navigator.pop(dialogContext, trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = name.text.trim();
              if (trimmed.length < 2) return;
              Navigator.pop(dialogContext, trimmed);
            },
            child: Text('Create group'.tr),
          ),
        ],
      ),
    );
    name.dispose();
    if (groupName == null || !mounted) return;

    try {
      final group = await _ledger.createGroup(groupName);
      if (!mounted) return;
      setState(() => _groupId = group.id);
      _markDirty();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${group.name} group created.')));
    } on ApiFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _handleBackNavigation() async {
    if (!_dirty) {
      await _popSafely();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep this party draft?'),
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

  Future<void> _chooseContact() async {
    if (_choosingContact) return;
    try {
      // OS contact permission and optional Hisaab account discovery consent
      // are separate. A declined discovery choice still opens local contacts.
      var consent = await _contactConsent.status();
      if (consent == ContactDiscoveryConsent.notAsked) {
        final granted = await _showContactPrimer();
        if (granted == null || !mounted) return;
        await _contactConsent.setGranted(granted);
        consent = granted
            ? ContactDiscoveryConsent.granted
            : ContactDiscoveryConsent.declined;
      }
      setState(() => _choosingContact = true);
      final directory = await _contacts.directory(
        ledgerPhones: _ledger.parties
            .map((party) => party.phone)
            .where((phone) => phone.trim().isNotEmpty)
            .toSet(),
        discoverOnHisaab: consent == ContactDiscoveryConsent.granted,
      );
      if (!mounted) return;
      final contact = await showModalBottomSheet<ContactPickResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => _ContactDirectorySheet(directory: directory),
      );
      if (contact == null || !mounted) return;

      final selectedPhone = await _choosePhone(contact);
      if (selectedPhone == null || !mounted) return;
      final existing = _partyWithPhone(selectedPhone);
      if (existing != null) {
        final addAnyway = await _showExistingParty(existing);
        if (addAnyway != true || !mounted) return;
      }

      setState(() {
        if (contact.name.isNotEmpty) _name.text = contact.name;
        _phone.text = selectedPhone;
      });
    } on ContactPermissionPermanentlyDenied {
      if (!mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow contact access'),
          content: const Text(
            'Contact access is turned off in Settings. You can enable it or '
            'continue entering the party manually.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Enter manually'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (open == true) await _contacts.openSettings();
    } on ContactPermissionRestricted {
      _showMessage(
        'Contacts are restricted on this device. Enter the details manually.',
      );
    } on ContactPermissionDenied {
      _showMessage(
        'Contact permission was not granted. You can still enter the party manually.',
      );
    } on ApiFailure catch (error) {
      _showMessage(
        '${error.message} You can still enter the party manually.',
        error: true,
      );
    } on PlatformException {
      _showMessage('Could not open contacts. Enter the details manually.');
    } catch (_) {
      _showMessage('Could not load contacts. Enter the details manually.');
    } finally {
      if (mounted) setState(() => _choosingContact = false);
    }
  }

  Future<bool?> _showContactPrimer() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.contacts_outlined),
      title: Text('Find contacts on Hisaab?'.tr),
      content: const Text(
        'To show who already uses Hisaab, the app sends valid normalized phone '
        'numbers for matching. Contact names stay on this phone. You can use '
        'your contact list without Hisaab matching, and change this later in '
        'Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Use contacts only'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Find on Hisaab'.tr),
        ),
      ],
    ),
  );

  Future<String?> _choosePhone(ContactPickResult contact) async {
    if (contact.phones.length <= 1) return contact.preferredPhone;
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a number'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                contact.name,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              for (final phone in contact.phones)
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(formatPhoneForDisplay(phone)),
                  onTap: () => Navigator.pop(context, phone),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Party? _partyWithPhone(String phone) {
    final key = phoneMatchKey(phone);
    if (key.isEmpty) return null;
    for (final party in _ledger.parties) {
      if (phoneMatchKey(party.phone) == key) return party;
    }
    return null;
  }

  Future<bool?> _showExistingParty(Party party) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Already in your ledger'.tr),
      content: Text(
        '${party.name} already uses this phone number. Open their statement '
        'or add a separate record anyway.',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
            Get.offNamed(AppRoutes.party, arguments: {'partyId': party.id});
          },
          child: Text('View party'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Add separately'.tr),
        ),
      ],
    ),
  );

  Future<void> _save({bool confirmDuplicate = false}) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    try {
      _requestAttempted = true;
      OptimisticMutationResult? queued;
      if (_editing) {
        await _ledger.updateParty(
          id: _editingPartyId!,
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          shortName: _shortName.text.trim(),
          notes: _notes.text.trim(),
          groupId: _groupId,
          idempotencyKey: _idempotencyKey,
        );
      } else {
        queued = await _ledger.createParty(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          shortName: _shortName.text.trim(),
          notes: _notes.text.trim(),
          groupId: _groupId,
          confirmDuplicate: confirmDuplicate,
          idempotencyKey: _idempotencyKey,
        );
      }
      if (!mounted) return;
      await _clearDraft();
      if (!mounted) return;
      await _popSafely(true);
      if (queued != null) {
        _showQueuedParty(queued);
      } else {
        Get.snackbar(
          'Party updated',
          'The party details were saved.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } on ApiFailure catch (error) {
      if (!_editing && error.code == 'DUPLICATE_WARNING' && !confirmDuplicate) {
        await _confirmDuplicate(error);
      } else {
        _showMessage(error.message, error: true);
      }
    }
  }

  void _showQueuedParty(OptimisticMutationResult result) {
    final remaining = result.undoUntil.difference(DateTime.now().toUtc());
    Get.snackbar(
      'Party saved on this phone',
      '${_name.text.trim()} is ready for entries and will sync automatically.',
      duration: remaining.isNegative ? const Duration(seconds: 1) : remaining,
      snackPosition: SnackPosition.BOTTOM,
      mainButton: remaining.isNegative
          ? null
          : TextButton(
              onPressed: () async {
                Get.closeCurrentSnackbar();
                final outcome = await _ledger.undoPending(result.operationId);
                Get.snackbar(
                  outcome == UndoPendingResult.undone
                      ? 'Party addition undone'
                      : 'Party is already syncing',
                  outcome == UndoPendingResult.undone
                      ? 'The pending party was removed.'
                      : 'A posted or uploading party is never removed silently.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              child: const Text('Undo'),
            ),
    );
  }

  Future<void> _confirmDuplicate(ApiFailure error) async {
    final duplicates = error.data?['duplicates'];
    final duplicateNames = duplicates is List
        ? duplicates
              .whereType<Map>()
              .map((item) => item['name']?.toString() ?? '')
              .where((name) => name.isNotEmpty)
              .join(', ')
        : '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('This party may already exist'),
        content: Text(
          duplicateNames.isEmpty
              ? 'Check the name and phone number before adding another party.'
              : 'Similar party found: $duplicateNames',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add anyway'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _idempotencyKey = const Uuid().v4();
      _requestAttempted = false;
      await _save(confirmDuplicate: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.red : null,
      ),
    );
  }

  bool _isUuid(String? value) =>
      value != null && Uuid.isValidUUID(fromString: value);

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !_dirty || _leavingAfterSave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBackNavigation());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            (_editing ? 'Edit party' : 'Add party').tr,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
              children: [
                OutlinedButton.icon(
                  onPressed: _choosingContact ? null : _chooseContact,
                  icon: _choosingContact
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.contacts_outlined),
                  label: Text(
                    (_choosingContact
                            ? 'Finding contacts…'
                            : 'Find from contacts')
                        .tr,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or enter manually'.tr,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Name'.tr,
                    hintText: 'Customer or supplier name'.tr,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter at least 2 characters'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  maxLength: 30,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone number (optional)'.tr,
                    hintText: '98765 43210',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'More details'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('Short name, group, or notes'.tr),
                        trailing: Icon(
                          _advanced
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                        ),
                        onTap: () {
                          setState(() => _advanced = !_advanced);
                          _markDirty();
                        },
                      ),
                      if (_advanced)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                          child: Column(
                            children: [
                              TextField(
                                controller: _shortName,
                                maxLength: 100,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Short or shop name (optional)',
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String?>(
                                      key: ValueKey(_groupId),
                                      initialValue: _groupId,
                                      decoration: InputDecoration(
                                        labelText: 'Group (optional)'.tr,
                                      ),
                                      items: [
                                        DropdownMenuItem<String?>(
                                          child: Text('No group'.tr),
                                        ),
                                        ..._ledger.groups.map(
                                          (group) => DropdownMenuItem<String?>(
                                            value: group.id,
                                            child: Text(group.name),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() => _groupId = value);
                                        _markDirty();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    tooltip: 'Create group'.tr,
                                    onPressed: _ledger.mutating.value
                                        ? null
                                        : _createGroup,
                                    icon: const Icon(
                                      Icons.create_new_folder_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _notes,
                                maxLength: 500,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Notes (optional)',
                                  counterText: '',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Obx(
                  () => AsyncActionButton(
                    busy: _ledger.mutating.value,
                    onPressed: _save,
                    label: (_editing ? 'Save changes' : 'Add party').tr,
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

class _ContactDirectorySheet extends StatefulWidget {
  const _ContactDirectorySheet({required this.directory});

  final ContactDirectory directory;

  @override
  State<_ContactDirectorySheet> createState() => _ContactDirectorySheetState();
}

class _ContactDirectorySheetState extends State<_ContactDirectorySheet> {
  String _query = '';

  List<ContactPickResult> _matching(List<ContactPickResult> contacts) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return contacts;
    final digits = query.replaceAll(RegExp(r'\D'), '');
    return contacts.where((contact) {
      if (contact.name.toLowerCase().contains(query)) return true;
      if (digits.isEmpty) return false;
      return contact.phones.any(
        (phone) => phone.replaceAll(RegExp(r'\D'), '').contains(digits),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final inLedger = _matching(widget.directory.alreadyInLedger);
    final onHisaab = _matching(widget.directory.onHisaab);
    final other = _matching(widget.directory.other);
    final noMatches = inLedger.isEmpty && onHisaab.isEmpty && other.isEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) => CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            sliver: SliverList.list(
              children: [
                Text(
                  'Choose a contact'.tr,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manual entry remains available if you do not want to use contacts.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                TextField(
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search name or phone'.tr,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                if (!widget.directory.hisaabMatchingAvailable) ...[
                  const SizedBox(height: 12),
                  const _ContactPrivacyNotice(
                    message:
                        'Hisaab account matching is not available right now. '
                        'Contacts already saved in this ledger are still '
                        'identified on-device.',
                  ),
                ] else if (widget.directory.discoveryTruncated) ...[
                  const SizedBox(height: 12),
                  _ContactPrivacyNotice(
                    message:
                        'Checked the first '
                        '${widget.directory.discoveryCheckedCount} valid '
                        'numbers for Hisaab accounts. Your complete local '
                        'contact list is still shown below.',
                  ),
                ],
              ],
            ),
          ),
          if (inLedger.isNotEmpty)
            _ContactSection(
              title: 'Already in your ledger'.tr,
              contacts: inLedger,
            ),
          if (onHisaab.isNotEmpty)
            _ContactSection(title: 'On Hisaab'.tr, contacts: onHisaab),
          if (other.isNotEmpty)
            _ContactSection(title: 'Other contacts'.tr, contacts: other),
          if (noMatches)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_search_outlined,
                        size: 42,
                        color: AppColors.muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _query.trim().isEmpty
                            ? 'No contacts with phone numbers found'
                            : 'No matching contacts',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverToBoxAdapter(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.edit_outlined),
                label: Text('Enter manually instead'.tr),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection({required this.title, required this.contacts});

  final String title;
  final List<ContactPickResult> contacts;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            final phone = contact.preferredPhone;
            final badge = switch (contact.kind) {
              ContactDirectoryKind.alreadyInLedger => 'In ledger',
              ContactDirectoryKind.onHisaab => 'On Hisaab',
              ContactDirectoryKind.other => null,
            };
            return Semantics(
              button: true,
              label:
                  '${contact.name}, ${formatPhoneForDisplay(phone)}'
                  '${badge == null ? '' : ', $badge'}',
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: CircleAvatar(
                  backgroundColor: AppColors.greenSoft,
                  foregroundColor: AppColors.greenDark,
                  child: Text(
                    contact.name.trim().isEmpty
                        ? '?'
                        : contact.name.trim().characters.first.toUpperCase(),
                  ),
                ),
                title: Text(
                  contact.name.trim().isEmpty
                      ? 'Unnamed contact'
                      : contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${formatPhoneForDisplay(phone)}'
                  '${contact.phones.length > 1 ? '  ·  +${contact.phones.length - 1} more' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: badge == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : _ContactBadge(
                        label: badge,
                        emphasized:
                            contact.kind == ContactDirectoryKind.onHisaab,
                      ),
                onTap: () => Navigator.pop(context, contact),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ContactBadge extends StatelessWidget {
  const _ContactBadge({required this.label, required this.emphasized});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.greenSoft : const Color(0xFFF0F3F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: emphasized ? AppColors.greenDark : AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ContactPrivacyNotice extends StatelessWidget {
  const _ContactPrivacyNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.privacy_tip_outlined,
            color: AppColors.amber,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
