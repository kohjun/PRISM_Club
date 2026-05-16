import 'package:flutter/material.dart';

/// Palette from `docs/04_UX_MOCKUPS_STORYBOARD.md` §6.
class PrismColors {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF7F7FB);
  static const text = Color(0xFF17151F);
  static const muted = Color(0xFF6F6A7A);
  static const primary = Color(0xFF7C3AED);
  static const soft = Color(0xFFF1EAFE);
  static const border = Color(0xFFE7E4EE);
}

ThemeData buildPrismTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: const ColorScheme.light(
      primary: PrismColors.primary,
      onPrimary: Colors.white,
      surface: PrismColors.background,
      onSurface: PrismColors.text,
      surfaceContainerHighest: PrismColors.surface,
      surfaceContainerHigh: PrismColors.soft,
      outline: PrismColors.border,
    ),
    scaffoldBackgroundColor: PrismColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: PrismColors.background,
      foregroundColor: PrismColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: PrismColors.text,
      displayColor: PrismColors.text,
    ),
    cardTheme: CardThemeData(
      color: PrismColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: PrismColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PrismColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PrismColors.primary,
        side: const BorderSide(color: PrismColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: PrismColors.soft,
      labelStyle: const TextStyle(color: PrismColors.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    ),
    dividerColor: PrismColors.border,
  );
}
