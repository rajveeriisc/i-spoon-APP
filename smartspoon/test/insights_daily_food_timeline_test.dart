import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspoon/features/insights/presentation/widgets/daily_food_timeline.dart';
import 'package:smartspoon/features/insights/domain/models.dart';

void main() {
  testWidgets('DailyFoodTimeline renders title and chart', (tester) async {
    final now = DateTime.now();
    final events = [
      BiteEvent(
        index: 1,
        timestamp: now.subtract(const Duration(hours: 1)),
        foodTempC: 42,
        tremorMagnitude: 0.3,
        type: BiteEventType.valid,
      ),
      BiteEvent(
        index: 2,
        timestamp: now,
        foodTempC: 41,
        tremorMagnitude: 0.4,
        type: BiteEventType.missed,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DailyFoodTimeline(events: events)),
      ),
    );

    expect(find.text('Daily Food Timeline'), findsOneWidget);
    // Dots are drawn; we at least ensure the widget tree builds
    expect(find.byType(DailyFoodTimeline), findsOneWidget);
  });
}
