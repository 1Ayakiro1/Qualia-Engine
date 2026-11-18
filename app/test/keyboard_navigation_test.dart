import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/features/common/desktop_menu.dart';
import 'package:bci_engine/features/common/widgets.dart';
import 'package:bci_engine/features/modules/active_module_view.dart';
import 'package:bci_engine/features/modules/modules_screen.dart';
import 'package:bci_engine/features/modules/module_ui.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget themed(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  builder: (_, child) => AppThemeScope(palette: AppPalette.dark, child: child!),
  home: Scaffold(body: child),
);

Future<void> tab(WidgetTester tester, {bool backwards = false}) async {
  if (backwards) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (backwards) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'shared actions tab once, skip disabled and activate with Enter/Space',
    (tester) async {
      final activated = <String>[];
      await tester.pumpWidget(
        themed(
          FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Column(
              children: [
                DesktopIconButton(
                  icon: Icons.add,
                  tooltip: 'First',
                  onPressed: () => activated.add('first'),
                ),
                const DesktopIconButton(
                  icon: Icons.block,
                  tooltip: 'Disabled',
                  onPressed: null,
                ),
                DesktopHoverTile(
                  onTap: () => activated.add('second'),
                  child: const Text('Second'),
                ),
                TextButton(
                  onPressed: () => activated.add('third'),
                  child: const Text('Third'),
                ),
              ],
            ),
          ),
        ),
      );
      await tab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activated, ['first']);
      await tab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(activated, ['first', 'second']);
      await tab(tester, backwards: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, ['first', 'second', 'first']);
    },
  );

  testWidgets('dropdown opens with keyboard and arrows skip disabled actions', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      themed(
        DesktopMenuButton<String>(
          tooltip: 'Choose',
          entries: const [
            DesktopMenuEntry(value: 'one', label: 'One'),
            DesktopMenuEntry(
              value: 'disabled',
              label: 'Disabled',
              enabled: false,
            ),
            DesktopMenuEntry(value: 'two', label: 'Two'),
          ],
          onSelected: (value) => selected = value,
          child: const Text('Choose'),
        ),
      ),
    );
    await tab(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopMenuSurface<String>), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'two');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopMenuSurface<String>), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(DesktopMenuSurface<String>), findsNothing);
  });

  testWidgets('submenu uses Right/Left and returns keyboard focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        DesktopMenuButton<String>(
          tooltip: 'Colors',
          entries: const [
            DesktopMenuEntry(
              value: 'colors',
              label: 'Colors',
              submenu: [
                DesktopMenuEntry(value: 'red', label: 'Red'),
                DesktopMenuEntry(value: 'blue', label: 'Blue'),
              ],
            ),
          ],
          onSelected: (_) {},
          child: const Text('Colors'),
        ),
      ),
    );
    await tab(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Red'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Red'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Red'), findsOneWidget);
  });

  testWidgets('rail can be reached and activated through Tab without mouse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pumpAndSettle();
    bool focused = false;
    for (var i = 0; i < 80; i++) {
      await tab(tester);
      if (FocusManager.instance.primaryFocus?.debugLabel == 'Workspace') {
        focused = true;
        break;
      }
    }
    expect(focused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(ModulesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topbar menus support keyboard activation, submenus and Esc', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 30 && FocusManager.instance.primaryFocus?.debugLabel != 'View menu';
      i++
    ) {
      await tab(tester);
    }
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'View menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
    // Explorer, Terminal, Theme (disabled actions are skipped).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('White'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('White'), findsNothing);
    expect(find.text('Theme'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsNothing);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'View menu');
  });

  testWidgets(
    'module text updates from host preserve focus and local numeric drafts',
    (tester) async {
      final values = <String, dynamic>{'note': 'initial', 'count': 1};
      late StateSetter rebuild;
      await tester.pumpWidget(
        themed(
          StatefulBuilder(
            builder: (_, setState) {
              rebuild = setState;
              return ModuleControls(
                schema: const [
                  {'id': 'note', 'type': 'text', 'label': 'Note'},
                  {'id': 'count', 'type': 'number', 'label': 'Count'},
                ],
                values: values,
                onChanged: (key, value) => setState(() => values[key] = value),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'local');
      await tester.pumpAndSettle();
      final focus = FocusManager.instance.primaryFocus;
      rebuild(() => values['note'] = 'host update');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'host update',
      );
      expect(FocusManager.instance.primaryFocus, same(focus));
      await tester.enterText(find.byType(TextField).last, '2.');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '2.',
      );
      expect(values['count'], 2);
    },
  );

  testWidgets(
    'module fullscreen keeps shared settings and Esc restores workspace',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (call) async {
          return call.method == 'isFullScreen' ? false : null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('window_manager'),
          null,
        ),
      );
      addTearDown(container.dispose);
      container.read(workspaceProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: themed(
            ModulesScreen(
              modules: const [],
              onAdd: () {},
              onEdit: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final node = container
          .read(workspaceProvider.notifier)
          .addNode(
            const SystemModule(
              id: 'keyboard.module',
              name: 'Keyboard Module',
              category: 'test',
              description: 'Keyboard controls',
              manifest: {
                'ui': [
                  {
                    'id': 'active',
                    'type': 'toggle',
                    'label': 'Active',
                    'default': false,
                  },
                ],
              },
            ),
            const Offset(4900, 4900),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open').first);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ActiveModuleView>(find.byType(ActiveModuleView).last)
            .fullscreen,
        isTrue,
      );
      expect(
        tester.getSize(find.byType(ActiveModuleView).last),
        const Size(1400, 900),
      );
      await tester.tap(find.byType(DesktopToggle).last);
      await tester.pumpAndSettle();
      expect(node.settings['active'], true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ActiveModuleView), findsOneWidget);
      expect(node.settings['active'], true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.byKey(ValueKey('workspace detach ${node.id}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
