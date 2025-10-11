import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspoon/features/insights/presentation/widgets/temperature_section.dart';
import 'package:smartspoon/features/insights/domain/models.dart';

void main() {
  testWidgets('TemperatureSection shows alert when food > 60C', (tester) async {
    const stats = TemperatureStats(foodTempC: 65, heaterTempC: 60);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TemperatureSection(stats: stats)),
      ),
    );
    expect(find.textContaining('Food is hot!'), findsOneWidget);
  });
}
