import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

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

    // Compute nicer Y axes
    final interval = max(2, (minutesNiceMax / 5).round());

    return Container(
      margin: EdgeInsets.symmetric(horizontal: size.width * 0.05),
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
                  Icons.insert_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Weekly Time & Bites',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              _LegendDot(color: Color(0xFF007AFF), label: 'Time (min)'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFFFFB100), label: 'Bites'),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return SizedBox(
                height: 240,
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
                            ? Colors.grey.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.1),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: interval.toDouble(),
                          getTitlesWidget: (v, meta) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              v.toInt().toString(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval:
                              max(1.0, (bitesNiceMax / 5).roundToDouble()) *
                              scaleFactor,
                          getTitlesWidget: (v, meta) {
                            final raw = (v / scaleFactor).round();
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                raw.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= keys.length) {
                              return const SizedBox.shrink();
                            }
                            final isSelected = _selectedIndex == idx;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF007AFF)
                                          .withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  dayLabel(keys[idx]),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF007AFF)
                                        : (isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600]),
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
                      touchCallback: (event, response) {
                        if (response?.lineBarSpots != null &&
                            response!.lineBarSpots!.isNotEmpty) {
                          setState(() {
                            _selectedIndex =
                                response.lineBarSpots!.first.x.toInt();
                          });
                        }
                      },
                      touchTooltipData: LineTouchTooltipData(
                        tooltipRoundedRadius: 12,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        getTooltipItems: (spots) {
                          return spots.map((s) {
                            final idx = s.x.toInt();
                            final d = keys[idx];
                            final minutes = (timeBuckets[d] ?? 0).toDouble();
                            final bites = (biteBuckets[d] ?? 0).toDouble();
                            final isTime = s.bar.color == const Color(0xFF007AFF);
                            final label = isTime ? 'Time' : 'Bites';
                            final value = isTime
                                ? '${minutes.toStringAsFixed(0)} min'
                                : bites.toStringAsFixed(0);
                            return LineTooltipItem(
                              '${dayLabel(d)}\n$label: $value',
                              TextStyle(
                                color: isTime
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFFFFB100),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: timeSpots
                            .take((timeSpots.length * _animationController.value)
                                .ceil())
                            .toList(),
                        isCurved: true,
                        curveSmoothness: 0.4,
                        color: const Color(0xFF007AFF),
                        barWidth: 3.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: const Color(0xFF007AFF),
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF007AFF).withValues(alpha: 0.3),
                              const Color(0xFF007AFF).withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 1.0],
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
                        curveSmoothness: 0.4,
                        color: const Color(0xFFFFB100),
                        barWidth: 3.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: const Color(0xFFFFB100),
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFFB100).withValues(alpha: 0.3),
                              const Color(0xFFFFB100).withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
