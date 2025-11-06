import 'package:flutter/material.dart';
import '../../domain/models.dart';

class TrendAnalytics extends StatelessWidget {
  const TrendAnalytics({super.key, required this.trends});
  final TrendData? trends;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            'Trends',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (trends == null)
            const Text('No data')
          else
            _buildList(context, trends!),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, TrendData data) {
    final bitesAvg = data.bitesPerMeal.isEmpty
        ? 0
        : data.bitesPerMeal.map((e) => e.value).reduce((a, b) => a + b) /
              data.bitesPerMeal.length;
    final tremorAvg = data.tremorIndexOverTime.isEmpty
        ? 0
        : data.tremorIndexOverTime.map((e) => e.value).reduce((a, b) => a + b) /
              data.tremorIndexOverTime.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Avg bites/meal: ${bitesAvg.toStringAsFixed(0)}'),
        Text('Avg tremor index: ${tremorAvg.toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        const Text('Highlights:'),
        const Text('• You ate slower but with fewer tremors'),
      ],
    );
  }
}
