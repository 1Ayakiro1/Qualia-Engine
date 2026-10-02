import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Scrolling spectrogram model fed by the synthetic signal (v0.1 demo).
/// Later the same model will be fed by the native core output.
class SpectroModel extends ChangeNotifier {
  SpectroModel({this.windowSize = 256, this.hop = 32, this.maxColumns = 320})
    : _ring = Float64List(windowSize) {
    for (int i = 0; i < windowSize; i++) {
      _hann[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (windowSize - 1)));
    }
  }

  /// STFT window (power of two).
  final int windowSize;

  /// New samples per spectral row.
  final int hop;

  /// Scrolling history length (columns).
  final int maxColumns;

  final Float64List _ring;
  final Float64List _hann = Float64List(256);
  int _write = 0;
  int _sinceLastRow = 0;
  double _gain = 1.0;

  /// Spectral rows, oldest first. Each row has [bins] normalized values.
  final List<Float64List> rows = <Float64List>[];

  /// Markers keyed by column offset from the right edge.
  final Map<int, String> markers = <int, String>{};
  int _markerSeq = 0;

  bool paused = false;

  int get bins => windowSize ~/ 4; // 64 display bins

  double get gain => _gain;

  set gain(double value) {
    _gain = value.clamp(0.2, 5.0);
    notifyListeners();
  }

  /// Feeds new samples; emits spectral rows according to [hop].
  void push(List<double> samples) {
    if (paused) {
      return;
    }
    for (final double s in samples) {
      _ring[_write] = s;
      _write = (_write + 1) % windowSize;
      _sinceLastRow++;
      if (_sinceLastRow >= hop) {
        _sinceLastRow = 0;
        _emitRow();
      }
    }
    notifyListeners();
  }

  void _emitRow() {
    final Float64List framed = Float64List(windowSize);
    for (int i = 0; i < windowSize; i++) {
      // Ring is ordered oldest→newest by construction order; read straight.
      framed[i] = _ring[(_write + i) % windowSize] * _hann[i];
    }
    final Float64List magnitude = _fftMagnitude(framed);

    final Float64List row = Float64List(bins);
    final int stride = magnitude.length ~/ bins;
    for (int b = 0; b < bins; b++) {
      double peak = 0;
      for (int k = 0; k < stride; k++) {
        final double m = magnitude[b * stride + k];
        if (m > peak) {
          peak = m;
        }
      }
      final double scaled = (peak * _gain + 1e-5);
      row[b] = ((math.log(scaled) / math.ln10 + 4.0) / 3.5).clamp(0.0, 1.0);
    }

    rows.add(row);
    while (rows.length > maxColumns) {
      rows.removeAt(0);
    }
    // Shift marker columns left by one.
    if (markers.isNotEmpty) {
      final Map<int, String> shifted = <int, String>{};
      markers.forEach((int col, String label) {
        final int newCol = col - 1;
        if (newCol >= 0) {
          shifted[newCol] = label;
        }
      });
      markers
        ..clear()
        ..addAll(shifted);
    }
  }

  /// Radix-2 FFT magnitude (one-sided, N/2 bins).
  Float64List _fftMagnitude(Float64List samples) {
    final int n = samples.length;
    final Float64List re = Float64List.fromList(samples);
    final Float64List im = Float64List(n);

    // Bit reversal.
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        double t = re[i];
        re[i] = re[j];
        re[j] = t;
        t = im[i];
        im[i] = im[j];
        im[j] = t;
      }
    }

    for (int len = 2; len <= n; len <<= 1) {
      final double angle = -2 * math.pi / len;
      final double wr = math.cos(angle);
      final double wi = math.sin(angle);
      for (int start = 0; start < n; start += len) {
        double cr = 1;
        double ci = 0;
        final int half = len >> 1;
        for (int k = 0; k < half; k++) {
          final int i0 = start + k;
          final int i1 = i0 + half;
          final double vr = re[i1] * cr - im[i1] * ci;
          final double vi = re[i1] * ci + im[i1] * cr;
          re[i1] = re[i0] - vr;
          im[i1] = im[i0] - vi;
          re[i0] += vr;
          im[i0] += vi;
          final double ncr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = ncr;
        }
      }
    }

    final Float64List magnitude = Float64List(n ~/ 2);
    for (int i = 0; i < n ~/ 2; i++) {
      magnitude[i] = math.sqrt(re[i] * re[i] + im[i] * im[i]) / n * 2;
    }
    return magnitude;
  }

  void addMarker() {
    if (rows.isEmpty) {
      return;
    }
    _markerSeq++;
    markers[-1] = 'M$_markerSeq'; // -1 = right edge; normalized below
    _normalizeMarkers();
    notifyListeners();
  }

  void removeMarker(int column, String label) {
    markers.remove(column);
    notifyListeners();
  }

  void _normalizeMarkers() {
    // Rightmost column is (maxColumns - 1).
    final Map<int, String> fixed = <int, String>{};
    markers.forEach((int col, String label) {
      final int c = col < 0 ? maxColumns - 1 : col;
      if (c >= 0) {
        fixed[c] = label;
      }
    });
    markers
      ..clear()
      ..addAll(fixed);
  }

  void clear() {
    rows.clear();
    markers.clear();
    _markerSeq = 0;
    _write = 0;
    _sinceLastRow = 0;
    notifyListeners();
  }

  void setPaused(bool value) {
    paused = value;
    notifyListeners();
  }
}

/// Inferno-like colormap for spectrogram rendering.
Color spectroColor(double value) {
  const List<Color> stops = <Color>[
    Color(0xFF04040A),
    Color(0xFF2C0F5A),
    Color(0xFF6C1D8F),
    Color(0xFFB6367C),
    Color(0xFFF16023),
    Color(0xFFF98E09),
    Color(0xFFFCFFA4),
  ];
  final double v = value.clamp(0.0, 1.0) * (stops.length - 1);
  final int index = v.floor();
  final int next = (index + 1).clamp(0, stops.length - 1);
  return Color.lerp(stops[index], stops[next], v - index)!;
}
