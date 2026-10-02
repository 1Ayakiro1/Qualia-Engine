import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Shared visual language of the engine shell (dark-first, minimal).
///
/// Both appearances are generated from a single [AppPalette], so Material
/// widgets (dialogs, text fields, chips) and the hand-drawn shell surfaces
/// never drift apart when the theme changes.
class AppTheme {
  const AppTheme._();

  /// Duration and curve shared by the MaterialApp theme animation and the
  /// palette cross-fade, keeping every surface in sync during a switch.
  static const Duration transitionDuration = Duration(milliseconds: 260);
  static const Curve transitionCurve = Curves.easeOutCubic;

  /// Shared hover transition: every interactive element cross-fades its
  /// hover highlight over the same short interval, so nothing snaps in.
  static const Duration hoverDuration = Duration(milliseconds: 140);
  static const Curve hoverCurve = Curves.easeOut;

  static final ThemeData _darkTheme = _build(AppPalette.dark);
  static final ThemeData _lightTheme = _build(AppPalette.light);

  static ThemeData dark() => _darkTheme;

  static ThemeData light() => _lightTheme;

  static ThemeData _build(AppPalette palette) {
    final base = ThemeData(brightness: palette.brightness, useMaterial3: true);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.text,
          brightness: palette.brightness,
        ).copyWith(
          primary: palette.text,
          onPrimary: palette.background,
          secondary: palette.mutedText,
          onSecondary: palette.background,
          surface: palette.panel,
          onSurface: palette.text,
          onSurfaceVariant: palette.mutedText,
          surfaceContainerLowest: palette.background,
          surfaceContainerLow: palette.panel,
          surfaceContainer: palette.panel,
          surfaceContainerHigh: palette.panel,
          surfaceContainerHighest: palette.panel,
          outline: palette.hover,
          outlineVariant: palette.hover,
          inverseSurface: palette.panel,
          onInverseSurface: palette.text,
        );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      dividerColor: palette.hover,
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(3),
        radius: const Radius.circular(3),
        trackVisibility: const WidgetStatePropertyAll(false),
        thumbColor: WidgetStatePropertyAll(palette.mutedText.withAlpha(100)),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: palette.text,
        displayColor: palette.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 36,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        titleTextStyle: TextStyle(
          color: palette.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: palette.text, fontSize: 14),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.background,
        selectedIconTheme: IconThemeData(color: palette.text),
        selectedLabelTextStyle: TextStyle(color: palette.text),
        indicatorColor: palette.panel,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.panel,
        labelStyle: TextStyle(color: palette.text),
      ),
      inputDecorationTheme: InputDecorationTheme(
        // Borderless filled fields: the fill contrast replaces outlines.
        filled: true,
        fillColor: palette.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        hintStyle: TextStyle(color: palette.mutedText, fontSize: 12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.text,
        selectionColor: palette.text.withAlpha(60),
        selectionHandleColor: palette.text,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(seconds: 1),
        showDuration: const Duration(seconds: 4),
        textStyle: TextStyle(color: palette.text, fontSize: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
