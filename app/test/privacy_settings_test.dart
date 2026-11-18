import 'package:bci_engine/core/privacy/privacy_preferences.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/features/common/widgets.dart';
import 'package:bci_engine/features/settings/settings_screen.dart';
import 'package:bci_engine/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final language in ['en', 'ru']) {
    testWidgets('privacy opt-ins are visible and persisted ($language)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await PrivacyPreferences.instance.load();
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.dark(),
            builder: (_, child) =>
                AppThemeScope(palette: AppPalette.dark, child: child!),
            home: const Scaffold(body: SettingsScreen(initialItem: 'Privacy')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'en' ? 'Data privacy' : 'Приватность данных'),
        findsWidgets,
      );
      final toggles = find.byType(DesktopToggle);
      expect(toggles, findsNWidgets(3));
      expect(
        tester.widgetList<DesktopToggle>(toggles).every((item) => !item.value),
        isTrue,
      );
      await tester.tap(toggles.first);
      await tester.pumpAndSettle();
      expect(PrivacyPreferences.instance.crashReports, isTrue);
      expect(PrivacyPreferences.instance.metrics, isFalse);
      expect(PrivacyPreferences.instance.externalData, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PrivacyPreferences.crashReportsKey), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
