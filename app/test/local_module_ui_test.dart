import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/features/modules/module_ui.dart';
import 'package:bci_engine/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'module results update without turning button events into state',
    (tester) async {
      final events = <String>[];
      Widget surface(int result) => MaterialApp(
        theme: AppTheme.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AppThemeScope(
          palette: AppPalette.dark,
          child: Scaffold(
            body: ModuleControls(
              schema: const [
                {'id': 'run', 'type': 'button', 'label': 'Run'},
                {'id': 'result', 'type': 'label', 'label': 'Result'},
              ],
              values: {'result': result},
              onChanged: (id, _) => events.add(id),
            ),
          ),
        ),
      );
      await tester.pumpWidget(surface(6));
      expect(find.text('Result: 6'), findsOneWidget);
      await tester.tap(find.text('Run'));
      await tester.tap(find.text('Run'));
      expect(events, ['run', 'run']);
      await tester.pumpWidget(surface(24));
      expect(find.text('Result: 24'), findsOneWidget);
      expect(find.text('Result: 6'), findsNothing);
    },
  );
}
