import 'package:flutter/material.dart';

/// Paleta Depredadog — fast-food, identidad "condimentos":
/// ketchup / mostaza / pan / parrilla / pepinillo.
/// Único archivo autorizado (junto a app_theme) para mencionar colores
/// literales. Cada rol tiene variante light y dark (ThemeMode.system).
class AppColors {
  AppColors._();

  // ---- Light ----
  static const Color primaryLight = Color(0xFFD62828); // rojo ketchup
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color secondaryLight = Color(0xFFFBBF24); // amarillo mostaza
  static const Color onSecondaryLight = Color(0xFF4A2511);
  static const Color tertiaryLight = Color(0xFF5B8C3A); // verde pepinillo
  static const Color onTertiaryLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFF3D6); // crema pan
  static const Color scaffoldLight = Color(0xFFFFFFFF); // blanco — fondo MVP
  static const Color onSurfaceLight = Color(0xFF4A2511); // marrón parrilla
  static const Color errorLight = Color(0xFFB3261E);
  static const Color onErrorLight = Color(0xFFFFFFFF);

  // ---- Dark (derivadas de la misma familia) ----
  static const Color primaryDark = Color(0xFFFDD019); // mostaza del logo
  static const Color onPrimaryDark = Color(0xFF1D1D1B); // negro rico
  static const Color secondaryDark = Color(0xFFFCD34D); // mostaza suavizada
  static const Color onSecondaryDark = Color(0xFF3D2B00);
  static const Color tertiaryDark = Color(0xFF8FBF6A);
  static const Color onTertiaryDark = Color(0xFF1E3A0F);
  static const Color surfaceDark = Color(0xFF241511); // parrilla profundo
  static const Color scaffoldDark = Color(0xFF000000); // negro puro — fondo
  static const Color onSurfaceDark = Color(0xFFFFF3D6); // crema pan
  static const Color errorDark = Color(0xFFF2B8B5);
  static const Color onErrorDark = Color(0xFF601410);

  /// Marca sobre fondos del backdrop (degradado ketchup → mostaza) —
  /// siempre blanco.
  static const Color onBrandGradient = Color(0xFFFFFFFF);
}
