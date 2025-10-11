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
}
