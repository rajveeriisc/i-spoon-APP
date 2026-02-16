import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/insights/application/insights_controller.dart';
import 'package:smartspoon/features/insights/domain/models.dart';
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
      body: Consumer<InsightsController>(
        builder: (context, controller, child) {
          return FutureBuilder<List<MealSummary>>(
            future: controller.getMealsForDate(DateTime.now()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final meals = snapshot.data ?? [];
              
              // Sort by time: Breakfast < Lunch < Dinner < Snack
              // Or just by time if available
              // Basic icons mapping
              IconData getIcon(String type) {
                switch(type.toLowerCase()) {
                  case 'breakfast': return Icons.free_breakfast_outlined;
                  case 'lunch': return Icons.lunch_dining_outlined;
                  case 'dinner': return Icons.dinner_dining_outlined;
                  default: return Icons.cookie_outlined;
                }
              }

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
                    
                    if (meals.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E1E2C) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.no_food_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No meals recorded today',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
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
                            ...meals.map((meal) {
                              final isLast = meal == meals.last;
                              final mealName = meal.mealType ?? 'Unknown';
                              return Container(
                                decoration: BoxDecoration(
                                  border: isLast ? null : Border(
                                    bottom: BorderSide(
                                      color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                                    ),
                                  ),
                                  color: isDarkMode ? null : (meals.indexOf(meal) % 2 == 0 ? Colors.white : const Color(0xFFF9FAFB)),
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
                                            child: Icon(getIcon(mealName), size: 18, color: AppTheme.turquoise),
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              mealName,
                                              overflow: TextOverflow.ellipsis,
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
                                        '${meal.totalBites}',
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
                                        '${(meal.durationMinutes ?? 0).toInt()} min', // Show mock duration
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
                                        '${meal.eatingPaceBpm}',
                                        textAlign: TextAlign.end,
                                        style: GoogleFonts.robotoMono(
                                          fontWeight: FontWeight.bold,
                                          color: _getSpeedColor(meal.eatingPaceBpm),
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
                    if (meals.isNotEmpty)
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
            }
          );
        },
      ),
    );
  }
  
  Color _getSpeedColor(double speed) {
    if (speed < 4) return Colors.green; // Adjusted thresholds for BPM
    if (speed < 8) return Colors.orange;
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
