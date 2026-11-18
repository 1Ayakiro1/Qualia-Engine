import 'dart:convert';

/// Mutation journal shared by document undo and future sync adapters.
enum WorkspaceMutationKind {
  document,
  selection,
  annotation,
  project,
  runtime,
}

class WorkspaceMutation {
  const WorkspaceMutation({
    required this.kind,
    required this.revision,
    required this._document,
  }) : _snapshot = null;

  const WorkspaceMutation.snapshot({
    required this.kind,
    required this.revision,
    required this._snapshot,
  }) : _document = null;

  final WorkspaceMutationKind kind;
  final int revision;
  final String? _document;
  final Map<String, dynamic>? _snapshot;
  String get document => _document ?? jsonEncode(_snapshot);

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'revision': revision,
    'document': _snapshot ?? jsonDecode(document),
  };
}

class WorkspaceMutationJournal {
  WorkspaceMutationJournal({this.maxLength = 100});
  final int maxLength;
  final List<WorkspaceMutation> _entries = [];
  int _revision = 0;

  List<WorkspaceMutation> get entries => List.unmodifiable(_entries);
  int get revision => _revision;

  WorkspaceMutation record(
    String document, {
    WorkspaceMutationKind kind = WorkspaceMutationKind.document,
  }) {
    final mutation = WorkspaceMutation(
      kind: kind,
      revision: ++_revision,
      document: document,
    );
    _entries.add(mutation);
    if (_entries.length > maxLength) _entries.removeAt(0);
    return mutation;
  }

  WorkspaceMutation recordSnapshot(Map<String, dynamic> snapshot) {
    final mutation = WorkspaceMutation.snapshot(
      kind: WorkspaceMutationKind.document,
      revision: ++_revision,
      snapshot: snapshot,
    );
    _entries.add(mutation);
    if (_entries.length > maxLength) _entries.removeAt(0);
    return mutation;
  }

  void clear() {
    _entries.clear();
    _revision = 0;
  }
}
