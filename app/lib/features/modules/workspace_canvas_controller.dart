import 'package:flutter/foundation.dart';

import '../../core/logic/logic_blocks.dart';
import '../../core/modules/module_registry.dart';
import '../../core/workspace/workspace_model.dart';

/// Commands shared by the scene pane and its canvas. All targets are instances.
class WorkspaceCanvasController {
  /// Selection lives in `selectionProvider`. This bridge is intentionally
  /// command-only; older embedders can keep constructing the controller while
  /// screens no longer store a second ValueNotifier selection state here.
  void Function(WorkspaceNode node, bool toggle)? selectFromScene;
  VoidCallback? addModule;
  ValueChanged<SystemModule>? insertModule;
  void Function(LogicBlockType)? addLogic;
  void Function(WorkspaceNode)? open;
  void Function(WorkspaceNode)? detach;
  void Function(WorkspaceNode)? fullscreen;
  void Function(WorkspaceNode)? copy;
  void Function(WorkspaceNode)? cut;

  void clear() {
    addModule = null;
    insertModule = null;
    addLogic = null;
    open = null;
    detach = null;
    fullscreen = null;
    copy = null;
    cut = null;
    selectFromScene = null;
  }
}
