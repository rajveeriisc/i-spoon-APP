import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../insights/domain/models.dart';
import '../../insights/application/insights_controller.dart';
import 'theme/wellness_colors.dart';

class TremorHistoryPage extends StatefulWidget {
  const TremorHistoryPage({super.key, required this.controller});

  final InsightsController controller;

  @override
  State<TremorHistoryPage> createState() => _TremorHistoryPageState();
}


class _TremorHistoryPageState extends State<TremorHistoryPage> {
  int _selectedDays = 7; // Default to 7 days
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
        backgroundColor: WellnessColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            'Tremor Analysis',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: WellnessColors.getBackground(context),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sorted = [..._summaries]
      ..sort((a, b) => a.date.compareTo(b.date));
    final now = sorted.isEmpty ? DateTime.now() : sorted.last.date;
    final display = _computeAggregates(sorted, now, _selectedDays);

    return Scaffold(
      backgroundColor: WellnessColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Tremor Analysis',
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
            _OverviewStrip(aggregate: display, days: _selectedDays),
            
            const SizedBox(height: 24),
            
            // Time Range Dropdown (matching Eating Pattern design)
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
                        if (val != null) {
                          setState(() => _selectedDays = val);
                          _loadData(); // Fetch new data when dropdown changes
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            _TremorDataTable(entries: display.entries),
            
            const SizedBox(height: 24),
            
            _EmailRequestCard(days: _selectedDays),
          ],
        ),
      ),
    );
  }

  _TremorAggregate _computeAggregates(
    List<DailyTremorSummary> summaries,
    DateTime end,
    int days,
  ) {
    final start = end.subtract(Duration(days: days - 1));
    final range = summaries
        .where((s) => !s.date.isBefore(start) && !s.date.isAfter(end))
        .toList();

    if (range.isEmpty) {
      return _TremorAggregate(
        entries: const [],
        avgMagnitude: 0,
        peakMagnitude: 0,
        avgFrequency: 0,
        levelDistribution: const {},
      );
    }

    final avgMag =
        range.fold<double>(0, (sum, e) => sum + e.avgMagnitude) / range.length;
    final peakMag = range.fold<double>(
      0,
      (max, e) => e.peakMagnitude > max ? e.peakMagnitude : max,
    );
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
      peakMagnitude: peakMag,
      avgFrequency: avgFreq,
      levelDistribution: levels,
    );
  }
}

class _TremorAggregate {
  const _TremorAggregate({
    required this.entries,
    required this.avgMagnitude,
    required this.peakMagnitude,
    required this.avgFrequency,
    required this.levelDistribution,
  });

  final List<DailyTremorSummary> entries;
  final double avgMagnitude;
  final double peakMagnitude;
  final double avgFrequency;
  final Map<TremorLevel, int> levelDistribution;
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({required this.aggregate, required this.days});

  final _TremorAggregate aggregate;
  final int days;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OverviewTile(
            title: 'Period Average',
            value: '${aggregate.avgMagnitude.toStringAsFixed(2)}',
            unit: 'rad/s',
            subtitle: 'Avg over $days days',
            color: WellnessColors.primaryBlue,
            icon: Icons.analytics,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _OverviewTile(
            title: 'Peak Magnitude',
            value: '${aggregate.peakMagnitude.toStringAsFixed(2)}',
            unit: 'rad/s',
            subtitle: 'Highest in period',
            color: WellnessColors.warmRed,
            icon: Icons.trending_up,
          ),
        ),
      ],
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

class _TremorDataTable extends StatelessWidget {
  const _TremorDataTable({required this.entries});

  final List<DailyTremorSummary> entries;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.MMMd();
    final columns = [
      const DataColumn(label: Text('Date')),
      const DataColumn(label: Text('Avg Mag')),
      const DataColumn(label: Text('Peak Mag')),
      const DataColumn(label: Text('Avg Hz')),
      const DataColumn(label: Text('Level')),
      const DataColumn(label: Text('Level Value')),
    ];

    final rows = entries
        .map(
          (entry) => DataRow(
            cells: [
              DataCell(Text(dateFmt.format(entry.date))),
              DataCell(Text(entry.avgMagnitude.toStringAsFixed(2))),
              DataCell(Text(entry.peakMagnitude.toStringAsFixed(2))),
              DataCell(Text(entry.avgFrequencyHz.toStringAsFixed(2))),
              DataCell(Text(_labelFor(entry.dominantLevel))),
              DataCell(Text(_levelValue(entry.dominantLevel).toString())),
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
            'Request an export for $selectedLabel of tremor analysis data, including detailed magnitude and frequency logs.',
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
