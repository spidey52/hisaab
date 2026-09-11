import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../app/app.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/storage/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../services/contact_discovery_consent_service.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/async_action_button.dart';
import '../auth/auth_controller.dart';
import '../learn/learn_page.dart';
import '../ledger/ledger_controller.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = Get.find<LedgerController>();
    final auth = Get.find<AuthController>();
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text('More'.tr)),
      body: Obx(() {
        final data = ledger.data.value;
        final userName = data?.user.fullName ?? 'Hisaab user';
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.greenSoft,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        initials(userName),
                        style: displayStyle(
                          fontSize: 17,
                          color: colors.greenDark,
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
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            data?.user.phoneE164 ?? '',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(
                      'Settings'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Business name and accessibility'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Get.toNamed(AppRoutes.settings),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: Text(
                      'Learn'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Short lessons on using your khata'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Get.to<void>(() => const LearnPage()),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync_rounded),
                    title: Text(
                      'Refresh data'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      ledger.isOffline.value
                          ? 'Try connecting to the server again'
                          : 'Download the latest ledger',
                    ),
                    trailing: ledger.loading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: ledger.loading.value
                        ? null
                        : () async {
                            try {
                              await ledger.reload();
                              AppSnackbar.success(
                                title: 'Up to date',
                                message:
                                    'The latest Hisaab is now on this phone.',
                                position: SnackbarPosition.bottom,
                              );
                            } on ApiFailure catch (error) {
                              AppSnackbar.error(
                                title: 'Could not refresh',
                                message: error.message,
                                position: SnackbarPosition.bottom,
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('About'.tr, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: Text(
                  'App version'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: Text(
                  '1.0.0 (redesign preview)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.muted),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text(
                  'Connection information',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign-in mode',
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ServerMode.parse(Get.find<AppStorage>().readServerMode()) ==
                            ServerMode.selfHosted
                        ? 'Self-hosted'
                        : 'Hisaab Cloud',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Server',
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    Get.find<ApiClient>().baseUrl,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your phone must be able to reach this Hisaab '
                    'server. If it is unavailable, saved changes remain on '
                    'this device and sync later. To use a different server, '
                    'sign out and choose Cloud or Self-hosted on the login '
                    'screen.',
                    style: TextStyle(color: colors.muted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: auth.busy.value
                  ? null
                  : () => _confirmLogout(context, auth, ledger),
              icon: const Icon(Icons.logout_rounded),
              label: Text('Sign out'.tr),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    AuthController auth,
    LedgerController ledger,
  ) async {
    final unsynced =
        ledger.pendingCount.value + ledger.needsAttentionCount.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign out of Hisaab?'.tr),
        content: Text(
          unsynced > 0
              ? '$unsynced saved ${unsynced == 1 ? 'change has' : 'changes have'} '
                    'not synced. Signing out will permanently discard '
                    '${unsynced == 1 ? 'it' : 'them'} from this phone.\n\n'
                    'Sync or review the saved changes first unless you are '
                    'sure you want to discard them.'
              : 'You will need a new phone verification code to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text((unsynced > 0 ? 'Review first' : 'Stay signed in').tr),
          ),
          FilledButton(
            style: unsynced > 0
                ? FilledButton.styleFrom(backgroundColor: context.colors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              (unsynced > 0 ? 'Sign out and discard' : 'Sign out').tr,
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await auth.logout();
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ledger = Get.find<LedgerController>();
  late final ContactDiscoveryConsentService _contactConsent =
      Get.isRegistered<ContactDiscoveryConsentService>()
      ? Get.find<ContactDiscoveryConsentService>()
      : SharedPreferencesContactDiscoveryConsentService(Get.find<AppStorage>());
  final _company = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late bool _accessibilityMode;
  late bool _contactDiscoverable;
  late String _language;
  bool _contactDiscovery = false;
  bool _loadingContactConsent = true;
  bool _exporting = false;
  bool _deleting = false;
  String _saveIdempotencyKey = const Uuid().v4();
  bool _saveAttempted = false;
  final Map<String, String> _operationKeys = {};

  @override
  void initState() {
    super.initState();
    final data = _ledger.data.value;
    _company.text = data?.company.name ?? 'My Hisaab';
    _accessibilityMode = data?.user.accessibilityMode ?? false;
    _contactDiscoverable = data?.user.contactDiscoverable ?? false;
    _language = data?.user.language == 'hi' ? 'hi' : 'en';
    _company.addListener(_settingsIntentChanged);
    _loadContactConsent();
  }

  @override
  void dispose() {
    _company.removeListener(_settingsIntentChanged);
    _company.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    try {
      _saveAttempted = true;
      await _ledger.updateSettings(
        companyName: _company.text.trim(),
        accessibilityMode: _accessibilityMode,
        idempotencyKey: _saveIdempotencyKey,
      );
      _saveIdempotencyKey = const Uuid().v4();
      _saveAttempted = false;
      if (!mounted) return;
      AppSnackbar.success(
        title: 'Settings saved'.tr,
        message: 'Your preferences are up to date.',
        position: SnackbarPosition.bottom,
      );
    } on ApiFailure catch (error) {
      if (!mounted) return;
      AppSnackbar.error(
        title: 'Could not save',
        message: error.message,
        position: SnackbarPosition.bottom,
      );
    }
  }

  void _settingsIntentChanged() {
    if (!_saveAttempted) return;
    _saveIdempotencyKey = const Uuid().v4();
    _saveAttempted = false;
  }

  Future<void> _loadContactConsent() async {
    final consent = await _contactConsent.status();
    if (!mounted) return;
    setState(() {
      _contactDiscovery = consent == ContactDiscoveryConsent.granted;
      _loadingContactConsent = false;
    });
  }

  Future<void> _setContactDiscovery(bool value) async {
    final previous = _contactDiscovery;
    setState(() => _contactDiscovery = value);
    try {
      await _contactConsent.setGranted(value);
      if (!mounted) return;
      AppSnackbar.success(
        title: value ? 'Contact matching on' : 'Contact matching off',
        message: value
            ? 'Hisaab contact matching is on.'
            : 'Hisaab contact matching is off.',
        position: SnackbarPosition.bottom,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _contactDiscovery = previous);
      AppSnackbar.error(
        title: 'Could not save',
        message: 'Could not save the privacy setting.',
        position: SnackbarPosition.bottom,
      );
    }
  }

  Future<void> _setContactDiscoverable(bool value) async {
    final previous = _contactDiscoverable;
    setState(() => _contactDiscoverable = value);
    try {
      final intent = 'contactDiscoverable:$value';
      await _ledger.updateSettings(
        contactDiscoverable: value,
        idempotencyKey: _operationKey(intent),
      );
      _operationKeys.remove(intent);
      if (!mounted) return;
      AppSnackbar.success(
        title: value ? 'Discoverable' : 'Hidden',
        message: value
            ? 'People who have your number can now find you on Hisaab.'
            : 'People can no longer find your Hisaab account by number.',
        position: SnackbarPosition.bottom,
      );
    } on ApiFailure catch (error) {
      if (!mounted) return;
      setState(() => _contactDiscoverable = previous);
      AppSnackbar.error(
        title: 'Could not save',
        message: error.message,
        position: SnackbarPosition.bottom,
      );
    }
  }

  Future<void> _setLanguage(String? value) async {
    if (value == null || value == _language) return;
    final previous = _language;
    setState(() => _language = value);
    try {
      final intent = 'language:$value';
      await _ledger.updateSettings(
        language: value,
        idempotencyKey: _operationKey(intent),
      );
      _operationKeys.remove(intent);
      await initializeDateFormatting(value == 'hi' ? 'hi_IN' : 'en_IN');
      setFormattingLocale(value);
      Get.updateLocale(Locale(value, 'IN'));
    } on ApiFailure catch (error) {
      if (!mounted) return;
      setState(() => _language = previous);
      AppSnackbar.error(
        title: 'Could not update language',
        message: error.message,
        position: SnackbarPosition.bottom,
      );
    }
  }

  String _operationKey(String intent) =>
      _operationKeys.putIfAbsent(intent, () => const Uuid().v4());

  Future<void> _export(
    LedgerExportFormat format,
    BuildContext shareContext,
  ) async {
    if (_exporting) return;
    final renderBox = shareContext.findRenderObject() as RenderBox?;
    final shareOrigin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
    setState(() => _exporting = true);
    try {
      final exported = await _ledger.exportLedger(format: format);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              exported.bytes,
              mimeType: exported.mimeType,
              name: exported.filename,
            ),
          ],
          fileNameOverrides: [exported.filename],
          subject: 'Hisaab ledger export',
          sharePositionOrigin: shareOrigin,
        ),
      );
    } on ApiFailure catch (error) {
      if (!mounted) return;
      AppSnackbar.error(
        title: 'Could not export',
        message: error.message,
        position: SnackbarPosition.bottom,
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (_deleting) return;
    final confirmation = TextEditingController();
    var matches = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Permanently delete this account?'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This permanently deletes the company ledger, parties, '
                  'entries, audit history, and any changes saved only on this '
                  'phone. It cannot be undone.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Type DELETE MY ACCOUNT to continue.'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmation,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: 'Confirmation'.tr),
                  onChanged: (value) => setDialogState(
                    () => matches = value.trim() == 'DELETE MY ACCOUNT',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Keep account'.tr),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.red,
              ),
              onPressed: matches
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text('Delete permanently'.tr),
            ),
          ],
        ),
      ),
    );
    confirmation.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await Get.find<AuthController>().deleteAccount();
    } on ApiFailure catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      AppSnackbar.error(
        title: 'Could not delete account',
        message: error.message,
        position: SnackbarPosition.bottom,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      AppSnackbar.error(
        title: 'Could not delete account',
        message: 'The account could not be deleted. Try again.',
        position: SnackbarPosition.bottom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings'.tr,
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
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const _SettingsSectionLabel(label: 'BUSINESS'),
              const SizedBox(height: 8),
              _SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: TextFormField(
                    controller: _company,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Business or ledger name'.tr,
                      hintText: 'e.g. Sharma Traders',
                      counterText: '',
                      prefixIcon: const Icon(Icons.storefront_outlined),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter at least 2 characters'
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SettingsSectionLabel(label: 'READING COMFORT'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  SwitchListTile(
                    value: _accessibilityMode,
                    onChanged: (value) {
                      setState(() => _accessibilityMode = value);
                      _settingsIntentChanged();
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    title: Text(
                      'Larger, clearer controls'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    subtitle: Text(
                      'Remember this preference across Hisaab devices.',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    secondary: _SettingsIcon(
                      icon: Icons.accessibility_new_rounded,
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: colors.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: InputDecoration(
                        labelText: 'App language'.tr,
                        prefixIcon: const Icon(Icons.translate_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                      ],
                      onChanged: _ledger.mutating.value ? null : _setLanguage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SettingsSectionLabel(label: 'PRIVACY'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  SwitchListTile(
                    value: _contactDiscovery,
                    onChanged: _loadingContactConsent
                        ? null
                        : _setContactDiscovery,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    title: Text(
                      'Find contacts on Hisaab'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    subtitle: Text(
                      'Send valid normalized phone numbers for account '
                      'matching. Contact names stay on this phone.',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    secondary: _loadingContactConsent
                        ? SizedBox(
                            width: 38,
                            height: 38,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.brand,
                                ),
                              ),
                            ),
                          )
                        : const _SettingsIcon(icon: Icons.contacts_outlined),
                  ),
                  Divider(height: 1, thickness: 1, color: colors.line),
                  SwitchListTile(
                    value: _contactDiscoverable,
                    onChanged: _ledger.mutating.value
                        ? null
                        : _setContactDiscoverable,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    title: Text(
                      'Allow people with my number to find me'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    subtitle: Text(
                      'This controls whether other Hisaab users who already '
                      'have your number can see that you use Hisaab.',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    secondary: const _SettingsIcon(
                      icon: Icons.person_search_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SettingsSectionLabel(label: 'DATA AND RECOVERY'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  Builder(
                    builder: (shareContext) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: _exporting
                          ? SizedBox(
                              width: 38,
                              height: 38,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.brand,
                                  ),
                                ),
                              ),
                            )
                          : const _SettingsIcon(icon: Icons.download_outlined),
                      title: Text(
                        'Export a backup'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      subtitle: Text(
                        'Share a complete server copy as JSON or CSV.'.tr,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: PopupMenuButton<LedgerExportFormat>(
                        tooltip: 'Choose export format'.tr,
                        enabled: !_exporting && !_deleting,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (format) => _export(format, shareContext),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: LedgerExportFormat.json,
                            child: Text('JSON backup'.tr),
                          ),
                          PopupMenuItem(
                            value: LedgerExportFormat.csv,
                            child: Text('CSV entries'.tr),
                          ),
                        ],
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: colors.line),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.redSoft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.delete_forever_outlined,
                        color: colors.red,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Delete account and ledger'.tr,
                      style: TextStyle(
                        color: colors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently removes all company data.'.tr,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: _deleting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.red,
                            ),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: colors.muted,
                          ),
                    onTap: _exporting || _deleting
                        ? null
                        : _confirmDeleteAccount,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Obx(
                () => AsyncActionButton(
                  label: 'Save settings'.tr,
                  busy: _ledger.mutating.value,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.label});

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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({this.child, this.children});

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

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.greenSoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: colors.greenDark, size: 20),
    );
  }
}
