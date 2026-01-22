import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/wellness_colors.dart';

/// Hero Header with gradient background
class HeroHeader extends StatelessWidget {
  final String greeting;
  final String subtitle;
  final VoidCallback? onRefresh;

  const HeroHeader({
    super.key,
    required this.greeting,
    this.subtitle = 'Your Wellness Insights',
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [WellnessColors.primaryBlue, WellnessColors.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          if (onRefresh != null)
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync, color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

/// Combined Metric Card - 2 column layout
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
    return Container(
      decoration: BoxDecoration(
        color: WellnessColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WellnessColors.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
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
              color: WellnessColors.getBorderColor(context).withValues(alpha: 0.5),
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
              Text(data.icon, style: const TextStyle(fontSize: 24)),
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
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: data.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: WellnessColors.getTextSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (data.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  data.subtitle!,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: WellnessColors.getTextMuted(context),
                  ),
                ),
              ],
            ],
          ),
          
          // Progress bar (if applicable)
          if (data.progress != null) ...[
            const SizedBox(height: 12),
            _buildProgressBar(data.progress!, data.color),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendBadge(MetricTrend trend) {
    final color = trend.direction == 'up' 
        ? WellnessColors.primaryGreen 
        : WellnessColors.sunsetOrange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${trend.direction == 'up' ? '↗' : '↘'} ${trend.value}%',
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress, Color color) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
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
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: WellnessColors.getTextPrimary(context),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: WellnessColors.getTextSecondary(context),
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
    return Container(
      decoration: BoxDecoration(
        color: WellnessColors.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                type.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const Text('⭐', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: WellnessColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: WellnessColors.getTextSecondary(context),
              height: 1.4,
            ),
          ),
          if (onAction != null || onLearnMore != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (onAction != null)
                  _buildActionButton(
                    'Take Action',
                    accentColor,
                    onAction!,
                    isPrimary: true,
                  ),
                if (onAction != null && onLearnMore != null)
                  const SizedBox(width: 12),
                if (onLearnMore != null)
                  _buildActionButton(
                    'Learn More',
                    accentColor,
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
          color: isPrimary ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isPrimary ? null : Border.all(color: color),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isPrimary ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
