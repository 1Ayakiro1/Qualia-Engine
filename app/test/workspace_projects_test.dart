import 'dart:convert';

import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/modules/module_preview_data.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/core/workspace/workspace_project.dart';
import 'package:bci_engine/core/workspace/workspace_repository.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const module = SystemModule(
  id: 'test',
  name: 'Test',
  category: 'Test',
  description: '',
  version: '1.0.0',
);

Future<ProviderContainer> container() async {
  final value = ProviderContainer();
  value.read(workspaceProvider);
  await Future<void>.delayed(Duration.zero);
  return value;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'legacy graph migrates to first project, projects persist independently',
    () async {
      final old = WorkspaceNode(id: 'old-node', module: module);
      SharedPreferences.setMockInitialValues({
        WorkspaceController.storageKey: jsonEncode({
          'nodes': [old.toJson()],
          'links': [],
          'library': [module.toWorkspaceJson()],
        }),
      });
      var scope = await container();
      final controller = scope.read(workspaceProvider.notifier);
      expect(
        scope.read(workspaceProvider).projects.single.nodes.single.id,
        'old-node',
      );
      final second = controller.createProject(
        'Second',
        description: 'Project two',
      );
      expect(scope.read(workspaceProvider).nodes, isEmpty);
      final node = controller.addNode(module, const Offset(50, 80));
      controller.setParameter(node.id, 'gain', .7);
      controller.switchProject('default');
      expect(scope.read(workspaceProvider).nodes.single.id, 'old-node');
      controller.moveNode('old-node', const Offset(123, 456));
      controller.switchProject(second);
      expect(scope.read(workspaceProvider).nodes.single.settings['gain'], .7);
      controller.editProject(second, 'Renamed', 'New description');
      await Future<void>.delayed(const Duration(milliseconds: 380));
      scope.dispose();
      scope = await container();
      expect(scope.read(workspaceProvider).activeProject.name, 'Renamed');
      expect(scope.read(workspaceProvider).projects.length, 2);
      scope.read(workspaceProvider.notifier).switchProject('default');
      expect(
        scope.read(workspaceProvider).nodes.single.position,
        const Offset(123, 456),
      );
      scope.dispose();
    },
  );
  test('deletion preserves other projects and library, last deletion creates empty project', () async {
    final scope = await container();
    final controller = scope.read(workspaceProvider.notifier);
    controller.addToLibrary(module);
    controller.addNode(module, Offset.zero);
    final id = controller.createProject('Other');
    controller.deleteProject('default');
    expect(scope.read(workspaceProvider).activeProjectId, id);
    controller.deleteProject(id);
    expect(scope.read(workspaceProvider).activeProjectId, isNot(id));
    expect(scope.read(workspaceProvider).projects.length, 1);
    expect(scope.read(workspaceProvider).nodes, isEmpty);
    expect(scope.read(workspaceProvider).library.single.id, module.id);
    scope.dispose();
  });
  test('package imports rekey nodes and links, reject missing dependencies atomically', () async {
    final a = WorkspaceNode(id: 'a', module: module);
    final b = WorkspaceNode(id: 'b', module: module);
    a.inputLabels['input'] = 'Label';
    final source = WorkspaceProject(
      id: 'source',
      name: 'Shared',
      nodes: [a, b],
      links: [
        WorkspaceLink(
          source: 'a',
          output: 'output',
          target: 'b',
          input: 'input',
        ),
      ],
    );
    final package = WorkspaceProject.fromPackage(
      jsonDecode(jsonEncode(source.toPackage())) as Map<String, dynamic>,
    );
    final scope = await container();
    final controller = scope.read(workspaceProvider.notifier);
    expect(() => controller.importProject(package, []), throwsFormatException);
    expect(scope.read(workspaceProvider).projects.length, 1);
    controller.importProject(package, [module]);
    final first = scope.read(workspaceProvider).activeProject;
    expect(first.nodes.first.inputLabels['input'], 'Label');
    expect(first.links.single.source, first.nodes.first.id);
    controller.importProject(package, [module]);
    final second = scope.read(workspaceProvider).activeProject;
    expect(first.nodes.first.id, isNot(second.nodes.first.id));
    expect(scope.read(workspaceProvider).library.single.id, module.id);
    scope.dispose();
  });
  test('resolver trusts host previews instead of embedded manifests and requires exact versions', () async {
    final preview = previewModules.first;
    final embedded = preview.withManifest({
      'preview': true,
      'arbitrary': 'untrusted',
    });
    final project = WorkspaceProject(
      id: 'test',
      name: 'Import',
      nodes: [WorkspaceNode(id: 'node', module: embedded)],
    );
    final result = await resolveWorkspaceModules(project, []);
    expect(result.single.manifest, preview.manifest);
    expect(
      () => resolveWorkspaceModules(
        WorkspaceProject(
          id: 'missing',
          name: 'Missing',
          nodes: [WorkspaceNode(id: 'node', module: module)],
        ),
        [],
      ),
      throwsA(isA<WorkspaceDependencyException>()),
    );
  });
  test('invalid graph packages are rejected', () {
    final source = WorkspaceProject(
      id: 'test',
      name: 'Test',
      nodes: [WorkspaceNode(id: 'a', module: module)],
    );
    final package =
        jsonDecode(jsonEncode(source.toPackage())) as Map<String, dynamic>;
    (package['project'] as Map)['links'] = [
      WorkspaceLink(
        source: 'a',
        output: 'output',
        target: 'missing',
        input: 'input',
      ).toJson(),
    ];
    expect(() => WorkspaceProject.fromPackage(package), throwsFormatException);
    expect(
      () => WorkspaceProject.fromPackage({'format': 'other', 'version': 1}),
      throwsFormatException,
    );
  });
}
