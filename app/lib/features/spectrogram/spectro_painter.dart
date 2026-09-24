import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'spectro_model.dart';

/// Scrolling heatmap painter for [SpectroModel].
class SpectroPainter extends CustomPainter {
  SpectroPainter({required this.model});

  final SpectroModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF05040C),
    );

    final int columns = model.rows.length;
    if (columns == 0 || model.bins == 0) {
      return;
    }
    final double cellW = size.width / model.maxColumns;
    final double cellH = size.height / model.bins;

    for (int c = 0; c < columns; c++) {
      final int col = model.maxColumns - columns + c;
      final Float64List row = model.rows[c];
      final double x = col * cellW;
      for (int b = 0; b < row.length; b++) {
        final double v = row[b];
        if (v <= 0.01) {
          continue;
        }
        paint.color = spectroColor(v);
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - (b + 1) * cellH, cellW + 0.5,
              cellH + 0.5),
          paint,
        );
      }
    }

    final TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    model.markers.forEach((int col, String label) {
      if (col < 0 || col >= model.maxColumns) {
        return;
      }
      final double x = col * cellW;
      paint
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      tp.text = TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
      );
      tp.layout();
      tp.paint(canvas, Offset(x + 3, 4));
      paint.style = PaintingStyle.fill;
    });
  }

  @override
  bool shouldRepaint(SpectroPainter oldDelegate) => true;
}
