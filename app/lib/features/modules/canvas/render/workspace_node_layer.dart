import 'package:flutter/material.dart';

import '../../../../core/workspace/workspace_model.dart';

/// Rendering boundary for node instances. The layer owns only composition;
/// node interaction/card details stay in the node widget supplied by the
/// caller. This lets the canvas later switch to viewport virtualization
/// without changing the document or pointer controllers.
class WorkspaceNodeLayer extends StatelessWidget {
  const WorkspaceNodeLayer({
    super.key,
    required this.nodes,
    required this.builder,
  });

  final List<WorkspaceNode> nodes;
  final Widget Function(BuildContext context, WorkspaceNode node) builder;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [for (final node in nodes) builder(context, node)],
  );
}
