import 'package:flutter/foundation.dart';

/// Geometry of the shell regions.
///
/// The shell keeps this separate from the widgets so future layout presets,
/// drag handles and persisted user arrangements can reuse the same model.
@immutable
class ShellLayoutConfig {
  const ShellLayoutConfig({
    required this.railWidth,
    required this.explorerWidth,
    required this.gap,
    required this.radius,
  });

  const ShellLayoutConfig.defaults()
    : railWidth = 48,
      explorerWidth = 280,
      gap = 6,
      radius = 10;

  final double railWidth;
  final double explorerWidth;
  final double gap;
  final double radius;

  ShellLayoutConfig copyWith({
    double? railWidth,
    double? explorerWidth,
    double? gap,
    double? radius,
  }) {
    return ShellLayoutConfig(
      railWidth: railWidth ?? this.railWidth,
      explorerWidth: explorerWidth ?? this.explorerWidth,
      gap: gap ?? this.gap,
      radius: radius ?? this.radius,
    );
  }
}
