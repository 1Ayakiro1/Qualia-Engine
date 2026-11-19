import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/theme/app_icons.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/core/logic/logic_blocks.dart';
import 'package:bci_engine/features/common/desktop_menu.dart';
import 'package:bci_engine/features/common/desktop_focus.dart';
import 'package:bci_engine/features/common/navigation_bindings.dart';
import 'package:bci_engine/features/modules/modules_screen.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_manager_test.dart' show capture, themed;

const module = SystemModule(
  id: 'ux.module',
  name: 'UX Module',
  category: 'utility',
  description: '',
);
const sourceOnly = SystemModule(
  id: 'ux.source',
  name: 'Source only',
  category: 'utility',
  description: '',
  manifest: {
    'ports': {
      'inputs': <String>[],
      'outputs': ['out'],
    },
  },
);

Future<void> shortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'explorer removal undo restores library, all projects and exact graph; redo persists',
    (tester) async {
      final container = ProviderContainer();
      container.read(workspaceProvider);
      await tester.pump();
      final controller = container.read(workspaceProvider.notifier);
      controller.addToLibrary(module);
      final a = controller.addNode(module, const Offset(40, 50));
      final b = controller.addNode(module, const Offset(440, 50));
      controller.setParameter(a.id, 'gain', 7);
      controller.setPortLabel(a.id, 'output', true, 'Signal');
      controller.connect(
        WorkspaceLink(
          source: a.id,
          output: 'output',
          target: b.id,
          input: 'input',
        ),
      );
      final second = controller.createProject('Second');
      final c = controller.addNode(module, const Offset(10, 20));
      controller.switchProject('default');
      controller.setModuleHidden(module.id, true);
      controller.removeWorkspaceModule(module.id);
      expect(container.read(workspaceProvider).nodes, isEmpty);
      expect(container.read(workspaceProvider).library, isEmpty);
      controller.undo();
      final restored = container.read(workspaceProvider);
      expect(restored.removedModuleIds, isNot(contains(module.id)));
      expect(restored.library.single.id, module.id);
      expect(restored.nodes.map((n) => n.id), [a.id, b.id]);
      expect(restored.nodes.first.settings['gain'], 7);
      expect(restored.nodes.first.outputLabels['output'], 'Signal');
      expect(restored.nodes.first.position, const Offset(40, 50));
      expect(restored.links.single.source, a.id);
      expect(
        restored.projects.firstWhere((p) => p.id == second).nodes.single.id,
        c.id,
      );
      expect(restored.hiddenModuleIds, contains(module.id));
      // Mutating a restored node cannot mutate a saved history snapshot.
      controller.redo();
      expect(
        container
            .read(workspaceProvider)
            .projects
            .every((p) => p.nodes.isEmpty),
        isTrue,
      );
      controller.undo();
      controller.setModuleHidden(module.id, false);
      controller.setParameter(b.id, 'gain', 9);
      expect(controller.canRedo, isFalse);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      container.dispose();
      final reloaded = ProviderContainer();
      addTearDown(reloaded.dispose);
      reloaded.read(workspaceProvider);
      await tester.pump();
      expect(reloaded.read(workspaceProvider).nodes.map((n) => n.id), [
        a.id,
        b.id,
      ]);
      expect(reloaded.read(workspaceProvider).links, hasLength(1));
      expect(reloaded.read(workspaceProvider.notifier).canUndo, isFalse);
    },
  );

  testWidgets('group drag undo is one step and snapshots do not alias nodes', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(workspaceProvider);
    await tester.pump();
    final c = container.read(workspaceProvider.notifier);
    final node = c.addNode(module, const Offset(10, 20));
    c.beginHistoryGroup();
    c.moveNodes({node.id}, const Offset(10, 10));
    c.moveNodes({node.id}, const Offset(20, 20));
    c.endHistoryGroup();
    c.undo();
    expect(
      container.read(workspaceProvider).nodes.single.position,
      const Offset(10, 20),
    );
    c.redo();
    expect(
      container.read(workspaceProvider).nodes.single.position,
      const Offset(40, 50),
    );
    c.undo();
    c.undo();
    expect(container.read(workspaceProvider).nodes, isEmpty);
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets(
    'junction insertion preserves the original route through two edges',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(workspaceProvider);
      await tester.pump();
      final controller = container.read(workspaceProvider.notifier);
      final source = controller.addNode(sourceOnly, const Offset(80, 120));
      final target = controller.addNode(module, const Offset(520, 120));
      final link = WorkspaceLink(
        source: source.id,
        output: 'out',
        target: target.id,
        input: 'input',
      );
      controller.connect(link);
      controller.beginHistoryGroup();
      final junction = controller.insertJunction(link, const Offset(300, 120));
      controller.endHistoryGroup();

      expect(junction, isNotNull);
      expect(junction!.isJunction, isTrue);
      expect(junction.position, const Offset(300, 120));
      expect(
        junction.portPosition('input', false),
        junction.portPosition('output', true),
      );
      expect(
        junction.portPosition('output', true),
        junction.position + Offset(junction.width / 2, junction.height / 2),
      );
      final graph = container.read(workspaceProvider);
      expect(graph.links, hasLength(2));
      bool hasLink({
        required String sourceId,
        required String output,
        required String targetId,
        required String input,
      }) => graph.links.any(
        (item) =>
            item.source == sourceId &&
            item.output == output &&
            item.target == targetId &&
            item.input == input,
      );
      expect(
        hasLink(
          sourceId: source.id,
          output: 'out',
          targetId: junction.id,
          input: 'input',
        ),
        isTrue,
      );
      expect(
        hasLink(
          sourceId: junction.id,
          output: 'output',
          targetId: target.id,
          input: 'input',
        ),
        isTrue,
      );
      expect(
        LogicBlocks.run(LogicBlockType.junction, const {}, 42).single.value,
        42,
      );
      controller.undo();
      expect(
        container
            .read(workspaceProvider)
            .links
            .any(
              (item) =>
                  item.source == link.source &&
                  item.output == link.output &&
                  item.target == link.target &&
                  item.input == link.input,
            ),
        isTrue,
      );
      expect(
        container.read(workspaceProvider).nodes.any((node) => node.isJunction),
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 350));
    },
  );

  testWidgets(
    'branch route renders one port-sized dot at the shared wire anchor',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final image = GlobalKey();
      await tester.pumpWidget(
        themed(
          container,
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
      final controller = container.read(workspaceProvider.notifier);
      final source = controller.addNode(module, const Offset(4900, 4900));
      final target = controller.addNode(module, const Offset(5400, 4900));
      controller.connect(
        WorkspaceLink(
          source: source.id,
          output: 'output',
          target: target.id,
          input: 'input',
        ),
      );
      await tester.pumpAndSettle();
      final sourceRect = tester.getRect(
        find.byKey(ValueKey('workspace node ${source.id}')),
      );
      final middle = sourceRect.topLeft + const Offset(400, 69);
      await tester.tap(
        find.byKey(const ValueKey('workspace canvas tool branch')),
      );
      await tester.pumpAndSettle();
      final stroke = await tester.startGesture(middle - const Offset(0, 35));
      for (var i = 1; i <= 10; i++) {
        await stroke.moveTo(middle + Offset(0, -35 + i * 7));
        await tester.pump();
      }
      await stroke.up();
      await tester.pumpAndSettle();
      final graph = container.read(workspaceProvider);
      final junction = graph.nodes.singleWhere((node) => node.isJunction);
      expect(graph.links, hasLength(2));
      final dot = find.byKey(ValueKey('workspace junction dot ${junction.id}'));
      expect(dot, findsOneWidget);
      expect(tester.getSize(dot), const Size(10, 10));
      expect(tester.getCenter(dot), middle);
      final junctionView = find.byKey(
        ValueKey('workspace node ${junction.id}'),
      );
      expect(
        find.descendant(of: junctionView, matching: find.byIcon(AppIcons.add)),
        findsNothing,
      );
      expect(
        find.descendant(of: junctionView, matching: find.byType(Container)),
        findsOneWidget,
      );
      await capture(tester, image, 'canvas-branch-dot');

      // The left/right hit areas remain input/output without extra visible dots.
      await tester.tap(
        find.byKey(const ValueKey('workspace canvas tool select')),
      );
      await tester.pumpAndSettle();
      final third = controller.addNode(module, const Offset(5400, 5200));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('workspace port ${junction.id} true output')),
      );
      await tester.tap(
        find.byKey(ValueKey('workspace port ${third.id} false input')),
      );
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).links, hasLength(3));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final output in [true, false]) {
    testWidgets(
      'wire from ${output ? 'output' : 'input'} opens context picker and connects new module',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.dark(),
              builder: (_, child) => AppThemeScope(
                palette: AppPalette.dark,
                child: RepaintBoundary(key: captureKey, child: child!),
              ),
              home: Scaffold(
                body: ModulesScreen(
                  modules: const [module, sourceOnly],
                  onAdd: () {},
                  onEdit: (_) {},
                  onRemove: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final key in [
          'workspace project menu',
          'workspace add menu',
          'workspace select menu',
          'workspace view menu',
        ]) {
          expect(tester.getSize(find.byKey(ValueKey(key))).height, 36);
        }
        final c = container.read(workspaceProvider.notifier);
        final node = c.addNode(module, const Offset(4900, 4900));
        await tester.pumpAndSettle();
        // A mouse-selected node has the same document border as one reached
        // through keyboard focus. Moving back to the mouse must not erase it.
        final card = find.byKey(ValueKey('workspace node ${node.id}'));
        Border border() =>
            (tester.widget<Container>(card).decoration as BoxDecoration).border!
                as Border;
        expect(border().top.color, AppPalette.dark.hover);
        await tester.tap(find.byKey(ValueKey('workspace header ${node.id}')));
        await tester.pumpAndSettle();
        expect(NavigationBindings.instance.keyboardMode, isFalse);
        expect(border().top.color, AppPalette.dark.text.withAlpha(150));
        await tester.tapAt(const Offset(900, 700));
        await tester.pumpAndSettle();
        expect(border().top.color, AppPalette.dark.hover);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        // HardwareKeyboard handlers are reset between widget tests, whereas
        // the navigation service is a process singleton.
        NavigationBindings.instance.setKeyboardMode(true);
        final action = find
            .ancestor(of: card, matching: find.byType(DesktopFocusableAction))
            .first;
        final focus = find
            .descendant(
              of: action,
              matching: find.byType(FocusableActionDetector),
            )
            .first;
        tester.widget<FocusableActionDetector>(focus).focusNode!.requestFocus();
        await tester.pumpAndSettle();
        expect(NavigationBindings.instance.keyboardMode, isTrue);
        expect(border().top.color, AppPalette.dark.text.withAlpha(150));
        await tester.tap(find.byKey(ValueKey('workspace header ${node.id}')));
        await tester.pumpAndSettle();
        expect(border().top.color, AppPalette.dark.text.withAlpha(150));
        if (output) await capture(tester, captureKey, 'canvas-mouse-selection');
        final port = find.byKey(
          ValueKey(
            'workspace port ${node.id} $output ${output ? 'output' : 'input'}',
          ),
        );
        final end = const Offset(850, 500);
        final drag = await tester.startGesture(
          tester.getCenter(port),
          kind: PointerDeviceKind.mouse,
        );
        await drag.moveBy(const Offset(25, 0));
        await tester.pump();
        await drag.moveTo(end);
        await tester.pump();
        await drag.up();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(DesktopMenuSurface<String>), findsOneWidget);
        expect(
          tester.getSize(find.byType(DesktopMenuSurface<String>)).width,
          inInclusiveRange(280, 340),
        );
        expect(find.text('Add module'), findsNothing);
        if (output) {
          await capture(tester, captureKey, 'wire-module-context-menu');
        }
        if (output) expect(find.text('Source only'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('desktop menu search')),
          'UX Module',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('UX Module').last);
        await tester.pumpAndSettle();
        final state = container.read(workspaceProvider);
        expect(state.nodes, hasLength(2));
        expect(state.links, hasLength(1));
        expect(
          output ? state.links.single.source : state.links.single.target,
          node.id,
        );
        await shortcut(tester, LogicalKeyboardKey.keyZ);
        expect(container.read(workspaceProvider).nodes, hasLength(1));
        expect(container.read(workspaceProvider).links, isEmpty);
        await shortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
        expect(container.read(workspaceProvider).nodes, hasLength(2));
        expect(container.read(workspaceProvider).links, hasLength(1));
        // A successful port-to-port drop must not open the picker.
        final target = container.read(workspaceProvider).nodes.last;
        final targetPort = find.byKey(
          ValueKey(
            'workspace port ${target.id} ${!output} ${output ? 'input' : 'output'}',
          ),
        );
        final direct = await tester.startGesture(
          tester.getCenter(port),
          kind: PointerDeviceKind.mouse,
        );
        await direct.moveBy(const Offset(25, 0));
        await tester.pump();
        await direct.moveTo(tester.getCenter(targetPort));
        await tester.pump();
        await direct.up();
        await tester.pumpAndSettle();
        expect(find.byType(DesktopMenuSurface<String>), findsNothing);
        expect(container.read(workspaceProvider).links, hasLength(1));
        // Click-to-wire also supports empty-space completion; dismiss adds nothing.
        await tester.tap(port);
        await tester.tapAt(const Offset(900, 700));
        await tester.pumpAndSettle();
        expect(find.byType(DesktopMenuSurface<String>), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(container.read(workspaceProvider).nodes, hasLength(2));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'scene collection hides and restores nodes; canvas add menu remains available',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(key: captureKey, child: const BciApp()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace add menu')), findsOneWidget);
      final c = container.read(workspaceProvider.notifier);
      c.addToLibrary(module);
      c.addNode(module, const Offset(4900, 4900));
      await tester.pumpAndSettle();
      final node = container.read(workspaceProvider).nodes.single;
      final row = find.byKey(ValueKey('scene collection node ${node.id}'));
      expect(row, findsOneWidget);
      final eye = find.byKey(
        ValueKey('scene collection visibility ${node.id}'),
      );
      await tester.tap(eye);
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceProvider).hiddenNodeIds,
        contains(node.id),
      );
      await tester.tap(eye);
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceProvider).hiddenNodeIds,
        isNot(contains(node.id)),
      );
      expect(
        AppPalette.dark.searchField.computeLuminance(),
        lessThan(AppPalette.dark.background.computeLuminance()),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'hidden instances cannot be selected, dragged, deleted or focused; logic still runs',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const BciApp()),
      );
      await tester.pumpAndSettle();
      final c = container.read(workspaceProvider.notifier);
      final node = c.addLogicBlock(
        LogicBlockType.values.first,
        const Offset(4900, 4900),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(ValueKey('workspace header ${node.id}'));
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(ValueKey('workspace selection ${node.id}')),
            )
            .properties
            .selected,
        isTrue,
      );
      c.setModuleHidden(node.module.id, true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(ValueKey('workspace selection ${node.id}')),
            )
            .properties
            .selected,
        isFalse,
      );
      expect(node.runtimeStatus, isNot('stopped'));
      await tester.drag(header, const Offset(100, 80), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(node.position, const Offset(4900, 4900));
      await shortcut(tester, LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).nodes.single.id, node.id);
      final focus = find.descendant(
        of: find.byKey(ValueKey('workspace node ${node.id}')),
        matching: find.byType(FocusableActionDetector),
      );
      for (final widget in tester.widgetList<FocusableActionDetector>(focus)) {
        expect(widget.focusNode?.canRequestFocus ?? false, isFalse);
      }
      c.setModuleHidden(node.module.id, false);
      await tester.pumpAndSettle();
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find.byKey(ValueKey('workspace selection ${node.id}')),
            )
            .properties
            .selected,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
