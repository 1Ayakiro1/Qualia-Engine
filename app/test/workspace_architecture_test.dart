import 'package:bci_engine/core/workspace/workspace_document_schema.dart';
import 'package:bci_engine/state/workspace_providers.dart';
import 'package:bci_engine/state/workspace_reducer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('workspace documents are upgraded to an explicit schema version', () {
    final document = WorkspaceDocumentSchema.decode({'projects': []});
    expect(document['schemaVersion'], WorkspaceDocumentSchema.currentVersion);
    expect(
      WorkspaceDocumentSchema.decode(WorkspaceDocumentSchema.encode(document)),
      document,
    );
  });

  test('mutation journal keeps bounded reducer events', () {
    final journal = WorkspaceMutationJournal(maxLength: 2);
    journal.record('{}');
    journal.record('{"value":1}', kind: WorkspaceMutationKind.annotation);
    journal.record('{"value":2}');
    expect(journal.entries, hasLength(2));
    expect(journal.entries.first.revision, 2);
    expect(journal.entries.last.kind, WorkspaceMutationKind.document);
  });

  test('selection controller is UI state and does not mutate documents', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(selectionProvider.notifier);
    expect(container.read(selectionProvider), const SelectionState());
    controller.replace(['node-a', 'node-b'], primaryId: 'node-b');
    expect(controller.state.ids, {'node-a', 'node-b'});
    expect(controller.state.primaryId, 'node-b');
    controller.toggle('node-a');
    expect(controller.state.ids, {'node-b'});
  });
}
