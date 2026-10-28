import 'dart:convert';

import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/features/common/widgets.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_ux_test.dart' show shortcut;

const module = SystemModule(
  id: 'save.module',
  name: 'Save module',
  category: 'utility',
  description: 'Not needed in settings',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'recovery is not an explicit save; save, undo, redo and discard survive restart',
    (tester) async {
      var scope = ProviderContainer();
      scope.read(workspaceProvider);
      await tester.pump();
      var c = scope.read(workspaceProvider.notifier);
      expect(c.hasUnsavedChanges, isFalse);
      c.addToLibrary(module);
      expect(c.hasUnsavedChanges, isFalse);
      final node = c.addNode(module, const Offset(4900, 4900));
      expect(c.hasUnsavedChanges, isTrue);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      scope.dispose();
      scope = ProviderContainer();
      scope.read(workspaceProvider);
      await tester.pump();
      c = scope.read(workspaceProvider.notifier);
      expect(c.hasUnsavedChanges, isTrue);
      expect(scope.read(workspaceProvider).nodes.single.id, node.id);
      c.editProject('default', 'My workspace', '');
      await c.saveProgress();
      expect(c.hasUnsavedChanges, isFalse);
      c.moveNodes({node.id}, const Offset(30, 20));
      expect(c.hasUnsavedChanges, isTrue);
      c.undo();
      expect(c.hasUnsavedChanges, isFalse);
      c.redo();
      expect(c.hasUnsavedChanges, isTrue);
      await c.discardProgress();
      expect(c.hasUnsavedChanges, isFalse);
      expect(
        scope.read(workspaceProvider).nodes.single.position,
        const Offset(4900, 4900),
      );
      expect(scope.read(workspaceProvider).library.single.id, module.id);
      c.removeWorkspaceModule(module.id);
      expect(scope.read(workspaceProvider).library, isEmpty);
      await c.discardProgress();
      expect(scope.read(workspaceProvider).library.single.id, module.id);
      expect(
        scope.read(workspaceProvider).removedModuleIds,
        isNot(contains(module.id)),
      );
      expect(scope.read(workspaceProvider).nodes.single.id, node.id);
      scope.dispose();
      scope = ProviderContainer();
      addTearDown(scope.dispose);
      scope.read(workspaceProvider);
      await tester.pump();
      expect(scope.read(workspaceProvider.notifier).hasUnsavedChanges, isFalse);
      expect(scope.read(workspaceProvider).activeProject.name, 'My workspace');
    },
  );

  Future<ProviderContainer> shell(
    WidgetTester tester, {
    List<String>? nativeCalls,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('window_manager'),
      (call) async {
        nativeCalls?.add(call.method);
        if (call.method.startsWith('is')) return false;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        null,
      ),
    );
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: scope, child: const BciApp()),
    );
    await tester.pumpAndSettle();
    return scope;
  }

  testWidgets(
    'Ctrl+S names an untitled workspace, cancel keeps draft; history notice lasts five seconds',
    (tester) async {
      final scope = await shell(tester);
      final c = scope.read(workspaceProvider.notifier);
      c.addNode(module, const Offset(4900, 4900));
      await tester.pumpAndSettle();
      await shortcut(tester, LogicalKeyboardKey.keyS);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find
                  .descendant(
                    of: find.byType(AlertDialog),
                    matching: find.byType(TextField),
                  )
                  .first,
            )
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.hasUnsavedChanges, isTrue);
      await shortcut(tester, LogicalKeyboardKey.keyS);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextField),
            )
            .first,
        'Signal lab',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(scope.read(workspaceProvider).activeProject.name, 'Signal lab');
      expect(c.hasUnsavedChanges, isFalse);
      expect(find.text('Workspace saved'), findsOneWidget);
      await shortcut(tester, LogicalKeyboardKey.keyZ);
      expect(find.text('Action undone'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Action undone'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Action undone'), findsNothing);
      await shortcut(tester, LogicalKeyboardKey.keyY);
      expect(find.text('Action redone'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native close guard: cancel, save-name cancellation, discard and clean close',
    (tester) async {
      final calls = <String>[];
      final scope = await shell(tester, nativeCalls: calls);
      final c = scope.read(workspaceProvider.notifier);
      expect(calls, contains('setPreventClose'));
      c.addNode(module, const Offset(4900, 4900));
      await tester.pumpAndSettle();
      Future<void> close() async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'window_manager',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onEvent', {'eventName': 'close'}),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await close();
      expect(find.text('Save workspace changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('destroy')));
      await close();
      await tester.tap(find.widgetWithText(TextButton, 'Save workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('destroy')));
      expect(c.hasUnsavedChanges, isTrue);
      await close();
      await tester.tap(find.text("Don't save"));
      await tester.pumpAndSettle();
      expect(calls.where((method) => method == 'destroy'), hasLength(1));
      expect(scope.read(workspaceProvider).nodes, isEmpty);
      expect(c.hasUnsavedChanges, isFalse);
      await close();
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls.where((method) => method == 'destroy'), hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('top menus switch on hover only during an open menu session', (
    tester,
  ) async {
    await shell(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1500, 900));
    await mouse.moveTo(tester.getCenter(find.text('Edit').first));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    await mouse.moveTo(tester.getCenter(find.text('File').first));
    await mouse.down(tester.getCenter(find.text('File').first));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Save workspace'), findsOneWidget);
    await mouse.moveTo(tester.getCenter(find.text('Edit').first));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Save workspace'), findsNothing);
    await mouse.moveTo(tester.getCenter(find.text('View').first));
    await tester.pumpAndSettle();
    expect(find.text('Explorer'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(find.text('Edit').first));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('close save action commits a named project', (tester) async {
    final calls = <String>[];
    final scope = await shell(tester, nativeCalls: calls);
    final c = scope.read(workspaceProvider.notifier);
    c.editProject('default', 'Named', '');
    c.addNode(module, const Offset(4900, 4900));
    await tester.pumpAndSettle();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'window_manager',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onEvent', {'eventName': 'close'}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save workspace'));
    await tester.pumpAndSettle();
    expect(calls, contains('destroy'));
    expect(c.hasUnsavedChanges, isFalse);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(
      prefs.getString(WorkspaceController.savedStorageKey)!,
    ) as Map;
    expect((saved['projects'] as List).first['name'], 'Named');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'shared toggle is a compact monochrome pill with keyboard activation',
    (tester) async {
      final scope = await shell(tester);
      final node = scope
          .read(workspaceProvider.notifier)
          .addNode(module, const Offset(4900, 4900));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('workspace header ${node.id}')));
      await tester.pumpAndSettle();
      final toggle = find.byType(DesktopToggle).first;
      expect(find.text(module.description), findsNothing);
      final actions = find.descendant(
        of: find.byKey(const ValueKey('workspace inspector actions')),
        matching: find.byType(DesktopIconButton),
      );
      expect(actions, findsNWidgets(3));
      expect(
        tester.getCenter(actions.at(0)).dy,
        tester.getCenter(actions.at(1)).dy,
      );
      expect(
        tester.getCenter(actions.at(1)).dy,
        tester.getCenter(actions.at(2)).dy,
      );
      expect(tester.getSize(toggle).width, 44);
      expect(tester.getSize(toggle).height, 32);
      final state = tester.widget<DesktopToggle>(toggle);
      expect(state.value, isTrue);
      final detector = find
          .descendant(
            of: toggle,
            matching: find.byType(FocusableActionDetector),
          )
          .first;
      tester
          .widget<FocusableActionDetector>(detector)
          .focusNode!
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(tester.widget<DesktopToggle>(toggle).value, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
