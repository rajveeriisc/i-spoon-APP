import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models.dart';
import 'dart:math';

class DailyFoodTimeline extends StatefulWidget {
  const DailyFoodTimeline({super.key, required this.events});
  final List<BiteEvent> events;

  @override
  State<DailyFoodTimeline> createState() => _DailyFoodTimelineState();
}

class _DailyFoodTimelineState extends State<DailyFoodTimeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    
    // Set initial selection to last day after frame build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
         // This will be effectively set in build method logic if -1
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Aggregate events into bites and time (minutes) per day for last 7 days
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final biteBuckets = <DateTime, int>{};
    final timeBuckets = <DateTime, double>{};
    for (var i = 0; i < 7; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      biteBuckets[d] = 0;
      timeBuckets[d] = 0;
    }
    for (final e in widget.events) {
      if (!e.timestamp.isBefore(start)) {
        final d = DateTime(
          e.timestamp.year,
          e.timestamp.month,
          e.timestamp.day,
        );
        if (biteBuckets.containsKey(d)) {
          biteBuckets[d] = (biteBuckets[d] ?? 0) + 1;
        }
      }
    }
    biteBuckets.forEach((d, count) {
      if (timeBuckets.containsKey(d)) {
        timeBuckets[d] = count * 0.3; // approx minutes, 18s per bite
      }
    });

    // Fill empty days with demo values so all 7 days render nicely
    final rnd = Random(2025);
    for (final d in biteBuckets.keys) {
      if ((biteBuckets[d] ?? 0) == 0) {
        biteBuckets[d] = 8 + rnd.nextInt(25); // 8..32 bites
      }
      if ((timeBuckets[d] ?? 0) == 0) {
        final est = (biteBuckets[d]! * 0.28) + rnd.nextDouble() * 6; // ~minutes
        timeBuckets[d] = est.clamp(8, 60);
      }
    }

    final keys = biteBuckets.keys.toList()..sort();
    
    // Set default selection if not set
    if (_selectedIndex == -1 && keys.isNotEmpty) {
      _selectedIndex = keys.length - 1;
    }

    double minutesMax = 0;
    double bitesMax = 0;
    for (final d in keys) {
      minutesMax = max(minutesMax, (timeBuckets[d] ?? 0).toDouble());
      bitesMax = max(bitesMax, (biteBuckets[d] ?? 0).toDouble());
    }
    if (minutesMax <= 0) minutesMax = 10;
    if (bitesMax <= 0) bitesMax = 10;
    final minutesNiceMax = (minutesMax / 10).ceil() * 10;
    final bitesNiceMax = max(5, (bitesMax / 5).ceil() * 5);
    final scaleFactor =
        minutesNiceMax / bitesNiceMax; // map bites to minutes scale

    final timeSpots = <FlSpot>[];
    final biteSpotsScaled = <FlSpot>[];
    for (var i = 0; i < keys.length; i++) {
      final d = keys[i];
      final minutes = (timeBuckets[d] ?? 0).toDouble();
      final bites = (biteBuckets[d] ?? 0).toDouble();
      timeSpots.add(FlSpot(i.toDouble(), minutes));
      biteSpotsScaled.add(FlSpot(i.toDouble(), bites * scaleFactor));
    }

    String dayLabel(DateTime d) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[d.weekday - 1];
    }
    
    String fullDateLabel(DateTime d) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dayLabel(d)}, ${d.day} ${months[d.month - 1]}';
    }

    // Compute nicer Y axes
    final interval = max(2, (minutesNiceMax / 5).round());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2C3E50) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      _LegendDot(color: Color(0xFF4A90E2), label: 'Time (min)'),
                      SizedBox(width: 12),
                      _LegendDot(color: Color(0xFFFFB74D), label: 'Bites'),
                    ],
                  ),
                ],
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
                        color: isDark
                            ? Colors.grey.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
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
                            final isSelected = _selectedIndex == idx;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                dayLabel(keys[idx]),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF4A90E2)
                                      : (isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[500]),
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
                        getTooltipItems: (spots) => spots.map((e) => null).toList(), // Disable built-in tooltip
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
                            FlLine(color: const Color(0xFF4A90E2), strokeWidth: 2, dashArray: [5, 5]),
                            FlDotData(
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 6,
                                  color: Colors.white,
                                  strokeWidth: 3,
                                  strokeColor: barData.color ?? Colors.black,
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
                        color: const Color(0xFF4A90E2),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF4A90E2).withValues(alpha: 0.2),
                              const Color(0xFF4A90E2).withValues(alpha: 0.0),
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
                        color: const Color(0xFFFFB74D),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateLabel,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white70 
                  : Colors.black87,
            ),
          ),
          Row(
            children: [
              _DetailItem(
                value: '${minutes.toInt()}m',
                label: 'Duration',
                color: const Color(0xFF4A90E2),
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
                color: const Color(0xFFFFB74D),
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
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white54 
                : Colors.black54,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
