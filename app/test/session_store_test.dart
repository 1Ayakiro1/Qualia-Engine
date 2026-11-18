import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bci_engine/core/session/edf_codec.dart';
import 'package:bci_engine/core/session/session_store.dart';

void main() {
  test('EDF round trip preserves bounded interleaved session samples', () {
    final samples = Float32List.fromList([
      -0.5, 0.25, 0.0, 0.75, 0.5, -0.25, 1.0, -1.0,
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
  });
}
