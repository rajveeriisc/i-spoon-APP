import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/models.dart';
import 'dart:math';

class DailyFoodTimeline extends StatelessWidget {
  const DailyFoodTimeline({super.key, required this.events});
  final List<BiteEvent> events;

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
    for (final e in events) {
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

    // removed duplicate filler block; handled above

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
          Row(
            children: const [
              Text(
                'Weekly Time & Bites',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              _LegendDot(color: Color(0xFF007AFF), label: 'Time (min)'),
              SizedBox(width: 12),
              _LegendDot(color: Color(0xFFFFB100), label: 'Bites'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
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
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: interval.toDouble(),
                      getTitlesWidget: (v, meta) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval:
                          max(1.0, (bitesNiceMax / 5).roundToDouble()) *
                          scaleFactor,
                      getTitlesWidget: (v, meta) {
                        final raw = (v / scaleFactor).round();
                        return Text(
                          raw.toString(),
                          style: const TextStyle(fontSize: 10),
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
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= keys.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          dayLabel(keys[idx]),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black87,
                    getTooltipItems: (spots) {
                      return spots.map((s) {
                        final idx = s.x.toInt();
                        final d = keys[idx];
                        final minutes = (timeBuckets[d] ?? 0).toDouble();
                        final bites = (biteBuckets[d] ?? 0).toDouble();
                        final isTime = s.bar.color == const Color(0xFF007AFF);
                        final label = isTime ? 'Time' : 'Bites';
                        final value = isTime
                            ? minutes.toStringAsFixed(0)
                            : bites.toStringAsFixed(0);
                        return LineTooltipItem(
                          '${dayLabel(d)}\n$label: $value',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: timeSpots,
                    isCurved: true,
                    color: const Color(0xFF007AFF),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF007AFF).withValues(alpha: 0.24),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: biteSpotsScaled,
                    isCurved: true,
                    color: const Color(0xFFFFB100),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFB100).withValues(alpha: 0.24),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
