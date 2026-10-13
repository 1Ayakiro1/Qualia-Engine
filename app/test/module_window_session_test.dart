import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/logic/logic_blocks.dart';
import 'package:bci_engine/core/modules/module_window_session.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native window sessions authenticate, synchronize, reuse and clean up', () async {
    final node = WorkspaceNode(
      id: 'window-node',
      module: const SystemModule(
        id: 'window.test',
        name: 'Window Test',
        category: 'test',
        description: 'Window fixture',
        manifest: {
          'ui': [
            {'id': 'gain', 'type': 'slider', 'min': 0, 'max': 10},
          ],
        },
      ),
    );
    final launches = <List<String>>[];
    Process? child;
    WorkspaceNode? current = node;
    final sessions = ModuleWindowSessions(
      nodeById: (_) => current,
      onParameter: (_, key, value) => node.settings[key] = value,
      launch: (args) async {
        launches.add(args);
        final fixture = File(
          '${Directory.systemTemp.path}/qualia-window-${DateTime.now().microsecondsSinceEpoch}.dart',
        );
        await fixture.writeAsString(
          'import "dart:async"; void main() { Timer(const Duration(seconds: 60), () {}); }',
        );
        addTearDown(() => fixture.delete());
        final cache = File(Platform.resolvedExecutable)
            .parent
            .parent
            .parent
            .parent
            .path;
        return child = await Process.start(
          '$cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
          [fixture.path],
        );
      },
    );
    addTearDown(sessions.dispose);
    expect(await sessions.open(node, locale: 'ru', light: true), isTrue);
    final port = launches.single[1];
    final token = launches.single[2];
    expect(token.length, 64);
    await expectLater(
      WebSocket.connect('ws://127.0.0.1:$port/wrong'),
      throwsA(isA<WebSocketException>()),
    );
    final socket = await WebSocket.connect('ws://127.0.0.1:$port/$token');
    addTearDown(socket.close);
    final messages = StreamIterator(socket);
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    final initial = jsonDecode(messages.current as String) as Map;
    expect(initial['locale'], 'ru');
    expect(initial['light'], true);
    expect(initial['node']['id'], node.id);
    socket.add(jsonEncode({'type': 'parameter', 'key': 'gain', 'value': 4}));
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    expect(node.settings['gain'], 4);
    expect(
      jsonDecode(messages.current as String)['node']['settings']['gain'],
      4,
    );
    node.settings['gain'] = 7;
    node.runtimeValues['result'] = 42;
    node.runtimeStatus = 'running';
    sessions.update();
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    expect(
      jsonDecode(messages.current as String)['node']['settings']['gain'],
      7,
    );
    expect(
      jsonDecode(messages.current as String)['node']['runtimeValues']['result'],
      42,
    );
    expect(
      jsonDecode(messages.current as String)['node']['runtimeStatus'],
      'running',
    );
    expect(await sessions.open(node, locale: 'ru', light: true), isTrue);
    expect(launches.length, 1);
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    expect(jsonDecode(messages.current as String)['type'], 'focus');
    socket.add(
      jsonEncode({'type': 'parameter', 'key': 'unknown', 'value': true}),
    );
    socket.add(
      jsonEncode({
        'type': 'parameter',
        'key': 'gain',
        'value': {'invalid': true},
      }),
    );
    socket.add(
      jsonEncode({'type': 'parameter', 'key': 'enabled', 'value': false}),
    );
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    expect(node.settings['enabled'], false);
    expect(node.settings.containsKey('unknown'), isFalse);
    expect(node.settings['gain'], 7);
    current = WorkspaceNode(
      id: node.id,
      module: LogicBlocks.module(LogicBlockType.script),
      kind: WorkspaceNodeKind.logic,
      logicType: LogicBlockType.script,
    );
    sessions.update();
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    expect(jsonDecode(messages.current as String)['node']['kind'], 'logic');
    socket.add(
      jsonEncode({
        'type': 'parameter',
        'key': 'script',
        'value': 'emit output value;',
      }),
    );
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isTrue,
    );
    expect(node.settings['script'], 'emit output value;');
    current = null;
    sessions.update();
    expect(
      await messages.moveNext().timeout(const Duration(seconds: 3)),
      isFalse,
    );
    await child!.exitCode.timeout(const Duration(seconds: 3));
  });

  test(
    'process launch failure returns false and releases session server',
    () async {
      final node = WorkspaceNode(
        id: 'failed',
        module: const SystemModule(
          id: 'failed.module',
          name: 'Failed',
          category: 'test',
          description: 'Failed fixture',
        ),
      );
      var attempts = 0;
      final sessions = ModuleWindowSessions(
        nodeById: (_) => node,
        onParameter: (_, _, _) {},
        launch: (_) async {
          attempts++;
          throw const ProcessException('missing', []);
        },
      );
      addTearDown(sessions.dispose);
      expect(await sessions.open(node, locale: 'en', light: false), isFalse);
      expect(await sessions.open(node, locale: 'en', light: false), isFalse);
      expect(attempts, 2);
    },
  );
}
