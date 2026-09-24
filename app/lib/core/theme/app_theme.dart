import 'package:flutter/material.dart';

/// Shared visual language of the engine shell (dark-first, minimal).
class AppTheme {
  const AppTheme._();

  static const Color accent = Color(0xFF7C9CFF);
  static const Color accentSecondary = Color(0xFFA78BFA);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? const Color(0xFF0B0F1A) : null,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant.withAlpha(80)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
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
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
