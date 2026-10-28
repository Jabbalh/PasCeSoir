import 'package:flutter/material.dart';

/// Couleurs reprises de la PWA (Nuxt UI / Tailwind)
abstract final class AppColors {
  static const primary = Color(0xFF6366F1); // indigo-500
  static const secondary = Color(0xFFEC4899); // pink-500 : Environnement
  static const tertiary = Color(0xFF14B8A6); // teal-500 : Soin
  static const info = Color(0xFF3B82F6); // blue-500 : Rituel
  static const success = Color(0xFF22C55E); // green-500 : Alimentation
  static const warning = Color(0xFFEAB308);
  static const error = Color(0xFFEF4444); // red-500 : Médication

  static const background = Color(0xFF0F172A); // slate-900
  static const surface = Color(0xFF1E293B); // slate-800
  static const border = Color(0xFF334155); // slate-700
  static const accented = Color(0xFF475569); // slate-600 : réveil de type non renseigné
  static const muted = Color(0xFF94A3B8); // slate-400
}

/// Thème sombre, comme la PWA (colorMode.preference = 'dark')
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    tertiary: AppColors.tertiary,
    error: AppColors.error,
    surface: AppColors.background,
    surfaceContainer: AppColors.surface,
    outline: AppColors.border,
    onSurfaceVariant: AppColors.muted,
  );

  final radius = BorderRadius.circular(12); // --ui-radius: 0.75rem

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: radius),
      filled: true,
      fillColor: AppColors.background,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
