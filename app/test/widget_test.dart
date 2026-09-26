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
    expect(find.text('change mode'), findsOneWidget);
    await tester.tap(
      find.byTooltip('Исследователь: Датасеты, спектрограммы, эксперименты'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Исследователь'), findsNothing);
    expect(find.byTooltip('Modules'), findsOneWidget);
    expect(find.text('ACTIVE MODULES'), findsOneWidget);
    expect(find.text('MODULE CATALOG'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Search modules...'), findsOneWidget);
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
    expect(find.text('ACTIVE MODULES'), findsNothing);
    expect(find.byTooltip('Modules'), findsNothing);
    await tester.tap(find.text('Back to app'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
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
    expect(find.text('Customize shortcuts (soon)'), findsOneWidget);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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

  testWidgets('preferences replace the shell sidebars from the rail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('configs'));
    await tester.pumpAndSettle();

    expect(find.text('Back to app'), findsOneWidget);
    expect(find.text('General'), findsWidgets);
    expect(find.byTooltip('configs'), findsNothing);
    expect(find.text('EXPLORER'), findsNothing);
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
    await tester.tap(find.byKey(const ValueKey<String>('Edit menu button')));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Preferences (soon)'), findsOneWidget);
    expect(find.byType(PopupMenuItem), findsNothing);
  });
}
