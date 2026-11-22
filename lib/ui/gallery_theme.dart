import 'package:flutter/material.dart';

/// Gallery Drift's owned visual language. Image content remains the hero:
/// neutral cinematic surfaces, a single warm accent and low-motion controls.
abstract final class GalleryTheme {
  static const background = Color(0xFF0D1016);
  static const surface = Color(0xFF1D222D);
  static const accent = Color(0xFFEBD6B8);
  static const muted = Color(0xFF929AAB);

  static ThemeData build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent, brightness: Brightness.dark,
      surface: background, primary: accent,
    );
    final radius = BorderRadius.circular(18);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      appBarTheme: const AppBarThemeData(
        backgroundColor: background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 23, fontWeight: FontWeight.w650,
          letterSpacing: -0.6),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
          letterSpacing: -0.2)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: background, backgroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: radius))),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: Color(0xFF454B55)),
          shape: RoundedRectangleBorder(borderRadius: radius))),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xD3222832),
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)))),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: radius),
        behavior: SnackBarBehavior.floating),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: radius)),
      dividerColor: const Color(0xFF343A46),
    );
  }
}
