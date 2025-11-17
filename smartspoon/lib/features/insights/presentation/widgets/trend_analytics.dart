import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/models.dart';

class TrendAnalytics extends StatefulWidget {
  const TrendAnalytics({super.key, required this.trends});
  final TrendData? trends;

  @override
  State<TrendAnalytics> createState() => _TrendAnalyticsState();
}

class _TrendAnalyticsState extends State<TrendAnalytics>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trends = widget.trends;

    if (trends == null) {
      return _buildEmptyState(isDark);
    }

    final bitesAvg = trends.bitesPerMeal.isEmpty
        ? 0.0
        : trends.bitesPerMeal.map((e) => e.value).reduce((a, b) => a + b) /
            trends.bitesPerMeal.length;

    final durationAvg = trends.avgMealDurationMin.isEmpty
        ? 0.0
        : trends.avgMealDurationMin.map((e) => e.value).reduce((a, b) => a + b) /
            trends.avgMealDurationMin.length;

    final tremorAvg = trends.tremorIndexOverTime.isEmpty
        ? 0.0
        : trends.tremorIndexOverTime.map((e) => e.value).reduce((a, b) => a + b) /
            trends.tremorIndexOverTime.length;

    // Calculate trends (up/down)
    final bitesTrend = _calculateTrend(trends.bitesPerMeal);
    final durationTrend = _calculateTrend(trends.avgMealDurationMin);
    final tremorTrend = _calculateTrend(trends.tremorIndexOverTime);

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
                      const Color(0xFF43E97B),
                      const Color(0xFF38F9D7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Weekly Trends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Trend Cards
          _TrendCard(
            label: 'Bites Per Meal',
            value: bitesAvg.toStringAsFixed(0),
            trend: bitesTrend,
            color: const Color(0xFF34C759),
            data: trends.bitesPerMeal,
            animation: _animationController,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _TrendCard(
            label: 'Meal Duration',
            value: '${durationAvg.toStringAsFixed(1)} min',
            trend: durationTrend,
            color: const Color(0xFF007AFF),
            data: trends.avgMealDurationMin,
            animation: _animationController,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _TrendCard(
            label: 'Tremor Index',
            value: tremorAvg.toStringAsFixed(0),
            trend: tremorTrend,
            color: const Color(0xFFFF9500),
            data: trends.tremorIndexOverTime,
            animation: _animationController,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildInsights(bitesTrend, durationTrend, tremorTrend, isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
      ),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.insights_outlined,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No trend data available',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(
      double bitesTrend, double durationTrend, double tremorTrend, bool isDark) {
    final insights = <String>[];

    if (tremorTrend < 0) {
      insights.add('Great! Your tremor levels are improving');
    } else if (tremorTrend > 0) {
      insights.add('Tremor levels increased - consider consulting your doctor');
    }

    if (durationTrend > 0 && tremorTrend <= 0) {
      insights.add('Taking your time helps reduce tremors');
    }

    if (bitesTrend < 0) {
      insights.add('Eating smaller portions - good for digestion');
    }

    if (insights.isEmpty) {
      insights.add('Keep maintaining your healthy eating habits!');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF43E97B).withValues(alpha: 0.1),
            const Color(0xFF38F9D7).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF43E97B).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 20,
                color: isDark ? const Color(0xFF43E97B) : const Color(0xFF38F9D7),
              ),
              const SizedBox(width: 8),
              Text(
                'Insights',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? const Color(0xFF43E97B) : const Color(0xFF38F9D7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF43E97B) : const Color(0xFF38F9D7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTrend<T extends num>(List<TrendDataPoint<T>> data) {
    if (data.length < 2) return 0;
    final first = data.first.value.toDouble();
    final last = data.last.value.toDouble();
    if (first == 0) return 0;
    return ((last - first) / first) * 100;
  }
}

class _TrendCard<T extends num> extends StatelessWidget {
  const _TrendCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.color,
    required this.data,
    required this.animation,
    required this.isDark,
  });

  final String label;
  final String value;
  final double trend;
  final Color color;
  final List<TrendDataPoint<T>> data;
  final Animation<double> animation;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isPositive = trend >= 0;
    final trendColor = trend.abs() < 1
        ? Colors.grey
        : isPositive
            ? Colors.red
            : const Color(0xFF34C759);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 16,
                      color: trendColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trend.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: trendColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'vs last week',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 60,
              child: _buildSparkline(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSparkline() {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.value.toDouble(),
      );
    }).toList();

    final maxY = data.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b);
    final minY = data.map((e) => e.value.toDouble()).reduce((a, b) => a < b ? a : b);
    final range = maxY - minY;
    final adjustedMaxY = maxY + (range * 0.1);
    final adjustedMinY = (minY - (range * 0.1)).clamp(0.0, double.infinity).toDouble();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return LineChart(
          LineChartData(
            minX: 0,
            maxX: (data.length - 1).toDouble(),
            minY: adjustedMinY,
            maxY: adjustedMaxY,
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots.take((spots.length * animation.value).ceil()).toList(),
                isCurved: true,
                color: color,
                barWidth: 2.5,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
