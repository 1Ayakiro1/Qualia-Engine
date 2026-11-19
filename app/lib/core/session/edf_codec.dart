import 'dart:convert';
import 'dart:typed_data';

/// A bounded, dependency-free EDF signal document. Samples are kept as
/// float32 in memory; EDF stores calibrated signed 16-bit samples on disk.
class SessionDocument {
  const SessionDocument({
    required this.sampleRate,
    required this.channels,
    required this.samples,
    this.startedAt,
    this.labels = const <String>[],
    this.annotations = const <SessionAnnotation>[],
    this.units = const <String>[],
  });

  final double sampleRate;
  final int channels;
  final Float32List samples;
  final DateTime? startedAt;
  final List<String> labels;
  final List<SessionAnnotation> annotations;
  final List<String> units;

  int get frames => channels <= 0 ? 0 : samples.length ~/ channels;

  void validate({int maxFrames = 25000000}) {
    if (!sampleRate.isFinite ||
        sampleRate <= 0 ||
        channels <= 0 ||
        channels > 256 ||
        samples.isEmpty ||
        samples.length % channels != 0 ||
        frames > maxFrames) {
      throw const FormatException('Invalid session signal dimensions.');
    }
    if (labels.isNotEmpty && labels.length != channels) {
      throw const FormatException(
        'Session channel labels do not match channels.',
      );
    }
    if (units.isNotEmpty && units.length != channels) {
      throw const FormatException(
        'Session channel units do not match channels.',
      );
    }
    for (final value in samples) {
      if (!value.isFinite) {
        throw const FormatException('Session contains NaN/Inf.');
      }
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
    if (document.annotations.isNotEmpty) {
      throw const FormatException('EDF+ annotations are not supported.');
    }
    final frames = document.frames;
    final minima = List<double>.filled(document.channels, double.infinity);
    final maxima = List<double>.filled(
      document.channels,
      double.negativeInfinity,
    );
    for (var i = 0; i < document.samples.length; i++) {
      final ch = i % document.channels;
      final v = document.samples[i];
      if (v < minima[ch]) minima[ch] = v;
      if (v > maxima[ch]) maxima[ch] = v;
    }
    for (var ch = 0; ch < document.channels; ch++) {
      if (minima[ch] >= -1 && maxima[ch] <= 1) {
        minima[ch] = -1;
        maxima[ch] = 1;
      } else {
        final padding = (maxima[ch] - minima[ch]).abs() * 0.001 + 0.001;
        minima[ch] -= padding;
        maxima[ch] += padding;
      }
      minima[ch] = double.parse(_number(minima[ch]));
      maxima[ch] = double.parse(_number(maxima[ch]));
      if (minima[ch] >= maxima[ch]) {
        throw const FormatException('Invalid EDF range');
      }
    }
    final duration = _number(frames / document.sampleRate);
    final samplesPerRecord = frames;
    final recordBytes = document.channels * samplesPerRecord * 2;
    final total = 256 + document.channels * 256 + recordBytes;
    if (total > maxBytes) throw const FormatException('EDF is too large.');
    final bytes = Uint8List(total);
    final header = ByteData.sublistView(bytes);
    _ascii(bytes, 0, 8, '0');
    _ascii(bytes, 8, 80, 'QUALIA');
    _ascii(bytes, 88, 80, 'EDF signal session');
    _ascii(bytes, 168, 8, _date(document.startedAt));
    _ascii(bytes, 176, 8, _time(document.startedAt));
    _ascii(bytes, 184, 8, '${256 + document.channels * 256}');
    _ascii(bytes, 192, 44, '');
    _ascii(bytes, 236, 8, '1');
    _ascii(bytes, 244, 8, duration);
    _ascii(bytes, 252, 4, '${document.channels}');
    var offset = 256;
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(
        bytes,
        offset,
        16,
        document.labels.isEmpty ? 'ch${channel + 1}' : document.labels[channel],
      );
      offset += 16;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      // The source may be EEG, EMG or another modality; do not invent it.
      _ascii(bytes, offset, 80, '');
      offset += 80;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(
        bytes,
        offset,
        8,
        document.units.isEmpty ? '' : document.units[channel],
      );
      offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, _number(minima[channel]));
      offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, _number(maxima[channel]));
      offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, '-32768');
      offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, '32767');
      offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 80, '');
      offset += 80;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 8, '$samplesPerRecord');
      offset += 8;
    }
    for (var channel = 0; channel < document.channels; channel++) {
      _ascii(bytes, offset, 32, '');
      offset += 32;
    }
    var sampleOffset = 256 + document.channels * 256;
    // EDF stores one signal's samples contiguously inside each record, while
    // the in-memory document is interleaved by frame.
    for (var channel = 0; channel < document.channels; channel++) {
      for (var frame = 0; frame < frames; frame++) {
        final value = document.samples[frame * document.channels + channel];
        final quantized =
            (((value - minima[channel]) / (maxima[channel] - minima[channel])) *
                        65535 -
                    32768)
                .round()
                .clamp(-32768, 32767);
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
    if (_field(bytes, 0, 8) != '0' ||
        _field(bytes, 192, 44).startsWith('EDF+') ||
        headerBytes < 256 ||
        channels <= 0 ||
        channels > 256 ||
        records <= 0 ||
        headerBytes != 256 + channels * 256 ||
        headerBytes > bytes.length) {
      throw const FormatException('Unsupported EDF header.');
    }
    final labels = <String>[];
    for (var channel = 0; channel < channels; channel++) {
      labels.add(_field(bytes, 256 + channel * 16, 16));
    }
    final samplesPerRecordOffset =
        256 + channels * (16 + 80 + 8 + 8 + 8 + 8 + 8 + 80);
    final samplesPerRecord =
        int.tryParse(_field(bytes, samplesPerRecordOffset, 8)) ?? 0;
    final duration = double.tryParse(_field(bytes, 244, 8)) ?? 0;
    if (samplesPerRecord <= 0 ||
        !duration.isFinite ||
        duration <= 0 ||
        samplesPerRecord * records > 25000000 ||
        samplesPerRecord * records * channels > 25000000 ||
        headerBytes + samplesPerRecord * records * channels * 2 !=
            bytes.length) {
      throw const FormatException('Invalid EDF records or duration.');
    }
    final minima = <double>[];
    final maxima = <double>[];
    final dmin = <int>[];
    final dmax = <int>[];
    for (var ch = 0; ch < channels; ch++) {
      if (int.tryParse(_field(bytes, samplesPerRecordOffset + ch * 8, 8)) !=
              samplesPerRecord ||
          labels[ch] == 'EDF Annotations') {
        throw const FormatException(
          'Mixed sampling rates/annotations are unsupported.',
        );
      }
      minima.add(
        double.tryParse(_field(bytes, 256 + channels * 104 + ch * 8, 8)) ??
            double.nan,
      );
      maxima.add(
        double.tryParse(_field(bytes, 256 + channels * 112 + ch * 8, 8)) ??
            double.nan,
      );
      dmin.add(
        int.tryParse(_field(bytes, 256 + channels * 120 + ch * 8, 8)) ?? 0,
      );
      dmax.add(
        int.tryParse(_field(bytes, 256 + channels * 128 + ch * 8, 8)) ?? 0,
      );
      if (!minima[ch].isFinite ||
          !maxima[ch].isFinite ||
          minima[ch] >= maxima[ch] ||
          dmin[ch] >= dmax[ch] ||
          dmin[ch] < -32768 ||
          dmax[ch] > 32767) {
        throw const FormatException('Invalid EDF calibration.');
      }
    }
    final values = Float32List(samplesPerRecord * records * channels);
    var cursor = headerBytes;
    for (var record = 0; record < records; record++) {
      for (var ch = 0; ch < channels; ch++) {
        for (var frame = 0; frame < samplesPerRecord; frame++) {
          final digital = header.getInt16(cursor, Endian.little);
          values[(record * samplesPerRecord + frame) * channels + ch] =
              minima[ch] +
              (digital - dmin[ch]) *
                  (maxima[ch] - minima[ch]) /
                  (dmax[ch] - dmin[ch]);
          cursor += 2;
        }
      }
    }
    final sampleRate = samplesPerRecord / duration;
    DateTime? startedAt;
    final date = _field(bytes, 168, 8).split('.').map(int.tryParse).toList();
    final time = _field(bytes, 176, 8).split('.').map(int.tryParse).toList();
    if (date.length == 3 &&
        time.length == 3 &&
        !date.contains(null) &&
        !time.contains(null)) {
      startedAt = DateTime(
        date[2]! >= 85 ? 1900 + date[2]! : 2000 + date[2]!,
        date[1]!,
        date[0]!,
        time[0]!,
        time[1]!,
        time[2]!,
      );
    }
    final document = SessionDocument(
      sampleRate: sampleRate,
      channels: channels,
      samples: values,
      labels: labels,
      units: [
        for (var ch = 0; ch < channels; ch++)
          _field(bytes, 256 + channels * 96 + ch * 8, 8),
      ],
      startedAt: startedAt,
    );
    document.validate();
    return document;
  }

  static String _field(Uint8List bytes, int offset, int length) => utf8
      .decode(bytes.sublist(offset, offset + length), allowMalformed: true)
      .trim();

  static void _ascii(Uint8List bytes, int offset, int length, String value) {
    final encoded = ascii.encode(value);
    if (encoded.length > length) {
      throw const FormatException('EDF field overflow');
    }
    for (var i = 0; i < length; i++) {
      bytes[offset + i] = i < encoded.length ? encoded[i] : 0x20;
    }
  }

  static String _number(double value) {
    if (!value.isFinite) throw const FormatException('Nonfinite EDF field');
    final plain = value.toString();
    if (plain.length <= 8) return plain;
    for (var precision = 6; precision >= 1; precision--) {
      final text = value.toStringAsPrecision(precision);
      if (text.length <= 8) return text;
    }
    throw const FormatException('EDF number is not representable');
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
