import 'package:bci_engine/core/logic/logic_blocks.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/workspace/workspace_fragment.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/features/modules/modules_screen.dart';
import 'package:bci_engine/features/modules/workspace_colors.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_manager_test.dart' show themed, capture;
import 'workspace_ux_test.dart' show module, shortcut;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'fragment validation rejects unrelated, malformed and invalid graphs',
    () {
      expect(WorkspaceFragment.decode('plain text'), isNull);
      expect(
        WorkspaceFragment.decode(
          '{"format":"qualia-workspace-fragment","version":1}',
        ),
        isNull,
      );
      final a = WorkspaceNode(id: 'a', module: module);
      final fragment = WorkspaceFragment.capture([a], [], {'a'});
      expect(
        WorkspaceFragment.decode(fragment.encode())!.project.nodes.single.id,
        'a',
      );
      a.settings['nested'] = {
        'values': [1, 2],
      };
      expect(fragment.project.nodes.single.settings, isEmpty);
    },
  );

  testWidgets(
    'paste remaps instances and internal links, deep copies settings and is one undo step',
    (tester) async {
      final scope = ProviderContainer();
      addTearDown(scope.dispose);
      scope.read(workspaceProvider);
      await tester.pump();
      final c = scope.read(workspaceProvider.notifier);
      c.addToLibrary(module);
      final a = c.addNode(module, const Offset(100, 120));
      final b = c.addNode(module, const Offset(500, 120));
      final other = c.addNode(module, const Offset(900, 120));
      c.setParameter(a.id, 'nested', {
        'items': [1, 2],
      });
      c.setPortLabel(a.id, 'output', true, 'Signal');
      c.setNodeColors({a.id}, WorkspaceNodeColor.red);
      c.connect(
        WorkspaceLink(
          source: a.id,
          output: 'output',
          target: b.id,
          input: 'input',
        ),
      );
      c.connect(
        WorkspaceLink(
          source: b.id,
          output: 'output',
          target: other.id,
          input: 'input',
        ),
      );
      final fragment = WorkspaceFragment.capture(
        scope.read(workspaceProvider).nodes,
        scope.read(workspaceProvider).links,
        {a.id, b.id},
      );
      final copied = c.pasteFragment(fragment, const Offset(200, 500));
      expect(copied, hasLength(2));
      expect(copied.first.id, isNot(a.id));
      expect(copied.first.position, const Offset(200, 500));
      expect(copied.last.position, const Offset(600, 500));
      expect(copied.first.headerColor, WorkspaceNodeColor.red);
      expect(copied.first.outputLabels['output'], 'Signal');
      expect(scope.read(workspaceProvider).links, hasLength(3));
      final link = scope.read(workspaceProvider).links.last;
      expect(link.source, copied.first.id);
      expect(link.target, copied.last.id);
      (copied.first.settings['nested']['items'] as List).add(3);
      expect(a.settings['nested']['items'], [1, 2]);
      expect(fragment.project.nodes.first.settings['nested']['items'], [1, 2]);
      c.undo();
      expect(scope.read(workspaceProvider).nodes, hasLength(3));
      expect(scope.read(workspaceProvider).links, hasLength(2));
      c.redo();
      expect(scope.read(workspaceProvider).nodes, hasLength(5));
      final target = c.createProject('Target');
      c.pasteFragment(fragment, Offset.zero);
      expect(scope.read(workspaceProvider).activeProjectId, target);
      expect(scope.read(workspaceProvider).nodes, hasLength(2));
      expect(scope.read(workspaceProvider).links, hasLength(1));
      await tester.pump(const Duration(milliseconds: 350));
    },
  );

  testWidgets(
    'group visibility is atomic and persisted; revealing preserves hidden siblings',
    (tester) async {
      var scope = ProviderContainer();
      scope.read(workspaceProvider);
      await tester.pump();
      final c = scope.read(workspaceProvider.notifier);
      final a = c.addNode(module, Offset.zero);
      final b = c.addNode(module, const Offset(400, 0));
      final sibling = c.addNode(module, const Offset(800, 0));
      final group = c.createSceneGroup('Group', nodeIds: {a.id, b.id});
      c.setSceneGroupHidden(group, true);
      expect(
        scope.read(workspaceProvider).hiddenNodeIds,
        containsAll([a.id, b.id]),
      );
      expect(
        scope.read(workspaceProvider).hiddenNodeIds,
        isNot(contains(sibling.id)),
      );
      c.undo();
      expect(scope.read(workspaceProvider).hiddenNodeIds, isEmpty);
      c.redo();
      c.setModuleHidden(module.id, true);
      c.setSceneGroupHidden(group, false);
      expect(scope.read(workspaceProvider).hiddenNodeIds, {sibling.id});
      await c.flushRecovery();
      scope.dispose();
      scope = ProviderContainer();
      addTearDown(scope.dispose);
      scope.read(workspaceProvider);
      await tester.pump();
      expect(scope.read(workspaceProvider).hiddenNodeIds, {sibling.id});
    },
  );

  testWidgets(
    'Shift and Alt select arrays; clipboard cut/paste and Delete apply to the array',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final scope = ProviderContainer();
      addTearDown(scope.dispose);
      final image = GlobalKey();
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        themed(
          scope,
          ModulesScreen(
            modules: const [module],
            onAdd: () {},
            onEdit: (_) {},
            onRemove: (_) {},
          ),
          captureKey: image,
        ),
      );
      await tester.pumpAndSettle();
      final c = scope.read(workspaceProvider.notifier);
      final a = c.addNode(module, const Offset(4900, 4900));
      final b = c.addNode(module, const Offset(5300, 4900));
      final d = c.addNode(module, const Offset(5700, 4900));
      c.setNodeColors({a.id}, WorkspaceNodeColor.blue);
      await tester.pumpAndSettle();
      BoxDecoration headerStyle(String id) =>
          tester
                  .widget<Container>(
                    find.byKey(ValueKey('workspace header $id')),
                  )
                  .decoration!
              as BoxDecoration;
      final originalHeaders = {
        for (final node in [a, b, d]) node.id: headerStyle(node.id).color,
      };
      bool selected(String id) =>
          tester
              .widget<Semantics>(
                find.byKey(ValueKey('workspace selection $id')),
              )
              .properties
              .selected ==
          true;
      await tester.tap(find.byKey(ValueKey('workspace header ${a.id}')));
      await tester.pumpAndSettle();
      for (final pair in [
        (LogicalKeyboardKey.shiftLeft, b),
        (LogicalKeyboardKey.altLeft, d),
      ]) {
        await tester.sendKeyDownEvent(pair.$1);
        await tester.tap(
          find.byKey(ValueKey('workspace header ${pair.$2.id}')),
        );
        await tester.sendKeyUpEvent(pair.$1);
        await tester.pumpAndSettle();
      }
      expect([a, b, d].every((n) => selected(n.id)), isTrue);
      for (final node in [a, b, d]) {
        expect(headerStyle(node.id).color, originalHeaders[node.id]);
        final card =
            tester
                    .widget<Container>(
                      find.byKey(ValueKey('workspace node ${node.id}')),
                    )
                    .decoration!
                as BoxDecoration;
        expect(card.color, AppPalette.dark.panel);
        expect(
          (card.border! as Border).top.color,
          AppPalette.dark.text.withAlpha(150),
        );
      }
      await capture(tester, image, 'workspace-multiple-selection');
      final before = a.position;
      await tester.drag(
        find.byKey(ValueKey('workspace header ${a.id}')),
        const Offset(30, 40),
      );
      await tester.pumpAndSettle();
      expect(a.position - before, const Offset(30, 40));
      expect(b.position, const Offset(5330, 4940));
      await shortcut(tester, LogicalKeyboardKey.keyC);
      expect(WorkspaceFragment.decode(clipboard)!.project.nodes, hasLength(3));
      await shortcut(tester, LogicalKeyboardKey.keyV);
      expect(scope.read(workspaceProvider).nodes, hasLength(6));
      await shortcut(tester, LogicalKeyboardKey.keyX);
      expect(scope.read(workspaceProvider).nodes, hasLength(3));
      await shortcut(tester, LogicalKeyboardKey.keyV);
      expect(scope.read(workspaceProvider).nodes, hasLength(6));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(scope.read(workspaceProvider).nodes, hasLength(3));
      await shortcut(tester, LogicalKeyboardKey.keyZ);
      expect(scope.read(workspaceProvider).nodes, hasLength(6));
      // Text editing keeps native clipboard shortcuts; it must not cut nodes.
      await tester.tap(find.byKey(ValueKey('workspace header ${a.id}')));
      await tester.pumpAndSettle();
      final label = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Instance label',
      );
      await tester.enterText(label, 'Example');
      await shortcut(tester, LogicalKeyboardKey.keyA);
      await shortcut(tester, LogicalKeyboardKey.keyX);
      expect(scope.read(workspaceProvider).nodes, hasLength(6));
      expect(clipboard, 'Example');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final scale in [.5, 1.0, 1.5]) {
    testWidgets(
      'junction double-click drag and context deletion at $scale zoom',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
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
              modules: const [module],
              onAdd: () {},
              onEdit: (_) {},
              onRemove: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final c = scope.read(workspaceProvider.notifier);
        final node = c.addLogicBlock(
          LogicBlockType.junction,
          const Offset(5200, 5000),
        );
        c.resizeNode(node.id, const Size(28, 28));
        final transform = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!;
        transform.value = Matrix4.identity()
          ..translateByDouble(
            400 - node.position.dx * scale,
            250 - node.position.dy * scale,
            0,
            1,
          )
          ..scaleByDouble(scale, scale, scale, 1);
        await tester.pumpAndSettle();
        final point = find.byKey(ValueKey('workspace node ${node.id}'));
        final center = tester.getCenter(point) + Offset(3 * scale, 0);
        await tester.tapAt(center);
        await tester.pump(const Duration(milliseconds: 80));
        final drag = await tester.startGesture(
          center,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        await drag.moveBy(const Offset(60, 40));
        await tester.pump();
        await drag.up();
        await tester.pumpAndSettle();
        final moved = scope.read(workspaceProvider).nodes.single.position;
        expect(moved.dx, closeTo(5200 + 60 / scale, .001));
        expect(moved.dy, closeTo(5000 + 40 / scale, .001));
        // A blank-canvas click freezes the point and restores its wire handles.
        await tester.tapAt(
          tester.getTopLeft(find.byType(InteractiveViewer)) +
              const Offset(100, 100),
        );
        await tester.pumpAndSettle();
        final target = c.addNode(module, moved + const Offset(220, 0));
        await tester.pumpAndSettle();
        final output = find.byKey(
          ValueKey('workspace port ${node.id} true output'),
        );
        expect(output, findsOneWidget);
        final wire = await tester.startGesture(tester.getCenter(output));
        await wire.moveBy(const Offset(40, 0));
        await tester.pump();
        await wire.moveTo(
          tester.getCenter(
            find.byKey(ValueKey('workspace port ${target.id} false input')),
          ),
        );
        await tester.pump();
        await wire.moveBy(const Offset(1, 0));
        await tester.pump();
        await wire.up();
        await tester.pumpAndSettle();
        expect(scope.read(workspaceProvider).nodes.first.position, moved);
        expect(scope.read(workspaceProvider).links.single.source, node.id);
        c.undo(); // connection
        c.undo(); // target
        await shortcut(tester, LogicalKeyboardKey.keyZ);
        expect(
          scope.read(workspaceProvider).nodes.single.position,
          const Offset(5200, 5000),
        );
        await tester.tap(point, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(scope.read(workspaceProvider).nodes, isEmpty);
        await shortcut(tester, LogicalKeyboardKey.keyZ);
        expect(scope.read(workspaceProvider).nodes.single.isJunction, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final light in [false, true]) {
    testWidgets(
      'junction color remains visible when selected and survives undo in ${light ? 'light' : 'dark'} theme',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
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
              modules: const [module],
              onAdd: () {},
              onEdit: (_) {},
              onRemove: (_) {},
            ),
            light: light,
          ),
        );
        await tester.pumpAndSettle();
        final c = scope.read(workspaceProvider.notifier);
        final node = c.addLogicBlock(
          LogicBlockType.junction,
          const Offset(5100, 5000),
        );
        c.resizeNode(node.id, const Size(28, 28));
        await tester.pumpAndSettle();
        final dot = find.byKey(ValueKey('workspace junction dot ${node.id}'));
        BoxDecoration decoration() =>
            tester
                    .widget<Container>(
                      find.descendant(
                        of: dot,
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        final palette = light ? AppPalette.light : AppPalette.dark;
        expect(decoration().color, palette.mutedText);
        // Use the same context-menu color command as ordinary nodes.
        await tester.tap(
          find.byKey(ValueKey('workspace node ${node.id}')),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Module color').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Purple'));
        await tester.pumpAndSettle();
        expect(node.headerColor, WorkspaceNodeColor.purple);
        expect(decoration().color, WorkspaceNodeColor.purple.tint);
        expect((decoration().border! as Border).top.color, palette.text);
        await tester.tapAt(
          tester.getTopLeft(find.byType(InteractiveViewer)) +
              const Offset(100, 400),
        );
        await tester.pumpAndSettle();
        expect(decoration().color, WorkspaceNodeColor.purple.tint);
        expect((decoration().border! as Border).top.color, palette.background);
        await shortcut(tester, LogicalKeyboardKey.keyZ);
        expect(decoration().color, palette.mutedText);
        await shortcut(tester, LogicalKeyboardKey.keyY);
        expect(decoration().color, WorkspaceNodeColor.purple.tint);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
