import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/features/modules/modules_screen.dart';
import 'package:bci_engine/features/modules/workspace_canvas_controller.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:bci_engine/state/app_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_manager_test.dart' show themed;

const studio = SystemModule(
  id: 'eternal-cortex',
  name: 'EternalCortex',
  category: 'utility',
  description: '',
  manifest: {
    'ports': {'inputs': <String>[], 'outputs': <String>[]},
  },
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> canvas(
    WidgetTester tester, {
    WorkspaceCanvasController? bridge,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      themed(
        scope,
        ModulesScreen(
          modules: const [studio],
          onAdd: () {},
          onEdit: (_) {},
          onRemove: (_) {},
          canvasController: bridge,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return scope;
  }

  testWidgets(
    'empty canvas context menu lists a portless module without search',
    (tester) async {
      final scope = await canvas(tester);
      final mouse = await tester.startGesture(
        const Offset(1000, 600),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('EternalCortex'), findsOneWidget);
      await tester.tap(find.text('EternalCortex'));
      await tester.pumpAndSettle();
      final node = scope.read(workspaceProvider).nodes.single;
      expect(node.module.id, studio.id);
      expect(node.inputs, isEmpty);
      expect(node.outputs, isEmpty);
      expect(find.byKey(ValueKey('workspace node ${node.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'import insertion is visible in the current viewport and undoable',
    (tester) async {
      final bridge = WorkspaceCanvasController();
      final scope = await canvas(tester, bridge: bridge);
      final controller = scope.read(workspaceProvider.notifier);
      controller.setBlockVisibility(modules: false);
      controller.setModuleHidden(studio.id, true);
      await tester.pumpAndSettle();
      bridge.insertModule!(studio);
      await tester.pumpAndSettle();
      final node = scope.read(workspaceProvider).nodes.single;
      final card = find.byKey(ValueKey('workspace node ${node.id}'));
      expect(card, findsOneWidget);
      expect(
        tester.getRect(card).overlaps(const Rect.fromLTWH(0, 0, 1600, 1000)),
        isTrue,
      );
      expect(scope.read(workspaceProvider).showModuleBlocks, isTrue);
      expect(
        scope.read(workspaceProvider).hiddenModuleIds,
        isNot(contains(studio.id)),
      );
      controller.undo();
      await tester.pumpAndSettle();
      expect(scope.read(workspaceProvider).nodes, isEmpty);
      expect(scope.read(workspaceProvider).showModuleBlocks, isFalse);
      controller.redo();
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('workspace node ${node.id}')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(bridge.insertModule, isNull);
      await tester.pump(const Duration(milliseconds: 350));
    },
  );

  testWidgets(
    'trusted qmod import installs and adds a selected canvas instance',
    (tester) async {
      await tester.runAsync(() async {
        final temporary = Directory('/tmp/opencode')
            .createTempSync('canvas-import-');
        addTearDown(() => temporary.deleteSync(recursive: true));
        final manifest = {
          'format': 'qualia-module',
          'schemaVersion': 1,
          'runtime': 'process-v1',
          'platform': 'portable',
          'id': studio.id,
          'name': studio.name,
          'version': '0.1.0',
          'launch': {
            'launcher': 'python3',
            'executable': 'main.py',
            'arguments': <String>[],
          },
          ...studio.manifest,
          'ui': <dynamic>[],
        };
        final archive = Archive();
        for (final entry in {
          'manifest.json': jsonEncode(manifest),
          'main.py': '# fixture',
        }.entries) {
          final bytes = utf8.encode(entry.value);
          archive.addFile(
            ArchiveFile(entry.key, bytes.length, bytes)..compress = false,
          );
        }
        final package = File('${temporary.path}/studio.qmod');
        package.writeAsBytesSync(ZipEncoder().encode(archive, level: 0)!);
        final messenger = tester.binding.defaultBinaryMessenger;
        for (final channel in [
          'plugins.flutter.io/file_selector',
          'plugins.flutter.io/path_provider',
          'window_manager',
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(channel), (
            call,
          ) async {
            if (call.method == 'openFile') return [package.path];
            if (call.method == 'getApplicationSupportDirectory') {
              return temporary.path;
            }
            if (call.method.startsWith('is')) return false;
            return null;
          });
          addTearDown(
            () => messenger.setMockMethodCallHandler(
              MethodChannel(channel),
              null,
            ),
          );
        }
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final scope = ProviderContainer();
        addTearDown(scope.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: scope, child: const BciApp()),
        );
        await tester.pumpAndSettle();
        tester.widget<ModulesScreen>(find.byType(ModulesScreen)).onAdd();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add locally (.qmod)'));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Add locally (.qmod)'));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        for (
          var attempt = 0;
          attempt < 20 && scope.read(workspaceProvider).library.isEmpty;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pumpAndSettle();
        }
        final graph = scope.read(workspaceProvider);
        expect(
          graph.library,
          hasLength(1),
          reason: scope
              .read(notificationProvider)
              .map((note) => note.message)
              .join('\n'),
        );
        expect(graph.library.single.id, studio.id);
        final node = graph.nodes.single;
        expect(node.module.isLocal, isTrue);
        expect(node.module.localPackage, graph.library.single.localPackage);
        expect(node.inputs, isEmpty);
        expect(node.outputs, isEmpty);
        expect(
          find.byKey(ValueKey('workspace node ${node.id}')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ModulesScreen>(find.byType(ModulesScreen))
              .selectedNodeId,
          node.id,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 350));
      });
    },
  );
}
