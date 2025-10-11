import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspoon/features/insights/presentation/widgets/tremor_charts.dart';
import 'package:smartspoon/features/insights/domain/models.dart';

void main() {
  testWidgets('TremorCharts shows metrics text', (tester) async {
    const metrics = TremorMetrics(
      currentMagnitude: 0.42,
      peakFrequencyHz: 5.1,
      level: TremorLevel.low,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TremorCharts(metrics: metrics)),
      ),
    );
    expect(find.textContaining('Current: 0.42'), findsOneWidget);
    expect(find.textContaining('Peak: 5.1'), findsOneWidget);
    expect(find.textContaining('Level: Low'), findsOneWidget);
  });
}
