import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/workspace/workspace_archive.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/core/workspace/workspace_project.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:bci_engine/features/common/widgets.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_manager_test.dart' show capture;

const module = SystemModule(
  id: 'grouped',
  name: 'Grouped module',
  category: 'utility',
  description: '',
);

void main() {
  setUpAll(() async {
    for (final style in ['Regular', 'Fill']) {
      final asset = style == 'Regular' ? 'Phosphor.ttf' : 'Phosphor-Fill.ttf';
      await (FontLoader('packages/phosphor_icons/Phosphor$style')..addFont(
            rootBundle.load('packages/phosphor_icons/lib/fonts/$asset'),
          ))
          .load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'scene Ctrl-click toggles individual instances with neutral selection synchronized to canvas',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final scope = ProviderContainer();
      addTearDown(scope.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: RepaintBoundary(key: boundary, child: const BciApp()),
        ),
      );
      await tester.pumpAndSettle();
      final c = scope.read(workspaceProvider.notifier);
      final a = c.addNode(module, const Offset(4900, 4900));
      final b = c.addNode(module, const Offset(5300, 4900));
      final hidden = c.addNode(module, const Offset(5700, 4900));
      c.setNodeHidden(hidden.id, true);
      await tester.pumpAndSettle();
      Finder row(String id) =>
          find.byKey(ValueKey('scene collection node $id'));
      bool selected(String id) =>
          tester.widget<DesktopHoverTile>(row(id)).selected;
      await tester.tap(row(a.id));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(row(b.id));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(selected(a.id), isTrue);
      expect(selected(b.id), isTrue);
      expect(
        tester.widget<DesktopHoverTile>(row(a.id)).selectedColor,
        AppPalette.dark.hover,
      );
      for (final node in [a, b]) {
        expect(
          tester
              .widget<Semantics>(
                find.byKey(ValueKey('workspace selection ${node.id}')),
              )
              .properties
              .selected,
          isTrue,
        );
      }
      await capture(tester, boundary, 'scene-ctrl-grey-selection');
      await tester.drag(
        find.byKey(ValueKey('workspace header ${a.id}')),
        const Offset(24, 36),
      );
      await tester.pumpAndSettle();
      expect(a.position, const Offset(4920, 4930));
      expect(b.position, const Offset(5320, 4930));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(row(a.id));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(selected(a.id), isFalse);
      expect(selected(b.id), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(row(hidden.id));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(selected(hidden.id), isTrue);
      expect(selected(b.id), isTrue);
      await tester.tap(row(a.id));
      await tester.pumpAndSettle();
      expect(selected(a.id), isTrue);
      expect(selected(b.id), isFalse);
      expect(selected(hidden.id), isFalse);
      await tester.tapAt(
        tester.getTopLeft(find.byType(InteractiveViewer)) +
            const Offset(200, 450),
      );
      await tester.pumpAndSettle();
      expect(selected(a.id), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('scene groups persist, remap imports, undo and prune deleted or transferred members', () async {
    final scope = ProviderContainer();
    scope.read(workspaceProvider);
    await Future<void>.delayed(Duration.zero);
    final c = scope.read(workspaceProvider.notifier);
    final a = c.addNode(module, Offset.zero);
    final b = c.addNode(module, const Offset(400, 0));
    c.connect(
      WorkspaceLink(
        source: a.id,
        output: 'output',
        target: b.id,
        input: 'input',
      ),
    );
    final group = c.createSceneGroup('Signals', nodeIds: {a.id, b.id});
    final other = c.createSceneGroup('Other');
    c.moveToSceneGroup({a.id}, other);
    expect(scope.read(workspaceProvider).activeProject.groups.first.nodeIds, [
      b.id,
    ]);
    c.undo();
    expect(scope.read(workspaceProvider).activeProject.groups.first.nodeIds, [
      a.id,
      b.id,
    ]);
    c.redo();
    c.renameSceneGroup(other, 'Renamed');
    expect(scope.read(workspaceProvider).links, hasLength(1));
    final snapshot = scope.read(workspaceProvider).activeProject;
    final decoded = WorkspaceArchive.decode(WorkspaceArchive.encode(snapshot));
    expect(decoded.groups.last.name, 'Renamed');
    final importedId = c.importProject(decoded, [module]);
    final imported = scope.read(workspaceProvider).activeProject;
    expect(imported.groups.last.nodeIds, [imported.nodes.first.id]);
    expect(imported.nodes.first.id, isNot(a.id));
    c.switchProject('default');
    c.moveNodesToProject({b.id}, importedId);
    expect(
      scope.read(workspaceProvider).activeProject.groups.first.nodeIds,
      isEmpty,
    );
    c.removeNode(a.id);
    expect(
      scope.read(workspaceProvider).activeProject.groups.last.nodeIds,
      isEmpty,
    );
    c.undo();
    expect(scope.read(workspaceProvider).activeProject.groups.last.nodeIds, [
      a.id,
    ]);
    c.removeSceneGroup(group);
    expect(scope.read(workspaceProvider).nodes, hasLength(1));
    await c.flushRecovery();
    scope.dispose();
    final reload = ProviderContainer();
    reload.read(workspaceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      reload.read(workspaceProvider).activeProject.groups.single.name,
      'Renamed',
    );
    expect(reload.read(workspaceProvider).activeProject.groups.single.nodeIds, [
      a.id,
    ]);
    reload.dispose();
  });

  test(
    'old documents work and invalid or duplicate group members are rejected',
    () {
      final node = WorkspaceNode(
        id: 'a',
        module: module,
        position: Offset.zero,
      );
      final json = WorkspaceProject(
        id: 'test',
        name: 'Test',
        nodes: [node],
      ).toJson();
      expect(WorkspaceProject.fromJson(json).groups, isEmpty);
      for (final members in [
        ['missing'],
        ['a', 'a'],
      ]) {
        expect(
          () => WorkspaceProject.fromJson({
            ...json,
            'groups': [
              {'id': 'group', 'name': 'Group', 'nodeIds': members},
            ],
          }),
          throwsFormatException,
        );
      }
    },
  );

  testWidgets(
    'scene objects create, collapse, search, edit and dissolve groups',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final scope = ProviderContainer();
      addTearDown(scope.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: RepaintBoundary(key: boundary, child: const BciApp()),
        ),
      );
      await tester.pumpAndSettle();
      final c = scope.read(workspaceProvider.notifier);
      final a = c.addNode(module, const Offset(4900, 4900));
      final b = c.addNode(module, const Offset(5300, 4900));
      await tester.pumpAndSettle();
      expect(find.text('SCENE OBJECTS'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scene create group')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('scene group name')),
        'Signals',
      );
      await tester.tap(find.byKey(ValueKey('scene group member ${a.id}')));
      await tester.tap(find.byKey(ValueKey('scene group member ${b.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scene group save')));
      await tester.pumpAndSettle();
      final group = scope.read(workspaceProvider).activeProject.groups.single;
      expect(group.nodeIds, [a.id, b.id]);
      final visibility = find.byKey(
        ValueKey('scene group visibility ${group.id}'),
      );
      await tester.tap(visibility);
      await tester.pumpAndSettle();
      expect(
        scope.read(workspaceProvider).hiddenNodeIds,
        containsAll([a.id, b.id]),
      );
      await tester.tap(visibility);
      await tester.pumpAndSettle();
      expect(scope.read(workspaceProvider).hiddenNodeIds, isEmpty);
      await capture(tester, boundary, 'scene-groups');
      await tester.tap(find.byKey(ValueKey('scene group ${group.id}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('scene collection node ${a.id}')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('scene collection search')),
        'Signals',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('scene collection node ${a.id}')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('scene collection search')),
        '',
      );
      await tester.pumpAndSettle();
      final menu = find.byKey(ValueKey('scene group menu ${group.id}'));
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit group'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('scene group name')),
        'Renamed',
      );
      await tester.tap(find.byKey(ValueKey('scene group member ${b.id}')));
      await tester.tap(find.byKey(const ValueKey('scene group save')));
      await tester.pumpAndSettle();
      expect(
        scope.read(workspaceProvider).activeProject.groups.single.nodeIds,
        [a.id],
      );
      c.undo();
      await tester.pumpAndSettle();
      expect(
        scope.read(workspaceProvider).activeProject.groups.single.name,
        'Signals',
      );
      expect(
        scope.read(workspaceProvider).activeProject.groups.single.nodeIds,
        [a.id, b.id],
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dissolve group'));
      await tester.pumpAndSettle();
      expect(scope.read(workspaceProvider).activeProject.groups, isEmpty);
      expect(scope.read(workspaceProvider).nodes, hasLength(2));
      final empty = c.createSceneGroup('Empty');
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey('scene collection node ${a.id}'));
      await tester.tapAt(tester.getCenter(row), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empty').last);
      await tester.pumpAndSettle();
      expect(
        scope.read(workspaceProvider).activeProject.groups.single.nodeIds,
        [a.id],
      );
      expect(
        scope.read(workspaceProvider).activeProject.groups.single.id,
        empty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final direction in [-1.0, 1.0]) {
    testWidgets(
      'canvas hint has ruler gap, swipes $direction and restores through View',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(const ProviderScope(child: BciApp()));
        await tester.pumpAndSettle();
        final hint = find.byKey(const ValueKey('workspace canvas hint false'));
        final canvas = tester.getRect(find.byType(InteractiveViewer));
        expect(tester.getRect(hint).left - canvas.left, closeTo(34 * 1.2, .01));
        await tester.drag(
          hint,
          Offset(direction * tester.getSize(hint).width, 0),
        );
        await tester.pumpAndSettle();
        expect(hint, findsNothing);
        await tester.tap(find.byKey(const ValueKey('workspace view menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Canvas hints'));
        await tester.pumpAndSettle();
        expect(hint, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
