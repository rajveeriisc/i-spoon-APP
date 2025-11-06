import 'package:flutter/material.dart';
import '../../domain/models.dart';

class TremorCharts extends StatelessWidget {
  const TremorCharts({super.key, required this.metrics});
  final TremorMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final m = metrics;
    final levelText = m == null
        ? '—'
        : (m.level == TremorLevel.low
              ? 'Low'
              : m.level == TremorLevel.moderate
              ? 'Moderate'
              : 'High');
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.39)
                : Colors.grey.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tremor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Current: ${m?.currentMagnitude.toStringAsFixed(2) ?? '—'} rad/s',
          ),
          Text('Peak: ${m?.peakFrequencyHz.toStringAsFixed(1) ?? '—'} Hz'),
          Text('Level: $levelText'),
        ],
      ),
    );
  }
}
