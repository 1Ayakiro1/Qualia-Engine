import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/app.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:bci_engine/state/workspace_providers.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/core/workspace/workspace_project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _visibilityModule = SystemModule(
  id: 'visibility.module',
  name: 'Visibility module',
  category: 'utility',
  description: '',
);

void main() {
  testWidgets(
    'partially hidden module selects on double click and restores via menu',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
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
      final controller = container.read(workspaceProvider.notifier);
      final node = controller.addNode(
        _visibilityModule,
        const Offset(4820, 4820),
      );
      controller.setNodeHidden(node.id, true);
      await tester.pumpAndSettle();
      final card = find.byKey(ValueKey('workspace node ${node.id}'));
      expect(find.byKey(ValueKey('workspace hide ${node.id}')), findsNothing);
      // A single click must not activate the dimmed node.
      await tester.tap(card);
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(container.read(selectionProvider).ids, isNot(contains(node.id)));
      await tester.tap(card);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(container.read(selectionProvider).ids, contains(node.id));
      await tester.tap(card, buttons: 2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show').last);
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceProvider).hiddenNodeIds,
        isNot(contains(node.id)),
      );
      controller.setNodeFullyHidden(node.id, true);
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      await tester.tap(
        find.byKey(ValueKey('scene collection node ${node.id}')),
        buttons: 2,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show').last);
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(
        container.read(workspaceProvider).nodes.single.fullyHidden,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('full hiding is persisted independently from partial hiding', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workspaceProvider.notifier);
    final node = controller.addNode(_visibilityModule, const Offset(40, 50));

    controller.setNodeFullyHidden(node.id, true);
    expect(container.read(workspaceProvider).nodes.single.fullyHidden, isTrue);
    expect(container.read(workspaceProvider).hiddenNodeIds, isEmpty);
    expect(node.toJson()['fullyHidden'], isTrue);
    expect(WorkspaceNode.fromJson(node.toJson()).fullyHidden, isTrue);
    final legacy = node.toJson()..remove('fullyHidden');
    expect(WorkspaceNode.fromJson(legacy).fullyHidden, isFalse);
    final package = container.read(workspaceProvider).activeProject.toPackage();
    expect(
      WorkspaceProject.fromPackage(package).nodes.single.fullyHidden,
      isTrue,
    );

    controller.undo();
    expect(container.read(workspaceProvider).nodes.single.fullyHidden, isFalse);
    controller.redo();
    expect(container.read(workspaceProvider).nodes.single.fullyHidden, isTrue);

    controller.setNodeFullyHidden(node.id, false);
    expect(container.read(workspaceProvider).nodes.single.fullyHidden, isFalse);
    expect(container.read(workspaceProvider).hiddenNodeIds, isEmpty);

    controller.setNodeHidden(node.id, true);
    expect(container.read(workspaceProvider).hiddenNodeIds, contains(node.id));
    expect(container.read(workspaceProvider).nodes.single.fullyHidden, isFalse);
    controller.setNodeHidden(node.id, false);
    expect(container.read(workspaceProvider).hiddenNodeIds, isEmpty);
  });

  test('full hiding survives saved checkpoint and recovery reopen', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    final controller = first.read(workspaceProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final node = controller.addNode(_visibilityModule, const Offset(40, 50));
    controller.setNodeFullyHidden(node.id, true);
    await controller.saveProgress();
    controller.setNodeFullyHidden(node.id, false);
    await controller.discardProgress();
    expect(first.read(workspaceProvider).nodes.single.fullyHidden, isTrue);
    await controller.flushRecovery();
    first.dispose();
    final reopened = ProviderContainer();
    addTearDown(reopened.dispose);
    reopened.read(workspaceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(reopened.read(workspaceProvider).nodes.single.fullyHidden, isTrue);
  });

  testWidgets('scene plus opens existing custom-module routes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scene add module')));
    await tester.pumpAndSettle();
    expect(find.text('Create locally'), findsOneWidget);
    expect(find.text('Create online'), findsOneWidget);
    expect(find.text('Add locally (.qmod)'), findsOneWidget);
    expect(find.text('Add online'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
