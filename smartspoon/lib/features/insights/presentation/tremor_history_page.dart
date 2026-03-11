import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../insights/domain/models.dart';
import '../../insights/application/insights_controller.dart';
import 'package:smartspoon/core/theme/app_theme.dart';

class TremorHistoryPage extends StatefulWidget {
  const TremorHistoryPage({super.key, required this.controller});

  final InsightsController controller;

  @override
  State<TremorHistoryPage> createState() => _TremorHistoryPageState();
}


class _TremorHistoryPageState extends State<TremorHistoryPage> {
  int _selectedDays = 7; // Default to 7 days
  String _selectedMeal = 'All';
  List<DailyTremorSummary> _summaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.controller.fetchTremorDataForRange(_selectedDays);
      setState(() {
        _summaries = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Tremor Analysis',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }


    final sorted = [..._summaries]
      ..sort((a, b) => a.date.compareTo(b.date));
    final now = sorted.isEmpty ? DateTime.now() : sorted.last.date;
    final display = _computeAggregates(sorted, now, _selectedDays, _selectedMeal);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Tremor Analysis',
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
            _OverviewStrip(aggregate: display, days: _selectedDays),
            
            const SizedBox(height: 24),
            
            // Time Range Dropdown (matching Eating Pattern design)
            // Mobile-responsive Layout for Header + Dropdowns
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
            
            _TremorDataTable(entries: display.entries),
          ],
        ),
      ),
    );
  }

  _TremorAggregate _computeAggregates(
    List<DailyTremorSummary> summaries,
    DateTime end,
    int days,
    String mealType,
  ) {
    final start = end.subtract(Duration(days: days - 1));
    var rawRange = summaries
        .where((s) => !s.date.isBefore(start) && !s.date.isAfter(end));

    List<DailyTremorSummary> range;
    if (mealType == 'All') {
      range = rawRange.toList();
    } else {
      range = rawRange.map((s) {
        // Return the specific meal summary, or an empty one if missing
        // Preserve the date from the parent
        final mealSummary = s.mealBreakdown?[mealType];
        if (mealSummary != null) return mealSummary;
        
        // Fallback empty summary
        return DailyTremorSummary(
          date: s.date,
          avgMagnitude: 0,
          avgFrequencyHz: 0,
          dominantLevel: TremorLevel.low,
        );
      }).toList();
    }

    if (range.isEmpty) {
      return _TremorAggregate(
        entries: const [],
        avgMagnitude: 0,
        avgFrequency: 0,
        levelDistribution: const {},
      );
    }

    final avgMag =
        range.fold<double>(0, (sum, e) => sum + e.avgMagnitude) / range.length;
    final avgFreq =
        range.fold<double>(0, (sum, e) => sum + e.avgFrequencyHz) /
        range.length;

    final Map<TremorLevel, int> levels = {};
    for (final entry in range) {
      levels.update(
        entry.dominantLevel,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return _TremorAggregate(
      entries: range,
      avgMagnitude: avgMag,
      avgFrequency: avgFreq,
      levelDistribution: levels,
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
                  _loadData(); // Fetch new data when dropdown changes
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TremorAggregate {
  const _TremorAggregate({
    required this.entries,
    required this.avgMagnitude,
    required this.avgFrequency,
    required this.levelDistribution,
  });

  final List<DailyTremorSummary> entries;
  final double avgMagnitude;
  final double avgFrequency;
  final Map<TremorLevel, int> levelDistribution;
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({required this.aggregate, required this.days});

  final _TremorAggregate aggregate;
  final int days;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        if (isNarrow) {
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: _OverviewTile(
                  title: 'Avg Magnitude',
                  value: aggregate.avgMagnitude.toStringAsFixed(2),
                  unit: 'index',
                  subtitle: 'Avg over $days days',
                  color: AppTheme.emerald,
                  icon: Icons.analytics,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: _OverviewTile(
                  title: 'Avg Frequency',
                  value: aggregate.avgFrequency.toStringAsFixed(1),
                  unit: 'Hz',
                  subtitle: 'Avg over $days days',
                  color: AppTheme.violet,
                  icon: Icons.graphic_eq_rounded,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _OverviewTile(
                title: 'Avg Magnitude',
                value: aggregate.avgMagnitude.toStringAsFixed(2),
                unit: 'index',
                subtitle: 'Avg over $days days',
                color: AppTheme.emerald,
                icon: Icons.analytics,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _OverviewTile(
                title: 'Avg Frequency',
                value: aggregate.avgFrequency.toStringAsFixed(1),
                unit: 'Hz',
                subtitle: 'Avg over $days days',
                color: AppTheme.violet,
                icon: Icons.graphic_eq_rounded,
              ),
            ),
          ],
        );
      },
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

class _TremorDataTable extends StatelessWidget {
  const _TremorDataTable({required this.entries});

  final List<DailyTremorSummary> entries;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.MMMd();
    final columns = [
      const DataColumn(label: Text('Date')),
      const DataColumn(label: Text('Avg Mag')),
      const DataColumn(label: Text('Avg Hz')),
      const DataColumn(label: Text('Level')),
    ];

    final rows = entries
        .map(
          (entry) => DataRow(
            cells: [
              DataCell(Text(dateFmt.format(entry.date))),
              DataCell(Text(entry.avgMagnitude.toStringAsFixed(2))),
              DataCell(Text(entry.avgFrequencyHz.toStringAsFixed(2))),
              DataCell(Text(_labelFor(entry.dominantLevel))),
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

  String _labelFor(TremorLevel level) {
    switch (level) {
      case TremorLevel.low:
        return 'Low';
      case TremorLevel.moderate:
        return 'Moderate';
      case TremorLevel.high:
        return 'High';
    }
  }

  int _levelValue(TremorLevel level) {
    switch (level) {
      case TremorLevel.low:
        return 1;
      case TremorLevel.moderate:
        return 2;
      case TremorLevel.high:
        return 3;
    }
  }
}
