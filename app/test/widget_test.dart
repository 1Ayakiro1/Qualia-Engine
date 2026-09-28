import 'package:bci_engine/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders top bar and dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ayakiro BCI Engine'), findsOneWidget);
    // The mode selector is now available from the activity rail, not the top bar.
    expect(find.byTooltip('user&dev switcher'), findsOneWidget);
    expect(find.text('Потребитель'), findsNothing);
    // Dashboard header.
    expect(find.text('Обзор'), findsWidgets);
  });

  testWidgets('mode switch panel reveals researcher mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    // Open the rail mode switcher and pick "Исследователь".
    await tester.tap(find.byTooltip('user&dev switcher'));
    await tester.pumpAndSettle();
    expect(find.text('Change mode'), findsNothing);
    await tester.tap(
      find.byTooltip('Исследователь: Датасеты, спектрограммы, эксперименты'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Исследователь'), findsNothing);
    expect(find.byTooltip('Modules'), findsOneWidget);
    expect(find.text('No active workspace items'), findsOneWidget);
    expect(find.text('ACTIVE MODULES'), findsNothing);
    expect(find.text('MODULE CATALOG'), findsNothing);
  });

  testWidgets('interface scale starts at 100% with a denser 120% visual base', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('100%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(find.text('110%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('shell shortcuts survive terminal panel toggles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(
      find.byKey(const ValueKey<String>('terminal panel toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('terminal panel toggle')),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();

    expect(find.text('110%'), findsOneWidget);
  });

  testWidgets('header menus remain available across interface scales', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    for (var index = 0; index < 5; index++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
    }
    expect(find.text('150%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('File menu button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('Edit menu button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('View menu button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('Build menu button')),
      findsOneWidget,
    );

    for (var index = 0; index < 7; index++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();
    }
    expect(find.text('80%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('File menu button')),
      findsOneWidget,
    );
  });

  testWidgets('explorer resize handle adapts the sidebar width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    final handle = find.byKey(const ValueKey<String>('explorer resize handle'));
    expect(handle, findsOneWidget);
    final before = tester.getTopLeft(handle).dx;
    await tester.drag(handle, const Offset(100, 0));
    await tester.pump();
    expect(tester.getTopLeft(handle).dx, greaterThan(before));
  });

  testWidgets('top menus and global search expose contextual actions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey<String>('File menu button')));
    await tester.pumpAndSettle();
    expect(find.text('New workspace'), findsOneWidget);
    expect(find.text('Import module (soon)'), findsOneWidget);
    await tester.tap(find.text('Preferences'));
    await tester.pumpAndSettle();
    expect(find.text('General'), findsWidgets);
    expect(find.text('Back to app'), findsOneWidget);
    expect(find.text('Integrations'), findsNothing);
    expect(find.text('Coding'), findsNothing);
    expect(find.text('ACTIVE MODULES'), findsNothing);
    expect(find.byTooltip('Modules'), findsNothing);
    await tester.tap(find.text('Back to app'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('Help menu button')));
    await tester.pumpAndSettle();
    for (final label in const <String>[
      'Documentation',
      'About Us',
      'Welcome',
      'Tutorials',
      'License',
      'Check updates',
      'Report Issue',
      'Our Youtube',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('About Us'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Version 0.4.2'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.key == const ValueKey<String>('global search field'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    expect(find.text('KEYBOARD SHORTCUTS'), findsOneWidget);
    expect(find.text('Shortcuts'), findsOneWidget);
    await tester.tap(find.text('Shortcuts'));
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsWidgets);
    expect(find.text('WORKSPACE'), findsOneWidget);
    expect(find.text('INTERFACE'), findsOneWidget);
    expect(find.text('Edit shortcuts'), findsOneWidget);
    await tester.tap(find.text('Edit shortcuts'));
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('View menu changes between system, dark and white themes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    Future<void> chooseTheme(String label) async {
      await tester.tap(find.byKey(const ValueKey<String>('View menu button')));
      await tester.pumpAndSettle();
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await chooseTheme('White');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    await chooseTheme('Dark');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    await chooseTheme('System');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
  });

  testWidgets('rail buttons navigate to sections outside the current mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Modules'));
    await tester.pumpAndSettle();

    expect(find.text('Исследователь'), findsNothing);
    expect(find.text('MODULE CATALOG'), findsOneWidget);
    expect(find.byTooltip('Modules'), findsOneWidget);
  });

  testWidgets('rail exposes extensions and configs with fast tooltips', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    final railTooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
    final extensions = railTooltips.firstWhere(
      (tooltip) => tooltip.message == 'extensions',
    );
    expect(extensions.waitDuration, const Duration(seconds: 1));

    expect(find.byTooltip('extensions'), findsOneWidget);
    await tester.tap(find.byTooltip('extensions'));
    await tester.pumpAndSettle();
    expect(find.text('EXPLORER'), findsOneWidget);
    expect(find.text('Signal Tools'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('toggle extension inspector')),
    );
    await tester.pumpAndSettle();
    expect(find.text('EXTENSION INSPECTOR'), findsOneWidget);

    await tester.tap(find.byTooltip('user&dev switcher'));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Исследователь: Датасеты, спектрограммы, эксперименты'),
      findsOneWidget,
    );
  });

  testWidgets('bug report opens as an empty rail workspace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('bug report'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('bug report'), findsOneWidget);
    expect(find.text('EXPLORER'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Signal Tools'), findsNothing);
  });

  testWidgets('extensions filter and tab controls are interactive', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('extensions'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Signal Tools'), findsWidgets);
    expect(find.text('Session Notes'), findsNothing);

    await tester.tap(find.text('Signal Tools').first);
    await tester.pumpAndSettle();
    expect(find.text('Extension details'), findsOneWidget);
    expect(find.byTooltip('Close tab'), findsOneWidget);

    await tester.tap(find.byTooltip('Close tab'));
    await tester.pumpAndSettle();
    expect(find.text('Select an extension'), findsOneWidget);
  });

  testWidgets('preferences replace the shell sidebars from the rail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('configs'));
    await tester.pumpAndSettle();

    expect(find.text('Back to app'), findsOneWidget);
    expect(find.text('General'), findsWidgets);
    expect(find.text('Pets'), findsNothing);
    expect(find.byTooltip('configs'), findsNothing);
    expect(find.text('EXPLORER'), findsNothing);

    await tester.tap(find.text('Keyboard shortcuts').last);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsWidgets);
    expect(find.text('WORKSPACE'), findsOneWidget);
  });

  testWidgets('profile and preference pages open from their own buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('User profile button'));
    await tester.pumpAndSettle();
    expect(find.text('Log in with:'), findsOneWidget);
    expect(find.text('Github'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Gmail'), findsOneWidget);
    expect(find.byTooltip('User profile button'), findsOneWidget);
    expect(find.text('EXPLORER'), findsNothing);
    await tester.tap(find.text('Back to app'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('configs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('Import 1'), findsOneWidget);

    await tester.tap(find.text('Back to app'));
    await tester.pumpAndSettle();
    expect(find.text('Обзор'), findsWidgets);
  });

  testWidgets('global search focuses, toggles its menu, and closes outside', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    final search = find.byKey(const ValueKey<String>('global search field'));
    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    expect(tester.widget<TextField>(search).focusNode?.hasFocus, isTrue);

    await tester.enterText(search, 'signal');
    expect(find.text('signal'), findsOneWidget);

    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.text('QUICK ACTIONS'), findsNothing);

    await tester.tap(search);
    await tester.pumpAndSettle();
    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    await tester.tapAt(const Offset(30, 300));
    await tester.pumpAndSettle();
    expect(find.text('QUICK ACTIONS'), findsNothing);
  });

  testWidgets('debug terminal requests an independent native window', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool launched = false;
    await tester.pumpWidget(
      ProviderScope(child: BciApp(onOpenDebugTerminal: () => launched = true)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Открыть терминал отладки'));
    await tester.pumpAndSettle();
    expect(launched, isTrue);
    expect(find.text('Debug terminal'), findsNothing);
  });

  testWidgets('active and catalog module searches are separate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Modules'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextField, 'Search active modules...'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Search modules...'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search active modules...'),
      'does-not-exist',
    );
    await tester.pump();
    expect(find.text('No active modules found'), findsOneWidget);
    expect(find.text('No modules found'), findsNothing);
  });

  testWidgets('editor tabs can be created, selected, and closed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Create new tab'), findsOneWidget);
    await tester.tap(find.byTooltip('Create new tab'));
    await tester.pumpAndSettle();
    expect(find.text('New tab'), findsOneWidget);

    await tester.tap(find.text('Устройства'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close tab'), findsWidgets);

    await tester.tap(find.byTooltip('Close tab').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close tab').first);
    await tester.pumpAndSettle();
    expect(find.text('No open tabs'), findsOneWidget);
  });

  testWidgets('Edit menu uses the themed contextual surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Run'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('Edit menu button')));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Preferences (soon)'), findsOneWidget);
    expect(find.byType(PopupMenuItem), findsNothing);
  });
}
