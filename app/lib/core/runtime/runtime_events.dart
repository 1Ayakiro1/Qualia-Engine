import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/scheduler.dart';

import 'synthetic_signal.dart';

class RuntimeFrame {
  const RuntimeFrame(this.timestamp, this.delta, this.sequence);

  final Duration timestamp;
  final Duration delta;
  final int sequence;
}

class RuntimeSignalBlock {
  const RuntimeSignalBlock(
    this.samples,
    this.sampleRate,
    this.sequence, {
    this.channels = 1,
    this.timestampSeconds,
    this.sourceId = 'simulator',
  });

  final List<double> samples;
  final double sampleRate;
  final int sequence;
  final int channels;
  final double? timestampSeconds;
  final String sourceId;
  int get frames => samples.length ~/ channels;
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
  Timer? _simulationTimer;
  Stopwatch? _simulationClock;
  int _generatedSamples = 0;
  bool _externalSource = false;
  Duration? _lastFrame;
  int _frameSequence = 0;
  int _signalSequence = 0;

  Stream<RuntimeFrame> get frames => _frames.stream;
  Stream<RuntimeSignalBlock> get signals => _signals.stream;

  bool get _hasConsumers => _frames.hasListener || _signals.hasListener;

  void useExternalSource(bool active) {
    _externalSource = active;
    _simulationClock?.reset();
    _generatedSamples = 0;
  }

  void _ensureTicker() {
    if (_ticker != null || !_hasConsumers) return;
    _lastFrame = null;
    _ticker = Ticker(_onTick)..start();
    if (simulateSignal) {
      _simulationClock = Stopwatch()..start();
      _generatedSamples = 0;
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 8), (_) {
        final target =
            (_simulationClock!.elapsedMicroseconds *
                    _simulator.sampleRate /
                    Duration.microsecondsPerSecond)
                .floor();
        final count = math.min(target - _generatedSamples, 4096);
        _generatedSamples = target;
        if (!_externalSource && _signals.hasListener && count > 0) {
          publishSignal(_simulator.take(count));
        }
      });
    }
  }

  void _stopIfUnused() {
    if (_hasConsumers) return;
    _ticker?.dispose();
    _ticker = null;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _simulationClock = null;
    _lastFrame = null;
  }

  void _onTick(Duration elapsed) {
    final previous = _lastFrame;
    _lastFrame = elapsed;
    final delta = previous == null ? Duration.zero : elapsed - previous;
    // Deliver data before the frame event so observers commit once per frame.
    _frames.add(RuntimeFrame(elapsed, delta, _frameSequence++));
  }

  void publishSignal(
    List<double> samples, {
    double sampleRate = 256,
    int channels = 1,
    double? timestampSeconds,
    String sourceId = 'simulator',
  }) {
    if (!sampleRate.isFinite || sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (samples.isEmpty) return;
    if (channels < 1 ||
        channels > 256 ||
        samples.length % channels != 0 ||
        samples.length > 1048576 ||
        samples.any((v) => !v.isFinite)) {
      throw ArgumentError('Invalid signal block');
    }
    _signals.add(
      RuntimeSignalBlock(
        Float32List.fromList(samples).asUnmodifiableView(),
        sampleRate,
        _signalSequence++,
        channels: channels,
        timestampSeconds: timestampSeconds,
        sourceId: sourceId,
      ),
    );
  }
}
