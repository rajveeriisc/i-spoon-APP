import 'package:flutter/material.dart';
import '../../domain/models.dart';

class TremorCharts extends StatelessWidget {
  const TremorCharts({
    super.key,
    required this.metrics,
    this.onViewHistory,
  });
  final TremorMetrics? metrics;
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final m = metrics;
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
              const Spacer(),
              if (onViewHistory != null)
                TextButton.icon(
                  onPressed: onViewHistory,
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('History'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Simplified Metrics Display
          Row(
            children: [
              Expanded(
                child: _SimpleMetricCard(
                  label: 'Tremor Level',
                  value: levelText,
                  icon: Icons.monitor_heart_rounded,
                  color: levelColor,
                  isDark: isDark,
                  isHighlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SimpleMetricCard(
                  label: 'Magnitude',
                  value: '${m?.currentMagnitude.toStringAsFixed(3) ?? '—'} rad/s',
                  icon: Icons.show_chart_rounded,
                  color: const Color(0xFF007AFF),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SimpleMetricCard(
                  label: 'Frequency',
                  value: '${m?.peakFrequencyHz.toStringAsFixed(1) ?? '—'} Hz',
                  icon: Icons.graphic_eq_rounded,
                  color: const Color(0xFF5856D6),
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

class _SimpleMetricCard extends StatelessWidget {
  const _SimpleMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: 0.1)
            : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? color.withValues(alpha: 0.3)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
