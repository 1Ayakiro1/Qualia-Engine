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

  testWidgets('interface scale starts at 110% and responds to shortcuts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('110%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(find.text('120%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(find.text('110%'), findsOneWidget);
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
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search files, symbols...  (Ctrl+P)',
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
}
