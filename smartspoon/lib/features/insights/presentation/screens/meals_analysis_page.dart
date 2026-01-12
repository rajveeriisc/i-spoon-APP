import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/insights/domain/services/unified_data_service.dart';
import 'package:smartspoon/core/theme/app_theme.dart';

class MealsAnalysisPage extends StatelessWidget {
  const MealsAnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
           'Meals Analysis',
           style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Consumer<UnifiedDataService>(
        builder: (context, dataService, child) {
          // Mock data distribution based on total bites for demo purposes
          // In a real app, this would come from a historical service or database
          final totalBites = dataService.totalBites;
          final breakfastBites = (totalBites * 0.3).round();
          final lunchBites = (totalBites * 0.4).round();
          final dinnerBites = (totalBites * 0.2).round();
          final snackBites = totalBites - breakfastBites - lunchBites - dinnerBites;

          final mealsData = [
            _MealData('Breakfast', Icons.free_breakfast_outlined, breakfastBites, 12, 12.5),
            _MealData('Lunch', Icons.lunch_dining_outlined, lunchBites, 25, 15.2),
            _MealData('Snacks', Icons.cookie_outlined, snackBites, 8, 8.4),
            _MealData('Dinner', Icons.dinner_dining_outlined, dinnerBites, 35, 10.1),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Overview",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Premium Data Table Container
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: isDarkMode ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.navy,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: _HeaderCell('Meal Type', align: TextAlign.start)),
                              Expanded(flex: 2, child: _HeaderCell('Bites', align: TextAlign.center)),
                              Expanded(flex: 2, child: _HeaderCell('Time', align: TextAlign.center)),
                              Expanded(flex: 2, child: _HeaderCell('Speed', align: TextAlign.end)),
                            ],
                          ),
                        ),

                        // Table Rows
                        ...mealsData.map((meal) {
                          final isLast = meal == mealsData.last;
                          return Container(
                            decoration: BoxDecoration(
                              border: isLast ? null : Border(
                                bottom: BorderSide(
                                  color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                                ),
                              ),
                              color: isDarkMode ? null : (mealsData.indexOf(meal) % 2 == 0 ? Colors.white : const Color(0xFFF9FAFB)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                // Meal Name & Icon
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.turquoise.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(meal.icon, size: 18, color: AppTheme.turquoise),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible( // Wrap text in Flexible
                                        child: Text(
                                          meal.name,
                                          overflow: TextOverflow.ellipsis, // Handle overflow
                                          maxLines: 1,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: isDarkMode ? Colors.white : AppTheme.navy,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Bite Count
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${meal.bites}',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.robotoMono(
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode ? Colors.white70 : Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                // Total Time
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${meal.minutes} min',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                // Speed
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${meal.speed}',
                                    textAlign: TextAlign.end,
                                    style: GoogleFonts.robotoMono(
                                      fontWeight: FontWeight.bold,
                                      color: _getSpeedColor(meal.speed),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Legend / Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.turquoise.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.turquoise.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.turquoise),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Speed is measured in bites per minute. Keep a steady pace for better digestion.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isDarkMode ? Colors.white70 : AppTheme.navy.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Color _getSpeedColor(double speed) {
    if (speed < 10) return Colors.green;
    if (speed < 15) return Colors.orange;
    return Colors.red;
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _HeaderCell(this.text, {required this.align});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: GoogleFonts.outfit(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _MealData {
  final String name;
  final IconData icon;
  final int bites;
  final int minutes;
  final double speed; // bites/min

  _MealData(this.name, this.icon, this.bites, this.minutes, this.speed);
}
