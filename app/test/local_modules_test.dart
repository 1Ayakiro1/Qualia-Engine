import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bci_engine/core/modules/local_module_store.dart';
import 'package:bci_engine/core/modules/module_runtime.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/workspace/workspace_project.dart';
import 'package:bci_engine/core/workspace/workspace_repository.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late LocalModuleStore store;
  late List<int> package;
  setUpAll(() async {
    temporary = await Directory('/tmp/opencode').createTemp('qualia-sdk-test-');
    store = LocalModuleStore(root: Directory('${temporary.path}/installed'));
    final result = await Process.run('python3', [
      'assets/module_sdk/qmod.py',
      'create',
      '${temporary.path}/project',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final build = await Process.run('python3', [
      '${temporary.path}/project/qmod.py',
      'build',
      '${temporary.path}/project',
    ]);
    expect(build.exitCode, 0, reason: '${build.stderr}');
    package = await File('${temporary.path}/project/dist/local-gain-0.1.0.qmod')
        .readAsBytes();
  });
  tearDownAll(() => temporary.delete(recursive: true));

  test(
    'offline SDK creates a real executable and immutable installation',
    () async {
      final module = await store.install(package);
      final again = await store.install(package);
      expect(module.localPackage, again.localPackage);
      expect(module.databaseId, isNull);
      expect(module.reviewState, 'local');
      expect(await File(await store.executable(module)).exists(), isTrue);
    },
  );

  test(
    'package rejects traversal, duplicate entries, links and compressed ZIP',
    () {
      List<int> zip(String name, {bool compressed = false, bool link = false}) {
        final archive = Archive();
        final entry = ArchiveFile(name, 3, [1, 2, 3]);
        entry.compress = compressed;
        entry.mode = link ? 0xA000 : 0x8000;
        archive.addFile(entry);
        return ZipEncoder().encode(archive)!;
      }

      for (final name in [
        '../escape',
        '/absolute',
        'a/../../escape',
        'a\\escape',
        'a:b',
      ]) {
        expect(
          () => LocalModuleStore.validateArchive(zip(name)),
          throwsFormatException,
        );
      }
      expect(
        () => LocalModuleStore.validateArchive(zip('link', link: true)),
        throwsFormatException,
      );
      expect(
        () => LocalModuleStore.validateArchive(
          zip('compressed', compressed: true),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'two C++ processes route ports, isolate state, and stop at project switch',
    () async {
      final module = await store.install(package);
      final updates = <String, Map<String, dynamic>>{};
      final statuses = <String, String>{};
      final processes = <Process>[];
      final runtime = ModuleRuntime(
        store: store,
        launch: (executable, directory) async {
          final process = await Process.start(
            executable,
            [],
            workingDirectory: directory,
          );
          processes.add(process);
          return process;
        },
        onUpdate: (id, status, values) {
          statuses[id] = status;
          updates[id] = {...?updates[id], ...values};
        },
      );
      addTearDown(runtime.dispose);
      final first = WorkspaceNode(
        id: 'first',
        module: module,
        settings: {'gain': 2, 'sample': 3},
      );
      final second = WorkspaceNode(
        id: 'second',
        module: module,
        settings: {'gain': 4},
      );
      final links = [
        const WorkspaceLink(
          source: 'first',
          output: 'output',
          target: 'second',
          input: 'input',
        ),
      ];
      runtime.sync('workspace-a', [first, second], links, [module]);
      Future<void> wait(bool Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (!condition()) {
          if (DateTime.now().isAfter(deadline)) {
            fail('Runtime timeout: $statuses $updates');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      await wait(
        () => statuses['first'] == 'running' && statuses['second'] == 'running',
      );
      runtime.event('first', 'run', true);
      expect(processes.length, 2);
      expect(processes[0].pid, isNot(processes[1].pid));
      await wait(() => updates['second']?['result'] == 24);
      expect(updates['first']?['result'], 6);
      first.settings['gain'] = 5;
      runtime.sync('workspace-a', [first, second], links, [module]);
      runtime.event('first', 'run', true);
      await wait(() => updates['second']?['result'] == 60);
      runtime.sync('workspace-b', [], [], [module]);
      await Future.wait(processes.map((p) => p.exitCode))
          .timeout(const Duration(seconds: 3));
      runtime.event('first', 'run', true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(updates['second']?['result'], 60);
    },
  );

  test('workspace metadata alone never authorizes native execution', () async {
    final module = await store.install(package);
    final statuses = <String>[];
    final runtime = ModuleRuntime(
      store: store,
      onUpdate: (_, status, _) => statuses.add(status),
    );
    addTearDown(runtime.dispose);
    runtime.sync(
      'untrusted',
      [WorkspaceNode(id: 'embedded', module: module)],
      [],
      [],
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(statuses, isEmpty);
  });

  test(
    'crashing instance does not kill its sibling or automatically respawn',
    () async {
      final module = await store.install(package);
      final processes = <Process>[];
      final statuses = <String, String>{};
      final runtime = ModuleRuntime(
        store: store,
        onUpdate: (id, status, _) => statuses[id] = status,
        launch: (executable, directory) async {
          final process = await Process.start(
            executable,
            [],
            workingDirectory: directory,
          );
          processes.add(process);
          return process;
        },
      );
      addTearDown(runtime.dispose);
      final nodes = [
        WorkspaceNode(id: 'a', module: module),
        WorkspaceNode(id: 'b', module: module),
      ];
      runtime.sync('project', nodes, [], [module]);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (statuses['a'] != 'running' || statuses['b'] != 'running') {
        if (DateTime.now().isAfter(deadline)) fail('Handshake timeout');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      processes.first.kill(ProcessSignal.sigkill);
      await processes.first.exitCode;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(statuses['a'], startsWith('exited'));
      expect(statuses['b'], 'running');
      runtime.sync('project', nodes, [], [module]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(processes.length, 2);
      runtime.dispose();
      await processes.last.exitCode.timeout(const Duration(seconds: 3));
    },
  );

  test('runtime values are transient but sent to module windows', () async {
    final module = await store.install(package);
    final node = WorkspaceNode(id: 'view', module: module);
    node.runtimeValues['result'] = 10;
    node.runtimeStatus = 'running';
    expect(jsonEncode(node.toJson()), isNot(contains('runtimeValues')));
    final snapshot = WorkspaceNode.fromJson(node.toJson(includeRuntime: true));
    expect(snapshot.runtimeValues['result'], 10);
    expect(snapshot.runtimeStatus, 'running');
  });

  test('local workspace dependencies require exact installed hash and never fetch online', () async {
    final module = await store.install(package);
    final project = WorkspaceProject(
      id: 'offline',
      name: 'Offline',
      nodes: [WorkspaceNode(id: 'node', module: module)],
    );
    final resolved = await resolveWorkspaceModules(project, [module]);
    expect(resolved.single.localPackage, module.localPackage);
    final wrong = SystemModule(
      id: module.id,
      name: module.name,
      category: 'Local',
      description: '',
      version: module.version,
      localPackage: 'a' * 64,
      manifest: module.manifest,
    );
    await expectLater(
      resolveWorkspaceModules(project, [wrong]),
      throwsA(isA<WorkspaceDependencyException>()),
    );
  });

  test('installed binary integrity is checked before launching', () async {
    final integrityStore = LocalModuleStore(
      root: Directory('${temporary.path}/integrity'),
    );
    final module = await integrityStore.install(package);
    final executable = await integrityStore.executable(module);
    await File(executable).writeAsString('tampered');
    await expectLater(
      integrityStore.executable(module),
      throwsA(isA<FileSystemException>()),
    );
  });
}
