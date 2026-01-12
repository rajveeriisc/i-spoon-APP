import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SummaryCards extends StatelessWidget {
  const SummaryCards({
    super.key,
    required this.totalBites,
    required this.paceBpm,
    this.onTotalBitesTap,
    this.onPaceTap,
  });

  final int totalBites;
  final double paceBpm;
  final VoidCallback? onTotalBitesTap;
  final VoidCallback? onPaceTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isTight = availableWidth < 400;
        final cardWidth = isTight ? availableWidth * 0.45 : (availableWidth - 32) / 2;
        
        return Semantics(
          label: 'Summary cards: total bites, eating pace',
          child: SizedBox(
            height: 180,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _SummaryCard(
                  title: 'Total Bites',
                  value: totalBites.toString(),
                  icon: Icons.restaurant_menu_rounded,
                  color: const Color(0xFF34C759),
                  width: cardWidth,
                  onTap: onTotalBitesTap,
                  gradientColors: [
                    const Color(0xFF34C759).withValues(alpha: 0.1),
                    const Color(0xFF34C759).withValues(alpha: 0.05),
                  ],
                ),
                const SizedBox(width: 16),
                _SummaryCard(
                  title: 'Eating Pace',
                  value: paceBpm.toStringAsFixed(1),
                  unit: 'bites/min',
                  icon: Icons.speed_rounded,
                  color: const Color(0xFFFFB100),
                  width: cardWidth,
                  onTap: onPaceTap,
                  gradientColors: [
                    const Color(0xFFFFB100).withValues(alpha: 0.1),
                    const Color(0xFFFFB100).withValues(alpha: 0.05),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
    this.onTap,
    required this.gradientColors,
  });

  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;
  final double width;
  final VoidCallback? onTap;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14), // Reduced from 20
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
              : [Colors.white, const Color(0xFFF8F9FA)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min, // Prevent overflow
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // Reduced from 10
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20), // Reduced from 22
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 24, // Reduced from 28
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    height: 1.1,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    unit!,
                    style: GoogleFonts.outfit(
                      fontSize: 12, // Reduced from 13
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 13, // Reduced from 14
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
