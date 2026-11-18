import 'dart:ui';

enum CanvasTool { select, pencil, eraser, cut, branch }

/// Pointer-session state for drawing and connection tools. Document mutations
/// remain in the workspace reducer/controller; this class only owns the live
/// gesture and therefore is safe to discard with a canvas route.
class CanvasToolController {
  CanvasTool tool = CanvasTool.select;
  int? pointer;
  List<Offset> points = const [];
  Offset? cursor;
  Offset? wireEnd;

  bool get isDrawing =>
      tool == CanvasTool.pencil || tool == CanvasTool.eraser ||
      tool == CanvasTool.cut;

  void begin(int pointerId, Offset point) {
    pointer = pointerId;
    points = [point];
  }

  void append(Offset point) {
    if (points.isEmpty || (point - points.last).distance > .5) {
      points = [...points, point];
    }
  }

  List<Offset> finish() {
    final result = points;
    pointer = null;
    points = const [];
    return result;
  }

  void cancel() {
    pointer = null;
    points = const [];
    wireEnd = null;
  }
}
