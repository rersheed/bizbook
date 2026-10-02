import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BizColors {
  static const primary = Color(0xFF0F7A4B);
  static const secondary = Color(0xFF22C55E);
  static const accent = Color(0xFFA7F3D0);
  static const text = Color(0xFF1F2937);
  static const surface = Color(0xFFF8FAF9);
  static const border = Color(0xFFE5E7EB);
  static const muted = Color(0xFF6B7280);
  static const highlight = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const white = Color(0xFFFFFFFF);
}

ThemeData buildBizTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BizColors.primary,
      primary: BizColors.primary,
      secondary: BizColors.secondary,
      surface: BizColors.surface,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: BizColors.surface,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: BizColors.text,
      displayColor: BizColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BizColors.surface,
      foregroundColor: BizColors.text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: BizColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: BizColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BizColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BizColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BizColors.primary,
        side: const BorderSide(color: BizColors.primary),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BizColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BizColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BizColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BizColors.primary, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: BizColors.border),
      backgroundColor: BizColors.white,
      selectedColor: BizColors.primary,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BizColors.primary,
      foregroundColor: Colors.white,
    ),
  );
}
