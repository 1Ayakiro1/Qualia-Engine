import 'dart:convert';
import 'dart:io';

import 'package:bci_engine/core/logic/logic_blocks.dart';
import 'package:bci_engine/core/modules/local_module_store.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/modules/module_runtime.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixtures = Platform.environment['QUALIA_LIBRARY_FIXTURES'];
  if (!Platform.isLinux || fixtures == null) {
    test(
      'built library fixtures integration (Linux + QUALIA_LIBRARY_FIXTURES)',
      () {},
      skip: true,
    );
    return;
  }
  late Directory temporary;
  late LocalModuleStore store;
  final modules = <String, SystemModule>{};
  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp(
      'qualia-library-integration-',
    );
    store = LocalModuleStore(root: temporary);
    for (final language in ['python', 'cpp', 'go']) {
      modules[language] = await store.install(
        await File('$fixtures/$language/dist/library-$language-0.1.0.qmod')
            .readAsBytes(),
      );
    }
  });
  tearDownAll(() => temporary.delete(recursive: true));

  Future<void> wait(bool Function() ready, Object Function() diagnostic) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!ready()) {
      if (DateTime.now().isAfter(deadline)) fail('Timeout: ${diagnostic()}');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('NumPy/OpenBLAS + C FFI -> select -> C++ .so -> Go crypto across real processes', () async {
    final values = <String, Map<String, dynamic>>{};
    final statuses = <String, String>{};
    final processes = <Process>[];
    final runtime = ModuleRuntime(
      store: store,
      launchPackaged: (command) async {
        final process = await Process.start(
          command.executable,
          command.arguments,
          workingDirectory: command.directory,
          includeParentEnvironment: false,
          environment: {
            'PATH': '/nonexistent',
            'PYTHONHOME': '/nonexistent',
            'PYTHONPATH': '/nonexistent',
            'OPENBLAS_NUM_THREADS': '1',
          },
        );
        processes.add(process);
        return process;
      },
      onUpdate: (id, status, update) {
        statuses[id] = status;
        values[id] = {...?values[id], ...update};
      },
    );
    addTearDown(runtime.dispose);
    final nodes = [
      WorkspaceNode(id: 'python', module: modules['python']!),
      WorkspaceNode(
        id: 'select',
        module: LogicBlocks.module(LogicBlockType.select),
        kind: WorkspaceNodeKind.logic,
        logicType: LogicBlockType.select,
        inputs: ['input'],
        outputs: ['output'],
        settings: {'fields': 'mean, rms'},
      ),
      WorkspaceNode(id: 'cpp', module: modules['cpp']!),
      WorkspaceNode(id: 'go', module: modules['go']!),
      WorkspaceNode(id: 'sibling', module: modules['cpp']!),
    ];
    final links = [
      const WorkspaceLink(
        source: 'python',
        output: 'output',
        target: 'select',
        input: 'input',
      ),
      const WorkspaceLink(
        source: 'select',
        output: 'output',
        target: 'cpp',
        input: 'input',
      ),
      const WorkspaceLink(
        source: 'cpp',
        output: 'output',
        target: 'go',
        input: 'input',
      ),
    ];
    runtime.sync('libraries', nodes, links, modules.values.toList());
    await wait(
      () => [
        'python',
        'cpp',
        'go',
        'sibling',
      ].every((id) => statuses[id] == 'running'),
      () => statuses,
    );
    expect(processes.map((p) => p.pid).toSet(), hasLength(4));
    runtime.event('python', 'run', true);
    await wait(
      () => values['go']?['result'] != null,
      () => '$statuses $values',
    );
    final python = values['python']!['result'] as Map;
    expect(python['mean'], 2.5);
    expect(python['rms'], closeTo(2.7386127875258306, 1e-12));
    expect(python['energy'], 6.25);
    expect(values['python']!['numpyVersion'], isNotEmpty);
    final received = (values['go']!['result'] as Map)['received'] as Map;
    expect(received['energy'], 6.25);
    expect(received['cppCalls'], 1);
    expect(
      received.containsKey('pythonCalls'),
      isFalse,
    ); // Allowlist removed it.
    expect(
      (values['go']!['result'] as Map)['digest'],
      matches(RegExp(r'^[a-f0-9]{64}$')),
    );
    expect(values['sibling']?['result'], isNull);
    runtime.event('python', 'run', true);
    await wait(
      () => (values['go']?['result'] as Map?)?['calls'] == 2,
      () => values,
    );
    expect((values['python']!['result'] as Map)['pythonCalls'], 2);
    expect((values['cpp']!['result'] as Map)['cppCalls'], 2);

    // Invalid source schema never reaches Go; later valid messages still work.
    runtime.event('cpp', 'badOutput', true);
    await wait(
      () => statuses['cpp'] == 'output rejected: schema',
      () => statuses,
    );
    expect((values['go']!['result'] as Map)['calls'], 2);
    // Invalid target schema also rejects, while the process remains alive.
    runtime.routeOutput('select', 'output', {'mean': 'wrong type'}, 32);
    expect(statuses['cpp'], 'input rejected: schema/type');
    runtime.event('python', 'run', true);
    await wait(
      () => (values['go']?['result'] as Map?)?['calls'] == 3,
      () => values,
    );

    // A crashed C++ node neither kills its sibling nor respawns on ordinary sync.
    runtime.event('cpp', 'crash', true);
    await wait(
      () => statuses['cpp']?.startsWith('exited') == true,
      () => statuses,
    );
    expect(statuses['sibling'], 'running');
    runtime.sync('libraries', nodes, links, modules.values.toList());
    expect(processes, hasLength(4));
    nodes[2].settings['enabled'] = false;
    runtime.sync('libraries', nodes, links, modules.values.toList());
    nodes[2].settings['enabled'] = true;
    runtime.sync('libraries', nodes, links, modules.values.toList());
    await wait(() => statuses['cpp'] == 'running', () => statuses);
    expect(processes, hasLength(5));
    runtime.event('python', 'run', true);
    await wait(
      () => (values['go']?['result'] as Map?)?['calls'] == 4,
      () => values,
    );
    expect(
      (values['cpp']!['result'] as Map)['cppCalls'],
      1,
    ); // New instance memory.
    runtime.sync('other-workspace', [], [], modules.values.toList());
    await Future.wait(processes.map((p) => p.exitCode))
        .timeout(const Duration(seconds: 3));
  });

  test('missing/tampered native library is rejected before launch', () async {
    final isolated = LocalModuleStore(
      root: Directory('${temporary.path}/missing-dependency'),
    );
    final module = await isolated.install(
      await File('$fixtures/cpp/dist/library-cpp-0.1.0.qmod').readAsBytes(),
    );
    final command = await isolated.command(module);
    await File('${command.directory}/lib/libqualia_math.so').delete();
    await expectLater(
      isolated.command(module),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'relocated extracted payload runs with only bundled Python and NumPy',
    () async {
      final command = await store.command(modules['python']!);
      final result = await Process.run(
        command.executable,
        command.arguments,
        workingDirectory: command.directory,
        includeParentEnvironment: false,
        environment: {
          'PATH': '/nonexistent',
          'PYTHONHOME': '/nonexistent',
          'OPENBLAS_NUM_THREADS': '1',
        },
      );
      // EOF exits after handshake; copied installation path differs from build path.
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(jsonDecode((result.stdout as String).trim())['type'], 'ready');
    },
  );
}
