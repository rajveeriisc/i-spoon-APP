import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SummaryCards extends StatelessWidget {
  const SummaryCards({
    super.key,
    required this.totalBites,
    required this.paceBpm,
    required this.tremorIndex,
  });

  final int totalBites;
  final double paceBpm;
  final int tremorIndex;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width * 0.45;
    return Semantics(
      label: 'Summary cards: total bites, eating pace, tremor index',
      child: SizedBox(
        height: 190,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: width * 0.05),
          children: [
            _SummaryCard(
              title: 'Total Bites',
              value: totalBites.toString(),
              icon: Icons.restaurant,
              color: const Color(0xFF34C759),
              width: cardWidth,
            ),
            _SummaryCard(
              title: 'Eating Pace',
              value: paceBpm.toStringAsFixed(1),
              unit: 'bites/min',
              icon: Icons.speed,
              color: const Color(0xFFFFB100),
              width: cardWidth,
            ),
            _SummaryCard(
              title: 'Tremor Index',
              value: tremorIndexLabel(tremorIndex),
              icon: Icons.back_hand,
              color: const Color(0xFF007AFF),
              width: cardWidth,
            ),
          ],
        ),
      ),
    );
  }

  String tremorIndexLabel(int index) {
    if (index < 35) return 'Low';
    if (index < 65) return 'Moderate';
    return 'High';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    this.unit,
    required this.icon,
    required this.color,
    required this.width,
  });

  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 16),
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
          Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.lato(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          if (unit != null)
            Text(
              unit!,
              style: GoogleFonts.lato(fontSize: 12, color: Colors.grey),
            ),
          const Spacer(),
          Text(
            title,
            style: GoogleFonts.lato(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
