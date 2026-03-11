import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Light-mode geometric background for wellness app
/// Subtle grid + soft color dots — very light, airy feel
class GeometricBackground extends StatelessWidget {
  const GeometricBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      painter: _WellnessBgPainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _WellnessBgPainter extends CustomPainter {
  final Color color;
  _WellnessBgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Very subtle dot grid — barely-visible on white background
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const spacing = 32.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    // Soft accent circles in corners
    _drawBlob(canvas, Offset(size.width * 0.9, -size.height * 0.05),
        size.width * 0.35, color); // primary top-right
    _drawBlob(canvas, Offset(-size.width * 0.05, size.height * 0.75),
        size.width * 0.30, const Color(0xFF0EA5E9)); // sky mid-left
    _drawBlob(canvas, Offset(size.width * 0.5, size.height * 1.0),
        size.width * 0.25, const Color(0xFF10B981)); // emerald bottom

    // Light hexagon outlines
    final hexPaint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    _drawHex(canvas, Offset(size.width * 0.92, size.height * 0.25), 45, hexPaint);
    _drawHex(canvas, Offset(size.width * 0.06, size.height * 0.12), 25, hexPaint);
    _drawHex(canvas, Offset(size.width * 0.65, size.height * 0.92), 32, hexPaint);
  }

  void _drawBlob(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.08),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  void _drawHex(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
