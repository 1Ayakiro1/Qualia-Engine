import 'dart:math' as math;

/// Deterministic EEG-like source used only when the native acquisition source
/// is unavailable. Production HALs publish their own blocks to the runtime hub.
class SyntheticSignal {
  SyntheticSignal({this.sampleRate = 256});

  final double sampleRate;
  final math.Random _rng = math.Random(7);
  double _time = 0;
  int _sampleIndex = 0;

  List<double> take(int count) => List<double>.generate(count, (_) {
    final value = 0.45 * math.sin(2 * math.pi * 8 * _time) +
        0.18 * math.sin(2 * math.pi * 41.5 * _time) +
        0.06 * math.sin(2 * math.pi * 105 * _time) +
        (_rng.nextDouble() - 0.5) * 0.12;
    _time += 1 / sampleRate;
    return value + (_sampleIndex++ % 1100 == 0 ? 0.9 : 0);
  });

  void reset() {
    _time = 0;
    _sampleIndex = 0;
  }
}
