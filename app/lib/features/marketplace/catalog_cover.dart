import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'catalog_entry.dart';

/// Shared wallpaper renderer for catalog cards and author previews.
class CatalogCover extends StatelessWidget {
  const CatalogCover({
    super.key,
    required this.color,
    required this.pattern,
    required this.iconName,
    this.imageUrl,
  });
  final Color color;
  final String pattern;
  final String iconName;
  final String? imageUrl;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.lerp(color, Colors.black, .55)!, color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      CustomPaint(painter: _WallpaperPainter(pattern: pattern)),
      if (imageUrl != null && Uri.tryParse(imageUrl!)?.scheme == 'https')
        Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      if (imageUrl == null)
        Center(
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(32),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              catalogIcon(iconName),
              size: 33,
              color: Colors.white.withAlpha(225),
            ),
          ),
        ),
    ],
  );
}

class _WallpaperPainter extends CustomPainter {
  const _WallpaperPainter({required this.pattern});
  final String pattern;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = Colors.white.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (pattern == 'grid') {
      for (var x = 0.0; x < size.width; x += 24) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (var y = 0.0; y < size.height; y += 24) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (pattern == 'contours') {
      for (var i = 0; i < 15; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * .65, size.height * .4),
            width: 30 + i * 40.0,
            height: 20 + i * 22.0,
          ),
          paint,
        );
      }
    } else {
      for (var y = -30.0; y < size.height + 30; y += 15) {
        final path = Path();
        for (var x = 0.0; x <= size.width; x += 6) {
          final dy = y + math.sin(x / 75 + y / 70) * 18;
          x == 0 ? path.moveTo(x, dy) : path.lineTo(x, dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WallpaperPainter oldDelegate) =>
      oldDelegate.pattern != pattern;
}
