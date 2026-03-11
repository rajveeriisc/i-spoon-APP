import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspoon/features/insights/presentation/widgets/daily_food_timeline.dart';
import 'package:smartspoon/features/insights/domain/models.dart';

void main() {
  testWidgets('DailyFoodTimeline renders with summaries', (tester) async {
    final now = DateTime.now();
    final summaries = [
      DailyBiteSummary(
        date: now,
        totalBites: 24,
        avgMealDurationMin: 12.0,
        totalDurationMin: 24.0,
        avgPaceBpm: 2.0,
        mealBites: {'Breakfast': 8, 'Lunch': 16},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DailyFoodTimeline(summaries: summaries)),
      ),
    );

    expect(find.text('Weekly History'), findsOneWidget);
    expect(find.byType(DailyFoodTimeline), findsOneWidget);
  });
}
