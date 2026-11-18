import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/features/marketplace/catalog_entry.dart';
import 'package:bci_engine/features/marketplace/marketplace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SystemModule module(int index, {Map<String, dynamic>? cover}) => SystemModule(
  id: 'masonry.$index',
  name: 'Card $index',
  category: 'Test',
  description: index.isEven ? 'Short description.' : 'An adaptive card with a longer description that wraps naturally without an empty fixed-height space beneath it.',
  manifest: {
    'kind': 'module',
    'cover': cover ?? {'aspectRatio': index.isEven ? 2.0 : 1.0},
  },
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('cover dimensions and invalid metadata have safe aspect ratios', () {
    expect(CatalogEntry.fromModule(module(0)).coverAspectRatio, 2);
    expect(
      CatalogEntry.fromModule(module(0, cover: {'width': 600, 'height': 800}))
          .coverAspectRatio,
      .75,
    );
    expect(
      CatalogEntry.fromModule(module(0, cover: {'aspectRatio': 100}))
          .coverAspectRatio,
      2.4,
    );
    for (final cover in [
      <String, dynamic>{},
      {'aspectRatio': double.nan},
      {'aspectRatio': -1},
      {'width': 200, 'height': 0},
      {'width': '200', 'height': 100},
    ]) {
      expect(
        CatalogEntry.fromModule(module(0, cover: cover)).coverAspectRatio,
        1.6,
      );
    }
  });

  for (final light in [false, true]) {
    testWidgets(
      'masonry packs unequal cards and adapts to one column (${light ? 'light' : 'dark'})',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: light ? AppTheme.light() : AppTheme.dark(),
              builder: (_, child) => AppThemeScope(
                palette: light ? AppPalette.light : AppPalette.dark,
                child: child!,
              ),
              home: Scaffold(
                body: MarketplaceScreen(
                  includePreviews: false,
                  loadPage: (_, _) async => List.generate(6, module),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Modules'));
        await tester.pumpAndSettle();
        expect(find.byType(SliverMasonryGrid), findsOneWidget);
        Rect rect(int index) =>
            tester.getRect(find.byKey(ValueKey('catalog card masonry.$index')));
        final first = rect(0);
        final second = rect(1);
        final third = rect(2);
        expect(first.width, closeTo(second.width, .01));
        final filterHeader = tester.getRect(
          find.byKey(const ValueKey('marketplace filters header')),
        );
        final search = tester.getRect(
          find.byKey(const ValueKey('marketplace search field')),
        );
        final kindSpacing = tester.getRect(
          find.byKey(const ValueKey('marketplace kind spacing')),
        );
        expect(filterHeader.top, search.top);
        expect(search.left - filterHeader.right, 20);
        expect(first.left, search.left);
        expect(search.top - kindSpacing.bottom, 0);
        expect(
          tester
              .widget<Padding>(
                find.byKey(const ValueKey('marketplace kind spacing')),
              )
              .padding,
          const EdgeInsets.all(20),
        );
        expect(second.height, greaterThan(first.height));
        for (final index in [0, 1, 2]) {
          final cover = tester.getRect(
            find.byKey(ValueKey('catalog cover masonry.$index')),
          );
          expect(cover.width / cover.height, closeTo(16 / 9, .001));
        }
        expect(third.left, closeTo(first.left, .01));
        expect(third.top, closeTo(first.bottom + 14, .01));
        expect(third.top, lessThan(second.bottom));
        // Filtering preserves IDs and remains valid with fewer columns.
        await tester.enterText(
          find.byKey(const ValueKey('marketplace search field')),
          'Card 1',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('catalog card masonry.0')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('catalog card masonry.1')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(600, 1000);
        await tester.pumpAndSettle();
        expect(rect(1).left, closeTo(rect(0).left, .01));
        expect(rect(1).top, closeTo(rect(0).bottom + 14, .01));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'masonry loads the next page while scrolling and opens appended cards',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final offsets = <int>[];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: (_, child) =>
                AppThemeScope(palette: AppPalette.dark, child: child!),
            home: Scaffold(
              body: MarketplaceScreen(
                includePreviews: false,
                loadPage: (offset, limit) async {
                  offsets.add(offset);
                  return offset == 0
                      ? List.generate(limit, module)
                      : [module(24)];
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modules'));
      await tester.pumpAndSettle();
      // The initially empty Extensions tab may prefetch the second page before
      // switching to Modules; both paths must preserve the appended records.
      expect(offsets.first, 0);
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('catalog card masonry.24')),
        500,
        scrollable: scrollable,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      expect(offsets, [0, 24]);
      await tester.tap(find.text('Card 24'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Add to Workspace'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
