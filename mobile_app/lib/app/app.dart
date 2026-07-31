import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../features/shell/app_shell.dart';
import '../features/splash/splash_page.dart';
import '../services/app_translations.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const otp = '/otp';
  static const shell = '/app';
  static const addParty = '/parties/new';
  static const party = '/parties/detail';
  static const addEntry = '/entries/new';
  static const openingBalance = '/entries/opening-balance';
  static const settings = '/settings';
}

class HisaabMobileApp extends StatelessWidget {
  const HisaabMobileApp({super.key, this.initialLocale});

  final Locale? initialLocale;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return GetMaterialApp(
      title: 'Hisaab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      translations: HisaabTranslations(),
      locale: initialLocale,
      fallbackLocale: const Locale('en', 'IN'),
      supportedLocales: const [Locale('en', 'IN'), Locale('hi', 'IN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => Obx(() {
        final media = MediaQuery.of(context);
        final accessibilityMode =
            Get.find<LedgerController>().data.value?.user.accessibilityMode ??
            false;
        final currentScale = media.textScaler.scale(1);
        final scaler = accessibilityMode && currentScale < 1.15
            ? const TextScaler.linear(1.15)
            : media.textScaler;
        return MediaQuery(
          data: media.copyWith(textScaler: scaler),
          child: child ?? const SizedBox.shrink(),
        );
      }),
      initialRoute: AppRoutes.splash,
      defaultTransition: Transition.cupertino,
      getPages: [
        GetPage(name: AppRoutes.splash, page: SplashPage.new),
        GetPage(name: AppRoutes.login, page: LoginPage.new),
        GetPage(name: AppRoutes.otp, page: OtpPage.new),
        GetPage(name: AppRoutes.shell, page: AppShell.new),
        GetPage(name: AppRoutes.addParty, page: AddPartyPage.new),
        GetPage(name: AppRoutes.party, page: PartyDetailPage.new),
        GetPage(name: AppRoutes.addEntry, page: AddEntryPage.new),
        GetPage(name: AppRoutes.openingBalance, page: OpeningBalancePage.new),
        GetPage(name: AppRoutes.settings, page: SettingsPage.new),
      ],
    );
  }
}
