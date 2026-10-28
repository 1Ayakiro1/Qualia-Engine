import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/logging/app_logger.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/features/common/widgets.dart';
import 'package:bci_engine/features/shell/app_shell.dart';
import 'package:bci_engine/features/shell/rail_settings.dart';
import 'package:bci_engine/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openDashboard(WidgetTester tester) async {
  // Dashboard is optional in the rail and no longer the startup tab.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AppShell)),
  );
  container.read(railProvider.notifier).setSection(SectionId.dashboard, true);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Dashboard'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('app shell starts directly on the module canvas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ayakiro BCI Engine'), findsOneWidget);
    expect(find.byTooltip('user&dev switcher'), findsNothing);
    expect(find.text('Потребитель'), findsNothing);
    expect(find.byKey(const ValueKey('workspace add menu')), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('Workspace remains available without the rail mode switcher', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('user&dev switcher'), findsNothing);
    expect(find.text('Change mode'), findsNothing);
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Исследователь'), findsNothing);
    expect(find.byTooltip('Workspace'), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace add menu')), findsOneWidget);
    expect(find.text('ACTIVE MODULES'), findsWidgets);
    expect(find.text('MODULE CATALOG'), findsWidgets);
  });

  testWidgets('Entity section supports adding and installing neural networks', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Entity'), findsWidgets);
    await tester.tap(find.byTooltip('Entity').last);
    await tester.pumpAndSettle();
    expect(find.text('ENTITY CATALOG'), findsOneWidget);
    expect(find.text('Artifact Detector'), findsWidgets);

    await tester.tap(find.text('Artifact Detector').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    expect(find.text('Uninstall'), findsOneWidget);

    await tester.tap(find.byTooltip('Add entity').last);
    await tester.pumpAndSettle();
    expect(find.text('Add entity'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('New neural entity'), findsWidgets);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('Explorer separates offline and online module actions', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add module').first);
    await tester.pumpAndSettle();
    expect(find.text('Create locally'), findsOneWidget);
    expect(find.text('Create online'), findsOneWidget);
    expect(find.text('Add locally (.qmod)'), findsOneWidget);
    expect(find.text('Add online'), findsOneWidget);
    await tester.tap(find.text('Add online'));
    await tester.pumpAndSettle();
    expect(find.text('EXPLORER'), findsNothing);
  });

  testWidgets('interface scale starts at 100% with a denser 120% visual base', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('100%'), findsWidgets);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(find.text('110%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(find.text('100%'), findsWidgets);
  });

  testWidgets('shell shortcuts survive terminal panel toggles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await openDashboard(tester);

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

  testWidgets('canvas zoom shortcuts follow hover without a canvas click', (
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
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    final viewer = find.byType(InteractiveViewer);
    final transform = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getTopLeft(viewer) + const Offset(100, 100));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(transform.value.getMaxScaleOnAxis(), lessThan(1));
    expect(find.text('100%'), findsWidgets);
    await mouse.moveTo(tester.getCenter(find.byTooltip('Workspace')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('90%'), findsOneWidget);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
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
    // The transformed scaffold must fill the window, even below the base scale.
    final shell = find
        .descendant(of: find.byType(AppShell), matching: find.byType(Scaffold))
        .first;
    final shellRect = tester.getRect(shell);
    expect(shellRect.left, closeTo(0, .01));
    expect(shellRect.top, closeTo(0, .01));
    expect(shellRect.width, closeTo(1400, .01));
    expect(shellRect.height, closeTo(800, .01));
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
    expect(find.byTooltip('Workspace'), findsNothing);
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
    expect(find.textContaining('Version 0.5.2-dev.2'), findsOneWidget);
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
    expect(find.text('Navigation'), findsWidgets);
    expect(find.text('WORKSPACE'), findsOneWidget);
    expect(find.text('INTERFACE'), findsOneWidget);
    expect(find.byKey(const ValueKey('edit navigation next')), findsOneWidget);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('topbar switches directly between adjacent context menus', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const ValueKey<String>('File menu button')));
    await tester.pumpAndSettle();
    expect(find.text('New workspace'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('View menu button')));
    await tester.pumpAndSettle();
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('New workspace'), findsNothing);
  });

  testWidgets('notification button shows the empty notification panel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    final button = find.byKey(const ValueKey<String>('notifications button'));
    expect(button, findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('No notifications'), findsOneWidget);
  });

  testWidgets('View menu changes between system, dark and white themes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    AppPalette paletteOf() =>
        AppThemeScope.of(tester.element(find.byType(AppShell)));

    // Dark-first default.
    expect(paletteOf().brightness, Brightness.dark);

    Future<void> chooseTheme(String label) async {
      await tester.tap(find.byKey(const ValueKey<String>('View menu button')));
      await tester.pumpAndSettle();
      expect(find.text('Theme'), findsOneWidget);
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);
      await tester.tap(find.text(label));
      // Run the frame that applies the mode change and starts the ticker,
      // so callers can observe the cross-fade mid-flight.
      await tester.pump();
    }

    // The switch to White cross-fades: mid-flight the palette is neither
    // endpoint, and it settles on the light tokens afterwards.
    await chooseTheme('White');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    await tester.pump(const Duration(milliseconds: 40));
    final AppPalette midTransition = paletteOf();
    expect(midTransition.background, isNot(AppPalette.light.background));
    expect(midTransition.background, isNot(AppPalette.dark.background));
    await tester.pumpAndSettle();
    expect(paletteOf().background, AppPalette.light.background);
    expect(paletteOf().brightness, Brightness.light);
    expect(find.byType(ColorFiltered), findsNothing);

    await chooseTheme('Dark');
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(paletteOf().background, AppPalette.dark.background);
    expect(paletteOf().brightness, Brightness.dark);

    // System mode resolves through the test platform brightness (light).
    await chooseTheme('System');
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    expect(paletteOf().brightness, Brightness.light);
  });

  testWidgets('rail buttons navigate to sections outside the current mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Исследователь'), findsNothing);
    expect(find.text('MODULE CATALOG'), findsOneWidget);
    expect(find.byTooltip('Workspace'), findsOneWidget);
  });

  testWidgets('rail exposes Marketplace with shared tooltips', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    final railTooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
    final extensions = railTooltips.firstWhere(
      (tooltip) => tooltip.message == 'Marketplace',
    );
    expect(extensions.waitDuration, const Duration(seconds: 1));

    expect(find.byTooltip('Marketplace'), findsOneWidget);
    await tester.tap(find.byTooltip('Marketplace'));
    await tester.pumpAndSettle();
    expect(find.text('EXPLORER'), findsNothing);
    expect(
      find.byKey(const ValueKey('marketplace search field')),
      findsOneWidget,
    );

    expect(
      find.byKey(const ValueKey<String>('toggle extension inspector')),
      findsNothing,
    );

    expect(find.byTooltip('user&dev switcher'), findsNothing);
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

  testWidgets('Marketplace replaces Explorer and active zone with catalog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Marketplace'));
    await tester.pumpAndSettle();

    expect(find.text('EXPLORER'), findsNothing);
    expect(find.byTooltip('Create new tab'), findsNothing);
    expect(find.text('Extensions'), findsOneWidget);
    expect(find.text('Modules'), findsOneWidget);
    expect(find.text('Themes'), findsOneWidget);
    await tester.tap(find.text('Themes'));
    await tester.pumpAndSettle();
    expect(find.text('Qualia Dark'), findsOneWidget);
    expect(find.text('Sort by'), findsNothing);
  });

  testWidgets('activity rail resizes on Profile, Extensions and Bug Report', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    for (final destination in const [
      'Marketplace',
      'User profile button',
      'bug report',
    ]) {
      await tester.tap(find.byTooltip(destination));
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey<String>('activity rail surface'));
      final initialWidth = tester.getSize(rail).width;
      await tester.drag(
        find.byKey(const ValueKey<String>('rail resize handle')),
        const Offset(24, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, greaterThan(initialWidth));
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('Marketplace adapts without an Explorer pane', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Marketplace'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('extensions explorer pane')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('extensions resize handle')),
      findsNothing,
    );
    await tester.tap(find.text('Modules'));
    await tester.pumpAndSettle();
    expect(find.text('Signal Source · Preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('module explorer groups collapse vertically', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('active module search')),
      findsOneWidget,
    );
    await tester.tap(find.text('ACTIVE MODULES'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('active module search')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('catalog module search')),
      findsOneWidget,
    );

    await tester.tap(find.text('MODULE CATALOG'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('catalog module search')),
      findsNothing,
    );
  });

  testWidgets('Rail settings can hide individual sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Rail settings'));
    await tester.pumpAndSettle();

    final workspace = find.byKey(
      const ValueKey('rail available section:modules'),
    );
    await tester.scrollUntilVisible(
      workspace,
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('rail settings scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(workspace), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(workspace);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Workspace'), findsNothing);
  });

  testWidgets('built-in theme can be applied from Marketplace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Marketplace'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Themes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Qualia Light'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Qualia Light')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qualia Light'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply theme'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
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

    await tester.ensureVisible(find.text('Navigation').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Navigation').last);
    await tester.pumpAndSettle();
    expect(find.text('Navigation'), findsWidgets);
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
    expect(find.text('GitHub'), findsOneWidget);
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
    expect(find.byKey(const ValueKey('workspace add menu')), findsOneWidget);
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

    await tester.tap(find.byTooltip('Open debug terminal'));
    await tester.pumpAndSettle();
    expect(launched, isTrue);
    expect(find.text('Debug terminal'), findsNothing);
  });

  testWidgets('active and catalog module searches are separate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Workspace'));
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
    expect(find.text('Signal Source · Preview'), findsOneWidget);
  });

  testWidgets('editor tabs can be created, selected, and closed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));
    // The canvas intentionally has no generic tab strip; other sections retain it.
    await openDashboard(tester);

    expect(find.byTooltip('Create new tab'), findsOneWidget);
    final createTab = find.byKey(
      const ValueKey<String>('create new tab button'),
    );
    expect(tester.getSize(createTab), const Size(30, 30));
    expect(find.byTooltip('Create new tab'), findsOneWidget);
    await tester.tap(find.byTooltip('Create new tab'));
    await tester.pumpAndSettle();
    expect(find.text('New tab'), findsOneWidget);

    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close tab'), findsWidgets);

    await tester.tap(find.byTooltip('Close tab').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close tab').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close tab').first);
    await tester.pumpAndSettle();
    expect(find.text('No open tabs'), findsOneWidget);
  });

  testWidgets('hover highlights fade in over the shared hover duration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pumpAndSettle();

    // The rail highlight is painted by the DecoratedBox the AnimatedContainer
    // renders, so its color reflects the in-flight animation rather than the
    // target the widget configuration already carries.
    BoxDecoration railHighlight(Finder tooltip) =>
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: tooltip,
                        matching: find.byType(DecoratedBox),
                      )
                      .last,
                )
                .decoration
            as BoxDecoration;

    final button = find.byTooltip('bug report');
    final start = railHighlight(button).color;

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(button));
    await tester.pump();
    final early = railHighlight(button).color;
    await tester.pump(AppTheme.hoverDuration ~/ 2);
    final midway = railHighlight(button).color;
    await tester.pump(AppTheme.hoverDuration);
    final settled = railHighlight(button).color;

    expect(early, start);
    expect(midway, isNot(start));
    expect(midway, isNot(settled));
    expect(settled, AppPalette.dark.hover);
  });

  testWidgets('titlebar controls align to its center and window edge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pumpAndSettle();

    final titlebar = find.byKey(const ValueKey<String>('shell titlebar'));
    final fileMenu = find.byKey(const ValueKey<String>('File menu button'));
    final closeButton = find.byTooltip('Close window');
    final barRect = tester.getRect(titlebar);
    final menuRect = tester.getRect(fileMenu);
    final closeRect = tester.getRect(closeButton);

    expect((menuRect.center.dy - barRect.center.dy).abs(), lessThan(0.5));
    expect((barRect.right - closeRect.right).abs(), closeTo(3.6, 0.5));
  });

  testWidgets('user actions land in the debug log with their source', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pumpAndSettle();
    await openDashboard(tester);

    // Tab creation through the tab strip plus button.
    final int beforeTabs = AppLogger.instance.length;
    await tester.tap(find.byTooltip('Create new tab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devices').last);
    await tester.pumpAndSettle();
    expect(
      AppLogger.instance
          .snapshot()
          .skip(beforeTabs)
          .any((e) => e.source == 'shell' && e.message.contains('таб открыт')),
      isTrue,
    );

    // Theme switch through the View menu.
    final int beforeTheme = AppLogger.instance.length;
    await tester.tap(find.byKey(const ValueKey<String>('View menu button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('White'));
    await tester.pumpAndSettle();
    expect(
      AppLogger.instance
          .snapshot()
          .skip(beforeTheme)
          .any((e) => e.source == 'ui' && e.message.contains('тема')),
      isTrue,
    );
  });

  testWidgets(
    'shared desktop action controls use rectangular tab close targets',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: BciApp()));
      await tester.pump(const Duration(milliseconds: 100));
      await openDashboard(tester);

      expect(find.byTooltip('Close tab'), findsNWidgets(2));
      final close = find.byTooltip('Close tab').first;
      expect(tester.getSize(close), const Size(22, 22));
      expect(find.byType(DesktopIconButton), findsWidgets);
    },
  );

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
