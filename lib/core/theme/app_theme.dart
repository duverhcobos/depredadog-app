import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema Material 3 de Depredadog (light + dark). Los widgets consumen
/// Theme.of(context) — nunca AppColors directo salvo marca sobre gradiente.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(
    ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.onPrimaryLight,
      secondary: AppColors.secondaryLight,
      onSecondary: AppColors.onSecondaryLight,
      tertiary: AppColors.tertiaryLight,
      onTertiary: AppColors.onTertiaryLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      error: AppColors.errorLight,
      onError: AppColors.onErrorLight,
    ),
    scaffold: AppColors.scaffoldLight,
  );

  static ThemeData dark() => _base(
    ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryDark,
      onPrimary: AppColors.onPrimaryDark,
      secondary: AppColors.secondaryDark,
      onSecondary: AppColors.onSecondaryDark,
      tertiary: AppColors.tertiaryDark,
      onTertiary: AppColors.onTertiaryDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      error: AppColors.errorDark,
      onError: AppColors.onErrorDark,
    ),
    scaffold: AppColors.scaffoldDark,
  );

  /// Familia display de la marca (§017, decisión del usuario): Anton —
  /// condensada con actitud para títulos, nombres de producto y
  /// headlines. Solo peso 400; los roles body/label siguen en sistema.
  static const String displayFontFamily = 'Anton';

  /// Anton en los slots display/headline/title del textTheme — así
  /// TODA la app hereda la voz tipográfica sin fontFamily sueltos.
  static TextTheme _displaySlots(TextTheme base) => base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontFamily: displayFontFamily),
    displayMedium: base.displayMedium?.copyWith(fontFamily: displayFontFamily),
    displaySmall: base.displaySmall?.copyWith(fontFamily: displayFontFamily),
    headlineLarge: base.headlineLarge?.copyWith(fontFamily: displayFontFamily),
    headlineMedium: base.headlineMedium?.copyWith(
      fontFamily: displayFontFamily,
    ),
    headlineSmall: base.headlineSmall?.copyWith(fontFamily: displayFontFamily),
    titleLarge: base.titleLarge?.copyWith(fontFamily: displayFontFamily),
    titleMedium: base.titleMedium?.copyWith(fontFamily: displayFontFamily),
    titleSmall: base.titleSmall?.copyWith(fontFamily: displayFontFamily),
  );

  static ThemeData _base(ColorScheme scheme, {Color? scaffold}) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold ?? scheme.surface,
      textTheme: _displaySlots(
        ThemeData(brightness: scheme.brightness).textTheme,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          // M3 deja ElevatedButton tonal (surfaceContainerLow) — la marca
          // pide el botón primario sólido en primario.
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // Mismo estándar que el primario: alto 52, radius 14 (Google, etc.)
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        // Foco en onSurface (carbón) — el primario rojo se confundía con el
        // color de error; así el foco se distingue del error a primera vista.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.onSurface, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
