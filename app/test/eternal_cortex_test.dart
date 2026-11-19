import 'dart:io';

import 'package:bci_engine/core/modules/local_module_store.dart';
import 'package:bci_engine/core/modules/module_runtime.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final package = Platform.environment['ETERNAL_CORTEX_QMOD'];
  test(
    'bundled EternalCortex installs, handshakes and isolates two windows',
    () async {
      final temporary = await Directory('/tmp/opencode')
          .createTemp('eternalcortex-host-');
      final processes = <Process>[];
      final statuses = <String, String>{};
      final values = <String, Map<String, dynamic>>{};
      final store = LocalModuleStore(root: temporary);
      final module = await store.installFile(File(package!));
      final runtime = ModuleRuntime(
        store: store,
        launchPackaged: (command) async {
          final process = await Process.start(
            command.executable,
            command.arguments,
            workingDirectory: command.directory,
            environment: {
              'QT_QPA_PLATFORM': 'offscreen',
              'PYTHONHOME': '/nonexistent',
              'PYTHONPATH': '/nonexistent',
              'PATH': '/nonexistent',
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
      addTearDown(() async {
        runtime.dispose();
        await Future.wait(processes.map((p) => p.exitCode));
        await temporary.delete(recursive: true);
      });
      runtime.sync(
        'review',
        [
          WorkspaceNode(id: 'review-a', module: module),
          WorkspaceNode(id: 'review-b', module: module),
        ],
        [],
        [module],
      );
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (values['review-a']?['status'] == null ||
          values['review-b']?['status'] == null) {
        if (DateTime.now().isAfter(deadline)) {
          fail('No ready state: $statuses / $values');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(processes.length, 2);
      expect(processes[0].pid, isNot(processes[1].pid));
      expect(statuses.values, everyElement('running'));
      expect(values['review-a']!['status'], contains('dedicated window'));
      runtime.event('review-a', 'show_window', true);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(statuses['review-b'], 'running');
      runtime.sync('another-workspace', [], [], [module]);
      await Future.wait(processes.map((p) => p.exitCode))
          .timeout(const Duration(seconds: 5));
    },
    skip: !Platform.isLinux || package == null,
  );
}
