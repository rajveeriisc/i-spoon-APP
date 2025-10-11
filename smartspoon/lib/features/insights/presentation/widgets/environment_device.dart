import 'package:flutter/material.dart';
import '../../domain/models.dart';

class EnvironmentDevice extends StatelessWidget {
  const EnvironmentDevice({super.key, this.environment, this.health});

  final EnvironmentData? environment;
  final DeviceHealth? health;

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
                ? Colors.black.withAlpha(100)
                : Colors.grey.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _Card(
              title: 'Environment',
              items: [
                'Temp: ${environment?.ambientTempC.toStringAsFixed(0) ?? '—'}°C',
                'Humidity: ${environment?.humidityPercent.toStringAsFixed(0) ?? '—'}%',
                'Pressure: ${environment?.pressureHpa.toStringAsFixed(0) ?? '—'} hPa',
              ],
              icon: Icons.sunny,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Card(
              title: 'Device',
              items: [
                'Battery: ${health?.batteryPercent ?? '—'}%',
                'Voltage: ${health?.voltage.toStringAsFixed(1) ?? '—'}V',
                'Cycles: ${health?.chargeCycles ?? '—'}',
              ],
              icon: Icons.memory,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.items, required this.icon});
  final String title;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          for (final i in items)
            Text(i, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
