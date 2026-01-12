import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/insights/presentation/bite_history_page.dart';
import 'package:smartspoon/features/insights/presentation/widgets/tremor_breakdown_chart.dart';


/// Wellness-focused Analytics Dashboard
/// Redesigned with calming colors, tabbed navigation, and AI insights
class InsightsDashboard extends StatefulWidget {
  const InsightsDashboard({super.key});

  @override
  State<InsightsDashboard> createState() => _InsightsDashboardState();
}

class _InsightsDashboardState extends State<InsightsDashboard> {
  String _activeTab = 'eating';

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InsightsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: WellnessColors.getBackground(context),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh data
          await Future.delayed(const Duration(seconds: 1));
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Hero Header
            SliverToBoxAdapter(
              child: HeroHeader(
                greeting: _getGreeting(),
                subtitle: 'Your Wellness Insights',
                onRefresh: () {
                  setState(() {});
                },
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Combined Metric Card
                  CombinedMetricCard(
                      metric1: MetricData(
                        icon: '🍽',
                        title: 'Total Bites',
                        value: '${controller.summary?.totalBites ?? 0}',
                        trend: const MetricTrend(value: 12, direction: 'up'),
                        progress: 74,
                        color: WellnessColors.primaryBlue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MealsAnalysisPage(),
                            ),
                          );
                        },
                      ),
                      metric2: MetricData(
                        icon: '⏱',
                        title: 'Eating Pace',
                        value:
                            '${(controller.summary?.eatingPaceBpm ?? 0).toStringAsFixed(1)}s',
                        color: WellnessColors.primaryGreen,
                        subtitle: 'Optimal',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BiteHistoryPage(
                                summaries: controller.dailySummaries,
                              ),
                            ),
                          );
                        },
                      ),
                  ),

                  const SizedBox(height: 20),

                  // Tab Navigation
                  _buildTabNavigation(),

                  const SizedBox(height: 20),

                  // Tab Content
                  _buildTabContent(controller),

                  const SizedBox(height: 24),

                  // AI Insights Section
                  const SectionTitle(
                    title: 'Wellness Insights',
                    subtitle: 'Daily Analysis',
                  ),
                  const SizedBox(height: 16),

                  AIInsightCard(
                    type: 'Great Progress',
                    title: 'Tremor levels decreased by 23%',
                    message: 'Your tremor stability has improved significantly over the past week. Keep up the great work!',
                    accentColor: WellnessColors.primaryGreen,
                    onAction: () {},
                    onLearnMore: () {},
                  ),

                  const SizedBox(height: 12),

                  AIInsightCard(
                    type: 'Eating Speed Alert',
                    title: 'Pace increased by 34%',
                    message: 'Your eating pace has increased. Try to slow down and chew more thoroughly for better digestion.',
                    accentColor: WellnessColors.amber,
                    onAction: () {},
                    onLearnMore: () {},
                  ),

                  const SizedBox(height: 100), // Bottom nav clearance
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: WellnessColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: WellnessColors.getBorderColor(context),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                _buildTab('Eating Patterns', 'eating'),
                _buildTab('Tremor', 'tremor'),
                _buildTab('Temp', 'temperature'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String key) {
    final isActive = _activeTab == key;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive
                ? WellnessColors.primaryBlue.withOpacity(0.05)
                : Colors.transparent,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive
                        ? WellnessColors.primaryBlue
                        : WellnessColors.getTextSecondary(context),
                  ),
                ),
              ),
              if (isActive)
                Positioned(
                  bottom: -14,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      color: WellnessColors.primaryBlue,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(InsightsController controller) {
    switch (_activeTab) {
      case 'eating':
        return _buildEatingPatternsTab(controller);
      case 'tremor':
        return _buildTremorTab(controller);
      case 'temperature':
        return _buildTemperatureTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEatingPatternsTab(InsightsController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Insight Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: const Border(
              left: BorderSide(color: WellnessColors.primaryBlue, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💡 Daily Insight',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: WellnessColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You ate ${controller.summary?.totalBites ?? 0} bites today. Your pace was mostly Optimal (3-4s). Great job!',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF334155),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Meal Distribution
        Text(
          'Meal Distribution',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: WellnessColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 12),

        _buildMealDistributionChart(),

        const SizedBox(height: 24),

        // Weekly Trends Header with View All button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly History',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: WellnessColors.getTextPrimary(context),
              ),
            ),
            if (controller.dailySummaries.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BiteHistoryPage(
                        summaries: controller.dailySummaries,
                      ),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: WellnessColors.primaryBlue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Weekly Trends
        DailyFoodTimeline(events: controller.bites),
      ],
    );
  }

  Widget _buildMealDistributionChart() {
    final meals = [
      {'name': 'Breakfast', 'bites': 45, 'percentage': 30},
      {'name': 'Lunch', 'bites': 52, 'percentage': 35},
      {'name': 'Dinner', 'bites': 50, 'percentage': 35},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Column(
        children: meals.map((meal) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      meal['name'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    Text(
                      '${meal['bites']} bites',
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
                      widthFactor: (meal['percentage'] as int) / 100,
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: WellnessColors.primaryBlue.withOpacity(0.8),
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
                          '${meal['percentage']}%',
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

  Widget _buildTremorTab(InsightsController controller) {
    // Calculate today's tremor summary
    final today = DateTime.now();
    final todaySummary = controller.tremorSummaries.firstWhere(
      (s) => s.date.year == today.year && s.date.month == today.month && s.date.day == today.day,
      orElse: () => DailyTremorSummary(
        date: today,
        avgMagnitude: 0,
        peakMagnitude: 0,
        avgFrequencyHz: 0,
        dominantLevel: TremorLevel.low,
        tremorLevelCounts: {'low': 0, 'moderate': 0, 'high': 0},
      ),
    );

    final levelText = todaySummary.dominantLevel == TremorLevel.low
        ? 'Low'
        : todaySummary.dominantLevel == TremorLevel.moderate
            ? 'Moderate'
            : 'High';

    final counts = todaySummary.tremorLevelCounts ?? {'low': 0, 'moderate': 0, 'high': 0};
    final totalEvents = counts['low']! + counts['moderate']! + counts['high']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Insight Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(12),
            border: const Border(
              left: BorderSide(color: WellnessColors.primaryBlue, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💡 Daily Insight',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: WellnessColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                totalEvents > 0
                    ? 'Your tremor level was mostly $levelText today. ${totalEvents} tremor events recorded.'
                    : 'No tremor data recorded today.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF334155),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tremor Level Distribution
        Text(
          'Tremor Level Distribution',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: WellnessColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 12),

        TremorBreakdownChart(
          lowCount: counts['low']!,
          moderateCount: counts['moderate']!,
          highCount: counts['high']!,
        ),

        const SizedBox(height: 24),

        // Current Metrics Card
        TremorCharts(
          metrics: controller.tremor,
          onViewHistory: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TremorHistoryPage(
                  controller: controller,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTemperatureTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WellnessColors.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WellnessColors.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temperature Control',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: WellnessColors.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Access full temperature controls and heater settings.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: WellnessColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HeaterControlPage(),
                ),
              );
            },
            icon: const Icon(Icons.thermostat),
            label: const Text('Open Heater Control'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WellnessColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
