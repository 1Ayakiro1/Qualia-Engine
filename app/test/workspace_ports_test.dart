import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/features/common/desktop_menu.dart';
import 'package:bci_engine/features/modules/modules_screen.dart';
import 'package:bci_engine/features/modules/workspace_colors.dart';
import 'package:bci_engine/features/modules/workspace_connections.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _module = SystemModule(
  id: 'test.ports',
  name: 'Port test',
  category: 'acquisition',
  description: 'Port annotations test',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'port annotations round-trip without changing IDs or author settings',
    () {
      final node = WorkspaceNode(
        id: 'node',
        module: _module,
        inputLabels: {'input': 'EEG signal'},
        outputLabels: {'output': 'Filtered signal'},
        inputTypes: {'input': WorkspacePortType.number},
        outputTypes: {'output': WorkspacePortType.list},
      );
      final restored = WorkspaceNode.fromJson(
        jsonDecode(jsonEncode(node.toJson())),
      );
      expect(restored.inputs, ['input']);
      expect(restored.outputs, ['output']);
      expect(restored.portLabel('input', false), 'EEG signal');
      expect(restored.portLabel('output', true), 'Filtered signal');
      expect(restored.portType('input', false), WorkspacePortType.number);
      expect(restored.portType('output', true), WorkspacePortType.list);
      expect(restored.settings, isEmpty);
      final old = node.toJson()
        ..remove('inputLabels')
        ..remove('outputLabels')
        ..remove('inputTypes')
        ..remove('outputTypes');
      expect(WorkspaceNode.fromJson(old).portLabel('input', false), 'input');
      expect(
        WorkspaceNode.fromJson(old).portType('input', false),
        WorkspacePortType.any,
      );
      final invalid = node.toJson()
        ..['inputLabels'] = {'input': '   ', 'other': 12}
        ..['inputTypes'] = {'input': 'unknown'};
      expect(WorkspaceNode.fromJson(invalid).inputLabels, isEmpty);
      expect(
        WorkspaceNode.fromJson(invalid).portType('input', false),
        WorkspacePortType.any,
      );
    },
  );

  testWidgets(
    'renaming and value types persist while existing links stay intact',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(workspaceProvider);
      await tester.pump();
      final controller = container.read(workspaceProvider.notifier);
      final source = controller.addNode(_module, Offset.zero);
      final target = controller.addNode(_module, const Offset(400, 0));
      final link = WorkspaceLink(
        source: source.id,
        output: 'output',
        target: target.id,
        input: 'input',
      );
      expect(controller.connect(link), isNull);
      controller.setPortLabel(source.id, 'output', true, '   Signal out   ');
      controller.setPortLabel(target.id, 'input', false, 'Signal in');
      controller.setPortType(
        target.id,
        'input',
        false,
        WorkspacePortType.number,
      );
      controller.setPortColor(
        source.id,
        'output',
        true,
        WorkspaceNodeColor.orange,
      );
      controller.setPortLabel(target.id, 'missing', false, 'Invalid');
      controller.setPortType(
        target.id,
        'missing',
        false,
        WorkspacePortType.string,
      );
      expect(source.portLabel('output', true), 'Signal out');
      expect(target.inputLabels.containsKey('missing'), isFalse);
      expect(target.inputTypes.containsKey('missing'), isFalse);
      expect(container.read(workspaceProvider).links.single, same(link));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(() async {
        final restored = ProviderContainer();
        addTearDown(restored.dispose);
        restored.read(workspaceProvider);
        for (
          var i = 0;
          i < 10 && !restored.read(workspaceProvider).loaded;
          i++
        ) {
          await Future<void>.delayed(Duration.zero);
        }
        final state = restored.read(workspaceProvider);
        expect(state.loaded, isTrue);
        expect(state.nodes.first.portLabel('output', true), 'Signal out');
        expect(
          state.nodes.last.portType('input', false),
          WorkspacePortType.number,
        );
        expect(state.links.single.input, 'input');
        expect(state.links.single.output, 'output');
      });
      controller.setPortLabel(source.id, 'output', true, '');
      controller.setPortType(target.id, 'input', false, WorkspacePortType.any);
      expect(source.portLabel('output', true), 'output');
      expect(target.inputTypes, isEmpty);
      await tester.pump(const Duration(milliseconds: 350));
    },
  );

  testWidgets(
    'connections use endpoint gradients, solid colors and neutral fallback',
    (tester) async {
      await tester.runAsync(() async {
        final source = WorkspaceNode(
          id: 'source',
          module: _module,
          position: Offset.zero,
        );
        final target = WorkspaceNode(
          id: 'target',
          module: _module,
          position: const Offset(400, 0),
        );
        const neutral = Color(0xff909090);
        const link = WorkspaceLink(
          source: 'source',
          output: 'output',
          target: 'target',
          input: 'input',
        );
        Future<Color> sample(int x) async {
          final recorder = ui.PictureRecorder();
          WorkspaceConnectionsPainter(
            nodes: [source, target],
            links: [link],
            neutral: neutral,
          ).paint(Canvas(recorder), const Size(720, 200));
          final picture = recorder.endRecording();
          final image = await picture.toImage(720, 200);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final y = source.portPosition('output', true).dy.floor();
          final offset = (y * 720 + x) * 4;
          final color = Color.fromARGB(
            bytes.getUint8(offset + 3),
            bytes.getUint8(offset),
            bytes.getUint8(offset + 1),
            bytes.getUint8(offset + 2),
          );
          image.dispose();
          picture.dispose();
          return color;
        }

        void near(Color actual, Color expected) {
          expect(actual.r, closeTo(expected.r, .035));
          expect(actual.g, closeTo(expected.g, .035));
          expect(actual.b, closeTo(expected.b, .035));
          expect(actual.a, closeTo(1, .01));
        }

        near(await sample(350), neutral);
        source.outputColors['output'] = WorkspaceNodeColor.orange;
        target.inputColors['input'] = WorkspaceNodeColor.yellow;
        near(await sample(295), WorkspaceNodeColor.orange.tint!);
        near(await sample(405), WorkspaceNodeColor.yellow.tint!);
        near(
          await sample(350),
          Color.lerp(
            WorkspaceNodeColor.orange.tint,
            WorkspaceNodeColor.yellow.tint,
            .5,
          )!,
        );
        target.inputColors['input'] = WorkspaceNodeColor.orange;
        near(await sample(350), WorkspaceNodeColor.orange.tint!);
        target.inputColors.clear();
        near(await sample(405), neutral);
        expect(
          workspaceConnectionPaint(
            const Offset(10, 10),
            const Offset(10, 100),
            Colors.orange,
            Colors.yellow,
          ).shader,
          isNotNull,
        );
        expect(
          workspaceConnectionPaint(
            const Offset(100, 10),
            const Offset(10, 10),
            Colors.orange,
            Colors.yellow,
          ).shader,
          isNotNull,
        );
        expect(
          workspaceConnectionPaint(
            Offset.zero,
            Offset.zero,
            Colors.orange,
            Colors.yellow,
          ).shader,
          isNull,
        );
        expect(
          workspaceConnectionPaint(
            Offset.zero,
            const Offset(100, 10),
            neutral,
            neutral,
          ).shader,
          isNull,
        );
      });
    },
  );

  testWidgets(
    'port menu offers Name, Value type and hover Color with keyboard rename',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final capture = GlobalKey();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: (context, child) =>
                AppThemeScope(palette: AppPalette.dark, child: child!),
            home: RepaintBoundary(
              key: capture,
              child: Scaffold(
                body: ModulesScreen(
                  modules: const [_module],
                  onAdd: () {},
                  onEdit: (_) {},
                  onRemove: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = container.read(workspaceProvider.notifier);
      final source = controller.addNode(_module, const Offset(4900, 4900));
      final target = controller.addNode(_module, const Offset(5350, 4980));
      controller.connect(
        WorkspaceLink(
          source: source.id,
          output: 'output',
          target: target.id,
          input: 'input',
        ),
      );
      controller.setPortColor(
        source.id,
        'output',
        true,
        WorkspaceNodeColor.orange,
      );
      await tester.pumpAndSettle();
      expect(find.text('Acquisition'), findsNothing);
      final port = find.byKey(
        ValueKey('workspace port ${target.id} false input'),
      );
      Future<void> menu() async {
        final click = await tester.startGesture(
          tester.getCenter(port),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await click.up();
        await click.removePointer();
        await tester.pumpAndSettle();
      }

      await menu();
      final entries = tester
          .widget<DesktopMenuSurface<String>>(
            find.byType(DesktopMenuSurface<String>),
          )
          .entries;
      expect(entries.map((entry) => entry.label), [
        'Name',
        'Value type',
        'Color',
      ]);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(tester.getCenter(find.text('Color')));
      await tester.pumpAndSettle();
      expect(find.text('Yellow'), findsOneWidget);
      // Clicking an already hovered parent must not collapse its submenu.
      await tester.tap(find.text('Color'));
      await tester.pumpAndSettle();
      expect(find.text('Yellow'), findsOneWidget);
      await tester.tap(find.text('Yellow'));
      await tester.pumpAndSettle();
      await mouse.removePointer();
      expect(target.portColor('input', false), WorkspaceNodeColor.yellow);
      await menu();
      await tester.tap(find.text('Value type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Number'));
      await tester.pumpAndSettle();
      expect(target.portType('input', false), WorkspacePortType.number);
      await menu();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('workspace port name field'));
      expect(name, findsOneWidget);
      await tester.enterText(name, 'EEG signal');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(target.portLabel('input', false), 'EEG signal');
      expect(find.text('EEG signal'), findsOneWidget);
      expect(container.read(workspaceProvider).links.single.input, 'input');
      expect(tester.takeException(), isNull);
      final path = Platform.environment['QUALIA_TEST_CAPTURE_DIR'];
      if (path != null) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(path).create(recursive: true);
          await File('$path/workspace-port-gradient.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
