import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';

/// Combined Metric Card - 2 column layout using PremiumGlassCard
class CombinedMetricCard extends StatelessWidget {
  final MetricData metric1;
  final MetricData metric2;

  const CombinedMetricCard({
    super.key,
    required this.metric1,
    required this.metric2,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: metric1.onTap,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: _MetricItem(data: metric1),
              ),
            ),
            Container(
              width: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
            Expanded(
              child: InkWell(
                onTap: metric2.onTap,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: _MetricItem(data: metric2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final MetricData data;

  const _MetricItem({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 130),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header with icon and trend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.icon,
                style: const TextStyle(fontSize: 24),
              ),
              if (data.trend != null) _buildTrendBadge(data.trend!),
            ],
          ),
          const SizedBox(height: 8),

          // Value and title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: GoogleFonts.manrope(
                  fontSize: 28, // Slightly smaller to fit glass card
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.title,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (data.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  data.subtitle!,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),

          // Progress bar (if applicable)
          if (data.progress != null) ...[
            const SizedBox(height: 12),
            _buildProgressBar(context, data.progress!, data.color),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendBadge(MetricTrend trend) {
    // Green for up, Red for down/bad, usually. Assuming 'up' is good for bites?
    // Actually typically 'up' is green.
    final color = trend.direction == 'up'
        ? AppTheme.emerald
        : AppTheme.rose;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${trend.direction == 'up' ? '↗' : '↘'} ${trend.value}%',
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double progress, Color color) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (progress / 100).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data models
class MetricData {
  final String icon;
  final String title;
  final String value;
  final MetricTrend? trend;
  final double? progress;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const MetricData({
    required this.icon,
    required this.title,
    required this.value,
    this.trend,
    this.progress,
    required this.color,
    this.subtitle,
    this.onTap,
  });
}

class MetricTrend {
  final int value;
  final String direction; // 'up' or 'down'

  const MetricTrend({required this.value, required this.direction});
}

/// Section Title Widget
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

/// AI Insight Card
class AIInsightCard extends StatelessWidget {
  final String type;
  final String title;
  final String message;
  final Color accentColor;
  final VoidCallback? onAction;
  final VoidCallback? onLearnMore;

  const AIInsightCard({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.accentColor,
    this.onAction,
    this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              Icon(Icons.auto_awesome, color: accentColor, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          if (onAction != null || onLearnMore != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (onAction != null)
                  _buildActionButton(
                    context,
                    'Take Action',
                    accentColor,
                    onAction!,
                    isPrimary: true,
                  ),
                if (onAction != null && onLearnMore != null)
                  const SizedBox(width: 12),
                if (onLearnMore != null)
                  _buildActionButton(
                    context,
                    'Learn More',
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    onLearnMore!,
                    isPrimary: false,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onTap, {
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isPrimary ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
