import 'package:bci_engine/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell renders top bar and dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ayakiro BCI Engine'), findsOneWidget);
    // Mode selector chip and engine status chip are present.
    expect(find.text('Потребитель'), findsOneWidget);
    // Dashboard header.
    expect(find.text('Обзор'), findsWidgets);
  });

  testWidgets('mode switch reveals researcher sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pump(const Duration(milliseconds: 100));

    // Open the mode menu and pick "Исследователь".
    await tester.tap(find.text('Потребитель'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Исследователь').last);
    await tester.pumpAndSettle();

    expect(find.text('Спектрограмма'), findsOneWidget);
    expect(find.text('Конвейер'), findsOneWidget);
  });
}
