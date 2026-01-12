import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TremorBreakdownChart extends StatelessWidget {
  const TremorBreakdownChart({
    super.key,
    required this.lowCount,
    required this.moderateCount,
    required this.highCount,
  });

  final int lowCount;
  final int moderateCount;
  final int highCount;

  @override
  Widget build(BuildContext context) {
    final total = lowCount + moderateCount + highCount;
    
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EDF2)),
        ),
        child: Center(
          child: Text(
            'No tremor data available',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    final lowPercent = (lowCount / total * 100).round();
    final moderatePercent = (moderateCount / total * 100).round();
    final highPercent = (highCount / total * 100).round();

    final levels = [
      {'name': 'Low', 'count': lowCount, 'percentage': lowPercent, 'color': const Color(0xFF34C759)},
      {'name': 'Moderate', 'count': moderateCount, 'percentage': moderatePercent, 'color': const Color(0xFFFFB100)},
      {'name': 'High', 'count': highCount, 'percentage': highPercent, 'color': const Color(0xFFFF3B30)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Column(
        children: levels.where((level) => (level['count'] as int) > 0).map((level) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: level['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          level['name'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${level['count']} events',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (level['percentage'] as int) / 100,
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: (level['color'] as Color).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Text(
                          '${level['percentage']}%',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E3A4A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
