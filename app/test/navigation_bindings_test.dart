import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/features/common/desktop_focus.dart';
import 'package:bci_engine/features/common/desktop_menu.dart';
import 'package:bci_engine/features/common/navigation_bindings.dart';
import 'package:bci_engine/features/common/widgets.dart';
import 'package:bci_engine/features/modules/active_module_view.dart';
import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  builder: (_, child) => AppThemeScope(
    palette: AppPalette.dark,
    child: NavigationScope(child: child!),
  ),
  home: Scaffold(body: child),
);

bool hasBorder(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(DesktopFocusableAction),
        matching: find.byType(DecoratedBox),
      ),
    )
    .any(
      (box) =>
          box.decoration is BoxDecoration &&
          (box.decoration as BoxDecoration).border != null,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NavigationBindings.instance.load();
    NavigationBindings.instance.setKeyboardMode(false);
  });
  testWidgets(
    'focus border appears only for keyboard navigation, mouse and typing do not enable it',
    (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        app(
          Column(
            children: [
              DesktopFocusableAction(
                focusNode: node,
                onActivate: () {},
                child: const Text('Action'),
              ),
              const TextField(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      node.requestFocus();
      await tester.pump();
      expect(hasBorder(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      node.requestFocus();
      await tester.pump();
      expect(hasBorder(tester), isTrue);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(const Offset(100, 100));
      await tester.pump();
      expect(hasBorder(tester), isFalse);
      await tester.tap(find.byType(TextField));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(NavigationBindings.instance.keyboardMode, isFalse);
      await mouse.removePointer();
    },
  );
  testWidgets(
    'remapped traversal and activation work; defaults no longer execute',
    (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        app(
          Column(
            children: [
              DesktopIconButton(
                icon: Icons.add,
                tooltip: 'First',
                onPressed: () => activated++,
              ),
              DesktopIconButton(
                icon: Icons.add,
                tooltip: 'Second',
                onPressed: () => activated += 10,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await NavigationBindings.instance.setBinding(
        NavigationAction.next,
        const NavigationChord(LogicalKeyboardKey.f6),
      );
      await NavigationBindings.instance.setBinding(
        NavigationAction.activate,
        const NavigationChord(LogicalKeyboardKey.f7),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f6);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'First');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.f7);
      expect(activated, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'First');
      await tester.sendKeyEvent(LogicalKeyboardKey.f6);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Second');
      await tester.sendKeyEvent(LogicalKeyboardKey.f7);
      expect(activated, 11);
    },
  );
  testWidgets('remapped menu movement and dismiss work', (tester) async {
    String? selected;
    await tester.pumpWidget(
      app(
        DesktopMenuButton<String>(
          tooltip: 'Menu',
          entries: const [
            DesktopMenuEntry(value: 'one', label: 'One'),
            DesktopMenuEntry(value: 'two', label: 'Two'),
          ],
          onSelected: (value) => selected = value,
          child: const Text('Menu'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await NavigationBindings.instance.setBinding(
      NavigationAction.menuDown,
      const NavigationChord(LogicalKeyboardKey.f6),
    );
    await NavigationBindings.instance.setBinding(
      NavigationAction.dismiss,
      const NavigationChord(LogicalKeyboardKey.f8),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'two');
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('One'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    await tester.pumpAndSettle();
    expect(find.text('One'), findsNothing);
  });
  testWidgets('fullscreen and back use edited shortcuts', (tester) async {
    var fullscreen = 0, back = 0;
    final node = WorkspaceNode(
      id: 'test',
      module: const SystemModule(
        id: 'test',
        name: 'Test',
        category: 'Test',
        description: '',
      ),
    );
    await tester.pumpWidget(
      app(
        ActiveModuleView(
          node: node,
          onBack: () => back++,
          onChanged: (_, _) {},
          onFullscreen: () => fullscreen++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await NavigationBindings.instance.setBinding(
      NavigationAction.fullscreen,
      const NavigationChord(LogicalKeyboardKey.f6),
    );
    await NavigationBindings.instance.setBinding(
      NavigationAction.dismiss,
      const NavigationChord(LogicalKeyboardKey.f8),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f11);
    expect(fullscreen, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    expect(fullscreen, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    expect(back, 1);
  });
  test('settings survive reload and conflicting edits are rejected', () async {
    final bindings = NavigationBindings.instance;
    expect(
      await bindings.setBinding(
        NavigationAction.next,
        const NavigationChord(LogicalKeyboardKey.f6),
      ),
      isTrue,
    );
    expect(
      await bindings.setBinding(
        NavigationAction.previous,
        const NavigationChord(LogicalKeyboardKey.tab),
      ),
      isTrue,
    );
    await bindings.load();
    expect(bindings.label(NavigationAction.next), 'F6');
    expect(bindings.label(NavigationAction.previous), 'Tab');
    expect(
      await bindings.setBinding(
        NavigationAction.activate,
        const NavigationChord(LogicalKeyboardKey.f6),
      ),
      isFalse,
    );
    await bindings.reset();
    expect(bindings.label(NavigationAction.next), 'Tab');
  });
}
