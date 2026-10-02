import 'dart:io';
import 'dart:ui' as ui;

import 'package:bci_engine/core/modules/module_registry.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/features/modules/modules_screen.dart';
import 'package:bci_engine/core/theme/app_theme.dart';
import 'package:bci_engine/core/theme/app_palette.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:bci_engine/features/marketplace/marketplace_screen.dart';
import 'package:bci_engine/features/modules/module_ui.dart';
import 'package:bci_engine/app.dart';
import 'package:bci_engine/core/modules/module_preview_data.dart';
import 'package:bci_engine/features/marketplace/catalog_entry.dart';
import 'package:bci_engine/features/shell/rail_settings.dart';
import 'package:bci_engine/features/common/widgets.dart';
import 'package:bci_engine/features/common/desktop_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _module = SystemModule(
  id: 'test.filter',
  name: 'Test Filter',
  category: 'dsp',
  description: 'A filter for interaction tests.',
  manifest: {
    'parameters': [
      {
        'id': 'gain',
        'type': 'slider',
        'label': 'Gain',
        'min': 0,
        'max': 10,
        'default': 2,
      },
      {
        'id': 'model',
        'type': 'select',
        'label': 'Neural model',
        'options': ['None', 'ONNX'],
      },
    ],
    'ui': [
      {'id': 'info', 'type': 'label', 'label': 'Author-defined active content'},
    ],
  },
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'node sizes clamp safely, grow with ports and round-trip old graphs',
    () {
      final node = WorkspaceNode(id: 'size', module: _module);
      final old = node.toJson()
        ..remove('width')
        ..remove('height');
      expect(WorkspaceNode.fromJson(old).width, WorkspaceNode.defaultWidth);
      node.resize(const Size(450, 360));
      expect(node.width, 450);
      expect(node.height, 360);
      expect(node.portPosition('output', true).dx, node.position.dx + 444);
      final restored = WorkspaceNode.fromJson(node.toJson());
      expect(restored.width, 450);
      expect(restored.height, 360);
      for (var index = 0; index < 10; index++) {
        restored.inputs.add('input $index');
      }
      expect(restored.height, greaterThan(360));
      restored.resize(Size.zero);
      expect(restored.height, restored.minHeight);
      expect(restored.width, WorkspaceNode.minWidth);
      restored.resize(const Size(double.nan, double.infinity));
      expect(restored.width, WorkspaceNode.minWidth);
      final malformed = WorkspaceNode(
        id: 'bad',
        module: _module,
        width: double.infinity,
        height: double.nan,
      );
      expect(malformed.width, WorkspaceNode.defaultWidth);
      expect(malformed.height.isFinite, isTrue);
    },
  );
  test('graph prevents self-links, missing ports and cycles', () {
    final nodes = [
      WorkspaceNode(id: 'a', module: _module),
      WorkspaceNode(id: 'b', module: _module),
    ];
    const ab = WorkspaceLink(
      source: 'a',
      output: 'output',
      target: 'b',
      input: 'input',
    );
    expect(validateWorkspaceLink(nodes, [], ab), isNull);
    expect(
      validateWorkspaceLink(
        nodes,
        [ab],
        const WorkspaceLink(
          source: 'b',
          output: 'output',
          target: 'a',
          input: 'input',
        ),
      ),
      contains('cycle'),
    );
    expect(
      validateWorkspaceLink(
        nodes,
        [],
        const WorkspaceLink(
          source: 'a',
          output: 'output',
          target: 'a',
          input: 'input',
        ),
      ),
      isNotNull,
    );
    expect(
      validateWorkspaceLink(
        nodes,
        [],
        const WorkspaceLink(
          source: 'a',
          output: 'bad',
          target: 'b',
          input: 'input',
        ),
      ),
      isNotNull,
    );
  });
  test('workspace presets validate format and deduplicate IDs', () {
    final preset = WorkspacePreset.fromJson({
      'format': 'qualia-workspace-preset',
      'version': 1,
      'name': 'Research',
      'modules': ['a', 'a', 'b'],
    });
    expect(preset.moduleIds, ['a', 'b']);
    expect(
      () => WorkspacePreset.fromJson({'name': 'bad', 'modules': []}),
      throwsFormatException,
    );
    expect(WorkspacePreset.fromJson(preset.toJson()).name, 'Research');
  });
  testWidgets(
    'workspace nodes support connections, ports, inspector, Open and Back',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(workspaceProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: (context, child) =>
                AppThemeScope(palette: AppPalette.dark, child: child!),
            home: Scaffold(
              body: ModulesScreen(
                modules: const [_module],
                onAdd: () {},
                onEdit: (_) {},
                onRemove: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = container.read(workspaceProvider.notifier);
      final a = controller.addNode(_module, const Offset(4900, 4900));
      final b = controller.addNode(_module, const Offset(5300, 4900));
      await tester.pumpAndSettle();
      expect(find.text('Test Filter'), findsNWidgets(2));
      await tester.tap(find.text('output').first);
      await tester.pump();
      await tester.tap(find.text('input').last);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).links.length, 1);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      viewer.transformationController!.value = Matrix4.identity()
        ..translateByDouble(-8000, -8000, 0, 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('return to workspace')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('return to workspace')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('return to workspace')), findsNothing);
      await tester.tap(find.text('+ Input').first);
      await tester.pumpAndSettle();
      expect(a.inputs.length, 2);
      await tester.tap(find.text('Test Filter').first);
      await tester.pumpAndSettle();
      expect(find.text('MODULE SETTINGS'), findsOneWidget);
      expect(find.text('Gain'), findsOneWidget);
      await tester.tap(find.text('Open').first);
      await tester.pumpAndSettle();
      expect(find.text('Author-defined active content'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Author-defined active content'), findsNothing);
      controller.removeNode(b.id);
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).links, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'workspace graph, library, preset and instance settings survive reload',
    (tester) async {
      final first = ProviderContainer();
      first.read(workspaceProvider);
      await tester.pump();
      final controller = first.read(workspaceProvider.notifier);
      controller.addToLibrary(_module);
      final a = controller.addNode(_module, const Offset(4900, 4900));
      final b = controller.addNode(_module, const Offset(5300, 4900));
      controller.connect(
        WorkspaceLink(
          source: a.id,
          output: 'output',
          target: b.id,
          input: 'input',
        ),
      );
      controller.setParameter(a.id, 'gain', 7);
      controller.resizeNode(a.id, const Size(440, 380));
      controller.addPort(a.id, false);
      const preset = WorkspacePreset(
        id: 'research',
        name: 'Research',
        moduleIds: ['test.filter', 'missing.module'],
      );
      controller.addPreset(preset);
      expect(controller.loadPreset(preset, [_module]), ['missing.module']);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      first.dispose();
      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(workspaceProvider);
      await tester.pump();
      final restored = second.read(workspaceProvider);
      expect(restored.loaded, isTrue);
      expect(restored.nodes.length, 2);
      expect(restored.links.length, 1);
      expect(restored.nodes.first.settings['gain'], 7);
      expect(restored.nodes.first.width, 440);
      expect(restored.nodes.first.height, 380);
      expect(restored.nodes.first.inputs, ['input', 'input 2']);
      expect(restored.nodes.first.position, const Offset(4900, 4900));
      expect(restored.library.single.id, _module.id);
      expect(restored.presets.single.name, 'Research');
      expect(restored.presetModuleIds, preset.moduleIds);
    },
  );
  testWidgets(
    'canvas menus, zoom, resizing and selection work at multiple scales',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: (_, child) =>
                AppThemeScope(palette: AppPalette.dark, child: child!),
            home: Scaffold(
              body: ModulesScreen(
                modules: const [_module],
                onAdd: () {},
                onEdit: (_) {},
                onRemove: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = container.read(workspaceProvider.notifier);
      final node = controller.addNode(_module, const Offset(4900, 4900));
      final other = controller.addNode(_module, const Offset(5400, 4900));
      controller.connect(
        WorkspaceLink(
          source: node.id,
          output: 'output',
          target: other.id,
          input: 'input',
        ),
      );
      await tester.pumpAndSettle();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      for (final scale in [.5, 1.0, 2.0]) {
        viewer.transformationController!.value = Matrix4.identity()
          ..translateByDouble(
            160 - node.position.dx * scale,
            140 - node.position.dy * scale,
            0,
            1,
          )
          ..scaleByDouble(scale, scale, scale, 1);
        await tester.pumpAndSettle();
        final sizeBefore = Size(node.width, node.height);
        final positionBefore = node.position;
        final handle = find.byKey(ValueKey('workspace resize ${node.id}'));
        final gesture = await tester.startGesture(tester.getCenter(handle));
        await tester.pump();
        await gesture.moveBy(const Offset(24, 24));
        await tester.pump();
        await gesture.moveBy(Offset(60 * scale, 40 * scale));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(node.width - sizeBefore.width, closeTo(60 + 24 / scale, 1));
        expect(node.height - sizeBefore.height, closeTo(40 + 24 / scale, 1));
        expect(node.position, positionBefore);
        final output = find.descendant(
          of: find.byKey(ValueKey('workspace node ${node.id}')),
          matching: find.text('output'),
        );
        final port = node.portPosition('output', true);
        // The output circle sits directly to the right of its text.
        final outputRect = tester.getRect(output);
        final viewportOrigin = tester.getTopLeft(
          find.byType(InteractiveViewer),
        );
        final renderedPort =
            viewportOrigin +
            MatrixUtils.transformPoint(
              viewer.transformationController!.value,
              port,
            );
        expect(outputRect.center.dy, closeTo(renderedPort.dy, .1));
        expect(outputRect.right + 11 * scale, closeTo(renderedPort.dx, .1));
        final beforeMove = node.position;
        final title = find.descendant(
          of: find.byKey(ValueKey('workspace node ${node.id}')),
          matching: find.text('Test Filter'),
        );
        final moveGesture = await tester.startGesture(tester.getCenter(title));
        await tester.pump();
        await moveGesture.moveBy(Offset(25 * scale, 15 * scale));
        await tester.pump();
        await moveGesture.up();
        await tester.pumpAndSettle();
        expect(node.position.dx - beforeMove.dx, closeTo(25, .1));
        expect(node.position.dy - beforeMove.dy, closeTo(15, .1));
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          scale,
        );
      }
      final before = viewer.transformationController!.value.getMaxScaleOnAxis();
      await tester.tap(find.byKey(const ValueKey('workspace zoom out')));
      await tester.pumpAndSettle();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        lessThan(before),
      );
      await tester.tap(find.byKey(const ValueKey('workspace view menu')));
      await tester.pumpAndSettle();
      expect(find.byType(DesktopMenuSurface<String>), findsOneWidget);
      await tester.tap(find.text('Actual size (100%)'));
      await tester.pumpAndSettle();
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      await tester.tap(find.byKey(const ValueKey('workspace add menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add module'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('workspace module search')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace select menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace select menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete selected'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).nodes, isEmpty);
      expect(container.read(workspaceProvider).links, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('malformed remote controls degrade safely', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) =>
            AppThemeScope(palette: AppPalette.dark, child: child!),
        home: Scaffold(
          body: ModuleControls(
            schema: const [
              {'id': 12, 'type': 'text'},
              {'id': 'gain', 'type': 'slider', 'min': 'bad', 'default': 'bad'},
              {'id': 'mode', 'type': 'select', 'options': false},
              {'id': 'hidden', 'type': 'untrusted-custom-widget'},
            ],
            values: const {},
            onChanged: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'preview catalog has separate scrolling filter blocks and license selection',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final capture = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: (context, child) =>
                AppThemeScope(palette: AppPalette.dark, child: child!),
            home: RepaintBoundary(
              key: capture,
              child: Scaffold(
                body: MarketplaceScreen(loadPage: (_, _) async => []),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Marketplace'), findsNothing);
      await tester.tap(find.text('Modules'));
      await tester.pumpAndSettle();
      expect(find.text('Signal Source · Preview'), findsOneWidget);
      final filters = find.byKey(const ValueKey('marketplace filters scroll'));
      final widthBefore = tester.getSize(filters).width;
      await tester.drag(
        find.byKey(const ValueKey('marketplace filter resize')),
        const Offset(90, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(filters).width, greaterThan(widthBefore));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getDouble('qualia.marketplace.filterWidth'),
        greaterThan(240),
      );
      expect(
        find.descendant(of: filters, matching: find.byType(DesktopPane)),
        findsWidgets,
      );
      await _capture(tester, capture, 'marketplace-dark-preview.png');
      final license = find.descendant(of: filters, matching: find.text('MIT'));
      await tester.scrollUntilVisible(
        license,
        100,
        scrollable: find.descendant(
          of: filters,
          matching: find.byType(Scrollable),
        ),
      );
      await Scrollable.ensureVisible(tester.element(license), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(license);
      await tester.pumpAndSettle();
      expect(find.text('Signal Source · Preview'), findsOneWidget);
      expect(find.text('Bandpass Filter · Preview'), findsNothing);
      await tester.drag(filters, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('In Workspace').hitTestable(), findsOneWidget);
      await _capture(tester, capture, 'marketplace-dark-filters-scrolled.png');
      await tester.drag(filters, const Offset(0, 1200));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reset filters'));
      await tester.pumpAndSettle();
      final catalogScroll = find.byType(CustomScrollView);
      await tester.drag(catalogScroll, const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(find.text('Signal Source · Preview').hitTestable(), findsNothing);
      expect(tester.widget<ListView>(filters).controller!.offset, 0);
      tester.view.physicalSize = const Size(600, 700);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      final compactLicense = find.descendant(
        of: find.byType(Dialog),
        matching: find.text('MIT'),
      );
      await tester.scrollUntilVisible(
        compactLicense,
        100,
        scrollable: find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        ),
      );
      await Scrollable.ensureVisible(
        tester.element(compactLicense),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(compactLicense);
      await tester.pumpAndSettle();
      await _capture(tester, capture, 'marketplace-narrow-license-dialog.png');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  test('licenses are read from manifest without inventing a default', () {
    expect(
      CatalogEntry.fromModule(previewWorkspaceModules.first).license,
      'MIT',
    );
    expect(CatalogEntry.fromModule(_module).license, 'Unspecified');
  });
  testWidgets('Workspace previews drag from Explorer to canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final capture = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: capture, child: const BciApp()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    final source = find.text('Signal Source · Preview');
    await tester.ensureVisible(source);
    await tester.pumpAndSettle();
    final target = find.byType(DragTarget<SystemModule>);
    final destination = tester.getCenter(target);
    final gesture = await tester.startGesture(tester.getCenter(source));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveTo(destination);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final graph = container.read(workspaceProvider);
    expect(find.byTooltip('Create new tab'), findsNothing);
    expect(find.byKey(const ValueKey('workspace add menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace select menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace view menu')), findsOneWidget);
    expect(graph.nodes.length, 1);
    expect(graph.nodes.single.module.id, previewWorkspaceModules.first.id);
    expect(graph.nodes.single.inputs, isEmpty);
    expect(find.text('MODULE SETTINGS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workspace view menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frame all (F)'));
    await tester.pumpAndSettle();
    await _capture(tester, capture, 'workspace-preview-drag.png');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('rail dialog reuses desktop controls and restores hidden rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final capture = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(key: capture, child: const BciApp()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rail settings'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(RailSettingsDialog),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .width,
      greaterThanOrEqualTo(600),
    );
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    await _capture(tester, capture, 'rail-settings-dark.png');
    await tester.tap(find.byKey(const ValueKey('rail setting Show rail')));
    await tester.pumpAndSettle();
    expect(container.read(railProvider).visible, isFalse);
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity rail surface')), findsNothing);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rail settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rail setting Show rail')));
    await tester.pumpAndSettle();
    expect(container.read(railProvider).visible, isTrue);
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity rail surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Marketplace sorting and list view work in light and narrow layouts',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final capture = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) =>
                AppThemeScope(palette: AppPalette.light, child: child!),
            home: RepaintBoundary(
              key: capture,
              child: Scaffold(
                body: MarketplaceScreen(
                  includePreviews: false,
                  loadPage: (offset, limit) async => offset == 0
                      ? [
                          _module,
                          SystemModule(
                            id: 'test.new',
                            name: 'A New Filter',
                            category: 'dsp',
                            description: 'Second test fixture.',
                            createdAt: DateTime(2026, 9, 30),
                          ),
                        ]
                      : [],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modules'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sort by'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('A New Filter')).dx,
        lessThan(tester.getTopLeft(find.text('Test Filter')).dx),
      );
      await _capture(tester, capture, 'marketplace-light-grid.png');
      await tester.tap(find.byTooltip('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      expect(find.byType(SliverFixedExtentList), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('A New Filter')).dy,
        lessThan(tester.getTopLeft(find.text('Test Filter')).dy),
      );
      await _capture(tester, capture, 'marketplace-light-list.png');
      tester.view.physicalSize = const Size(600, 800);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, capture, 'marketplace-light-narrow.png');
    },
  );
  testWidgets(
    'Marketplace uses published data, filters, clear search, likes and library action',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: (context, child) =>
                AppThemeScope(palette: AppPalette.dark, child: child!),
            home: Scaffold(
              body: MarketplaceScreen(
                includePreviews: false,
                loadPage: (offset, limit) async => offset == 0 ? [_module] : [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modules'));
      await tester.pumpAndSettle();
      expect(find.text('Test Filter'), findsOneWidget);
      final search = find.byKey(const ValueKey('marketplace search field'));
      await tester.enterText(search, 'unknown');
      await tester.pumpAndSettle();
      expect(find.text('No matching items'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, '');
      await tester.tap(find.byTooltip('Like Test Filter'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      await tester.tap(find.text('Test Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Workspace'));
      await tester.pumpAndSettle();
      expect(container.read(workspaceProvider).library.single.id, _module.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

// Opt-in visual evidence: QUALIA_TEST_CAPTURE_DIR=/tmp/opencode/qualia-review.
// Fixtures remain test-only; they are never seeded into the app's catalog.
Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final path = Platform.environment['QUALIA_TEST_CAPTURE_DIR'];
  if (path == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(path).create(recursive: true);
    await File('$path/$name').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
