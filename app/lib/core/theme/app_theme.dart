import 'package:flutter/material.dart';

/// Shared visual language of the engine shell (dark-first, minimal).
class AppTheme {
  const AppTheme._();

  static const Color background = Color(0xFF141414);
  static const Color panel = Color(0xFF181818);
  static const Color border = Color(0xFF272727);
  static const Color text = Color(0xFFBDBDBD);
  static const Color mutedText = Color(0xFF858585);
  static const Color accent = text;
  static const Color accentSecondary = text;

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: text,
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? background : null,
      canvasColor: dark ? background : null,
      dividerColor: dark ? border : null,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? background : scheme.surface,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 36,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? panel : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: dark ? border : scheme.outlineVariant.withAlpha(80),
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? background : scheme.surface,
        selectedIconTheme: const IconThemeData(color: text),
        selectedLabelTextStyle: const TextStyle(color: text),
        indicatorColor: panel,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant.withAlpha(80)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dark ? border : scheme.outline),
        ),
        isDense: true,
        hintStyle: TextStyle(color: dark ? mutedText : null, fontSize: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
