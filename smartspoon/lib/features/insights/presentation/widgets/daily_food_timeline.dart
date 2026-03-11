import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';
import '../../domain/models.dart';
import '../screens/meals_analysis_page.dart';
import 'dart:math' show max;

class DailyFoodTimeline extends StatefulWidget {
  const DailyFoodTimeline({super.key, required this.summaries});
  final List<DailyBiteSummary> summaries;

  @override
  State<DailyFoodTimeline> createState() => _DailyFoodTimelineState();
}

class _DailyFoodTimelineState extends State<DailyFoodTimeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _selectedIndex = -1;
  // Fixed to 7 days for Weekly History
  final int _rangeDays = 7;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build day-keyed buckets for selected range (7 / 30 / 90 days)
    final biteBuckets = <DateTime, int>{};
    final timeBuckets = <DateTime, double>{};
    for (var i = _rangeDays - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      biteBuckets[d] = 0;
      timeBuckets[d] = 0.0;
    }

    // Fill from daily_summaries (authoritative source)
    for (final s in widget.summaries) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (biteBuckets.containsKey(d)) {
        biteBuckets[d] = (biteBuckets[d] ?? 0) + s.totalBites;
        timeBuckets[d] = (timeBuckets[d] ?? 0) + s.totalDurationMin;
      }
    }

    final keys = biteBuckets.keys.toList()..sort();
    if (_selectedIndex == -1 && keys.isNotEmpty) {
      _selectedIndex = keys.length - 1;
    }

    double minutesMax =
        timeBuckets.values.fold(0.0, (a, b) => a > b ? a : b.toDouble());
    double bitesMax =
        biteBuckets.values.fold(0.0, (a, b) => a > b ? a : b.toDouble());
    if (minutesMax <= 0) minutesMax = 10;
    if (bitesMax <= 0) bitesMax = 10;
    final minutesNiceMax = (minutesMax / 10).ceil() * 10;
    final bitesNiceMax = (bitesMax / 5).ceil() * 5;
    final scaleFactor = minutesNiceMax / bitesNiceMax.clamp(1, 99999);

    final timeSpots = <FlSpot>[];
    final biteSpotsScaled = <FlSpot>[];
    for (var i = 0; i < keys.length; i++) {
      final d = keys[i];
      timeSpots.add(FlSpot(i.toDouble(), (timeBuckets[d] ?? 0).toDouble()));
      biteSpotsScaled.add(
          FlSpot(i.toDouble(), (biteBuckets[d] ?? 0) * scaleFactor));
    }

    String dayLabel(DateTime d) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[d.weekday - 1];
    }
    
    String fullDateLabel(DateTime d) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dayLabel(d)}, ${d.day} ${months[d.month - 1]}';
    }

    final interval = max(2, (minutesNiceMax / 5).round());

    // Use PremiumGlassCard instead of generic Container
    return PremiumGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly History',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _LegendDot(color: AppTheme.emerald, label: 'Time (min)'),
                      const SizedBox(width: 12),
                      _LegendDot(color: AppTheme.amber, label: 'Bites'),
                    ],
                  ),
                ],
              ),
              // History button mapping to MealsAnalysisPage
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MealsAnalysisPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 16, color: AppTheme.emerald),
                      const SizedBox(width: 6),
                      Text(
                        'History',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Chart
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (keys.length - 1).toDouble(),
                    minY: 0,
                    maxY: minutesNiceMax.toDouble(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: interval.toDouble(),
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false), // Hide left titles for cleaner look
                      ),
                      rightTitles: const AxisTitles(
                         sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= keys.length) {
                              return const SizedBox.shrink();
                            }
                            // For 30/90 day ranges, only label every 7th point
                            final labelStep = _rangeDays <= 7 ? 1 : 7;
                            if (idx % labelStep != 0 && idx != keys.length - 1) {
                              return const SizedBox.shrink();
                            }
                            final isSelected = _selectedIndex == idx;
                            final d = keys[idx];
                            final label = _rangeDays <= 7
                                ? dayLabel(d)
                                : '${d.day}/${d.month}';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _selectedIndex = idx;
                                  });
                                },
                                child: Text(
                                  label,
                                  style: GoogleFonts.manrope(
                                    fontSize: _rangeDays <= 7 ? 12 : 10,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.emerald
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(

                        getTooltipItems: (spots) => spots.map((e) => null).toList(), // Disable built-in description in tooltip, just show dot
                      ),
                      touchCallback: (event, response) {
                        if (response?.lineBarSpots != null &&
                            response!.lineBarSpots!.isNotEmpty) {
                          setState(() {
                            _selectedIndex =
                                response.lineBarSpots!.first.x.toInt();
                          });
                        }
                      },
                      getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                        return spotIndexes.map((spotIndex) {
                          return TouchedSpotIndicatorData(
                            FlLine(color: AppTheme.emerald, strokeWidth: 2, dashArray: [5, 5]),
                            FlDotData(
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 6,
                                  color: Theme.of(context).colorScheme.surface,
                                  strokeWidth: 3,
                                  strokeColor: barData.color ?? Theme.of(context).colorScheme.primary,
                                );
                              },
                            ),
                          );
                        }).toList();
                      },
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: timeSpots
                            .take((timeSpots.length * _animationController.value)
                                .ceil())
                            .toList(),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AppTheme.emerald,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.emerald.withValues(alpha: 0.2),
                              AppTheme.emerald.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      LineChartBarData(
                        spots: biteSpotsScaled
                            .take((biteSpotsScaled.length *
                                    _animationController.value)
                                .ceil())
                            .toList(),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AppTheme.amber, // Gold
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Detail Section below graph
          if (_selectedIndex >= 0 && _selectedIndex < keys.length)
            _buildDetailSection(
              context, 
              keys[_selectedIndex], 
              timeBuckets[keys[_selectedIndex]] ?? 0, 
              biteBuckets[keys[_selectedIndex]] ?? 0,
              fullDateLabel(keys[_selectedIndex]),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context, 
    DateTime date, 
    double minutes, 
    int bites,
    String dateLabel,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateLabel,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Row(
            children: [
              _DetailItem(
                value: '${minutes.toInt()}m',
                label: 'Duration',
                color: AppTheme.emerald,
              ),
              Container(
                height: 24,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Theme.of(context).dividerColor,
              ),
              _DetailItem(
                value: '$bites',
                label: 'Bites',
                color: AppTheme.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _DetailItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
              )
            ]
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
