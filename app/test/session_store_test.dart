import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bci_engine/core/session/edf_codec.dart';
import 'package:bci_engine/core/session/session_store.dart';

void main() {
  test('EDF preserves large amplitudes and calibrated multiple records', () {
    final original = SessionDocument(
      sampleRate: 2,
      channels: 2,
      startedAt: DateTime(2026, 11, 19, 12, 30),
      samples: Float32List.fromList([100, -200, 150, -100, 200, 0, 250, 100]),
    );
    final bytes = EdfCodec.encode(original);
    // Convert the single record payload to two record-major records.
    void field(int offset, int length, String value) {
      bytes.setRange(offset, offset + length, value.padRight(length).codeUnits);
    }

    field(236, 8, '2');
    field(244, 8, '1');
    field(256 + 2 * 216, 8, '2');
    field(256 + 2 * 216 + 8, 8, '2');
    final payload = bytes.sublist(768);
    bytes.setRange(768, bytes.length, [
      ...payload.sublist(0, 4),
      ...payload.sublist(8, 12),
      ...payload.sublist(4, 8),
      ...payload.sublist(12, 16),
    ]);
    final decoded = EdfCodec.decode(bytes);
    expect(decoded.sampleRate, 2);
    expect(decoded.startedAt, original.startedAt);
    for (var i = 0; i < original.samples.length; i++) {
      expect(decoded.samples[i], closeTo(original.samples[i], .01));
    }
    field(256 + 2 * 216 + 8, 8, '3');
    expect(() => EdfCodec.decode(bytes), throwsFormatException);
  });

  test(
    'EDF rejects truncation, invalid calibration, annotations and headers',
    () {
      final document = SessionDocument(
        sampleRate: 256,
        channels: 1,
        samples: Float32List.fromList([1, 2, 3]),
      );
      final bytes = EdfCodec.encode(document);
      expect(
        () => EdfCodec.decode(bytes.sublist(0, bytes.length - 1)),
        throwsFormatException,
      );
      final corrupt = Uint8List.fromList(bytes);
      corrupt.setRange(256 + 104, 256 + 112, 'NaN     '.codeUnits);
      expect(() => EdfCodec.decode(corrupt), throwsFormatException);
      final annotated = SessionDocument(
        sampleRate: 1,
        channels: 1,
        samples: Float32List.fromList([0]),
        annotations: const [SessionAnnotation(0, 'marker')],
      );
      expect(() => EdfCodec.encode(annotated), throwsFormatException);
    },
  );
  test('EDF round trip preserves bounded interleaved session samples', () {
    final samples = Float32List.fromList([
      -0.5,
      0.25,
      0.0,
      0.75,
      0.5,
      -0.25,
      1.0,
      -1.0,
    ]);
    final document = SessionDocument(
      sampleRate: 250,
      channels: 2,
      samples: samples,
      labels: const ['C3', 'C4'],
    );
    final decoded = EdfCodec.decode(EdfCodec.encode(document));
    expect(decoded.sampleRate, closeTo(250, .001));
    expect(decoded.channels, 2);
    expect(decoded.labels, ['C3', 'C4']);
    expect(decoded.samples.length, samples.length);
    for (var i = 0; i < samples.length; i++) {
      expect(decoded.samples[i], closeTo(samples[i], 1 / 32767));
    }
  });

  test('session store uses atomic EDF files and metadata index', () async {
    final directory = await Directory.systemTemp.createTemp('qualia-session-');
    addTearDown(() => directory.delete(recursive: true));
    final store = SessionStore(root: directory);
    final path = await store.save(
      'fixture_1',
      SessionDocument(
        sampleRate: 128,
        channels: 1,
        samples: Float32List.fromList([0, .5, -.5, 1]),
      ),
    );
    expect(await path.exists(), isTrue);
    expect(await File('${directory.path}/fixture_1.json').exists(), isTrue);
    expect((await store.list()).single['frames'], 4);
    expect((await store.load('fixture_1')).samples.length, 4);
    await expectLater(store.load('../outside'), throwsFormatException);
    final restarted = SessionStore(root: directory);
    expect((await restarted.list()).single['id'], 'fixture_1');
  });
}
