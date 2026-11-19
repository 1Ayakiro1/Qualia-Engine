import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bci_engine/core/render/frame_gate.dart';
import 'package:bci_engine/core/render/render_preferences.dart';
import 'package:bci_engine/core/runtime/runtime_events.dart';
import 'package:bci_engine/core/runtime/lsl_source.dart';
import 'package:bci_engine/core/native/engine_bindings.dart';
import 'package:bci_engine/core/session/session_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fractional frame cap retains 60 updates on a 144 Hz display', () {
    final gate = FrameGate();
    var accepted = 0;
    for (var i = 0; i < 1440; i++) {
      if (gate.accept(
        Duration(microseconds: (i * 1000000 / 144).round()),
        60,
      )) {
        accepted++;
      }
    }
    expect(accepted, inInclusiveRange(599, 601));
    expect(gate.accept(const Duration(seconds: 11), 0), isTrue);
  });

  test('render preferences recover invalid persisted values', () async {
    SharedPreferences.setMockInitialValues({
      'render_preferences_v1':
          '{"backend":"unknown","frameRate":-1,"quality":"bad"}',
    });
    final prefs = await RenderPreferences.load();
    expect(prefs.backend, RenderBackend.auto);
    expect(prefs.frameRate, 0);
    expect(prefs.quality, RenderQuality.balanced);
    expect(prefs.copyWith(frameRate: 123).frameRate, 0);
  });

  test(
    'recorder preserves channel order, rate, bounds and source identity',
    () {
      final recorder = SessionRecorder(maxValues: 8);
      final block = RuntimeSignalBlock(
        Float32List.fromList([1, 10, 2, 20]),
        250,
        1,
        channels: 2,
        sourceId: 'fixture',
      );
      recorder.add(block);
      expect(
        () => recorder.add(const RuntimeSignalBlock([1], 256, 2)),
        throwsFormatException,
      );
      recorder.add(block);
      expect(() => recorder.add(block), throwsFormatException);
      final document = recorder.finish(DateTime(2026))!;
      expect(document.samples, [1, 10, 2, 20, 1, 10, 2, 20]);
      expect(document.sampleRate, 250);
      expect(document.channels, 2);
    },
  );

  test(
    'signal publication rejects invalid dimensions and copies float32 data',
    () async {
      final hub = RuntimeEventHub();
      final future = hub.signals.first;
      final samples = [1.0, 2.0];
      hub.publishSignal(samples, channels: 2, sampleRate: 250);
      samples[0] = 999;
      final block = await future;
      expect(block.samples, [1, 2]);
      expect(() => block.samples[0] = 0, throwsUnsupportedError);
      expect(block.frames, 1);
      expect(() => hub.publishSignal([1], channels: 2), throwsArgumentError);
      expect(() => hub.publishSignal([double.nan]), throwsArgumentError);
    },
  );

  test(
    'LSL worker delivers typed multichannel blocks and stops cleanly',
    () async {
      if (Platform.environment['QUALIA_TEST_LSL'] != '1') return;
      final bindings = CoreBindings.tryLoad();
      expect(bindings, isNotNull);
      final streams = bindings!.discoverLsl();
      expect(streams, hasLength(1));
      final hub = RuntimeEventHub();
      final source = LslRuntimeSource(bindings.path, events: hub);
      final blockFuture = hub.signals.first;
      expect(await source.start(streams.single), isTrue);
      final block = await blockFuture.timeout(const Duration(seconds: 5));
      expect(block.channels, 2);
      expect(block.sampleRate, 250);
      expect(block.samples.take(6), [0, 0, 1, -1, 2, -2]);
      expect(block.timestampSeconds, 10);
      await source.stop().timeout(const Duration(seconds: 5));
      expect(source.active, isNull);
      expect(await source.start(streams.single), isTrue);
      await source.stop();
    },
  );
}
