/// Monotonic presentation cap. Keeps fractional phase instead of rounding
/// 144/60 down to 48 FPS. Never changes acquisition timing.
class FrameGate {
  int? _next;
  int? _rate;

  bool accept(Duration timestamp, int rate) {
    final now = timestamp.inMicroseconds;
    if (rate <= 0) {
      _next = null;
      _rate = rate;
      return true;
    }
    final interval = (1000000 / rate).round();
    if (_rate != rate || _next == null) {
      _rate = rate;
      _next = now + interval;
      return true;
    }
    if (now < _next!) return false;
    _next = now - _next! > interval ? now + interval : _next! + interval;
    return true;
  }
}
