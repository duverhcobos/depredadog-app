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
      );

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
