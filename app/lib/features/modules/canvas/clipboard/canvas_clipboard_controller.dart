import 'dart:ui';

import '../../../../core/workspace/workspace_fragment.dart';
import '../../../../core/workspace/workspace_model.dart';
import '../../../../core/modules/module_registry.dart';
import '../../../../state/workspace_state.dart';

/// Clipboard boundary for canvas commands. Serialization and graph mutation
/// are kept out of the pointer/shortcut widget code.
class CanvasClipboardController {
  CanvasClipboardController(this.workspace);
  final WorkspaceController workspace;
  WorkspaceFragment? fragment;

  void copy(WorkspaceProjectSnapshot snapshot) => fragment = snapshot.fragment;

  List<WorkspaceNode> paste(
    WorkspaceFragment value,
    Offset position, {
    List<SystemModule> availableModules = const [],
  }) => workspace.pasteFragment(
    value,
    position,
    availableModules: availableModules,
  );
}

class WorkspaceProjectSnapshot {
  const WorkspaceProjectSnapshot(this.fragment);
  final WorkspaceFragment fragment;
}
