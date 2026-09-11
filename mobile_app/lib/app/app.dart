import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/login_page.dart';
import '../features/auth/otp_page.dart';
import '../features/entries/add_entry_page.dart';
import '../features/entries/opening_balance_page.dart';
import '../features/ledger/ledger_controller.dart';
import '../features/parties/add_party_page.dart';
import '../features/parties/party_detail_page.dart';
import '../features/settings/settings_page.dart';
import '../features/splash/splash_page.dart';
import '../services/app_translations.dart';
import 'modules/main/bindings/main_binding.dart';
import 'modules/main/views/main_view.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const otp = '/otp';
  static const shell = '/main';
  static const addParty = '/parties/new';
  static const party = '/parties/detail';
  static const addEntry = '/entries/new';
  static const openingBalance = '/entries/opening-balance';
  static const settings = '/settings';
}

class HisaabMobileApp extends StatefulWidget {
  const HisaabMobileApp({super.key, this.initialLocale});

  final Locale? initialLocale;

  @override
  State<HisaabMobileApp> createState() => _HisaabMobileAppState();
}

class _HisaabMobileAppState extends State<HisaabMobileApp> {
  Worker? _worker;
  bool _accessibilityMode = false;

  @override
  void initState() {
    super.initState();
    _attachAccessibilityWorker();
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  void _attachAccessibilityWorker() {
    if (_worker != null || !Get.isRegistered<LedgerController>()) return;
    final ledger = Get.find<LedgerController>();
    _accessibilityMode = ledger.data.value?.user.accessibilityMode ?? false;
    _worker = ever(ledger.data, (data) {
      final next = data?.user.accessibilityMode ?? false;
      if (next == _accessibilityMode) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || next == _accessibilityMode) return;
        setState(() => _accessibilityMode = next);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Hisaab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.withAccessibility(AppTheme.light, _accessibilityMode),
      darkTheme: AppTheme.withAccessibility(AppTheme.dark, _accessibilityMode),
      themeMode: ThemeMode.system,
      translations: HisaabTranslations(),
      locale: widget.initialLocale,
      fallbackLocale: const Locale('en', 'IN'),
      supportedLocales: const [Locale('en', 'IN'), Locale('hi', 'IN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Never wrap [child] in MediaQuery/Theme — that races with IME insets.
      initialRoute: AppRoutes.splash,
      defaultTransition: Transition.cupertino,
      getPages: [
        GetPage(name: AppRoutes.splash, page: SplashPage.new),
        GetPage(name: AppRoutes.login, page: LoginPage.new),
        GetPage(name: AppRoutes.otp, page: OtpPage.new),
        GetPage(
          name: AppRoutes.shell,
          page: MainView.new,
          binding: MainBinding(),
        ),
        // Legacy shell path kept so older deep links still land on Main.
        GetPage(name: '/app', page: MainView.new, binding: MainBinding()),
        GetPage(name: AppRoutes.addParty, page: AddPartyPage.new),
        GetPage(name: AppRoutes.party, page: PartyDetailPage.new),
        GetPage(name: AppRoutes.addEntry, page: AddEntryPage.new),
        GetPage(name: AppRoutes.openingBalance, page: OpeningBalancePage.new),
        GetPage(name: AppRoutes.settings, page: SettingsPage.new),
      ],
    );
  }
}
