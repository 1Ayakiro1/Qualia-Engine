import 'package:flutter/material.dart';

/// Semantic color tokens of the engine shell.
///
/// Every surface resolves colors through a palette instead of hard-coded
/// constants. Two palettes exist — [AppPalette.dark] (default) and
/// [AppPalette.light] — and both are built from the same neutral ramp, so the
/// white appearance keeps the exact hierarchy of the dark one: panel lighter
/// than background, muted text one step quieter than primary text.
///
/// The palettes are deliberately borderless: structure comes from the
/// background/panel contrast, overlay shadows and spacing, never from
/// stroked outlines.
@immutable
class AppPalette {
  const AppPalette._({
    required this.brightness,
    required this.background,
    required this.panel,
    required this.hover,
    required this.text,
    required this.mutedText,
  });

  /// Dark-first neutral appearance — the default look of the engine.
  static const AppPalette dark = AppPalette._(
    brightness: Brightness.dark,
    background: Color(0xFF141414),
    panel: Color(0xFF181818),
    hover: Color(0xFF242424),
    text: Color(0xFFBDBDBD),
    mutedText: Color(0xFF858585),
  );

  /// White appearance mirrored from [dark]: same roles, inverted ramp.
  /// The hover tint stays close to the surfaces so the highlight reads as
  /// a gentle lift instead of a hard block.
  static const AppPalette light = AppPalette._(
    brightness: Brightness.light,
    background: Color(0xFFF3F3F4),
    panel: Color(0xFFFFFFFF),
    hover: Color(0xFFECECEE),
    text: Color(0xFF303034),
    mutedText: Color(0xFF7B7B82),
  );

  /// Which appearance this palette renders.
  final Brightness brightness;

  /// Base canvas behind every pane (window background, tab strips).
  final Color background;

  /// Recessed search surface, slightly darker than the surrounding chrome.
  Color get searchField => Color.alphaBlend(
    Colors.black.withValues(alpha: isDark ? .18 : .04),
    background,
  );

  /// Raised surface: cards, menus, tooltips, inspectors.
  final Color panel;

  /// Shared hover tint of every interactive element.
  ///
  /// Resting elements fade this color with alpha zero, so the hover
  /// transition interpolates alpha only — never through translucent black,
  /// which used to make light-theme highlights flash muddy.
  final Color hover;

  /// Primary foreground color.
  final Color text;

  /// Secondary foreground color (hints, subtitles, disabled states).
  final Color mutedText;

  /// The engine's accent is intentionally text-colored: interaction states
  /// stay monochrome in both appearances.
  Color get accent => text;

  bool get isDark => brightness == Brightness.dark;

  /// Interpolates every token. This is what the animated theme switch
  /// renders, so all surfaces cross-fade together instead of snapping.
  AppPalette lerpTo(AppPalette to, double t) => AppPalette._(
    brightness: t < 0.5 ? brightness : to.brightness,
    background: Color.lerp(background, to.background, t)!,
    panel: Color.lerp(panel, to.panel, t)!,
    hover: Color.lerp(hover, to.hover, t)!,
    text: Color.lerp(text, to.text, t)!,
    mutedText: Color.lerp(mutedText, to.mutedText, t)!,
  );
}

/// Provides the live [AppPalette] to the whole tree.
///
/// The scope sits above the Navigator inside `MaterialApp.builder`, so shell
/// surfaces, dialogs, tooltips and overlay menus all resolve the same palette
/// — including mid-animation frames while the theme cross-fades.
class AppThemeScope extends InheritedWidget {
  const AppThemeScope({super.key, required this.palette, required super.child});

  final AppPalette palette;

  static AppPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()!.palette;

  @override
  bool updateShouldNotify(AppThemeScope oldWidget) =>
      oldWidget.palette != palette;
}

extension AppPaletteContext on BuildContext {
  /// Shorthand for [AppThemeScope.of].
  AppPalette get palette => AppThemeScope.of(this);
}
