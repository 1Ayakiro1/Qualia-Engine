import 'package:bci_engine/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders top bar and dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ayakiro BCI Engine'), findsOneWidget);
    // Mode selector chip and engine status chip are present.
    expect(find.text('Потребитель'), findsOneWidget);
    // Dashboard header.
    expect(find.text('Обзор'), findsWidgets);
  });

  testWidgets('mode switch panel reveals researcher mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    // Open the rail mode switcher and pick "Исследователь".
    await tester.tap(find.byTooltip('Режим пользователя'));
    await tester.pumpAndSettle();
    expect(find.text('change mode'), findsOneWidget);
    await tester.tap(
      find.byTooltip('Исследователь: Датасеты, спектрограммы, эксперименты'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Исследователь'), findsOneWidget);
    expect(find.byTooltip('Конвейер'), findsOneWidget);
    expect(find.text('ACTIVE MODULES'), findsOneWidget);
  });
}
