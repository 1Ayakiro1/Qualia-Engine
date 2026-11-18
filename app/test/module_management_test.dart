import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/modules/module_preview_data.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/logic/logic_blocks.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:bci_engine/features/common/widgets.dart';
import 'package:bci_engine/features/modules/modules_screen.dart';
import 'package:bci_engine/features/modules/workspace_connections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_manager_test.dart' show capture;

const module = SystemModule(
  id: 'managed',
  name: 'Managed',
  category: 'utility',
  description: '',
  active: true,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('module visibility, activity, removal and transfers persist', () async {
    var scope = ProviderContainer();
    scope.read(workspaceProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = scope.read(workspaceProvider.notifier);
    controller.addToLibrary(module);
    final a = controller.addNode(module, const Offset(4800, 4800));
    final b = controller.addNode(module, const Offset(5200, 4800));
    final c = controller.addNode(module, const Offset(5600, 4800));
    controller.setParameter(a.id, 'gain', 3);
    controller.connect(
      WorkspaceLink(
        source: a.id,
        output: 'output',
        target: b.id,
        input: 'input',
      ),
    );
    controller.connect(
      WorkspaceLink(
        source: b.id,
        output: 'output',
        target: c.id,
        input: 'input',
      ),
    );
    final target = controller.createProject('Target');
    controller.switchProject('default');
    controller.setModuleActive(module.id, false);
    controller.setModuleHidden(module.id, true);
    controller.moveNodesToProject({a.id, b.id}, target);
    expect(scope.read(workspaceProvider).nodes.single.id, c.id);
    expect(scope.read(workspaceProvider).links, isEmpty);
    controller.switchProject(target);
    expect(scope.read(workspaceProvider).nodes.length, 2);
    expect(scope.read(workspaceProvider).links.single.source, a.id);
    expect(scope.read(workspaceProvider).nodes.first.settings['gain'], 3);
    expect(
      scope.read(workspaceProvider).nodes.first.position,
      const Offset(4800, 4800),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    scope.dispose();
    scope = ProviderContainer();
    scope.read(workspaceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(scope.read(workspaceProvider).hiddenModuleIds, contains(module.id));
    expect(
      scope.read(workspaceProvider).moduleActiveOverrides[module.id],
      false,
    );
    expect(scope.read(workspaceProvider).nodes.length, 2);
    scope.read(workspaceProvider.notifier).removeWorkspaceModule(module.id);
    expect(
      scope
          .read(workspaceProvider)
          .projects
          .every((p) => p.nodes.isEmpty && p.links.isEmpty),
      true,
    );
    expect(scope.read(workspaceProvider).library, isEmpty);
    expect(scope.read(workspaceProvider).removedModuleIds, contains(module.id));
    scope.read(workspaceProvider.notifier).addToLibrary(module);
    expect(
      scope.read(workspaceProvider).removedModuleIds,
      isNot(contains(module.id)),
    );
    scope.dispose();
  });

  testWidgets('Scene Collection selects and hides module instances', (
    tester,
  ) async {
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
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    expect(find.text('WORKSPACE PRESETS'), findsNothing);
    final preview = previewWorkspaceModules.first;
    final node = scope
        .read(workspaceProvider.notifier)
        .addNode(preview, const Offset(4820, 4820));
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('scene collection node ${node.id}'));
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(scope.read(workspaceProvider).nodes.single.id, node.id);
    final eye = find.byKey(ValueKey('scene collection visibility ${node.id}'));
    await tester.tap(eye);
    await tester.pumpAndSettle();
    expect(scope.read(workspaceProvider).hiddenNodeIds, contains(node.id));
    expect(find.byKey(ValueKey('workspace node ${node.id}')), findsOneWidget);
    await tester.tap(eye);
    await tester.pumpAndSettle();
    expect(
      scope.read(workspaceProvider).hiddenNodeIds,
      isNot(contains(node.id)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scene pane owns settings and edits only the selected instance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    final image = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: RepaintBoundary(key: image, child: const BciApp()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    final controller = scope.read(workspaceProvider.notifier);
    final first = controller.addNode(module, const Offset(4900, 4900));
    final second = controller.addNode(module, const Offset(5280, 4900));
    await tester.pumpAndSettle();
    final pane = find.byKey(const ValueKey('workspace scene collection pane'));
    await tester.tap(find.byKey(ValueKey('workspace header ${first.id}')));
    await tester.pumpAndSettle();
    expect(find.text('MODULE SETTINGS'), findsNothing);
    expect(
      find.byKey(const ValueKey('scene module settings block')),
      findsNothing,
    );
    final actions = find.byKey(const ValueKey('workspace inspector actions'));
    expect(find.descendant(of: pane, matching: actions), findsOneWidget);
    final objects = tester.getRect(
      find.byKey(const ValueKey('scene objects block')),
    );
    expect(tester.getRect(actions).top, greaterThan(objects.bottom + 12));
    final enabled = find
        .descendant(
          of: find.descendant(
            of: pane,
            matching: find.byKey(const ValueKey('enabled-toggle')),
          ),
          matching: find.byType(DesktopToggle),
        )
        .first;
    await tester.tap(enabled);
    await tester.pumpAndSettle();
    expect(
      scope.read(workspaceProvider).nodes.first.settings['enabled'],
      false,
    );
    expect(
      scope.read(workspaceProvider).nodes.last.settings['enabled'],
      isNull,
    );
    await tester.tap(
      find.byKey(ValueKey('scene collection node ${second.id}')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<DesktopToggle>(enabled).value, true);
    await capture(tester, image, 'scene-selection-settings');
    final open = find
        .descendant(of: actions, matching: find.byType(DesktopIconButton))
        .first;
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace canvas drop target')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('workspace inspector add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add module').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace canvas drop target')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('desktop menu search')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'hidden scene instances stay editable and reveal only themselves',
    (tester) async {
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
      final controller = scope.read(workspaceProvider.notifier);
      final first = controller.addNode(module, const Offset(4900, 4900));
      final second = controller.addNode(module, const Offset(5300, 4900));
      controller.connect(
        WorkspaceLink(
          source: first.id,
          output: 'output',
          target: second.id,
          input: 'input',
        ),
      );
      controller.setModuleHidden(module.id, true);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('scene collection node ${first.id}')),
      );
      await tester.pumpAndSettle();
      final inspector = find.byType(WorkspaceInspector);
      expect(tester.widget<WorkspaceInspector>(inspector).node?.id, first.id);
      final visibility = find.byKey(
        const ValueKey('workspace object visibility'),
      );
      await tester.ensureVisible(visibility);
      await tester.pumpAndSettle();
      expect(tester.widget<DesktopToggle>(visibility).value, isFalse);
      await tester.tap(visibility);
      await tester.pumpAndSettle();
      expect(
        scope.read(workspaceProvider).hiddenModuleIds,
        isNot(contains(module.id)),
      );
      expect(
        scope.read(workspaceProvider).hiddenNodeIds,
        isNot(contains(first.id)),
      );
      expect(scope.read(workspaceProvider).hiddenNodeIds, contains(second.id));
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<WorkspaceConnectionsPainter>()
          .single;
      expect(
        painter.nodes.map((n) => n.id),
        containsAll([first.id, second.id]),
      );
      expect(painter.links, hasLength(1));
      expect(painter.dimmedNodeIds, contains(second.id));

      await tester.tap(
        find.byKey(ValueKey('scene collection visibility ${second.id}')),
      );
      await tester.pumpAndSettle();
      expect(
        scope.read(workspaceProvider).hiddenNodeIds,
        isNot(contains(second.id)),
      );
      await tester.tap(
        find.byKey(ValueKey('scene collection visibility ${first.id}')),
      );
      await tester.pumpAndSettle();
      // Hidden object remains the inspector target, not a canvas selection.
      expect(tester.widget<WorkspaceInspector>(inspector).node?.id, first.id);
      expect(tester.widget<WorkspaceInspector>(inspector).hidden, isTrue);
      await tester.tap(
        find.byKey(ValueKey('scene collection object toggle ${second.id}')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<WorkspaceInspector>(inspector).node?.id, second.id);
      await tester.tap(find.text('Position and size'));
      await tester.pumpAndSettle();
      final x = find.descendant(
        of: inspector,
        matching: find.widgetWithText(TextField, 'X'),
      );
      await tester.ensureVisible(x);
      await tester.pumpAndSettle();
      await tester.enterText(x, '5250');
      await tester.pumpAndSettle();
      expect(scope.read(workspaceProvider).nodes.last.position.dx, 5250);
      expect(scope.read(workspaceProvider).nodes.first.position.dx, 4900);
      final width = find
          .descendant(
            of: inspector,
            matching: find.widgetWithText(TextField, 'Width'),
          )
          .first;
      await tester.ensureVisible(width);
      await tester.pumpAndSettle();
      await tester.enterText(width, '380');
      await tester.pumpAndSettle();
      expect(scope.read(workspaceProvider).nodes.last.width, 380);
      expect(
        scope.read(workspaceProvider).nodes.first.width,
        WorkspaceNode.defaultWidth,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('revealing package-hidden instance preserves siblings across workspaces and undo', () async {
    final scope = ProviderContainer();
    scope.read(workspaceProvider);
    await Future<void>.delayed(Duration.zero);
    final controller = scope.read(workspaceProvider.notifier);
    final first = controller.addNode(module, Offset.zero);
    final sibling = controller.addNode(module, const Offset(400, 0));
    final otherProject = controller.createProject('Other');
    final other = controller.addNode(module, Offset.zero);
    controller.switchProject('default');
    controller.setModuleHidden(module.id, true);
    controller.setNodeHidden(first.id, false);
    expect(
      scope.read(workspaceProvider).hiddenNodeIds,
      containsAll([sibling.id, other.id]),
    );
    expect(
      scope.read(workspaceProvider).hiddenNodeIds,
      isNot(contains(first.id)),
    );
    controller.undo();
    expect(scope.read(workspaceProvider).hiddenModuleIds, contains(module.id));
    controller.redo();
    controller.switchProject(otherProject);
    expect(scope.read(workspaceProvider).hiddenNodeIds, contains(other.id));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    scope.dispose();
    final reloaded = ProviderContainer();
    reloaded.read(workspaceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      reloaded.read(workspaceProvider).hiddenModuleIds,
      isNot(contains(module.id)),
    );
    expect(
      reloaded.read(workspaceProvider).hiddenNodeIds,
      containsAll([sibling.id, other.id]),
    );
    reloaded.dispose();
  });

  testWidgets('Scene Collection mixes logic blocks and modules with collapse', (
    tester,
  ) async {
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
    final controller = scope.read(workspaceProvider.notifier);
    final moduleNode = controller.addNode(
      previewWorkspaceModules.first,
      const Offset(4820, 4820),
    );
    final logicNode = controller.addLogicBlock(
      LogicBlockType.values.first,
      const Offset(5100, 4820),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('scene collection node ${moduleNode.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('scene collection node ${logicNode.id}')),
      findsOneWidget,
    );
    final toggle = find.byKey(
      ValueKey('scene collection object toggle ${moduleNode.id}'),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.textContaining(moduleNode.module.id), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.textContaining(moduleNode.module.id), findsNothing);
  });

  testWidgets('inactive module remains movable through workspace actions', (
    tester,
  ) async {
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
    final controller = scope.read(workspaceProvider.notifier);
    controller.addToLibrary(module);
    final node = controller.addNode(module, const Offset(4820, 4820));
    controller.setModuleActive(module.id, false);
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workspace add menu')), findsOneWidget);
    expect(scope.read(workspaceProvider).nodes.single.id, node.id);
    expect(
      scope.read(workspaceProvider).moduleActiveOverrides[module.id],
      false,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
