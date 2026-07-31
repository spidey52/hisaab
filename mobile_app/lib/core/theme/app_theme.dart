import 'package:flutter/material.dart';

abstract final class AppColors {
  static const green = Color(0xFF08783E);
  static const greenDark = Color(0xFF075C32);
  static const greenSoft = Color(0xFFEAF6EF);
  static const red = Color(0xFFC83C35);
  static const redSoft = Color(0xFFFFECEA);
  static const amber = Color(0xFFE07614);
  static const ink = Color(0xFF18201C);
  static const muted = Color(0xFF68736D);
  static const line = Color(0xFFE1E7E3);
  static const page = Color(0xFFF8FAF8);
}

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        primary: AppColors.green,
        surface: Colors.white,
        error: AppColors.red,
      ),
      scaffoldBackgroundColor: AppColors.page,
      fontFamily: 'sans-serif',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: Color(0xFF929A95)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: AppColors.ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.greenSoft,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
