import 'dart:math' as math;

/// Synthetic EEG-like signal for development and demos.
/// Mix of alpha (8 Hz), beta (41.5 Hz), gamma (105 Hz) + noise + rare spikes.
class SyntheticSignal {
  SyntheticSignal({this.sampleRate = 256});

  final double sampleRate;
  final math.Random _rng = math.Random();
  double _t = 0;
  int _sampleIndex = 0;

  double next() {
    final double t = _t;
    _t += 1.0 / sampleRate;

    double value =
        0.45 * math.sin(2 * math.pi * 8.0 * t) +
        0.18 * math.sin(2 * math.pi * 41.5 * t) +
        0.06 * math.sin(2 * math.pi * 105.0 * t);
    value += (_rng.nextDouble() - 0.5) * 0.12;

    _sampleIndex++;
    if (_sampleIndex % 1100 == 0) {
      value += 0.9; // rare "eye-blink"-like artifact
    }
    return value;
  }

  List<double> take(int count) =>
      List<double>.generate(count, (int _) => next());

  void reset() {
    _t = 0;
    _sampleIndex = 0;
  }
}
