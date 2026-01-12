import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspoon/features/insights/presentation/widgets/summary_cards.dart';

void main() {
  testWidgets('SummaryCards displays values and labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SummaryCards(totalBites: 47, paceBpm: 3.2),
        ),
      ),
    );

    expect(find.text('Total Bites'), findsOneWidget);
    expect(find.text('47'), findsOneWidget);
    expect(find.text('Eating Pace'), findsOneWidget);
    expect(find.text('3.2'), findsOneWidget);
    expect(find.text('bites/min'), findsOneWidget);
    // expect(find.text('Tremor Index'), findsOneWidget);
    // expect(find.text('Low'), findsOneWidget);
  });
}
