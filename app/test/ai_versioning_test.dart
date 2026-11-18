import 'dart:convert';

import 'package:bci_engine/core/workspace/workspace_project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace revision survives package round-trip', () {
    const project = WorkspaceProject(
      id: 'source',
      name: 'Source',
      revision: WorkspaceRevision(
        revision: 'r1',
        kind: 'snapshot',
        packageDigest: 'digest-a',
      ),
    );
    final restored = WorkspaceProject.fromPackage(
      jsonDecode(jsonEncode(project.toPackage())) as Map<String, dynamic>,
    );
    expect(restored.revision?.revision, 'r1');
    expect(restored.revision?.packageDigest, 'digest-a');
  });

  test('legacy package without revision remains compatible', () {
    final restored = WorkspaceProject.fromPackage({
      'format': 'qualia-workspace',
      'version': 1,
      'project': {'id': 'legacy', 'name': 'Legacy', 'nodes': [], 'links': []},
    });
    expect(restored.revision, isNull);
  });

  test('fork lineage is represented without changing parent', () {
    const fork = WorkspaceRevision(
      revision: 'fork-child-123',
      parentRevision: 'r1',
      parentDigest: 'digest-b',
      kind: 'fork',
    );
    expect(fork.toJson()['parentRevision'], 'r1');
    expect(fork.toJson()['kind'], 'fork');
  });
}
