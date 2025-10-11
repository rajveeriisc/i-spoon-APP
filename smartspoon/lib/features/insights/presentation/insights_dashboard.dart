import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../insights/application/insights_controller.dart';
import 'widgets/header.dart';
import 'widgets/summary_cards.dart';
import 'widgets/temperature_section.dart';
import 'widgets/daily_food_timeline.dart';
// weekly_bite_count_chart removed; combined into DailyFoodTimeline
import 'widgets/tremor_charts.dart';
import 'widgets/environment_device.dart';
import 'widgets/trend_analytics.dart';
import 'widgets/recommendations.dart';

class InsightsDashboard extends StatelessWidget {
  const InsightsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<InsightsController>();
    final padding = MediaQuery.of(context).size.width * 0.05;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: HeaderSection(lastUpdated: DateTime.now())),
          SliverToBoxAdapter(child: SizedBox(height: padding)),
          SliverToBoxAdapter(
            child: SummaryCards(
              totalBites: controller.summary?.totalBites ?? 0,
              paceBpm: controller.summary?.eatingPaceBpm ?? 0,
              tremorIndex: controller.summary?.tremorIndex ?? 0,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: padding)),
          SliverToBoxAdapter(
            child: TemperatureSection(stats: controller.temperature),
          ),
          SliverToBoxAdapter(child: SizedBox(height: padding)),
          SliverToBoxAdapter(
            child: DailyFoodTimeline(events: controller.bites),
          ),
          // Weekly bite count is merged into DailyFoodTimeline as a second line
          SliverToBoxAdapter(child: SizedBox(height: padding)),
          SliverToBoxAdapter(child: TremorCharts(metrics: controller.tremor)),
          SliverToBoxAdapter(child: SizedBox(height: padding)),
          SliverToBoxAdapter(
            child: EnvironmentDevice(
              environment: controller.environment,
              health: controller.deviceHealth,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: padding)),
          SliverToBoxAdapter(child: TrendAnalytics(trends: controller.trends)),
          SliverToBoxAdapter(child: SizedBox(height: padding)),
          SliverToBoxAdapter(child: Recommendations(trends: controller.trends)),
        ],
      ),
    );
  }
}
