import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/app.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/storage/app_storage.dart';
import '../../../../data/repositories/ledger_repository.dart';
import '../../../../features/auth/auth_controller.dart';
import '../../../../features/learn/learn_page.dart';
import '../../../../features/ledger/ledger_controller.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// More tab actions wired to existing settings / export / auth flows.
class MoreController extends GetxController {
  LedgerController get ledger => Get.find<LedgerController>();
  AuthController get auth => Get.find<AuthController>();

  final exporting = false.obs;

  String get businessName => ledger.data.value?.company.name ?? 'My Hisaab';

  String get userName => ledger.data.value?.user.fullName ?? 'Hisaab user';

  String get userPhone => ledger.data.value?.user.phoneE164 ?? '';

  String get appVersion => '1.0.0';

  String? get lastSyncedLabel {
    final at = ledger.lastSyncedAt.value;
    if (at == null) return null;
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final time = DateFormat('h:mm a', Intl.getCurrentLocale()).format(local);
    if (day == today) return 'Last backup: Today, $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Last backup: Yesterday, $time';
    }
    return 'Last backup: ${DateFormat('d MMM yyyy, h:mm a', Intl.getCurrentLocale()).format(local)}';
  }

  String get connectionMode {
    final mode = ServerMode.parse(Get.find<AppStorage>().readServerMode());
    return mode == ServerMode.selfHosted ? 'Self-hosted' : 'Hisaab Cloud';
  }

  String get serverUrl => Get.find<ApiClient>().baseUrl;

  void openSettings() => Get.toNamed(AppRoutes.settings);

  void openHelp() => Get.to<void>(() => const LearnPage());

  Future<void> refreshData() async {
    try {
      await ledger.reload();
      AppSnackbar.success(
        title: 'Up to date',
        message: 'The latest Hisaab is now on this phone.',
        position: SnackbarPosition.bottom,
      );
    } on ApiFailure catch (error) {
      AppSnackbar.error(
        title: 'Could not refresh',
        message: error.message,
        position: SnackbarPosition.bottom,
      );
    }
  }

  Future<void> exportData(LedgerExportFormat format, Rect? shareOrigin) async {
    if (exporting.value) return;
    exporting.value = true;
    try {
      final exported = await ledger.exportLedger(format: format);
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
      AppSnackbar.error(
        title: 'Could not export',
        message: error.message,
        position: SnackbarPosition.bottom,
      );
    } finally {
      exporting.value = false;
    }
  }

  Future<void> confirmLogout(BuildContext context) async {
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
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
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

  void showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Hisaab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version $appVersion'),
            const SizedBox(height: 12),
            Text('Sign-in mode: $connectionMode'),
            const SizedBox(height: 8),
            SelectableText('Server: $serverUrl'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
