import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bci_engine/core/modules/local_module_store.dart';
import 'package:bci_engine/core/modules/module_platform.dart';
import 'package:bci_engine/core/modules/module_runtime.dart';
import 'package:bci_engine/core/logic/logic_blocks.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target selection is deterministic, explicit and legacy compatible', () {
    final m = {
      'runtime': 'process-v1',
      'targets': {
        for (final target in ModulePlatform.supported)
          target: {
            'executable': 'targets/$target/module',
            'arguments': <String>[],
          },
      },
    };
    for (final target in ModulePlatform.supported) {
      expect(
        ModulePlatform.select(m, target: target)['executable'],
        'targets/$target/module',
      );
    }
    expect(
      () => ModulePlatform.select(m, target: 'android-arm64'),
      throwsFormatException,
    );
    expect(
      ModulePlatform.select({
        'runtime': 'native-process-v1',
        'platform': 'linux-x64',
      }, target: 'linux-x64')['executable'],
      'bin/module',
    );
    expect(ModulePlatform.supported, contains(ModulePlatform.current));
  });
  test(
    'cross-platform path safety rejects Windows aliases and case collisions',
    () {
      for (final path in [
        'bin/CON.exe',
        'aux.txt',
        'bin/a.',
        'bin/a ',
        'bin/a:b',
        'bin/a?b',
        '../bin/module',
      ]) {
        expect(LocalModuleStore.safePath(path), isFalse, reason: path);
      }
      final archive = Archive()
        ..addFile(ArchiveFile('manifest.json', 2, utf8.encode('{}')))
        ..addFile(ArchiveFile('bin/Test', 1, [1]))
        ..addFile(ArchiveFile('bin/test', 1, [2]));
      expect(
        () => LocalModuleStore.validateArchive(
          ZipEncoder().encode(archive, level: 0)!,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'binary headers reject mismatched architecture and malformed PE/fat Mach-O',
    () {
      expect(ModulePlatform.matches(List.filled(64, 0), 'linux-x64'), isFalse);
      final pe = List.filled(96, 0)
        ..[0] = 77
        ..[1] = 90
        ..[60] = 255;
      expect(ModulePlatform.matches(pe, 'windows-x64'), isFalse);
      final mach = List.filled(32, 0)
        ..[0] = 0xcf
        ..[1] = 0xfa
        ..[2] = 0xed
        ..[3] = 0xfe
        ..[4] = 7
        ..[7] = 1
        ..[12] = 2;
      expect(ModulePlatform.matches(mach, 'macos-x64'), isTrue);
      expect(ModulePlatform.matches(mach, 'macos-arm64'), isFalse);
      final fat = List.filled(32, 0)
        ..[0] = 0xca
        ..[1] = 0xfe
        ..[2] = 0xba
        ..[3] = 0xbe
        ..[7] = 255;
      expect(ModulePlatform.matches(fat, 'macos-x64'), isFalse);
    },
  );

  final fixture = Platform.environment['QUALIA_UNIVERSAL_QMOD'];
  test('one six-target package installs and runs on this host; instances isolate and shut down', () async {
    final bytes = await File(fixture!).readAsBytes();
    final dir = await Directory.systemTemp.createTemp('qualia-universal-');
    addTearDown(() => dir.delete(recursive: true));
    final store = LocalModuleStore(root: dir);
    final module = await store.install(bytes);
    final nativeFixture = Platform.environment['QUALIA_NATIVE_LIBRARY_QMOD'];
    final native = nativeFixture == null
        ? null
        : await store.install(await File(nativeFixture).readAsBytes());
    final command = await store.command(module);
    expect(command.executable, contains(ModulePlatform.current));
    expect(ModulePlatform.launches(module.manifest), hasLength(6));
    final statuses = <String, String>{};
    final values = <String, Map<String, dynamic>>{};
    final children = <Process>[];
    final runtime = ModuleRuntime(
      store: store,
      launchPackaged: (command) async {
        final child = await Process.start(
          command.executable,
          command.arguments,
          workingDirectory: command.directory,
          includeParentEnvironment: false,
          environment: {'PATH': '/nonexistent'},
        );
        children.add(child);
        return child;
      },
      onUpdate: (id, status, value) {
        statuses[id] = status;
        values[id] = {...?values[id], ...value};
      },
    );
    addTearDown(runtime.dispose);
    Future<void> wait(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (!ready()) {
        if (DateTime.now().isAfter(deadline)) fail('Timeout $statuses $values');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    runtime.sync(
      'universal',
      [
        WorkspaceNode(id: 'a', module: module),
        WorkspaceNode(id: 'b', module: module),
        if (native != null) WorkspaceNode(id: 'cpp', module: native),
        WorkspaceNode(
          id: 'source',
          module: LogicBlocks.module(LogicBlockType.select),
          kind: WorkspaceNodeKind.logic,
          logicType: LogicBlockType.select,
        ),
        WorkspaceNode(
          id: 'source-b',
          module: LogicBlocks.module(LogicBlockType.select),
          kind: WorkspaceNodeKind.logic,
          logicType: LogicBlockType.select,
        ),
      ],
      [
        const WorkspaceLink(
          source: 'source',
          output: 'output',
          target: 'a',
          input: 'input',
        ),
        const WorkspaceLink(
          source: 'source-b',
          output: 'output',
          target: 'b',
          input: 'input',
        ),
        if (native != null)
          const WorkspaceLink(
            source: 'source-cpp',
            output: 'output',
            target: 'cpp',
            input: 'input',
          ),
      ],
      [module, if (native != null) native],
    );
    await wait(() => statuses['a'] == 'running' && statuses['b'] == 'running');
    expect(
      children.map((p) => p.pid).toSet(),
      hasLength(native == null ? 2 : 3),
    );
    runtime.routeOutput('source', 'output', {'mean': 2.5}, 32);
    await wait(() => values['a']?['result'] != null);
    final result = values['a']!['result'] as Map;
    expect(result['calls'], 1);
    expect(
      result['digest'],
      sha256.convert(utf8.encode('{"mean":2.5}')).toString(),
    );
    expect(values['b']?['result'], isNull);
    runtime.routeOutput('source-b', 'output', {'mean': 4}, 32);
    await wait(() => values['b']?['result'] != null);
    expect((values['b']!['result'] as Map)['calls'], 1);
    if (native != null) {
      await wait(() => statuses['cpp'] == 'running');
      // Reuse source because its output may feed multiple target modules.
      runtime.sync(
        'universal',
        [
          WorkspaceNode(id: 'a', module: module),
          WorkspaceNode(id: 'b', module: module),
          WorkspaceNode(id: 'cpp', module: native),
          WorkspaceNode(
            id: 'source-cpp',
            module: LogicBlocks.module(LogicBlockType.select),
            kind: WorkspaceNodeKind.logic,
            logicType: LogicBlockType.select,
          ),
        ],
        [
          const WorkspaceLink(
            source: 'source-cpp',
            output: 'output',
            target: 'cpp',
            input: 'input',
          ),
        ],
        [module, native],
      );
      runtime.routeOutput('source-cpp', 'output', {'mean': 2.5}, 32);
      await wait(() => values['cpp']?['result'] != null);
      expect((values['cpp']!['result'] as Map)['energy'], 6.25);
      expect((values['cpp']!['result'] as Map)['cppCalls'], 1);
    }
    runtime.sync('other', [], [], [module]);
    await Future.wait(children.map((p) => p.exitCode))
        .timeout(const Duration(seconds: 3));
    // Integrity covers foreign platform payloads too, not only this host binary.
    final other = ModulePlatform.launches(module.manifest).entries
        .firstWhere((e) => e.key != ModulePlatform.current);
    await File('${command.directory}/${other.value['executable']}')
        .writeAsString('tampered');
    await expectLater(
      store.command(module),
      throwsA(isA<FileSystemException>()),
    );
  }, skip: fixture == null || fixture.isEmpty);
}
