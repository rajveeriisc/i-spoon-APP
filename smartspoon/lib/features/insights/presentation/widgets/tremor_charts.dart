import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/insights/domain/models.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';
import 'package:smartspoon/features/insights/presentation/widgets/analytics_widgets.dart';

class TremorCharts extends StatelessWidget {
  final TremorMetrics? metrics;
  final VoidCallback? onViewHistory;

  const TremorCharts({
    super.key,
    this.metrics,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final level = metrics?.level ?? TremorLevel.low;
    final magnitude = metrics?.currentMagnitude ?? 0.0;
    final frequency = metrics?.peakFrequencyHz ?? 0.0;

    Color levelColor;
    String levelLabel;
    switch (level) {
      case TremorLevel.low:
        levelColor = AppTheme.emerald;
        levelLabel = 'Low';
        break;
      case TremorLevel.moderate:
        levelColor = AppTheme.amber;
        levelLabel = 'Moderate';
        break;
      case TremorLevel.high:
        levelColor = const Color(0xFFEF4444);
        levelLabel = 'High';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title + optional "View History" button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tremor Analysis',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time sensor data',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            if (onViewHistory != null)
              TextButton(
                onPressed: onViewHistory,
                child: Text(
                  'View History',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.emerald,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        PremiumGlassCard(
          child: Column(
            children: [
              // Level indicator
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: levelColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tremor Level: $levelLabel',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: levelColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      levelLabel.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: levelColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Metrics row
              Row(
                children: [
                  Expanded(
                    child: _MetricBox(
                      label: 'Magnitude',
                      value: magnitude.toStringAsFixed(3),
                      unit: 'index',
                      color: levelColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricBox(
                      label: 'Frequency',
                      value: frequency.toStringAsFixed(1),
                      unit: 'Hz',
                      color: AppTheme.indigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Gauge bar
              _TremorGaugeBar(level: level, magnitude: magnitude),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TremorGaugeBar extends StatelessWidget {
  final TremorLevel level;
  final double magnitude;

  const _TremorGaugeBar({required this.level, required this.magnitude});

  @override
  Widget build(BuildContext context) {
    // Normalize magnitude index (0–3 scale) to 0–1 range for gauge bar
    final normalized = (magnitude / 3.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Severity',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '${(normalized * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 10,
            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              level == TremorLevel.low
                  ? AppTheme.emerald
                  : level == TremorLevel.moderate
                      ? AppTheme.amber
                      : const Color(0xFFEF4444),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Low', style: GoogleFonts.manrope(fontSize: 10, color: AppTheme.emerald)),
            Text('Moderate', style: GoogleFonts.manrope(fontSize: 10, color: AppTheme.amber)),
            Text('High', style: GoogleFonts.manrope(fontSize: 10, color: const Color(0xFFEF4444))),
          ],
        ),
      ],
    );
  }
}
