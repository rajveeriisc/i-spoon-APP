import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';
import 'package:smartspoon/core/widgets/premium_header.dart';

/// Wellness-focused Analytics Dashboard with Premium Dark Theme
class InsightsDashboard extends StatefulWidget {
  const InsightsDashboard({super.key});

  @override
  State<InsightsDashboard> createState() => _InsightsDashboardState();
}

class _InsightsDashboardState extends State<InsightsDashboard> {
  String _activeTab = 'eating';

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InsightsController>();
    final unifiedData = context.watch<UnifiedDataService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Premium dark gradient background
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkBackgroundGradient
                  : AppTheme.backgroundGradient,
            ),
          ),
          // 2. Subtle geometric background pattern
          const GeometricBackground(),
          
          // 3. Content
          SafeArea(
            child: Column(
              children: [
                const PremiumHeader(
                  title: 'Wellness Insights',
                  subtitle: 'Your Daily Health Summary',
                  showProfile: false, // Save space or keep minimal
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(seconds: 1));
                      setState(() {});
                    },
                    color: AppTheme.emerald,
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                      child: Column(
                        children: [
                          CombinedMetricCard(
                            metric1: MetricData(
                              icon: '🍽',
                              title: 'Total Bites',
                              value: '${unifiedData.totalBites}',
                              trend: const MetricTrend(value: 12, direction: 'up'), // Real data needed?
                              progress: 74,
                              color: AppTheme.emerald,
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
                              value: '${(unifiedData.avgBiteTime).toStringAsFixed(1)}s',
                              color: AppTheme.amber, // Gold for pace
                              subtitle: 'sec / bite',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const BiteHistoryPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Tab Navigation
                          _buildTabNavigation(),
                          const SizedBox(height: 24),

                          // Tab Content
                          _buildTabContent(controller),
                          const SizedBox(height: 24),
                          
                          // Insights Section
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: SectionTitle(
                              title: 'Key Observations',
                              subtitle: 'Recent behavior & trends',
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          AIInsightCard(
                            type: 'Great Progress',
                            title: 'Tremor levels decreased by 23%',
                            message: 'Your tremor stability has improved significantly over the past week.',
                            accentColor: AppTheme.emerald,
                            onAction: () {},
                          ),
                          const SizedBox(height: 12),
                          AIInsightCard(
                            type: 'Eating Speed Alert',
                            title: 'Pace increased by 34%',
                            message: 'Try to slow down and chew more thoroughly for better digestion.',
                            accentColor: AppTheme.amber,
                          ),
                        ],
                      ),
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

  Widget _buildTabNavigation() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildTab('Eating', 'eating'),
          _buildTab('Tremor', 'tremor'),
          _buildTab('Temp', 'temperature'),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String key) {
    final isActive = _activeTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.emerald.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(21),
            border: isActive ? Border.all(color: AppTheme.emerald.withValues(alpha: 0.5)) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(InsightsController controller) {
    // FadeSwitcher or AnimatedSwitcher logic could go here, keeping it simple for now
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
        DailyFoodTimeline(summaries: controller.dailySummaries),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTremorTab(InsightsController controller) {
    // Logic for daily insight from original code
    final today = DateTime.now();
    final todaySummary = controller.tremorSummaries.firstWhere(
      (s) => s.date.year == today.year && s.date.month == today.month && s.date.day == today.day,
      orElse: () => DailyTremorSummary(
        date: today,
        avgMagnitude: 0,
        avgFrequencyHz: 0,
        dominantLevel: TremorLevel.low,
        tremorLevelCounts: {'low': 0, 'moderate': 0, 'high': 0},
      ),
    );
    final counts = todaySummary.tremorLevelCounts ?? {'low': 0, 'moderate': 0, 'high': 0};

    return Column(
      children: [
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
        const SizedBox(height: 24),
        TremorBreakdownChart(
          lowCount: counts['low']!,
          moderateCount: counts['moderate']!,
          highCount: counts['high']!,
        ),
      ],
    );
  }

  Widget _buildTemperatureTab() {
    return PremiumGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Temperature Control',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Icon(Icons.thermostat, color: AppTheme.rose),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Access full temperature controls and heater settings.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HeaterControlPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Open Heater Control',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
