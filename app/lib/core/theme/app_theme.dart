import 'package:flutter/material.dart';

/// Shared visual language of the engine shell (dark-first, minimal).
class AppTheme {
  const AppTheme._();

  static const Color accent = Color(0xFF61B5FF);
  static const Color accentSecondary = Color(0xFF8ABEFF);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF1E1E1E) : null,
      canvasColor: dark ? const Color(0xFF1E1E1E) : null,
      dividerColor: dark ? const Color(0xFF3C3C3C) : null,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: const Color(0xFFE5E5E5),
        displayColor: const Color(0xFFE5E5E5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF121212) : scheme.surface,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 36,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF242424) : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: dark ? const Color(0xFF3C3C3C) : scheme.outlineVariant.withAlpha(80)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? const Color(0xFF121212) : scheme.surface,
        selectedIconTheme: const IconThemeData(color: accent),
        selectedLabelTextStyle: const TextStyle(color: accent),
        indicatorColor: accent.withAlpha(36),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant.withAlpha(80)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        hintStyle: TextStyle(color: dark ? Colors.white38 : null, fontSize: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
