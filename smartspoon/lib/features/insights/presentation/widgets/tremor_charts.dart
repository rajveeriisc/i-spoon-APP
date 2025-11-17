import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models.dart';

class TremorCharts extends StatefulWidget {
  const TremorCharts({super.key, required this.metrics});
  final TremorMetrics? metrics;

  @override
  State<TremorCharts> createState() => _TremorChartsState();
}

class _TremorChartsState extends State<TremorCharts>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final m = widget.metrics;
    final level = m?.level ?? TremorLevel.low;
    final levelText = level == TremorLevel.low
        ? 'Low'
        : level == TremorLevel.moderate
            ? 'Moderate'
            : 'High';

    final levelColor = level == TremorLevel.low
        ? const Color(0xFF34C759)
        : level == TremorLevel.moderate
            ? const Color(0xFFFFB100)
            : const Color(0xFFFF3B30);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
      ),
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
                      const Color(0xFF667EEA),
                      const Color(0xFF764BA2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.back_hand_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Tremor Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Waveform and Radial Gauge Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _TremorWaveform(
                  magnitude: m?.currentMagnitude ?? 0.05,
                  frequency: m?.peakFrequencyHz ?? 5.0,
                  animation: _animationController,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 20),
              _RadialTremorGauge(
                level: level,
                magnitude: m?.currentMagnitude ?? 0.05,
                color: levelColor,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Metrics Cards
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Magnitude',
                  value: m?.currentMagnitude.toStringAsFixed(3) ?? '—',
                  unit: 'rad/s',
                  icon: Icons.show_chart_rounded,
                  color: levelColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Frequency',
                  value: m?.peakFrequencyHz.toStringAsFixed(1) ?? '—',
                  unit: 'Hz',
                  icon: Icons.graphic_eq_rounded,
                  color: const Color(0xFF007AFF),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Level',
                  value: levelText,
                  unit: '',
                  icon: Icons.monitor_heart_rounded,
                  color: levelColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TremorWaveform extends StatelessWidget {
  const _TremorWaveform({
    required this.magnitude,
    required this.frequency,
    required this.animation,
    required this.isDark,
  });

  final double magnitude;
  final double frequency;
  final Animation<double> animation;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Real-time Waveform',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.grey.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WaveformPainter(
                    magnitude: magnitude,
                    frequency: frequency,
                    phase: animation.value * 2 * math.pi,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double magnitude;
  final double frequency;
  final double phase;
  final bool isDark;

  _WaveformPainter({
    required this.magnitude,
    required this.frequency,
    required this.phase,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF667EEA)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF667EEA).withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    final glowPath = Path();

    const points = 200;
    final amplitude = size.height * 0.3 * (magnitude * 10).clamp(0.0, 1.0);

    for (var i = 0; i < points; i++) {
      final x = (i / points) * size.width;
      final t = (i / points) * 4 * math.pi + phase;
      final y = size.height / 2 +
          amplitude * math.sin(frequency * t) +
          amplitude * 0.3 * math.sin(frequency * 2 * t + 1.5);

      if (i == 0) {
        path.moveTo(x, y);
        glowPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        glowPath.lineTo(x, y);
      }
    }

    canvas.drawPath(glowPath, glowPaint);
    canvas.drawPath(path, paint);

    // Draw center line
    final centerLinePaint = Paint()
      ..color = isDark
          ? Colors.grey.withValues(alpha: 0.2)
          : Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerLinePaint,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) => true;
}

class _RadialTremorGauge extends StatelessWidget {
  const _RadialTremorGauge({
    required this.level,
    required this.magnitude,
    required this.color,
    required this.isDark,
  });

  final TremorLevel level;
  final double magnitude;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final progress = level == TremorLevel.low
        ? 0.33
        : level == TremorLevel.moderate
            ? 0.66
            : 1.0;

    return SizedBox(
      width: 100,
      height: 144,
      child: Column(
        children: [
          Text(
            'Level',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: _RadialGaugePainter(
                progress: progress,
                color: color,
                isDark: isDark,
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.monitor_heart_rounded,
                    color: color,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _RadialGaugePainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;

    // Background arc
    final bgPaint = Paint()
      ..color = isDark
          ? Colors.grey.withValues(alpha: 0.2)
          : Colors.grey.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Progress arc
    final progressSweep = sweepAngle * progress;

    final gradientShader = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + progressSweep,
      colors: [
        const Color(0xFF34C759),
        const Color(0xFFFFB100),
        const Color(0xFFFF3B30),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    final progressPaint = Paint()
      ..shader = gradientShader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progressSweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RadialGaugePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
