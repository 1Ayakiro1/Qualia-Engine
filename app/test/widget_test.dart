import 'package:bci_engine/app.dart';
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
}
