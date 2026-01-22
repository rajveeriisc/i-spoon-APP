import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../insights/domain/models.dart';
import 'theme/wellness_colors.dart';

class BiteHistoryPage extends StatefulWidget {
  const BiteHistoryPage({super.key, required this.summaries});

  final List<DailyBiteSummary> summaries;

  @override
  State<BiteHistoryPage> createState() => _BiteHistoryPageState();
}



class _BiteHistoryPageState extends State<BiteHistoryPage> {
  int _selectedDays = 7; // Default to 7 days

  @override
  Widget build(BuildContext context) {
    // Sort summaries by date
    final sorted = [...widget.summaries]
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final now = sorted.isEmpty ? DateTime.now() : sorted.last.date;
    
    // Compute aggregates for selected range
    final display = _computeAggregates(sorted, now, _selectedDays);

    return Scaffold(
      backgroundColor: WellnessColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Eating Patterns',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: WellnessColors.getBackground(context),
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
            
            // Time Range Dropdown (moved here, above table)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Breakdown',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: WellnessColors.getTextPrimary(context),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: WellnessColors.primaryBlue.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedDays,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: WellnessColors.primaryBlue),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: WellnessColors.getTextPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
                        DropdownMenuItem(value: 30, child: Text('1 Month')),
                        DropdownMenuItem(value: 60, child: Text('2 Months')),
                        DropdownMenuItem(value: 90, child: Text('3 Months')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDays = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Data Table
            _BiteDataTable(entries: display.entries),
            
            const SizedBox(height: 32),
            
            // Report Request
            _EmailRequestCard(days: _selectedDays),
          ],
        ),
      ),
    );
  }

  _BiteAggregate _computeAggregates(
    List<DailyBiteSummary> summaries,
    DateTime end,
    int days,
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

    return _BiteAggregate(
      entries: range.reversed.toList(), // Show newest first in table
      totalBites: totalBites,
      totalDuration: totalDuration,
      avgPace: avgPace,
      avgDuration: avgDuration,
      mealBites: mealAgg,
    );
  }
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

  final List<DailyBiteSummary> entries;
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
            subtitle: 'Avg ${(aggregate.totalBites / days).toStringAsFixed(1)}/day',
            color: WellnessColors.primaryBlue,
            icon: Icons.analytics,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _OverviewTile(
            title: 'Avg Pace',
            value: '${aggregate.avgPace.toStringAsFixed(1)}s',
            unit: 'seconds/bite',
            subtitle: 'Average over $days days',
            color: WellnessColors.primaryGreen,
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
        color: WellnessColors.getCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WellnessColors.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meal Distribution',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: WellnessColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 20),
          ...meals.map((meal) {
            final double percentage = total == 0 ? 0 : (meal.value / total) * 100;
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
                          color: WellnessColors.getTextSecondary(context),
                        ),
                      ),
                      Text(
                        '${meal.value} bites (${percentage.toStringAsFixed(0)}%)',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: WellnessColors.primaryBlue,
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
                          color: WellnessColors.getBorderColor(context).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage / 100,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [WellnessColors.primaryBlue, WellnessColors.primaryBlue.withValues(alpha: 0.6)],
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
        color: WellnessColors.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WellnessColors.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                  color: WellnessColors.getTextSecondary(context),
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
              color: WellnessColors.getTextMuted(context),
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

  final List<DailyBiteSummary> entries;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.MMMd();
    
    // Sort columns
    final columns = [
      DataColumn(
        label: Text('Date', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      DataColumn(
        label: Text('Break\nfast', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
      DataColumn(
        label: Text('Lunch', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
      DataColumn(
        label: Text('Dinner', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
      DataColumn(
        label: Text('Snacks', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
      DataColumn(
        label: Text('Total\nBites', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
      DataColumn(
        label: Text('Total\nTime', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
      DataColumn(
        label: Text('Pace', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        numeric: true,
      ),
    ];

    final rows = entries
        .map(
          (entry) => DataRow(
            cells: [
              DataCell(
                Text(
                  dateFmt.format(entry.date),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                ),
              ),
              DataCell(Text('${entry.mealBites['Breakfast'] ?? 0}', style: GoogleFonts.outfit())),
              DataCell(Text('${entry.mealBites['Lunch'] ?? 0}', style: GoogleFonts.outfit())),
              DataCell(Text('${entry.mealBites['Dinner'] ?? 0}', style: GoogleFonts.outfit())),
              DataCell(Text('${entry.mealBites['Snacks'] ?? 0}', style: GoogleFonts.outfit())),
              DataCell(
                Text(
                  entry.totalBites.toString(),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(
                Text(
                  '${entry.totalDurationMin.toStringAsFixed(1)}m',
                  style: GoogleFonts.outfit(),
                ),
              ),
              DataCell(
                Text(
                  '${entry.avgPaceBpm.toStringAsFixed(1)}s',
                  style: GoogleFonts.outfit(
                    color: entry.avgPaceBpm > 5 
                        ? WellnessColors.primaryGreen 
                        : (entry.avgPaceBpm < 2 
                            ? WellnessColors.warmRed 
                            : WellnessColors.amber),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final table = DataTable(
          headingRowColor: WidgetStateProperty.all(
            WellnessColors.primaryBlue.withValues(alpha: 0.05),
          ),
          columnSpacing: 20,
          horizontalMargin: 20,
          dividerThickness: 0.5,
          columns: columns,
          rows: rows,
        );

        final tableWidget = constraints.maxWidth < 600
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: table,
              )
            : SizedBox(width: double.infinity, child: table);

        return Container(
          decoration: BoxDecoration(
            color: WellnessColors.getCardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WellnessColors.getBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: tableWidget,
          ),
        );
      },
    );
  }
}

class _EmailRequestCard extends StatelessWidget {
  const _EmailRequestCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    String selectedLabel;
    if (days <= 7) selectedLabel = 'this week';
    else if (days <= 30) selectedLabel = 'this month';
    else if (days <= 90) selectedLabel = 'last 3 months';
    else selectedLabel = 'selected period';
        
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WellnessColors.primaryBlue.withValues(alpha: 0.1),
            WellnessColors.primaryGreen.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WellnessColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.analytics_outlined, color: WellnessColors.primaryBlue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Reports',
                      style: GoogleFonts.outfit(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: WellnessColors.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      'Get deeper insights via email',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: WellnessColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Request an export for $selectedLabel of eating pattern data, including detailed bite logs and heater usage stats.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: WellnessColors.getTextSecondary(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Report requested. Check your email shortly.',
                      style: GoogleFonts.outfit(),
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: WellnessColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              icon: const Icon(Icons.email_outlined, size: 18),
              label: Text(
                'Request Email Report',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: WellnessColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
