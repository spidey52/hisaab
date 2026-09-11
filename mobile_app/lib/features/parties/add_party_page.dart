import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../app/app.dart';
import '../../core/network/api_failure.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/models.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../services/contact_discovery_consent_service.dart';
import '../../services/contact_service.dart';
import '../../services/form_draft_service.dart';
import '../../shared/widgets/app_snackbar.dart';
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
    AppSnackbar.info(
      title: 'Draft restored',
      message: 'Your saved party draft was restored.',
      position: SnackbarPosition.bottom,
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
    final groupName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _CreateGroupDialog(),
    );
    if (groupName == null || !mounted) return;

    try {
      final group = await _ledger.createGroup(groupName);
      if (!mounted) return;
      setState(() => _groupId = group.id);
      _markDirty();
      AppSnackbar.success(
        title: 'Group created',
        message: '${group.name} is ready to use.',
        position: SnackbarPosition.bottom,
      );
    } on ApiFailure catch (error) {
      if (!mounted) return;
      AppSnackbar.error(
        title: 'Could not create group',
        message: error.message,
        position: SnackbarPosition.bottom,
      );
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
        backgroundColor: Colors.transparent,
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
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(contact.name, style: TextStyle(color: context.colors.muted)),
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
        AppSnackbar.success(
          title: 'Party updated',
          message: 'The party details were saved.',
          position: SnackbarPosition.bottom,
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
    AppSnackbar.success(
      title: 'Party saved on this phone',
      message:
          '${_name.text.trim()} is ready for entries and will sync automatically.',
      duration: remaining.isNegative ? const Duration(seconds: 1) : remaining,
      position: SnackbarPosition.bottom,
      actionLabel: remaining.isNegative ? null : 'Undo',
      onAction: remaining.isNegative
          ? null
          : () async {
              final outcome = await _ledger.undoPending(result.operationId);
              if (outcome == UndoPendingResult.undone) {
                AppSnackbar.success(
                  title: 'Party addition undone',
                  message: 'The pending party was removed.',
                  position: SnackbarPosition.bottom,
                );
              } else {
                AppSnackbar.warning(
                  title: 'Party is already syncing',
                  message:
                      'A posted or uploading party is never removed silently.',
                  position: SnackbarPosition.bottom,
                );
              }
            },
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
    if (error) {
      AppSnackbar.error(
        title: 'Something went wrong',
        message: message,
        position: SnackbarPosition.bottom,
      );
    } else {
      AppSnackbar.info(
        title: 'Heads up',
        message: message,
        position: SnackbarPosition.bottom,
      );
    }
  }

  bool _isUuid(String? value) =>
      value != null && Uuid.isValidUUID(fromString: value);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
            (_editing ? 'Edit party' : 'Add party').tr,
            style: displayStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.ink,
              letterSpacing: -0.2,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: colors.line),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    ListenableBuilder(
                      listenable: Listenable.merge([_name, _phone]),
                      builder: (context, _) => _PartyPreviewCard(
                        name: _name.text,
                        phone: _phone.text,
                        editing: _editing,
                      ),
                    ),
                    if (!_editing) ...[
                      const SizedBox(height: 18),
                      const _PartySectionLabel(label: 'QUICK ADD'),
                      const SizedBox(height: 8),
                      _ContactImportCard(
                        busy: _choosingContact,
                        onTap: _choosingContact ? null : _chooseContact,
                      ),
                      const SizedBox(height: 14),
                      const _OrDivider(label: 'or enter manually'),
                    ],
                    const SizedBox(height: 18),
                    const _PartySectionLabel(label: 'PARTY DETAILS'),
                    const SizedBox(height: 8),
                    _PartySurfaceCard(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              maxLength: 100,
                              decoration: InputDecoration(
                                labelText: 'Name'.tr,
                                hintText: 'Customer or supplier name'.tr,
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                                counterText: '',
                              ),
                              validator: (value) =>
                                  (value?.trim().length ?? 0) < 2
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
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+ ()-]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Phone number (optional)'.tr,
                                hintText: '98765 43210',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _PartySectionLabel(label: 'OPTIONAL'),
                    const SizedBox(height: 8),
                    _PartySurfaceCard(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() => _advanced = !_advanced);
                              _markDirty();
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                14,
                                10,
                                14,
                              ),
                              child: Row(
                                children: [
                                  const _PartyIconBadge(
                                    icon: Icons.tune_rounded,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'More details'.tr,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: colors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Short name, group, or notes'.tr,
                                          style: TextStyle(
                                            color: colors.muted,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: _advanced ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: colors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox(width: double.infinity),
                          secondChild: Column(
                            children: [
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: colors.line,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  14,
                                  14,
                                  16,
                                ),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _shortName,
                                      maxLength: 100,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      decoration: InputDecoration(
                                        labelText:
                                            'Short or shop name (optional)'.tr,
                                        prefixIcon: const Icon(
                                          Icons.storefront_outlined,
                                        ),
                                        counterText: '',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<String?>(
                                                key: ValueKey(_groupId),
                                                initialValue: _groupId,
                                                decoration: InputDecoration(
                                                  labelText:
                                                      'Group (optional)'.tr,
                                                  prefixIcon: const Icon(
                                                    Icons.folder_outlined,
                                                  ),
                                                ),
                                                items: [
                                                  DropdownMenuItem<String?>(
                                                    child: Text('No group'.tr),
                                                  ),
                                                  ..._ledger.groups.map(
                                                    (group) =>
                                                        DropdownMenuItem<
                                                          String?
                                                        >(
                                                          value: group.id,
                                                          child: Text(
                                                            group.name,
                                                          ),
                                                        ),
                                                  ),
                                                ],
                                                onChanged: (value) {
                                                  setState(
                                                    () => _groupId = value,
                                                  );
                                                  _markDirty();
                                                },
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Obx(
                                            () => IconButton.filledTonal(
                                              tooltip: 'Create group'.tr,
                                              style: IconButton.styleFrom(
                                                backgroundColor:
                                                    colors.greenSoft,
                                                foregroundColor:
                                                    colors.greenDark,
                                              ),
                                              onPressed: _ledger.mutating.value
                                                  ? null
                                                  : _createGroup,
                                              icon: const Icon(
                                                Icons
                                                    .create_new_folder_outlined,
                                              ),
                                            ),
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
                                      decoration: InputDecoration(
                                        labelText: 'Notes (optional)'.tr,
                                        alignLabelWithHint: true,
                                        prefixIcon: const Padding(
                                          padding: EdgeInsets.only(bottom: 36),
                                          child: Icon(Icons.notes_outlined),
                                        ),
                                        counterText: '',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          crossFadeState: _advanced
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 220),
                          sizeCurve: Curves.easeOutCubic,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _PartySaveBar(editing: _editing, onSave: _save),
          ],
        ),
      ),
    );
  }
}

class _PartyPreviewCard extends StatelessWidget {
  const _PartyPreviewCard({
    required this.name,
    required this.phone,
    required this.editing,
  });

  final String name;
  final String phone;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trimmed = name.trim();
    final displayName = trimmed.isEmpty
        ? (editing ? 'Party details' : 'New party')
        : trimmed;
    final phoneLabel = phone.trim().isEmpty
        ? 'Phone optional · add later anytime'
        : formatPhoneForDisplay(phone.trim());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.brand,
            Color.lerp(colors.brand, colors.brandDeep, 0.55)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.brand.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.onBrand.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.onBrand.withValues(alpha: 0.22)),
            ),
            child: Text(
              initials(trimmed.isEmpty ? '?' : trimmed),
              style: displayStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.onBrand,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'Editing party' : 'Ready for your ledger',
                  style: TextStyle(
                    color: colors.onBrandFaint,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.onBrand,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  phoneLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onBrand.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

class _ContactImportCard extends StatelessWidget {
  const _ContactImportCard({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _PartySurfaceCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                busy
                    ? SizedBox(
                        width: 42,
                        height: 42,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: colors.brand,
                            ),
                          ),
                        ),
                      )
                    : const _PartyIconBadge(icon: Icons.contacts_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (busy ? 'Finding contacts…' : 'Find from contacts').tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pick a name and number from your phone',
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(child: Divider(color: colors.line, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.tr,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.line, height: 1)),
      ],
    );
  }
}

class _PartySectionLabel extends StatelessWidget {
  const _PartySectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: context.colors.brand,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.05,
      ),
    );
  }
}

class _PartySurfaceCard extends StatelessWidget {
  const _PartySurfaceCard({this.child, this.children});

  final Widget? child;
  final List<Widget>? children;

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
        child: child ?? Column(children: children ?? const []),
      ),
    );
  }
}

class _PartyIconBadge extends StatelessWidget {
  const _PartyIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: colors.greenDark, size: 21),
    );
  }
}

class _PartySaveBar extends StatelessWidget {
  const _PartySaveBar({required this.editing, required this.onSave});

  final bool editing;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ledger = Get.find<LedgerController>();
    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.line)),
          boxShadow: [
            BoxShadow(
              color: colors.ink.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Obx(
              () => AsyncActionButton(
                busy: ledger.mutating.value,
                onPressed: onSave,
                icon: editing
                    ? Icons.check_rounded
                    : Icons.person_add_alt_1_rounded,
                label: (editing ? 'Save changes' : 'Add party').tr,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns its [TextEditingController] for the dialog route lifetime so the
/// controller is not disposed while the IME / input decorator is still
/// animating closed.
class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close([String? result]) {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, result);
  }

  void _submit() {
    final trimmed = _name.text.trim();
    if (trimmed.length < 2) return;
    _close(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Create a party group'.tr,
        style: displayStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.ink,
          letterSpacing: -0.2,
        ),
      ),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Group name'.tr,
          hintText: 'For example: Wholesale'.tr,
          prefixIcon: const Icon(Icons.folder_outlined),
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: _close, child: Text('Cancel'.tr)),
        FilledButton(onPressed: _submit, child: Text('Create group'.tr)),
      ],
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

    return Material(
      color: context.colors.page,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          final colors = context.colors;
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                sliver: SliverList.list(
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
                    const SizedBox(height: 16),
                    Text(
                      'Choose a contact'.tr,
                      style: displayStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manual entry remains available if you do not want to use contacts.',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
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
                          Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.settledSoft,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.person_search_outlined,
                              size: 30,
                              color: colors.muted,
                            ),
                          ),
                          const SizedBox(height: 14),
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
          );
        },
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
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colors.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
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
                leading: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.greenSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    contact.name.trim().isEmpty
                        ? '?'
                        : contact.name.trim().characters.first.toUpperCase(),
                    style: displayStyle(
                      fontSize: 15,
                      color: context.colors.greenDark,
                      fontWeight: FontWeight.w700,
                    ),
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized ? colors.greenSoft : colors.settledSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: emphasized ? colors.greenDark : colors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
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
          Icon(Icons.privacy_tip_outlined, color: colors.amber, size: 20),
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
