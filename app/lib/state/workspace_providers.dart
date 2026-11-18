import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/workspace/workspace_model.dart';
import 'workspace_state.dart';

/// Read models keep screens from depending on the complete workspace state.
final documentProvider = Provider<WorkspaceState>(
  (ref) => ref.watch(workspaceProvider),
);

final projectProvider = Provider((ref) {
  final document = ref.watch(documentProvider);
  return document.activeProject;
});

final annotationProvider = Provider<List<WorkspaceAnnotation>>(
  (ref) => ref.watch(projectProvider).annotations,
);

final workspaceNodesProvider = Provider<List<WorkspaceNode>>(
  (ref) => ref.watch(projectProvider).nodes,
);

final workspaceLinksProvider = Provider<List<WorkspaceLink>>(
  (ref) => ref.watch(projectProvider).links,
);

class SelectionState {
  const SelectionState({this.ids = const {}, this.primaryId});
  final Set<String> ids;
  final String? primaryId;
  SelectionState copyWith({Set<String>? ids, String? primaryId}) =>
      SelectionState(
        ids: Set.unmodifiable(ids ?? this.ids),
        primaryId: primaryId,
      );
}

/// UI-only selection. It intentionally does not participate in document
/// persistence or undo history.
class SelectionController extends Notifier<SelectionState> {
  @override
  SelectionState build() => const SelectionState();

  void replace(Iterable<String> ids, {String? primaryId}) {
    state = SelectionState(
      ids: ids.toSet(),
      primaryId: primaryId,
    );
  }

  void clear() => state = const SelectionState();
  void toggle(String id) {
    final ids = {...state.ids};
    if (!ids.remove(id)) ids.add(id);
    state = SelectionState(ids: ids, primaryId: ids.contains(id) ? id : null);
  }
}

final selectionProvider = NotifierProvider<SelectionController, SelectionState>(
  SelectionController.new,
);
