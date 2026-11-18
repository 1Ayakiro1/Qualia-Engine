import 'dart:ui';

import '../../../../core/workspace/workspace_model.dart';
import '../../../../state/workspace_state.dart';

class CanvasJunctionController {
  CanvasJunctionController(this.workspace);
  final WorkspaceController workspace;

  WorkspaceNode? insert(WorkspaceLink link, Offset position) =>
      workspace.insertJunction(link, position);
}
