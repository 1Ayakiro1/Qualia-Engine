import 'dart:typed_data';

import '../runtime/runtime_events.dart';
import 'edf_codec.dart';

/// Bounded float32 capture; rejects source/format changes instead of writing
/// an EDF with silently incorrect channels or sample timing.
class SessionRecorder {
  SessionRecorder({this.maxValues = 16000000});
  final int maxValues;
  final List<Float32List> _blocks = [];
  int _values = 0;
  double? _rate;
  int? _channels;
  String? _source;

  void add(RuntimeSignalBlock block) {
    if (_rate != null &&
        (_rate != block.sampleRate ||
            _channels != block.channels ||
            _source != block.sourceId)) {
      throw const FormatException('Signal source changed during recording');
    }
    if (_values + block.samples.length > maxValues) {
      throw const FormatException('Recording memory limit reached');
    }
    _rate = block.sampleRate;
    _channels = block.channels;
    _source = block.sourceId;
    _blocks.add(Float32List.fromList(block.samples));
    _values += block.samples.length;
  }

  SessionDocument? finish(DateTime startedAt) {
    if (_values == 0) return null;
    final samples = Float32List(_values);
    var offset = 0;
    for (final block in _blocks) {
      samples.setRange(offset, offset + block.length, block);
      offset += block.length;
    }
    _blocks.clear();
    _values = 0;
    return SessionDocument(
      sampleRate: _rate!,
      channels: _channels!,
      samples: samples,
      startedAt: startedAt,
      labels: [for (var i = 0; i < _channels!; i++) 'CH ${i + 1}'],
    );
  }
}
