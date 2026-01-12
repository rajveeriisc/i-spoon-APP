import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models.dart';

class TemperatureSection extends StatefulWidget {
  const TemperatureSection({super.key, required this.stats});

  final TemperatureStats? stats;

  @override
  State<TemperatureSection> createState() => _TemperatureSectionState();
}

class _TemperatureSectionState extends State<TemperatureSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final food = widget.stats?.foodTempC ?? 45;
    final heater = widget.stats?.heaterTempC ?? 60;
    final alert = food > 60;

    return Container(
      // margin handled by parent
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF2C2C2E),
                  const Color(0xFF1C1C1E),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF8F9FA),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B6B),
                      const Color(0xFFFF8E53),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.whatshot_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Temperature Monitor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AnimatedCircularTempGauge(
                label: 'Food Temp',
                value: food,
                maxValue: 100,
                color: const Color(0xFF34C759),
                animation: _controller,
                icon: Icons.restaurant_rounded,
              ),
              _AnimatedCircularTempGauge(
                label: 'Heater',
                value: heater,
                maxValue: 100,
                color: const Color(0xFFFF3B30),
                animation: _controller,
                icon: Icons.local_fire_department_rounded,
              ),
            ],
          ),
          if (alert) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.15),
                    Colors.deepOrange.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Food is hot! Wait 60 seconds before next bite',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnimatedCircularTempGauge extends StatelessWidget {
  const _AnimatedCircularTempGauge({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.animation,
    required this.icon,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final Animation<double> animation;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (value / maxValue).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final animatedProgress = progress * animation.value;

        return Column(
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: CustomPaint(
                painter: _CircularGaugePainter(
                  progress: animatedProgress,
                  color: color,
                  isDark: isDark,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(value * animation.value).toStringAsFixed(0)}°C',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(progress),
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getStatusText(double progress) {
    if (progress < 0.3) return 'Cool';
    if (progress < 0.5) return 'Warm';
    if (progress < 0.7) return 'Hot';
    return 'Very Hot';
  }
}

class _CircularGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _CircularGaugePainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final strokeWidth = 12.0;

    // Background circle
    final bgPaint = Paint()
      ..color = isDark
          ? Colors.grey.withValues(alpha: 0.2)
          : Colors.grey.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc with gradient
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * progress;

    if (progress > 0) {
      final gradientShader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          color.withValues(alpha: 0.5),
          color,
          color.withValues(alpha: 0.8),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

      final progressPaint = Paint()
        ..shader = gradientShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }

    // Glow effect at the end of progress
    if (progress > 0) {
      final endAngle = startAngle + sweepAngle;
      final glowX = center.dx + radius * math.cos(endAngle);
      final glowY = center.dy + radius * math.sin(endAngle);
      final glowCenter = Offset(glowX, glowY);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(glowCenter, 8, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_CircularGaugePainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
 