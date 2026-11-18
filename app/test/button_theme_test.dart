import 'package:bci_engine/core/theme/app_icons.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/features/modules/workspace_manager.dart';
import 'package:bci_engine/l10n/generated/app_localizations.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_manager_test.dart' show capture;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final light in [false, true]) {
    final theme = light ? AppTheme.light() : AppTheme.dark();
    final name = light ? 'light' : 'dark';

    test(
      '$name action themes use the same shape in every interaction state',
      () {
        final styles = [
          theme.textButtonTheme.style!,
          theme.filledButtonTheme.style!,
          theme.elevatedButtonTheme.style!,
          theme.outlinedButtonTheme.style!,
          theme.iconButtonTheme.style!,
        ];
        for (final style in styles) {
          for (final state in <Set<WidgetState>>[
            {},
            {WidgetState.hovered},
            {WidgetState.focused},
            {WidgetState.pressed},
            {WidgetState.selected},
            {WidgetState.disabled},
          ]) {
            expect(style.shape!.resolve(state), AppTheme.controlShape);
          }
        }
      },
    );

    testWidgets(
      '$name Material action variants render desktop rounded rectangles',
      (tester) async {
        void activate() {}
        final controls = <Widget>[
          TextButton(onPressed: activate, child: const Text('Text')),
          FilledButton(onPressed: activate, child: const Text('Filled')),
          FilledButton.tonal(onPressed: activate, child: const Text('Tonal')),
          ElevatedButton(onPressed: activate, child: const Text('Elevated')),
          OutlinedButton(onPressed: activate, child: const Text('Outlined')),
          IconButton(onPressed: activate, icon: const Icon(AppIcons.add)),
          IconButton.filled(
            onPressed: activate,
            icon: const Icon(AppIcons.add),
          ),
          IconButton.filledTonal(
            onPressed: activate,
            icon: const Icon(AppIcons.add),
          ),
          IconButton.outlined(
            onPressed: activate,
            icon: const Icon(AppIcons.add),
          ),
          const TextButton(onPressed: null, child: Text('Disabled')),
        ];
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(body: Wrap(children: controls)),
          ),
        );
        for (final control in controls) {
          final materials = tester.widgetList<Material>(
            find.descendant(
              of: find.byWidget(control),
              matching: find.byType(Material),
            ),
          );
          expect(materials, isNotEmpty);
          expect(materials.first.shape, isA<RoundedRectangleBorder>());
          expect(
            (materials.first.shape! as RoundedRectangleBorder).borderRadius,
            AppTheme.controlBorderRadius,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$name unsaved workspace dialog buttons retain standard corners on hover',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final scope = ProviderContainer();
        addTearDown(scope.dispose);
        scope.read(workspaceProvider);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: scope,
            child: MaterialApp(
              theme: theme,
              locale: const Locale('ru'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (_, child) => AppThemeScope(
                palette: light ? AppPalette.light : AppPalette.dark,
                child: RepaintBoundary(key: boundary, child: child!),
              ),
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () => confirmWorkspaceClose(context, ref),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        scope.read(workspaceProvider.notifier).setCanvasSize(width: 12000);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        final buttons = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        );
        expect(buttons, findsNWidgets(3));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(buttons.last));
        await tester.pumpAndSettle();
        for (final button in buttons.evaluate()) {
          final material = tester.widget<Material>(
            find
                .descendant(
                  of: find.byWidget(button.widget),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(material.shape, AppTheme.controlShape);
        }
        await capture(tester, boundary, 'workspace-close-button-corners-$name');
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          scope.read(workspaceProvider.notifier).hasUnsavedChanges,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
