import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic color tokens for the "Bahi-Khata Modern" design language.
///
/// Every color in the app resolves through this extension so the whole UI
/// adapts between the warm-paper light theme and the deep-green dark theme.
/// Access via `context.colors`.
@immutable
class HisaabColors extends ThemeExtension<HisaabColors> {
  const HisaabColors({
    required this.page,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.muted,
    required this.line,
    required this.brand,
    required this.brandDeep,
    required this.onBrand,
    required this.onBrandFaint,
    required this.green,
    required this.greenDark,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.amber,
    required this.amberSoft,
    required this.settledSoft,
    required this.heroTop,
    required this.heroBottom,
  });

  /// Scaffold ground — warm ledger paper in light, green-black in dark.
  final Color page;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color muted;
  final Color line;

  /// Brand green used for identity surfaces (hero card, brand mark).
  final Color brand;
  final Color brandDeep;
  final Color onBrand;
  final Color onBrandFaint;

  /// "You got" / money-in direction.
  final Color green;

  /// Foreground variant of [green] that stays legible on [greenSoft].
  final Color greenDark;
  final Color greenSoft;

  /// "You gave" / money-out direction (brick, not alarm red).
  final Color red;
  final Color redSoft;

  /// Pending / attention accents.
  final Color amber;
  final Color amberSoft;

  /// Neutral chip ground for settled balances and quiet labels.
  final Color settledSoft;

  /// Passbook hero card gradient.
  final Color heroTop;
  final Color heroBottom;

  static const light = HisaabColors(
    // Cool white/slate surfaces to match the redesigned shell screenshots.
    // Brand greens (brand / brandDeep / onBrand* / hero*) stay unchanged.
    page: Color(0xFFF7F8F9),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    ink: Color(0xFF1F2937),
    muted: Color(0xFF6B7280),
    line: Color(0xFFE5E7EB),
    brand: Color(0xFF0A5C3C),
    brandDeep: Color(0xFF07402A),
    onBrand: Color(0xFFF6FBF5),
    onBrandFaint: Color(0xFFBBD9C6),
    green: Color(0xFF15803D),
    greenDark: Color(0xFF166534),
    greenSoft: Color(0xFFDCFCE7),
    red: Color(0xFFDC2626),
    redSoft: Color(0xFFFEE2E2),
    amber: Color(0xFFB06F12),
    amberSoft: Color(0xFFFAF0DD),
    settledSoft: Color(0xFFF3F4F6),
    heroTop: Color(0xFF0E6B45),
    heroBottom: Color(0xFF073B26),
  );

  static const dark = HisaabColors(
    page: Color(0xFF111613),
    surface: Color(0xFF1A211C),
    surfaceRaised: Color(0xFF222B25),
    ink: Color(0xFFE8EDE8),
    muted: Color(0xFFA2ADA5),
    line: Color(0xFF2D362F),
    brand: Color(0xFF17643F),
    brandDeep: Color(0xFF0C3A25),
    onBrand: Color(0xFFF0F9F2),
    onBrandFaint: Color(0xFF9CC4AB),
    green: Color(0xFF6AC694),
    greenDark: Color(0xFF8AD5AC),
    greenSoft: Color(0xFF1E3327),
    red: Color(0xFFE08A72),
    redSoft: Color(0xFF3A241C),
    amber: Color(0xFFDFAF60),
    amberSoft: Color(0xFF32270F),
    settledSoft: Color(0xFF262E28),
    heroTop: Color(0xFF1A5A3A),
    heroBottom: Color(0xFF0B2C1D),
  );

  @override
  HisaabColors copyWith() => this;

  @override
  HisaabColors lerp(ThemeExtension<HisaabColors>? other, double t) {
    if (other is! HisaabColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return HisaabColors(
      page: mix(page, other.page),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      brand: mix(brand, other.brand),
      brandDeep: mix(brandDeep, other.brandDeep),
      onBrand: mix(onBrand, other.onBrand),
      onBrandFaint: mix(onBrandFaint, other.onBrandFaint),
      green: mix(green, other.green),
      greenDark: mix(greenDark, other.greenDark),
      greenSoft: mix(greenSoft, other.greenSoft),
      red: mix(red, other.red),
      redSoft: mix(redSoft, other.redSoft),
      amber: mix(amber, other.amber),
      amberSoft: mix(amberSoft, other.amberSoft),
      settledSoft: mix(settledSoft, other.settledSoft),
      heroTop: mix(heroTop, other.heroTop),
      heroBottom: mix(heroBottom, other.heroBottom),
    );
  }
}

extension HisaabColorsContext on BuildContext {
  HisaabColors get colors =>
      Theme.of(this).extension<HisaabColors>() ?? HisaabColors.light;
}

/// Display face used for page titles and rupee numerals.
TextStyle displayStyle({
  double? fontSize,
  FontWeight fontWeight = FontWeight.w700,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.bricolageGrotesque(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

abstract final class AppTheme {
  static ThemeData get light => _build(HisaabColors.light, Brightness.light);

  static ThemeData get dark => _build(HisaabColors.dark, Brightness.dark);

  /// Larger Material text styles when the user enables accessibility mode.
  /// Applied on [GetMaterialApp.theme] — never via a nested MediaQuery/Theme
  /// in [GetMaterialApp.builder], which races with the IME.
  static ThemeData withAccessibility(ThemeData theme, bool enabled) {
    if (!enabled) return theme;
    const factor = 1.15;
    return theme.copyWith(
      textTheme: theme.textTheme.apply(fontSizeFactor: factor),
      primaryTextTheme: theme.primaryTextTheme.apply(fontSizeFactor: factor),
    );
  }

  static ThemeData _build(HisaabColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.brand,
        brightness: brightness,
        primary: isDark ? c.green : c.brand,
        onPrimary: isDark ? c.brandDeep : c.onBrand,
        surface: c.surface,
        onSurface: c.ink,
        error: c.red,
      ),
      scaffoldBackgroundColor: c.page,
    );

    final textTheme = base.textTheme
        .apply(bodyColor: c.ink, displayColor: c.ink)
        .copyWith(
          displayLarge: displayStyle(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -1.2,
          ),
          displayMedium: displayStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -1,
          ),
          displaySmall: displayStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.6,
          ),
          headlineMedium: displayStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.5,
          ),
          headlineSmall: displayStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.3,
          ),
          titleLarge: displayStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: c.ink,
            letterSpacing: -0.2,
          ),
        );

    return base.copyWith(
      extensions: [c],
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: c.page,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: displayStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.ink,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: c.surface,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: c.surface,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        labelStyle: TextStyle(color: c.muted),
        hintStyle: TextStyle(color: c.muted.withValues(alpha: 0.7)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? c.green : c.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.red, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: isDark ? c.green : c.brand,
          foregroundColor: isDark ? c.brandDeep : c.onBrand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? c.green : c.brand,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: c.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          foregroundColor: c.ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: c.surface,
        indicatorColor: c.greenSoft,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? (isDark ? c.greenDark : c.brandDeep)
                : c.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? (isDark ? c.greenDark : c.brandDeep)
                : c.muted,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line),
      listTileTheme: ListTileThemeData(iconColor: c.muted),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: displayStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        side: BorderSide(color: c.line),
        selectedColor: c.greenSoft,
        labelStyle: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? c.surfaceRaised : c.ink,
        contentTextStyle: TextStyle(
          color: isDark ? c.ink : const Color(0xFFF6F8F5),
        ),
        actionTextColor: isDark ? c.green : const Color(0xFF8ED8B0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? c.brandDeep : c.onBrand)
              : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (isDark ? c.green : c.brand)
              : c.settledSoft,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? c.green : c.brand,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? c.greenDark : c.brandDeep,
        unselectedLabelColor: c.muted,
        indicatorColor: isDark ? c.green : c.brand,
      ),
    );
  }
}
