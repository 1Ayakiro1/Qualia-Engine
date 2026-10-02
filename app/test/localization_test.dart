import 'dart:convert';
import 'dart:io';

import 'package:bci_engine/app.dart';
import 'package:bci_engine/l10n/generated/app_localizations.dart';
import 'package:bci_engine/l10n/locale_controller.dart';
import 'package:bci_engine/features/settings/settings_screen.dart';
import 'package:bci_engine/features/marketplace/marketplace_screen.dart';
import 'package:bci_engine/features/modules/module_ui.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('RU and EN catalogs have identical keys and placeholder contracts', () {
    final en = jsonDecode(
      File('lib/l10n/languages/app_en.arb').readAsStringSync(),
    ) as Map;
    final ru = jsonDecode(
      File('lib/l10n/languages/app_ru.arb').readAsStringSync(),
    ) as Map;
    final keys = en.keys
        .where((key) => !key.toString().startsWith('@'))
        .toSet();
    expect(
      ru.keys.where((key) => !key.toString().startsWith('@')).toSet(),
      keys,
    );
    for (final key in keys) {
      expect(
        (ru[key] as String).trim(),
        isNotEmpty,
        reason: '$key has no Russian translation',
      );
      final metadata = en['@$key'] as Map?;
      for (final name in (metadata?['placeholders'] as Map? ?? {}).keys) {
        expect(
          ru[key],
          contains('{$name'),
          reason: '$key loses placeholder $name',
        );
      }
    }
  });

  test('Russian module counts follow plural rules', () {
    final l10n = lookupAppLocalizations(const Locale('ru'));
    expect(l10n.workspaceCounts(1, 1), '1 модуль · 1 соединение');
    expect(l10n.workspaceCounts(2, 5), '2 модуля · 5 соединений');
    expect(l10n.workspaceCounts(21, 22), '21 модуль · 22 соединения');
    expect(
      lookupAppLocalizations(const Locale('en')).workspaceCounts(1, 2),
      '1 module · 2 connections',
    );
  });

  test('locale selection survives controller recreation', () async {
    final first = ProviderContainer();
    first.read(localeProvider);
    await first.read(localeProvider.notifier).select('ru');
    first.dispose();
    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(localeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(localeProvider), const Locale('ru'));
  });

  testWidgets(
    'Language settings switch shell immediately without losing page',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const BciApp()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('configs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language ru')));
      await tester.pumpAndSettle();
      expect(find.text('Язык'), findsWidgets);
      expect(find.text('Общие'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(container.read(localeProvider), const Locale('ru'));
      await tester.tap(find.text('Назад в приложение'));
      await tester.pumpAndSettle();
      expect(find.text('Обзор'), findsWidgets);
      expect(find.text('Файл'), findsOneWidget);
      expect(find.byTooltip('Маркетплейс'), findsOneWidget);
      await tester.tap(find.text('Файл'));
      await tester.pumpAndSettle();
      expect(
        find.text('Добавить пресет рабочего пространства'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(600, 800));
      await tester.pumpAndSettle();
      await container.read(localeProvider.notifier).select('en');
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('File'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Russian catalog filters preserve stable values across language changes',
    (tester) async {
      tester.view.physicalSize = const Size(1300, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final locale = ValueNotifier(const Locale('ru'));
      addTearDown(locale.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: ValueListenableBuilder<Locale>(
            valueListenable: locale,
            builder: (_, value, _) => MaterialApp(
              locale: value,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.dark(),
              builder: (_, child) =>
                  AppThemeScope(palette: AppPalette.dark, child: child!),
              home: Scaffold(
                body: MarketplaceScreen(loadPage: (_, _) async => []),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Модули'));
      await tester.pumpAndSettle();
      final filters = find.byKey(const ValueKey('marketplace filters scroll'));
      final mit = find.descendant(of: filters, matching: find.text('MIT'));
      await tester.ensureVisible(mit);
      await tester.pumpAndSettle();
      await tester.tap(mit);
      await tester.pumpAndSettle();
      expect(find.text('Источник сигнала · Демо'), findsOneWidget);
      expect(find.text('Полосовой фильтр · Демо'), findsNothing);
      final all = find.descendant(of: filters, matching: find.text('Все')).last;
      await Scrollable.ensureVisible(tester.element(all), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(all);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Полосовой фильтр · Демо'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Полосовой фильтр · Демо'), findsOneWidget);
      final month = find.text('В этом месяце');
      await Scrollable.ensureVisible(tester.element(month), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(month);
      await tester.pumpAndSettle();
      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      // Stored values remain IDs, not the translated Russian strings.
      expect(find.text('This month'), findsOneWidget);
      await tester.ensureVisible(find.text('All time'));
      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Signal Source · Preview'),
        -200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Signal Source · Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Add to Workspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('author control labels and option values are not translated', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark(),
        builder: (_, child) =>
            AppThemeScope(palette: AppPalette.dark, child: child!),
        home: Scaffold(
          body: ModuleControls(
            schema: const [
              {
                'id': 'mode',
                'type': 'select',
                'label': 'Mode',
                'options': ['Standard', 'Low latency'],
              },
            ],
            values: const {'mode': 'Standard'},
            onChanged: (_, value) => selected = value as String,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mode'), findsOneWidget);
    await tester.tap(find.byTooltip('Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low latency').last);
    await tester.pumpAndSettle();
    expect(selected, 'Low latency');
    expect(tester.takeException(), isNull);
  });
}
