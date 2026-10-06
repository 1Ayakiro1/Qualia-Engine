import 'dart:io';
import 'dart:ui' as ui;

import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/core/workspace/workspace_project.dart';
import 'package:bci_engine/core/workspace/workspace_repository.dart';
import 'package:bci_engine/features/marketplace/marketplace_screen.dart';
import 'package:bci_engine/features/modules/modules_screen.dart';
import 'package:bci_engine/l10n/generated/app_localizations.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget themed(
  ProviderContainer container,
  Widget child, {
  String language = 'en',
  bool light = false,
  GlobalKey? captureKey,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: _theme(light),
    builder: (_, child) => AppThemeScope(
      palette: light ? AppPalette.light : AppPalette.dark,
      child: RepaintBoundary(key: captureKey, child: child!),
    ),
    home: Scaffold(body: child),
  ),
);

ThemeData _theme(bool light) {
  final theme = light ? AppTheme.light() : AppTheme.dark();
  if (Platform.environment['QUALIA_TEST_CAPTURE_DIR'] == null) return theme;
  return theme.copyWith(
    dialogTheme: theme.dialogTheme.copyWith(
      titleTextStyle: theme.dialogTheme.titleTextStyle?.copyWith(
        fontFamily: 'Roboto',
      ),
      contentTextStyle: theme.dialogTheme.contentTextStyle?.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
  );
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final path = Platform.environment['QUALIA_TEST_CAPTURE_DIR'];
  if (path == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(path).create(recursive: true);
    await File('$path/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'workspace button creates and switches projects; manager edits and deletes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        themed(
          container,
          RepaintBoundary(
            child: ModulesScreen(
              modules: const [],
              onAdd: () {},
              onEdit: (_) {},
              onRemove: (_) {},
            ),
          ),
          captureKey: key,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace project menu')));
      await tester.pumpAndSettle();
      expect(find.text('Workspace manager'), findsOneWidget);
      await tester.tap(find.text('New workspace'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Project two');
      await tester.enterText(find.byType(TextField).last, 'Independent graph');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceProvider).activeProject.name,
        'Project two',
      );
      await tester.tap(find.byKey(const ValueKey('workspace project menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workspace').last);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).activeProjectId, 'default');
      await tester.tap(find.byKey(const ValueKey('workspace project menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workspace manager'));
      await tester.pumpAndSettle();
      await capture(tester, key, 'workspace-manager');
      await tester.tap(find.byTooltip('Workspace actions').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit workspace'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Renamed project');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Renamed project'), findsOneWidget);
      await tester.tap(find.byTooltip('Workspace actions').last);
      await tester.pumpAndSettle();
      expect(find.text('Export / share'), findsOneWidget);
      expect(find.text('Submit to Marketplace'), findsOneWidget);
      await tester.tap(find.text('Delete workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).projects.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['en', 'ru']) {
    testWidgets(
      'Marketplace workspace installation creates project ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          themed(
            container,
            RepaintBoundary(
              key: key,
              child: MarketplaceScreen(
                includePreviews: false,
                loadPage: (_, _) async => [],
                loadWorkspacePage: (_, _) async => [
                  const PublishedWorkspace(
                    id: 'catalog-test',
                    project: WorkspaceProject(
                      id: 'shared',
                      name: 'Shared project',
                      description: 'Community layout',
                    ),
                    author: 'Author',
                    license: 'CC-BY-4.0',
                  ),
                ],
              ),
            ),
            language: language,
            light: language == 'ru',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(language == 'en' ? 'Workspaces' : 'Воркспейсы'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Shared project'), findsOneWidget);
        await capture(tester, key, 'workspace-marketplace-$language');
        await tester.tap(find.text('Shared project'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            language == 'en' ? 'Install workspace' : 'Установить воркспейс',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(workspaceProvider).activeProject.name,
          'Shared project',
        );
        expect(container.read(workspaceProvider).projects.length, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
