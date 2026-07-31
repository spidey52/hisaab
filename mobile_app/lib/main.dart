import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/app_storage.dart';
import 'core/sync/sync_coordinator.dart';
import 'core/utils/formatters.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/ledger_repository.dart';
import 'features/auth/auth_controller.dart';
import 'features/ledger/ledger_controller.dart';
import 'features/shell/navigation_controller.dart';
import 'services/calculator_preference_service.dart';
import 'services/contact_service.dart';
import 'services/contact_discovery_consent_service.dart';
import 'services/form_draft_service.dart';
import 'services/party_communication_service.dart';
import 'services/app_translations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validateForCurrentBuild();
  await Future.wait([
    initializeDateFormatting('en_IN'),
    initializeDateFormatting('hi_IN'),
  ]);

  final storage = await AppStorage().init();
  Get.put<AppStorage>(storage, permanent: true);
  final initialLanguage =
      (storage.readCachedBootstrap()?['user'] as Map?)?['language']
          ?.toString() ??
      'en';
  setFormattingLocale(initialLanguage);

  final apiClient = ApiClient(storage);
  Get.put<ApiClient>(apiClient, permanent: true);
  Get.put<AuthRepository>(AuthRepository(apiClient, storage), permanent: true);
  Get.put<LedgerRepository>(
    LedgerRepository(apiClient, storage),
    permanent: true,
  );
  Get.put<ContactService>(
    DeviceContactService(discovery: ApiContactDiscoveryAdapter(apiClient)),
    permanent: true,
  );
  Get.put<ContactDiscoveryConsentService>(
    SharedPreferencesContactDiscoveryConsentService(storage),
    permanent: true,
  );
  Get.put<CalculatorPreferenceService>(
    const SharedPreferencesCalculatorPreferenceService(),
    permanent: true,
  );
  Get.put<FormDraftService>(
    EncryptedFormDraftService(storage),
    permanent: true,
  );
  Get.put<PartyCommunicationService>(
    const DevicePartyCommunicationService(),
    permanent: true,
  );

  final ledgerController = Get.put<LedgerController>(
    LedgerController(Get.find<LedgerRepository>()),
    permanent: true,
  );
  late final AuthController authController;
  final syncCoordinator = Get.put<SyncCoordinator>(
    SyncCoordinator(
      runSync: ledgerController.syncNow,
      onAuthenticationRequired: () => authController.handleExpiredSession(),
    ),
    permanent: true,
  );
  authController = Get.put<AuthController>(
    AuthController(
      Get.find<AuthRepository>(),
      ledgerController,
      storage,
      apiClient,
      syncCoordinator,
    ),
    permanent: true,
  );
  Get.put<NavigationController>(NavigationController(), permanent: true);

  runApp(
    HisaabMobileApp(
      initialLocale: HisaabTranslations.localeFor(initialLanguage),
    ),
  );
}
