import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../insights/application/insights_controller.dart';
import '../../insights/domain/models.dart';
import 'package:smartspoon/core/theme/app_theme.dart';

class BiteHistoryPage extends StatefulWidget {
  const BiteHistoryPage({super.key});

  @override
  State<BiteHistoryPage> createState() => _BiteHistoryPageState();
}



class _BiteHistoryPageState extends State<BiteHistoryPage> {
  int _selectedDays = 7; // Default to 7 days
  String _selectedMeal = 'All';

  @override
  Widget build(BuildContext context) {
    // Watch daily summaries directly from controller so live updates rebuild the page
    final controller = context.watch<InsightsController>();
    
    // Sort summaries by date
    final sorted = [...controller.dailySummaries]
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final now = sorted.isEmpty ? DateTime.now() : sorted.last.date;
    
    // Compute aggregates for selected range
    final display = _computeAggregates(sorted, now, _selectedDays, _selectedMeal);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Eating Patterns',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            _OverviewStrip(aggregate: display, days: _selectedDays),
            
            const SizedBox(height: 24),
            
            // Meal Breakdown Chart
            _MealBreakdownChart(aggregate: display),
            
            const SizedBox(height: 24),
            
            // Time Range & Meal Dropdowns
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 600;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isSmall)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeaderTitle(context),
                          _buildDropdownsRow(context),
                        ],
                      )
                    else ...[
                      _buildHeaderTitle(context),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildDropdownsRow(context),
                      ),
                    ],
                  ],
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            // Data Table
            _BiteDataTable(entries: display.entries),
            
            
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTitle(BuildContext context) {
    return Text(
      'Daily Breakdown',
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildDropdownsRow(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Meal Selection Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMeal,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 18, color: AppTheme.emerald),
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              items: ['All', 'Breakfast', 'Lunch', 'Snacks', 'Dinner']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMeal = val);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Date Range Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedDays,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 18, color: AppTheme.emerald),
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
                DropdownMenuItem(value: 30, child: Text('1 Month')),
                DropdownMenuItem(value: 60, child: Text('2 Months')),
                DropdownMenuItem(value: 90, child: Text('3 Months')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedDays = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  _BiteAggregate _computeAggregates(
    List<DailyBiteSummary> summaries,
    DateTime end,
    int days,
    String selectedMeal,
  ) {
    final start = end.subtract(Duration(days: days - 1));
    final range = summaries
        .where((s) => !s.date.isBefore(start) && !s.date.isAfter(end))
        .toList();

    if (range.isEmpty) {
      return const _BiteAggregate(
        entries: [],
        totalBites: 0,
        totalDuration: 0,
        avgPace: 0,
        avgDuration: 0,
        mealBites: {},
      );
    }

    final totalBites = range.fold<int>(0, (sum, e) => sum + e.totalBites);
    final totalDuration = range.fold<double>(0, (sum, e) => sum + e.totalDurationMin);
    final avgPace =
        range.fold<double>(0, (sum, e) => sum + e.avgPaceBpm) / range.length;
    final avgDuration =
        range.fold<double>(0, (sum, e) => sum + e.avgMealDurationMin) / range.length;

    // Aggregate meal-wise bites
    final mealAgg = <String, int>{};
    for (var day in range) {
      day.mealBites.forEach((meal, bites) {
        mealAgg[meal] = (mealAgg[meal] ?? 0) + bites;
      });
    }

    final List<_MealEntry> flatEntries = [];
    for (var day in range.reversed) { // Show newest first
      if (selectedMeal == 'All') {
        final sortedMeals = day.mealBites.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (var meal in sortedMeals) {
          if (meal.value > 0) {
            flatEntries.add(_MealEntry(day.date, meal.key, meal.value));
          }
        }
      } else {
        final bites = day.mealBites[selectedMeal] ?? 0;
        if (bites > 0) {
          flatEntries.add(_MealEntry(day.date, selectedMeal, bites));
        }
      }
    }

    return _BiteAggregate(
      entries: flatEntries,
      totalBites: totalBites,
      totalDuration: totalDuration,
      avgPace: avgPace,
      avgDuration: avgDuration,
      mealBites: mealAgg,
    );
  }
}

class _MealEntry {
  final DateTime date;
  final String mealName;
  final int bites;
  const _MealEntry(this.date, this.mealName, this.bites);
}

class _BiteAggregate {
  const _BiteAggregate({
    required this.entries,
    required this.totalBites,
    required this.totalDuration,
    required this.avgPace,
    required this.avgDuration,
    required this.mealBites,
  });

  final List<_MealEntry> entries;
  final int totalBites;
  final double totalDuration;
  final double avgPace;
  final double avgDuration;
  final Map<String, int> mealBites;
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({required this.aggregate, required this.days});

  final _BiteAggregate aggregate;
  final int days;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OverviewTile(
            title: 'Period Total',
            value: '${aggregate.totalBites}',
            unit: 'total bites',
            subtitle: 'Avg ${(days > 0 ? (aggregate.totalBites / days) : 0).toStringAsFixed(1)}/day',
            color: AppTheme.emerald,
            icon: Icons.analytics,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _OverviewTile(
            title: 'Avg Pace',
            value: aggregate.avgPace.isNaN ? '0.0' : aggregate.avgPace.toStringAsFixed(1),
            unit: 'bites/min',
            subtitle: 'Average over $days days',
            color: AppTheme.emerald,
            icon: Icons.timer,
          ),
        ),
      ],
    );
  }
}

class _MealBreakdownChart extends StatelessWidget {
  const _MealBreakdownChart({required this.aggregate});

  final _BiteAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final meals = aggregate.mealBites.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final total = aggregate.totalBites;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Meal Distribution',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No meal data available for this period.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ...meals.map((meal) {
              final double percentage = (meal.value / total) * 100;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          meal.key,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          '${meal.value} bites (${percentage.toStringAsFixed(0)}%)',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage / 100,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppTheme.emerald, AppTheme.emerald.withValues(alpha: 0.6)],
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String unit;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13, 
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiteDataTable extends StatelessWidget {
  const _BiteDataTable({required this.entries});

  final List<_MealEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No meal data for this period.',
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final dateFmt = DateFormat.MMMd();
    final columns = [
      const DataColumn(label: Text('Date')),
      const DataColumn(label: Text('Meal')),
      const DataColumn(label: Text('Bites')),
    ];

    final rows = entries
        .map(
          (entry) => DataRow(
            cells: [
              DataCell(Text(dateFmt.format(entry.date))),
              DataCell(Text(entry.mealName)),
              DataCell(Text(entry.bites.toString())),
            ],
          ),
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final table = DataTable(
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
          ),
          columns: columns,
          rows: rows,
        );

        final tableWidget = constraints.maxWidth < 600
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: table,
              )
            : table;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: tableWidget,
          ),
        );
      },
    );
  }
}
