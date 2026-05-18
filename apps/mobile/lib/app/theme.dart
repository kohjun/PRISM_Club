import 'package:flutter/material.dart';

import 'design_tokens.dart';

// Re-export so existing `import 'app/theme.dart'` keeps working — old code
// reaches `PrismColors.primary / muted / soft / border` and new code reaches
// the full ramp (`PrismColors.pp600 / ink1 / line2`).
export 'design_tokens.dart'
    show
        PrismColors,
        PrismSpacing,
        PrismRadius,
        PrismElevation,
        PrismFonts,
        PrismType,
        PrismAvatarPalette;

/// Builds the app-wide Material 3 theme from design tokens.
///
/// The hierarchy: white surface, Club Purple as the only accent, ink ramp for
/// type, flat 1px borders by default. Letter-spacing is negative across
/// title sizes for the Korean "tight" feel; numerals use tabular figures
/// where readability matters.
ThemeData buildPrismTheme() {
  final base = ThemeData(
    brightness: Brightness.light,
    fontFamily: PrismFonts.body,
    useMaterial3: true,
  );

  final colorScheme = const ColorScheme.light(
    primary: PrismColors.pp600,
    onPrimary: Colors.white,
    primaryContainer: PrismColors.pp100,
    onPrimaryContainer: PrismColors.pp900,
    secondary: PrismColors.ink2,
    onSecondary: Colors.white,
    secondaryContainer: PrismColors.bgTint,
    onSecondaryContainer: PrismColors.ink1,
    error: PrismColors.danger,
    onError: Colors.white,
    surface: PrismColors.bg,
    onSurface: PrismColors.ink1,
    surfaceContainerLowest: PrismColors.bg,
    surfaceContainerLow: PrismColors.bgSoft,
    surfaceContainerHighest: PrismColors.bgTint,
    surfaceContainerHigh: PrismColors.pp50,
    outline: PrismColors.line,
    outlineVariant: PrismColors.line2,
  );

  final textTheme = base.textTheme.copyWith(
    displayLarge: PrismType.displayLg,
    displayMedium: PrismType.displayLg.copyWith(
      fontSize: 26,
      letterSpacing: -0.8,
    ),
    displaySmall: PrismType.titleXl,
    headlineMedium: PrismType.titleXl,
    headlineSmall: PrismType.titleMd,
    titleLarge: PrismType.titleMd,
    titleMedium: PrismType.titleSm,
    titleSmall: PrismType.titleSm.copyWith(fontSize: 14),
    bodyLarge: PrismType.bodyLg,
    bodyMedium: PrismType.body,
    bodySmall: PrismType.caption,
    labelLarge: PrismType.label,
    labelMedium: PrismType.label.copyWith(fontSize: 12),
    labelSmall: PrismType.overline,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: PrismColors.bg,
    canvasColor: PrismColors.bg,
    dividerColor: PrismColors.divider,
    textTheme: textTheme.apply(
      bodyColor: PrismColors.ink1,
      displayColor: PrismColors.ink1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PrismColors.bg,
      foregroundColor: PrismColors.ink1,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: PrismFonts.body,
        color: PrismColors.ink1,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      toolbarHeight: 56,
    ),
    cardTheme: CardThemeData(
      color: PrismColors.bg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        side: const BorderSide(color: PrismColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PrismColors.pp600,
        foregroundColor: Colors.white,
        disabledBackgroundColor: PrismColors.bgTint,
        disabledForegroundColor: PrismColors.ink4,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.md),
        ),
        textStyle: const TextStyle(
          fontFamily: PrismFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PrismColors.pp600,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PrismColors.ink2,
        side: const BorderSide(color: PrismColors.line2),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.md),
        ),
        textStyle: const TextStyle(
          fontFamily: PrismFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PrismColors.pp700,
        textStyle: const TextStyle(
          fontFamily: PrismFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: PrismColors.ink2),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: PrismColors.bgTint,
      selectedColor: PrismColors.pp600,
      labelStyle: const TextStyle(
        fontFamily: PrismFonts.body,
        color: PrismColors.ink2,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: PrismFonts.body,
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: const BorderSide(color: PrismColors.line2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.md,
        vertical: 6,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PrismColors.bgTint,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.cardPad,
        vertical: PrismSpacing.md,
      ),
      hintStyle: const TextStyle(
        fontFamily: PrismFonts.body,
        color: PrismColors.ink4,
        fontSize: 14,
        letterSpacing: -0.2,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PrismRadius.md),
        borderSide: const BorderSide(color: PrismColors.line2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PrismRadius.md),
        borderSide: const BorderSide(color: PrismColors.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PrismRadius.md),
        borderSide: const BorderSide(color: PrismColors.pp600, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PrismRadius.md),
        borderSide: const BorderSide(color: PrismColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PrismRadius.md),
        borderSide: const BorderSide(color: PrismColors.danger, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PrismColors.bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: PrismColors.pp100,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: PrismColors.pp700, size: 24);
        }
        return const IconThemeData(color: PrismColors.ink3, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: PrismFonts.body,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: -0.2,
          color: selected ? PrismColors.pp700 : PrismColors.ink3,
        );
      }),
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PrismColors.bg,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: PrismColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PrismRadius.xxl),
        ),
      ),
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: PrismColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: PrismColors.ink1,
      contentTextStyle: TextStyle(
        fontFamily: PrismFonts.body,
        color: Colors.white,
        fontSize: 13,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PrismColors.pp600,
    ),
  );
}
