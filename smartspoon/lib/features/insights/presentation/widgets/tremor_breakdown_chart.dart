import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';

class TremorBreakdownChart extends StatelessWidget {
  final int lowCount;
  final int moderateCount;
  final int highCount;

  const TremorBreakdownChart({
    super.key,
    required this.lowCount,
    required this.moderateCount,
    required this.highCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = lowCount + moderateCount + highCount;

    return PremiumGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Tremor Distribution",
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            total == 0 ? 'No tremor events recorded' : '$total events recorded today',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 20),
          if (total == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: AppTheme.emerald.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No tremors detected',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _BreakdownBar(
              label: 'Low',
              count: lowCount,
              total: total,
              color: AppTheme.emerald,
            ),
            const SizedBox(height: 10),
            _BreakdownBar(
              label: 'Moderate',
              count: moderateCount,
              total: total,
              color: AppTheme.amber,
            ),
            const SizedBox(height: 10),
            _BreakdownBar(
              label: 'High',
              count: highCount,
              total: total,
              color: const Color(0xFFEF4444),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _BreakdownBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    final percent = (fraction * 100).toStringAsFixed(0);

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 12,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          child: Text(
            '$count ($percent%)',
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}
