import 'dart:convert';

import 'package:bci_engine/core/theme/app_icons.dart';
import 'package:bci_engine/core/workspace/workspace_eraser.dart';
import 'package:bci_engine/core/workspace/workspace_model.dart';
import 'package:bci_engine/features/modules/modules_screen.dart';
import 'package:bci_engine/state/workspace_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_manager_test.dart' show themed, capture;

const stroke = WorkspaceAnnotation(
  id: 'stroke',
  points: [Offset(0, 0), Offset(100, 0)],
  color: 0xFFE57373,
  width: 4,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final style in ['Regular', 'Fill']) {
      final asset = style == 'Regular' ? 'Phosphor.ttf' : 'Phosphor-Fill.ttf';
      await (FontLoader('packages/phosphor_icons/Phosphor$style')..addFont(
            rootBundle.load('packages/phosphor_icons/lib/fonts/$asset'),
          ))
          .load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'eraser splits sparse strokes and preserves color, diameter and IDs',
    () {
      final erased = eraseWorkspaceAnnotations(
        [stroke],
        const Offset(50, -40),
        const Offset(50, 40),
        16,
      );
      expect(erased, hasLength(2));
      expect(erased.first.id, stroke.id);
      expect(erased.last.id, isNot(stroke.id));
      expect(erased.first.points.last.dx, closeTo(40, .001));
      expect(erased.last.points.first.dx, closeTo(60, .001));
      for (final fragment in erased) {
        final loaded = WorkspaceAnnotation.fromJson(
          jsonDecode(jsonEncode(fragment.toJson())),
        );
        expect(loaded.color, stroke.color);
        expect(loaded.width, stroke.width);
        expect(loaded.points, fragment.points);
      }
      expect(stroke.points, [const Offset(0, 0), const Offset(100, 0)]);
    },
  );

  test('eraser supports clicks, fast sweeps, no-op, full removal and dots', () {
    expect(
      eraseWorkspaceAnnotations(
        [stroke],
        const Offset(50, 50),
        const Offset(90, 50),
        10,
      ).single,
      same(stroke),
    );
    expect(
      eraseWorkspaceAnnotations(
        [stroke],
        const Offset(-20, 0),
        const Offset(120, 0),
        16,
      ),
      isEmpty,
    );
    final click = eraseWorkspaceAnnotations(
      [stroke],
      const Offset(50, 0),
      const Offset(50, 0),
      16,
    );
    expect(click, hasLength(2));
    expect(click.first.points.last.dx, closeTo(40, .001));
    const dot = WorkspaceAnnotation(
      id: 'dot',
      points: [Offset(0, 0)],
      width: 12,
    );
    expect(
      eraseWorkspaceAnnotations([dot], Offset.zero, Offset.zero, 1),
      isEmpty,
    );
    expect(
      eraseWorkspaceAnnotations(
        [dot],
        const Offset(100, 0),
        const Offset(100, 0),
        1,
      ).single,
      same(dot),
    );
  });

  for (final scale in [.5, 1.0, 1.5]) {
    testWidgets(
      'brush and eraser controls, partial erase, undo and cancel at $scale zoom',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          themed(
            container,
            RepaintBoundary(
              key: boundary,
              child: ModulesScreen(
                modules: const [],
                onAdd: () {},
                onEdit: (_) {},
                onRemove: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final controller = container.read(workspaceProvider.notifier);
        final viewport = find.byType(InteractiveViewer);
        final transform = tester
            .widget<InteractiveViewer>(viewport)
            .transformationController!;
        transform.value = Matrix4.identity()..scaleByDouble(scale, scale, 1, 1);
        await tester.pumpAndSettle();
        final origin = tester.getTopLeft(viewport);
        Offset at(Offset point) => origin + point * scale;
        final start = Offset(420 / scale, 360 / scale);
        final end = start + const Offset(200, 0);
        final middle = (start + end) / 2;
        Finder tool(String name) =>
            find.byKey(ValueKey('workspace canvas tool $name'));
        await tester.tap(tool('pencil'));
        await tester.pumpAndSettle();
        expect(
          find.byIcon(AppIcons.resolve(AppIcons.pencil, active: true)),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('workspace brush color')));
        await tester.pumpAndSettle();
        // Existing localized workspace palette is reused.
        await tester.tap(find.text('Red'));
        await tester.pumpAndSettle();
        tester
            .widget<Slider>(
              find.byKey(const ValueKey('workspace brush diameter')),
            )
            .onChanged!(8);
        await tester.pumpAndSettle();
        final draw = await tester.startGesture(
          at(start),
          kind: PointerDeviceKind.mouse,
        );
        await draw.moveTo(at(end));
        await tester.pump();
        final preview = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<WorkspaceAnnotationPainter>()
            .single;
        expect(preview.activeColor.toARGB32(), stroke.color);
        expect(preview.activeWidth, 8);
        await draw.up();
        await tester.pumpAndSettle();
        final original = container.read(workspaceProvider).annotations.single;
        expect(original.color, stroke.color);
        expect(original.width, 8);
        await capture(tester, boundary, 'canvas-brush-$scale');

        await tester.tap(tool('eraser'));
        await tester.pumpAndSettle();
        tester
            .widget<Slider>(
              find.byKey(const ValueKey('workspace eraser diameter')),
            )
            .onChanged!(30);
        await tester.pumpAndSettle();
        final erase = await tester.startGesture(
          at(middle + const Offset(0, -40)),
          kind: PointerDeviceKind.mouse,
        );
        await erase.moveTo(at(middle + const Offset(0, 40)));
        await tester.pump();
        // Preview is immediate but document/history are committed on release only.
        expect(container.read(workspaceProvider).annotations, hasLength(1));
        await erase.up();
        await tester.pumpAndSettle();
        final fragments = container.read(workspaceProvider).annotations;
        expect(fragments, hasLength(2));
        expect(fragments.first.points.last.dx, closeTo(middle.dx - 19, .01));
        expect(fragments.last.points.first.dx, closeTo(middle.dx + 19, .01));
        await capture(tester, boundary, 'canvas-eraser-$scale');
        controller.undo();
        expect(
          container.read(workspaceProvider).annotations.single.toJson(),
          original.toJson(),
        );
        controller.redo();
        expect(container.read(workspaceProvider).annotations, hasLength(2));
        await tester.pumpAndSettle();
        final cancel = await tester.startGesture(
          at(start),
          kind: PointerDeviceKind.mouse,
        );
        await cancel.moveTo(at(end));
        await cancel.cancel();
        await tester.pumpAndSettle();
        expect(
          container
              .read(workspaceProvider)
              .annotations
              .map((a) => a.toJson())
              .toList(),
          fragments.map((a) => a.toJson()).toList(),
        );
        await tester.tap(tool('pencil'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Slider>(
                find.byKey(const ValueKey('workspace brush diameter')),
              )
              .value,
          8,
        );
        await tester.tapAt(at(start + const Offset(0, 100)));
        await tester.pumpAndSettle();
        expect(
          container.read(workspaceProvider).annotations.last.points,
          hasLength(1),
        );
        await tester.tap(tool('select'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('workspace drawing options')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 350));
        final reloaded = ProviderContainer();
        addTearDown(reloaded.dispose);
        reloaded.read(workspaceProvider);
        await tester.pump();
        final saved = reloaded.read(workspaceProvider).annotations;
        expect(saved, hasLength(3));
        expect(saved.first.color, original.color);
        expect(saved.first.width, original.width);
        expect(saved.first.points, fragments.first.points);
        expect(saved.last.points, hasLength(1));
      },
    );
  }
}
