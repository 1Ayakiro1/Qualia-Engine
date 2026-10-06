import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/workspace/workspace_model.dart';
import 'workspace_colors.dart';

/// A connection inherits endpoint colors; uncolored endpoints stay neutral.
/// The gradient is anchored to actual ports, including reversed/vertical edges.
Paint workspaceConnectionPaint(
  Offset from,
  Offset to,
  Color output,
  Color input,
) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 2
    ..color = output;
  if (output != input && (to - from).distanceSquared > .001) {
    paint.shader = ui.Gradient.linear(from, to, [output, input]);
  }
  return paint;
}

void paintWorkspaceConnection(
  Canvas canvas,
  Offset from,
  Offset to,
  Color output,
  Color input,
) {
  final dx = math.max(60.0, (to.dx - from.dx).abs() * .45);
  canvas.drawPath(
    Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx + dx, from.dy, to.dx - dx, to.dy, to.dx, to.dy),
    workspaceConnectionPaint(from, to, output, input),
  );
}

class WorkspaceConnectionsPainter extends CustomPainter {
  const WorkspaceConnectionsPainter({
    required this.nodes,
    required this.links,
    required this.neutral,
    this.pendingNode,
    this.pendingPort,
    this.pendingOutput = false,
    this.wireEnd,
    this.dimmedModuleIds = const {},
  });
  final List<WorkspaceNode> nodes;
  final List<WorkspaceLink> links;
  final Color neutral;
  final String? pendingNode;
  final String? pendingPort;
  final bool pendingOutput;
  final Offset? wireEnd;
  final Set<String> dimmedModuleIds;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final node in nodes) node.id: node};
    for (final link in links) {
      final source = byId[link.source];
      final target = byId[link.target];
      if (source == null || target == null) continue;
      final dimmed =
          dimmedModuleIds.contains(source.module.id) ||
          dimmedModuleIds.contains(target.module.id);
      paintWorkspaceConnection(
        canvas,
        source.portPosition(link.output, true),
        target.portPosition(link.input, false),
        (source.portColor(link.output, true).tint ?? neutral).withAlpha(
          dimmed ? 70 : 255,
        ),
        (target.portColor(link.input, false).tint ?? neutral).withAlpha(
          dimmed ? 70 : 255,
        ),
      );
    }
    final node = byId[pendingNode];
    if (node != null && pendingPort != null && wireEnd != null) {
      final port = node.portPosition(pendingPort!, pendingOutput);
      final tint = node.portColor(pendingPort!, pendingOutput).tint ?? neutral;
      paintWorkspaceConnection(
        canvas,
        pendingOutput ? port : wireEnd!,
        pendingOutput ? wireEnd! : port,
        (pendingOutput ? tint : neutral).withAlpha(130),
        (pendingOutput ? neutral : tint).withAlpha(130),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WorkspaceConnectionsPainter oldDelegate) => true;
}
