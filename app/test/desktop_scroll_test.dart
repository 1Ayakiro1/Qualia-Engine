import 'package:bci_engine/features/common/desktop_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wheel steps ease, accumulate and stop at boundaries', (
    tester,
  ) async {
    final controller = DesktopScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ListView.builder(
          controller: controller,
          itemExtent: 50,
          itemCount: 100,
          itemBuilder: (_, index) => Text('Item $index'),
        ),
      ),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(ListView)),
        scrollDelta: const Offset(0, 100),
      ),
    );
    expect(controller.offset, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 35));
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, lessThan(100));
    controller.position.pointerScroll(100);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(200, .01));
    controller.position.pointerScroll(100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final reversingAt = controller.offset;
    controller.position.pointerScroll(-80);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(reversingAt - 80, .01));
    controller.jumpTo(200);
    controller.position.pointerScroll(-80);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(120, .01));
    controller.position.pointerScroll(100);
    await tester.pump();
    controller.jumpTo(400);
    await tester.pumpAndSettle();
    expect(controller.offset, 400);
    controller.position.pointerScroll(10000);
    await tester.pumpAndSettle();
    expect(controller.offset, controller.position.maxScrollExtent);
    controller.position.pointerScroll(-10000);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('precision deltas and reduced motion stay immediate', (
    tester,
  ) async {
    final controller = DesktopScrollController();
    addTearDown(controller.dispose);
    Widget app(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: ListView.builder(
          controller: controller,
          itemExtent: 50,
          itemCount: 100,
          itemBuilder: (_, index) => Text('Item $index'),
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    controller.position.pointerScroll(4.5);
    expect(controller.offset, 4.5);
    controller.position.pointerScroll(100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final offset = controller.offset;
    controller.position.pointerScroll(3);
    expect(controller.offset, closeTo(offset + 3, .01));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(offset + 3, .01));
    await tester.pumpWidget(app(true));
    controller.position.pointerScroll(100);
    expect(controller.offset, closeTo(offset + 103, .01));
    controller.position.pointerScroll(double.nan);
    expect(controller.offset.isFinite, isTrue);
    expect(tester.takeException(), isNull);
  });
}
