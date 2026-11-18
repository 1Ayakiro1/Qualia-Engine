import 'package:flutter/material.dart';

import '../../../../core/workspace/workspace_model.dart';

/// One painter for all annotations, including the live gesture preview.
class WorkspaceAnnotationLayerPainter extends CustomPainter {
  const WorkspaceAnnotationLayerPainter({
    required this.annotations,
    this.activePoints = const [],
    required this.activeColor,
    required this.activeWidth,
    this.cursor,
    this.cursorDiameter = 3,
    this.cursorColor = const Color(0xFFE7E7E7),
  });

  final List<WorkspaceAnnotation> annotations;
  final List<Offset> activePoints;
  final Color activeColor;
  final double activeWidth;
  final Offset? cursor;
  final double cursorDiameter;
  final Color cursorColor;

  @override
  void paint(Canvas canvas, Size size) {
    void stroke(List<Offset> points, Color color, double width) {
      if (points.isEmpty) return;
      if (points.length == 1) {
        canvas.drawCircle(points.first, width / 2, Paint()..color = color);
        return;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (final annotation in annotations) {
      stroke(annotation.points, Color(annotation.color), annotation.width);
    }
    stroke(activePoints, activeColor, activeWidth);
    if (cursor case final point?) {
      canvas.drawCircle(
        point,
        cursorDiameter / 2,
        Paint()
          ..color = cursorColor.withAlpha(180)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WorkspaceAnnotationLayerPainter oldDelegate) =>
      oldDelegate.annotations != annotations ||
      oldDelegate.activePoints != activePoints ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.activeWidth != activeWidth ||
      oldDelegate.cursor != cursor ||
      oldDelegate.cursorDiameter != cursorDiameter ||
      oldDelegate.cursorColor != cursorColor;
}
