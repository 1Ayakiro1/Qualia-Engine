import 'dart:convert';
import 'dart:typed_data';

/// A bounded, dependency-free EDF+ signal document. Samples are kept as
/// float32 in memory; EDF stores calibrated signed 16-bit samples on disk.
class SessionDocument {
  const SessionDocument({
    required this.sampleRate,
    required this.channels,
    required this.samples,
    this.startedAt,
    this.labels = const <String>[],
    this.annotations = const <SessionAnnotation>[],
  });

  final double sampleRate;
  final int channels;
  final Float32List samples;
  final DateTime? startedAt;
  final List<String> labels;
  final List<SessionAnnotation> annotations;

  int get frames => channels <= 0 ? 0 : samples.length ~/ channels;

  void validate({int maxFrames = 25000000}) {
    if (!sampleRate.isFinite || sampleRate <= 0 ||
        channels <= 0 || channels > 256 || samples.isEmpty ||
        samples.length % channels != 0 || frames > maxFrames) {
      throw const FormatException('Invalid session signal dimensions.');
    }
    if (labels.isNotEmpty && labels.length != channels) {
      throw const FormatException('Session channel labels do not match channels.');
    }
    for (final value in samples) {
      if (!value.isFinite) throw const FormatException('Session contains NaN/Inf.');
    }
  }
}

class SessionAnnotation {
  const SessionAnnotation(this.frame, this.text);
  final int frame;
  final String text;
}

/// Minimal EDF writer/reader for uniformly sampled float32 sessions.
/// Unsupported EDF variants are rejected instead of silently approximated.
class EdfCodec {
  const EdfCodec._();

  static const maxBytes = 512 * 1024 * 1024;

  static Uint8List encode(SessionDocument document) {
    document.validate();
    final frames = document.frames;
    final samplesPerRecord = frames;
    final recordBytes = document.channels * samplesPerRecord * 2;
    final total = 256 + document.channels * 256 + recordBytes;
    if (total > maxBytes) throw const FormatException('EDF is too large.');
    final bytes = Uint8List(total);
    final header = ByteData.sublistView(bytes);
    _ascii(bytes, 0, 8, '0');
    _ascii(bytes, 8, 80, 'QUALIA');
    _ascii(bytes, 88, 80, 'EDF+ signal session');
    _ascii(bytes, 168, 8, _date(document.startedAt));
    _ascii(bytes, 176, 8, _time(document.startedAt));
    _ascii(bytes, 184, 8, '${256 + document.channels * 256}');
    _ascii(bytes, 192, 44, 'Qualia Engine EDF export');
    _ascii(bytes, 236, 8, '1');
    _ascii(bytes, 244, 8, (frames / document.sampleRate).toStringAsFixed(6));
    _ascii(bytes, 252, 4, '${document.channels}');
    var offset = 256;
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 16, document.labels.isEmpty ? 'ch${channel + 1}' : document.labels[channel]);
      offset += 16;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 80, 'EEG'); offset += 80;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, 'uV'); offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, '-1'); offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, '1'); offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, '-32768'); offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, '32767'); offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 80, ''); offset += 80;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, '$samplesPerRecord'); offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 32, ''); offset += 32;
    }
    var sampleOffset = 256 + document.channels * 256;
    // EDF stores one signal's samples contiguously inside each record, while
    // the in-memory document is interleaved by frame.
    for (var channel = 0; channel < document.channels; channel++) {
      for (var frame = 0; frame < frames; frame++) {
        final value = document.samples[frame * document.channels + channel];
        final quantized = (value.clamp(-1.0, 1.0) * 32767).round();
        header.setInt16(sampleOffset, quantized, Endian.little);
        sampleOffset += 2;
      }
    }
    return bytes;
  }

  static SessionDocument decode(List<int> input) {
    if (input.length < 512 || input.length > maxBytes) {
      throw const FormatException('Invalid EDF size.');
    }
    final bytes = Uint8List.fromList(input);
    final header = ByteData.sublistView(bytes);
    final headerBytes = int.tryParse(_field(bytes, 184, 8)) ?? 0;
    final channels = int.tryParse(_field(bytes, 252, 4)) ?? 0;
    final records = int.tryParse(_field(bytes, 236, 8)) ?? 0;
    if (headerBytes < 256 || channels <= 0 || channels > 256 || records <= 0 ||
        headerBytes != 256 + channels * 256) {
      throw const FormatException('Unsupported EDF header.');
    }
    final labels = <String>[];
    for (var channel = 0; channel < channels; channel++) {
      labels.add(_field(bytes, 256 + channel * 16, 16));
    }
    final samplesOffset = headerBytes;
    final sampleCount = bytes.length - samplesOffset;
    if (sampleCount <= 0 || sampleCount.isOdd || sampleCount ~/ 2 > 25000000 * channels) {
      throw const FormatException('Invalid EDF sample payload.');
    }
    final values = Float32List(sampleCount ~/ 2);
    var cursor = samplesOffset;
    final sampleFrames = values.length ~/ channels;
    for (var channel = 0; channel < channels; channel++) {
      for (var frame = 0; frame < sampleFrames; frame++) {
        values[frame * channels + channel] =
            header.getInt16(cursor, Endian.little) / 32767.0;
        cursor += 2;
      }
    }
    final samplesPerRecordOffset = 256 + channels * (16 + 80 + 8 + 8 + 8 + 8 + 8 + 80);
    final samplesPerRecord = int.tryParse(
          _field(bytes, samplesPerRecordOffset, 8),
        ) ??
        0;
    final duration = double.tryParse(_field(bytes, 244, 8)) ?? 0;
    final sampleRate = samplesPerRecord > 0 && duration > 0
        ? samplesPerRecord / duration
        : 1.0;
    final document = SessionDocument(
      sampleRate: sampleRate,
      channels: channels,
      samples: values,
      labels: labels,
    );
    document.validate();
    return document;
  }

  static String _field(Uint8List bytes, int offset, int length) =>
      utf8.decode(bytes.sublist(offset, offset + length), allowMalformed: true).trim();

  static void _ascii(Uint8List bytes, int offset, int length, String value) {
    final encoded = ascii.encode(value);
    for (var i = 0; i < length; i++) {
      bytes[offset + i] = i < encoded.length ? encoded[i] : 0x20;
    }
  }

  static String _date(DateTime? date) {
    final value = date ?? DateTime.now();
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${(value.year % 100).toString().padLeft(2, '0')}';
  }

  static String _time(DateTime? date) {
    final value = date ?? DateTime.now();
    return '${value.hour.toString().padLeft(2, '0')}.${value.minute.toString().padLeft(2, '0')}.${value.second.toString().padLeft(2, '0')}';
  }
}
