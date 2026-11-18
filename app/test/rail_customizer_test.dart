import 'dart:convert';

import 'package:bci_engine/app.dart';
import 'package:bci_engine/features/shell/rail_settings.dart';
import 'package:bci_engine/features/common/desktop_menu.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/state/app_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_manager_test.dart' show capture;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'legacy rail preferences migrate, mixed ordering persists without duplicates',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'qualia.rail.v1': jsonEncode({
          'visible': true,
          'sections': ['profile', 'modules', 'settings'],
          'extensions': ['test.extension'],
        }),
      });
      final container = ProviderContainer();
      container.read(railProvider);
      await tester.pumpAndSettle();
      final c = container.read(railProvider.notifier);
      c.place(extensionRailKey('test.extension'), 0);
      c.place(sectionRailKey(SectionId.settings), 1);
      c.place(sectionRailKey(SectionId.dashboard), 2);
      c.setSection(SectionId.profile, false);
      final order = container.read(railProvider).orderedKeys;
      expect(order, [
        'extension:test.extension',
        'section:settings',
        'section:dashboard',
        'section:modules',
      ]);
      expect(order.toSet().length, order.length);
      c.place('section:settings', 0, atBottom: true);
      expect(container.read(railProvider).bottomKeys, ['section:settings']);
      expect(
        container.read(railProvider).topKeys,
        isNot(contains('section:settings')),
      );
      await tester.pumpAndSettle();
      container.dispose();
      final reloaded = ProviderContainer();
      addTearDown(reloaded.dispose);
      reloaded.read(railProvider);
      await tester.pumpAndSettle();
      expect(reloaded.read(railProvider).orderedKeys.toSet(), order.toSet());
      expect(reloaded.read(railProvider).bottomKeys, ['section:settings']);
    },
  );

  for (final scale in [.96, 1.2, 1.8]) {
    testWidgets('context menu retains shell scale $scale and viewport bounds', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          builder: (_, child) =>
              AppThemeScope(palette: AppPalette.dark, child: child!),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomRight,
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDesktopMenu<String>(
                      context: context,
                      position: const Offset(1390, 890),
                      width: 240,
                      entries: const [
                        DesktopMenuEntry(value: 'one', label: 'One'),
                      ],
                    ),
                    child: const Text('Open menu'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open menu'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(DesktopMenuSurface<String>));
      expect(rect.width, closeTo(240 * scale, .01));
      expect(rect.right, lessThanOrEqualTo(1400));
      expect(rect.bottom, lessThanOrEqualTo(900));
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopMenuSurface<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'rail editor adds, reorders and removes by mouse drag at shell scale',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(key: captureKey, child: const BciApp()),
        ),
      );
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('activity rail surface'));
      final railRect = tester.getRect(rail);
      await tester.tap(find.byTooltip('Rail settings'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      final available = find.byKey(
        const ValueKey('rail available section:dashboard'),
      );
      final target = find.byKey(const ValueKey('rail edit section:profile'));
      expect(
        tester.getSize(available).height,
        closeTo(tester.getSize(target).height, .01),
      );
      expect(tester.getRect(target).left, greaterThanOrEqualTo(railRect.left));
      await capture(tester, captureKey, 'rail-customizer');

      Future<void> drag(Finder from, Offset end) async {
        final gesture = await tester.startGesture(
          tester.getCenter(from),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 180));
        await gesture.moveTo(end);
        await tester.pump(const Duration(milliseconds: 180));
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await drag(available, tester.getTopLeft(target) + const Offset(20, 2));
      expect(
        container.read(railProvider).orderedKeys.first,
        'section:dashboard',
      );
      final workspace = find.byKey(const ValueKey('rail edit section:modules'));
      final dashboard = find.byKey(
        const ValueKey('rail edit section:dashboard'),
      );
      await drag(workspace, tester.getTopLeft(dashboard) + const Offset(20, 2));
      expect(container.read(railProvider).orderedKeys.first, 'section:modules');
      await drag(
        find.byKey(const ValueKey('rail edit section:dashboard')),
        tester.getCenter(find.text('Unused items')),
      );
      expect(
        container.read(railProvider).sections,
        isNot(contains(SectionId.dashboard)),
      );
      // The empty bottom zone accepts a real mouse drag, not just controller calls.
      await drag(
        find.byKey(const ValueKey('rail edit section:settings')),
        tester.getCenter(find.byKey(const ValueKey('rail bottom drop zone'))),
      );
      expect(container.read(railProvider).bottomKeys, ['section:settings']);
      await tester.tap(find.byKey(const ValueKey('rail edit section:entity')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        find.byKey(const ValueKey('rail return flight 2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('rail available section:entity')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rail return flight 2')), findsNothing);
      final focusedButton = find
          .descendant(
            of: find.byKey(const ValueKey('rail edit section:modules')),
            matching: find.byType(FocusableActionDetector),
          )
          .first;
      tester
          .widget<FocusableActionDetector>(focusedButton)
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(container.read(railProvider).orderedKeys[1], 'section:modules');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(container.read(railProvider).orderedKeys.first, 'section:modules');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(RailCustomizer), findsNothing);
      expect(
        tester.getCenter(find.byTooltip('configs')).dy,
        greaterThan(railRect.bottom - 80),
      );
      // Normal navigation now uses the same persisted order as the editor.
      expect(
        tester.getTopLeft(find.byTooltip('Workspace')).dy,
        lessThan(tester.getTopLeft(find.byTooltip('User profile button')).dy),
      );
      await tester.tap(find.byTooltip('Rail settings'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(1250, 650));
      await tester.pumpAndSettle();
      expect(find.byType(RailCustomizer), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
