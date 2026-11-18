import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';

import 'synthetic_signal.dart';

class RuntimeFrame {
  const RuntimeFrame(this.timestamp, this.delta, this.sequence);

  final Duration timestamp;
  final Duration delta;
  final int sequence;
}

class RuntimeSignalBlock {
  const RuntimeSignalBlock(this.samples, this.sampleRate, this.sequence);

  final List<double> samples;
  final double sampleRate;
  final int sequence;
}

/// Host-local data events and a single Flutter frame clock (which uses the
/// native vsync bridge on Linux). This is not a module transport or acquisition
/// clock: real producers call [publishSignal] independently of display FPS.
class RuntimeEventHub {
  RuntimeEventHub({this.simulateSignal = false}) {
    _frames = StreamController<RuntimeFrame>.broadcast(
      sync: true,
      onListen: _ensureTicker,
      onCancel: _stopIfUnused,
    );
    _signals = StreamController<RuntimeSignalBlock>.broadcast(
      sync: true,
      onListen: _ensureTicker,
      onCancel: _stopIfUnused,
    );
  }

  // The session and spectrogram currently display the shared offline demo.
  // Simulation is explicitly disabled in hubs used for real acquisition.
  static final RuntimeEventHub instance = RuntimeEventHub(simulateSignal: true);
  final bool simulateSignal;
  final SyntheticSignal _simulator = SyntheticSignal();
  late final StreamController<RuntimeFrame> _frames;
  late final StreamController<RuntimeSignalBlock> _signals;
  Ticker? _ticker;
  Duration? _lastFrame;
  double _sampleRemainder = 0;
  int _frameSequence = 0;
  int _signalSequence = 0;

  Stream<RuntimeFrame> get frames => _frames.stream;
  Stream<RuntimeSignalBlock> get signals => _signals.stream;

  bool get _hasConsumers => _frames.hasListener || _signals.hasListener;

  void _ensureTicker() {
    if (_ticker != null || !_hasConsumers) return;
    _lastFrame = null;
    _sampleRemainder = 0;
    _ticker = Ticker(_onTick)..start();
  }

  void _stopIfUnused() {
    if (_hasConsumers) return;
    _ticker?.dispose();
    _ticker = null;
    _lastFrame = null;
  }

  void _onTick(Duration elapsed) {
    final previous = _lastFrame;
    _lastFrame = elapsed;
    final delta = previous == null ? Duration.zero : elapsed - previous;
    if (simulateSignal && _signals.hasListener) {
      // Fractional accumulation preserves 256 Hz at 60/144/165/240 Hz. A
      // suspended window does not create an unbounded catch-up allocation.
      _sampleRemainder += math.min(delta.inMicroseconds, 250000) *
          _simulator.sampleRate / Duration.microsecondsPerSecond;
      final count = _sampleRemainder.floor();
      _sampleRemainder -= count;
      if (count > 0) publishSignal(_simulator.take(count));
    }
    // Deliver data before the frame event so observers commit once per frame.
    _frames.add(RuntimeFrame(elapsed, delta, _frameSequence++));
  }

  void publishSignal(List<double> samples, {double sampleRate = 256}) {
    if (!sampleRate.isFinite || sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (samples.isEmpty) return;
    _signals.add(RuntimeSignalBlock(
      List<double>.unmodifiable(samples), sampleRate, _signalSequence++,
    ));
  }
}
