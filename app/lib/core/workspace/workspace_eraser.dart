import 'dart:math' as math;
import 'dart:ui';

import 'workspace_id.dart';
import 'workspace_model.dart';

/// Subtract a swept circular eraser from polylines in scene coordinates.
/// Returns original objects for untouched strokes (including their IDs).
List<WorkspaceAnnotation> eraseWorkspaceAnnotations(
  List<WorkspaceAnnotation> annotations,
  Offset from,
  Offset to,
  double diameter,
) {
  if (!diameter.isFinite || diameter <= 0) return annotations;
  final result = <WorkspaceAnnotation>[];
  for (final annotation in annotations) {
    final radius = (diameter + annotation.width) / 2;
    final fragments = <List<Offset>>[];
    var current = <Offset>[];
    var changed = false;
    void flush() {
      if (current.isNotEmpty) fragments.add(current);
      current = [];
    }

    final points = annotation.points;
    if (points.isEmpty) {
      result.add(annotation);
      continue;
    }
    // Single-point annotations are round brush dots.
    for (var i = 0; i < math.max(1, points.length - 1); i++) {
      final a = points[i];
      final b = points[math.min(i + 1, points.length - 1)];
      final cuts = _capsuleIntervals(a, b, from, to, radius);
      if (cuts.isEmpty) {
        if (current.isEmpty) current.add(a);
        if (current.last != b) current.add(b);
        continue;
      }
      changed = true;
      var start = 0.0;
      for (final cut in cuts) {
        if (cut.$1 > start + 1e-9) {
          if (current.isEmpty) current.add(Offset.lerp(a, b, start)!);
          current.add(Offset.lerp(a, b, cut.$1)!);
        }
        flush();
        start = math.max(start, cut.$2);
      }
      if (start < 1 - 1e-9) {
        current = [Offset.lerp(a, b, start)!, b];
      }
    }
    flush();
    if (!changed) {
      result.add(annotation);
      continue;
    }
    for (var i = 0; i < fragments.length; i++) {
      result.add(
        WorkspaceAnnotation(
          id: i == 0 ? annotation.id : WorkspaceId.create('annotation'),
          points: fragments[i],
          color: annotation.color,
          width: annotation.width,
        ),
      );
    }
  }
  return result;
}

/// Intersections of AB with the capsule: two circles plus a finite strip.
List<(double, double)> _capsuleIntervals(
  Offset a,
  Offset b,
  Offset from,
  Offset to,
  double radius,
) {
  final delta = b - a;
  final intervals = <(double, double)>[];
  void add(double lo, double hi) {
    lo = math.max(0, lo);
    hi = math.min(1, hi);
    if (lo <= hi) intervals.add((lo, hi));
  }

  for (final center in [from, to]) {
    final p = a - center;
    final aa = delta.distanceSquared;
    final cc = p.distanceSquared - radius * radius;
    if (aa == 0) {
      if (cc <= 0) add(0, 1);
      continue;
    }
    final bb = 2 * (p.dx * delta.dx + p.dy * delta.dy);
    final discriminant = bb * bb - 4 * aa * cc;
    if (discriminant < 0) continue;
    final root = math.sqrt(discriminant);
    add((-bb - root) / (2 * aa), (-bb + root) / (2 * aa));
  }
  final axis = to - from;
  final length = axis.distance;
  if (length > 0) {
    final unit = axis / length;
    final normal = Offset(-unit.dy, unit.dx);
    double dot(Offset p, Offset q) => p.dx * q.dx + p.dy * q.dy;
    var lo = 0.0;
    var hi = 1.0;
    for (final slab in [(unit, 0.0, length), (normal, -radius, radius)]) {
      final origin = dot(a - from, slab.$1);
      final direction = dot(delta, slab.$1);
      if (direction.abs() < 1e-12) {
        if (origin < slab.$2 || origin > slab.$3) hi = -1;
      } else {
        final x = (slab.$2 - origin) / direction;
        final y = (slab.$3 - origin) / direction;
        lo = math.max(lo, math.min(x, y));
        hi = math.min(hi, math.max(x, y));
      }
    }
    add(lo, hi);
  }
  intervals.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(double, double)>[];
  for (final interval in intervals) {
    if (merged.isNotEmpty && interval.$1 <= merged.last.$2) {
      merged[merged.length - 1] = (
        merged.last.$1,
        math.max(merged.last.$2, interval.$2),
      );
    } else {
      merged.add(interval);
    }
  }
  return merged;
}
