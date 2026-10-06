import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

/// Eases coarse wheel steps while keeping small precision-scroll deltas direct.
/// Flutter on Linux does not identify the physical source of scroll signals,
/// so the distinction is deliberately based on delta size, not device kind.
class DesktopScrollController extends ScrollController {
  DesktopScrollController({super.debugLabel});

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _DesktopScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    keepScrollOffset: keepScrollOffset,
    initialPixels: initialScrollOffset,
    debugLabel: debugLabel,
  );
}

class _DesktopScrollPosition extends ScrollPositionWithSingleContext {
  _DesktopScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    super.keepScrollOffset,
    super.initialPixels,
    super.debugLabel,
  });

  double? _wheelTarget;
  int _generation = 0;

  @override
  void pointerScroll(double delta) {
    if (!delta.isFinite) return;
    if (delta.abs() < 40 ||
        MediaQuery.maybeDisableAnimationsOf(context.storageContext) == true) {
      _wheelTarget = null;
      ++_generation;
      super.pointerScroll(delta);
      return;
    }
    // Reversing direction should respond immediately, not first consume the
    // unrendered tail of the previous wheel movement.
    final base = _wheelTarget != null && (_wheelTarget! - pixels) * delta >= 0
        ? _wheelTarget!
        : pixels;
    final target = (base + delta)
        .clamp(minScrollExtent, maxScrollExtent)
        .toDouble();
    if (target == pixels) {
      _wheelTarget = null;
      ++_generation;
      super.pointerScroll(0);
      return;
    }
    _wheelTarget = target;
    final generation = ++_generation;
    updateUserScrollDirection(
      delta < 0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    unawaited(
      animateTo(
        target,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      ).whenComplete(() {
        if (generation == _generation) _wheelTarget = null;
      }),
    );
  }

  @override
  void jumpTo(double value) {
    _wheelTarget = null;
    ++_generation;
    super.jumpTo(value);
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    _wheelTarget = null;
    ++_generation;
    return super.drag(details, dragCancelCallback);
  }

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    _wheelTarget = null;
    ++_generation;
    return super.hold(holdCancelCallback);
  }
}
