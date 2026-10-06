import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/modules/module_preview_data.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets(
    'Explorer hover menu hides, activates, edits and removes modules',
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
      await tester.tap(find.byTooltip('Workspace'));
      await tester.pumpAndSettle();
      expect(find.text('WORKSPACE PRESETS'), findsNothing);
      final preview = previewWorkspaceModules.first;
      final node = scope
          .read(workspaceProvider.notifier)
          .addNode(preview, const Offset(4820, 4820));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      addTearDown(mouse.removePointer);
      Future<void> menu() async {
        await mouse.moveTo(
          tester.getCenter(find.text('Signal Source · Preview').first),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('module settings button')).first,
        );
        await tester.pumpAndSettle();
      }

      await menu();
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(
        scope.read(workspaceProvider).hiddenModuleIds,
        contains(preview.id),
      );
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(ValueKey('workspace node ${node.id}')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, .58);
      expect(find.byIcon(Icons.visibility_off_outlined), findsWidgets);
      await menu();
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await menu();
      await tester.tap(find.text('Make inactive'));
      await tester.pumpAndSettle();
      expect(
        scope.read(workspaceProvider).moduleActiveOverrides[preview.id],
        false,
      );
      await menu();
      await tester.tap(find.text('Make active'));
      await tester.pumpAndSettle();
      expect(
        scope.read(workspaceProvider).moduleActiveOverrides[preview.id],
        true,
      );
      await menu();
      await tester.tap(find.text('Edit module').last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Module editing panel placeholder. Editing tools will be added later.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await menu();
      await tester.tap(find.text('Delete module'));
      await tester.pumpAndSettle();
      expect(scope.read(workspaceProvider).nodes, isEmpty);
      expect(find.text('Signal Source · Preview'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inactive module moves through the Explorer workspace submenu', (
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
    final target = controller.createProject('Transfer destination');
    controller.switchProject('default');
    controller.setModuleActive(module.id, false);
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Managed').first));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('module settings button')).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer destination'));
    await tester.pumpAndSettle();
    expect(scope.read(workspaceProvider).nodes, isEmpty);
    controller.switchProject(target);
    await tester.pumpAndSettle();
    expect(scope.read(workspaceProvider).nodes.single.id, node.id);
      expect(
        scope.read(workspaceProvider).moduleActiveOverrides[module.id],
        false,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
  });
}
