import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/theme/app_icons.dart';
import 'package:bci_engine/features/common/widgets.dart';
import 'package:bci_engine/features/shell/nav_registry.dart';
import 'package:bci_engine/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_manager_test.dart' show capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Load the actual bundled fonts, not the test runner's placeholder glyphs.
    for (final style in ['Regular', 'Fill']) {
      final asset = style == 'Regular' ? 'Phosphor.ttf' : 'Phosphor-Fill.ttf';
      final loader = FontLoader('packages/phosphor_icons/Phosphor$style')
        ..addFont(rootBundle.load('packages/phosphor_icons/lib/fonts/$asset'));
      await loader.load();
    }
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('navigation uses locally bundled Regular and active Fill icons', () {
    for (final section in kNavSections) {
      expect(section.icon.fontPackage, 'phosphor_icons');
      expect(section.icon.fontFamily, 'PhosphorRegular');
      expect(
        AppIcons.resolve(section.icon, active: true).fontFamily,
        'PhosphorFill',
      );
    }
    expect(AppIcons.heart.fontFamily, 'PhosphorRegular');
    expect(AppIcons.heartFilled.fontFamily, 'PhosphorFill');
    expect(AppIcons.sidebarFilled.fontFamily, 'PhosphorFill');
  });

  for (final theme in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('Phosphor shell and canvas controls render in ${theme.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider.notifier).setThemeMode(theme);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(key: boundary, child: const BciApp()),
        ),
      );
      await tester.pumpAndSettle();

      for (final button in tester.widgetList<DesktopIconButton>(
        find.byType(DesktopIconButton),
      )) {
        expect(button.icon.fontPackage, 'phosphor_icons');
        expect(
          button.icon.fontFamily,
          isIn(['PhosphorRegular', 'PhosphorFill']),
        );
        final rendered = find.descendant(
          of: find.byWidget(button),
          matching: find.byType(Icon),
        );
        if (button.customIcon == null) {
          expect(
            tester.widget<Icon>(rendered.first).icon,
            AppIcons.resolve(button.icon, active: button.active),
          );
        }
      }
      for (final icon in [
        AppIcons.resolve(AppIcons.cursor, active: true),
        AppIcons.pencil,
        AppIcons.scissors,
        AppIcons.branch,
        AppIcons.bell,
        AppIcons.magnet,
        AppIcons.caretsLeft,
        AppIcons.sidebar,
      ]) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Icon &&
                (widget.icon == icon ||
                    widget.icon == AppIcons.resolve(icon, active: true)),
          ),
          findsWidgets,
        );
      }
      final snap = find.byKey(const ValueKey('workspace toggle snap'));
      expect(tester.widget<DesktopIconButton>(snap).customIcon, isNull);
      await tester.tap(snap);
      await tester.pumpAndSettle();
      expect(tester.widget<DesktopIconButton>(snap).active, isTrue);
      expect(
        find.byIcon(AppIcons.resolve(AppIcons.magnet, active: true)),
        findsOneWidget,
      );
      await tester.tap(snap);
      await tester.pumpAndSettle();
      expect(tester.widget<DesktopIconButton>(snap).active, isFalse);
      final tools = find.byKey(const ValueKey('workspace toggle canvas tools'));
      await tester.tap(tools);
      await tester.pumpAndSettle();
      expect(
        tester.widget<DesktopIconButton>(tools).icon,
        AppIcons.caretsRight,
      );
      await tester.tap(tools);
      await tester.pumpAndSettle();
      expect(tester.widget<DesktopIconButton>(tools).icon, AppIcons.caretsLeft);
      await capture(tester, boundary, 'phosphor-workspace-${theme.name}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
