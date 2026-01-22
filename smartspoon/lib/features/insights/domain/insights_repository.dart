import 'dart:async';
import 'models.dart';

abstract class LiveTelemetrySource {
  Stream<TemperatureStats> get temperature$;
  Stream<TremorMetrics> get tremor$;
  Stream<DeviceHealth> get deviceHealth$;
  Stream<EnvironmentData> get environment$;
}

abstract class InsightsRepository {
  LiveTelemetrySource get live;

  Future<MealSummary> getLastMealSummary();
  Future<List<BiteEvent>> getBiteEvents({
    required DateTime start,
    required DateTime end,
  });
  Future<TrendData> getTrends({required DateTime start, required DateTime end});
  Future<List<DailyBiteSummary>> getDailyBiteSummaries({
    required DateTime start,
    required DateTime end,
  });
  Future<List<DailyTremorSummary>> getDailyTremorSummaries({
    required DateTime start,
    required DateTime end,
  });

  /// Fetch detailed meal records for a specific date (for analysis page)
  Future<List<MealSummary>> getMealsForDate(DateTime date);
}
