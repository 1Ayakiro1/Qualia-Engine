import 'dart:convert';
import 'dart:io';

import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/modules/module_preview_data.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/core/workspace/workspace_archive.dart';
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
      annotations: const [
        WorkspaceAnnotation(
          id: 'annotation-1',
          points: [Offset(10, 20), Offset(30, 40)],
          color: 0xFF00FF00,
          width: 5,
        ),
      ],
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
    expect(first.annotations.single.id, 'annotation-1');
    expect(first.annotations.single.points, const [
      Offset(10, 20),
      Offset(30, 40),
    ]);
    expect(first.annotations.single.color, 0xFF00FF00);
    expect(first.annotations.single.width, 5);
    controller.importProject(package, [module]);
    final second = scope.read(workspaceProvider).activeProject;
    expect(first.nodes.first.id, isNot(second.nodes.first.id));
    expect(scope.read(workspaceProvider).library.single.id, module.id);
    scope.dispose();
  });
  test('custom canvas dimensions round-trip without changing graph data', () {
    final source = WorkspaceProject(
      id: 'sized',
      name: 'Sized',
      canvasWidth: 24000,
      canvasHeight: 18000,
    );
    final restored = WorkspaceProject.fromPackage(
      jsonDecode(jsonEncode(source.toPackage())) as Map<String, dynamic>,
    );
    expect(restored.canvasWidth, 24000);
    expect(restored.canvasHeight, 18000);
    expect(restored.nodes, isEmpty);
    expect(restored.links, isEmpty);
    expect(
      () => WorkspaceProject.fromJson({
        'id': 'bad',
        'name': 'Bad',
        'canvasWidth': 100,
      }),
      throwsFormatException,
    );
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

  test(
    'portable workspace archive keeps graph entities and instance variables',
    () async {
      final node = WorkspaceNode(
        id: 'entity-1',
        module: module,
        settings: {'gain': .75, 'enabled': true},
      );
      final source = WorkspaceProject(
        id: 'portable',
        name: 'Portable workspace',
        nodes: [node],
      );
      final bytes = WorkspaceArchive.encode(
        source,
        hiddenNodeIds: {'entity-1'},
        hiddenModuleIds: {'test'},
        moduleActiveOverrides: {'test': false},
        removedModuleIds: {'removed'},
        showLogicBlocks: false,
        showModuleBlocks: false,
      );
      expect(WorkspaceArchive.looksLikeArchive(bytes), isTrue);
      final restored = WorkspaceArchive.decodeContents(bytes);
      expect(restored.project.id, source.id);
      expect(restored.project.nodes.single.id, node.id);
      expect(restored.project.nodes.single.settings, {
        'gain': .75,
        'enabled': true,
      });
      expect(restored.hiddenNodeIds, {'entity-1'});
      expect(restored.hiddenModuleIds, {'test'});
      expect(restored.moduleActiveOverrides, {'test': false});
      expect(restored.removedModuleIds, {'removed'});
      expect(restored.showLogicBlocks, isFalse);
      expect(restored.showModuleBlocks, isFalse);
      final root = await Directory.systemTemp.createTemp('qualia-workspace-');
      addTearDown(() => root.delete(recursive: true));
      final folder = Directory('${root.path}/Portable.qualia-workspace');
      await WorkspaceArchive.writeDirectory(
        folder,
        source,
        hiddenNodeIds: {'entity-1'},
        showLogicBlocks: false,
      );
      final fromFolder = await WorkspaceArchive.decodeDirectoryContents(folder);
      expect(fromFolder.project.nodes.single.settings['gain'], .75);
      expect(fromFolder.hiddenNodeIds, {'entity-1'});
      expect(fromFolder.showLogicBlocks, isFalse);
    },
  );

  test(
    'portable visibility state follows rekeyed imported instances',
    () async {
      final source = WorkspaceProject(
        id: 'portable-state',
        name: 'Portable state',
        nodes: [WorkspaceNode(id: 'source-node', module: module)],
      );
      final contents = WorkspaceArchive.decodeContents(
        WorkspaceArchive.encode(
          source,
          hiddenNodeIds: {'source-node'},
          moduleActiveOverrides: {'test': false},
          showModuleBlocks: false,
        ),
      );
      final scope = await container();
      addTearDown(scope.dispose);
      final controller = scope.read(workspaceProvider.notifier);
      controller.importProject(
        contents.project,
        [module],
        hiddenNodeIds: contents.hiddenNodeIds,
        moduleActiveOverrides: contents.moduleActiveOverrides,
        showModuleBlocks: contents.showModuleBlocks,
      );
      final state = scope.read(workspaceProvider);
      expect(state.hiddenNodeIds, {state.nodes.single.id});
      expect(state.moduleActiveOverrides, {'test': false});
      expect(state.showModuleBlocks, isFalse);
    },
  );

  test('workspace folder is restored as the next startup document', () async {
    final root = await Directory.systemTemp.createTemp('qualia-workspace-');
    addTearDown(() => root.delete(recursive: true));
    final folder = Directory('${root.path}/Saved.qualia-workspace');
    final scope = await container();
    final controller = scope.read(workspaceProvider.notifier);
    final node = controller.addNode(module, const Offset(18, 24));
    controller.setParameter(node.id, 'gain', .42);
    await controller.saveWorkspaceDirectory(folder.path);
    expect(controller.workspaceDirectoryPath, folder.path);
    scope.dispose();

    final restored = await container();
    addTearDown(restored.dispose);
    expect(
      restored.read(workspaceProvider).activeProject.nodes.single.position,
      const Offset(18, 24),
    );
    expect(restored.read(workspaceProvider).nodes.single.settings['gain'], .42);
  });
}
