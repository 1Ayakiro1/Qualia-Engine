/// Nested dot layers retain their world-space positions while zooming.
/// Only the intermediate dots fade; coarse anchor dots always stay visible.
class WorkspaceGridLevel {
  const WorkspaceGridLevel(this.spacing, this.fadeStart, this.fadeEnd);
  final double spacing;
  final double fadeStart;
  final double fadeEnd;

  static const levels = [
    WorkspaceGridLevel(96, 0, 0),
    WorkspaceGridLevel(48, .35, .65),
    WorkspaceGridLevel(24, .75, 1.25),
  ];

  double opacity(double scale) {
    if (fadeEnd == fadeStart) return 1;
    final t = ((scale - fadeStart) / (fadeEnd - fadeStart)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}
