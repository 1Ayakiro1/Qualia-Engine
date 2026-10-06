import 'dart:io';
import 'dart:ui' as ui;

import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/features/settings/keyboard_shortcuts_panel.dart';
import 'package:bci_engine/features/settings/navigation_shortcuts.dart';
import 'package:bci_engine/features/settings/settings_screen.dart';
import 'package:bci_engine/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:bci_engine/features/common/navigation_bindings.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NavigationBindings.instance.load();
    NavigationBindings.instance.setKeyboardMode(false);
  });

  testWidgets(
    'navigation editor captures a real persisted binding and rejects conflicts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          builder: (_, child) =>
              AppThemeScope(palette: AppPalette.dark, child: child!),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: KeyboardShortcutsPanel(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Navigation'), findsOneWidget);
      for (final shortcut in navigationShortcutGroups.values.expand(
        (items) => items,
      )) {
        final row = find.byKey(ValueKey('navigation shortcut ${shortcut.id}'));
        expect(row, findsOneWidget);
        expect(
          find.descendant(
            of: row,
            matching: find.text(
              shortcut.keys(lookupAppLocalizations(const Locale('en'))),
            ),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('edit navigation next')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f6);
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(NavigationBindings.instance.label(NavigationAction.next), 'F6');
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(NavigationBindings.storageKey),
          contains('next'),
        );
      });
      await tester.tap(find.byKey(const ValueKey('edit navigation next')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        find.text(
          'This combination is already used by another navigation action.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['en', 'ru']) {
    testWidgets(
      'Navigation preferences expose editable bindings in $language at compact width',
      (tester) async {
        tester.view.physicalSize = const Size(800, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final capture = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.dark(),
              builder: (_, child) =>
                  AppThemeScope(palette: AppPalette.dark, child: child!),
              home: RepaintBoundary(
                key: capture,
                child: const Scaffold(
                  body: SettingsScreen(initialItem: 'Navigation'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(language == 'en' ? 'Navigation' : 'Навигация'),
          findsWidgets,
        );
        expect(find.text('Navigation 1'), findsNothing);
        expect(
          find.byKey(const ValueKey('navigation shortcut next')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('shortcut edit action')),
          findsNothing,
        );
        final last = find.byKey(
          const ValueKey('navigation shortcut fullscreen'),
        );
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        expect(
          find.text(
            language == 'en' ? 'Keyboard shortcuts' : 'Горячие клавиши',
          ),
          findsNothing,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('navigation shortcut next')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final path = Platform.environment['QUALIA_TEST_CAPTURE_DIR'];
        if (path != null) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(path).create(recursive: true);
            await File('$path/navigation-settings-$language.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }

  testWidgets('Navigation can be opened from the preferences sidebar', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BciApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('configs'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Navigation'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('navigation shortcut next')),
      findsOneWidget,
    );
    expect(find.text('Keyboard shortcuts'), findsNothing);
    expect(
      find.byKey(const ValueKey('navigation shortcut next')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
