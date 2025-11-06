import 'package:flutter/material.dart';
import '../../domain/models.dart';

class TemperatureSection extends StatelessWidget {
  const TemperatureSection({super.key, required this.stats});

  final TemperatureStats? stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final food = stats?.foodTempC ?? 45;
    final heater = stats?.heaterTempC ?? 60;
    final alert = food > 60;

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
            'Food & Heater Temperature',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TempGauge(
                label: 'Food',
                value: food,
                color: const Color(0xFF34C759),
              ),
              _TempGauge(
                label: 'Heater',
                value: heater,
                color: const Color(0xFFFF3B30),
              ),
            ],
          ),
          if (alert) ...[
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Food is hot! Wait 60 seconds before next bite'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TempGauge extends StatelessWidget {
  const _TempGauge({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.thermostat, color: color),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)}°C',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
