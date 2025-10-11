import 'package:flutter/foundation.dart';

@immutable
class MealSummary {
  final int totalBites;
  final double eatingPaceBpm; // bites per minute
  final int tremorIndex; // 0-100
  final DateTime? lastMealStart;
  final DateTime? lastMealEnd;

  const MealSummary({
    required this.totalBites,
    required this.eatingPaceBpm,
    required this.tremorIndex,
    this.lastMealStart,
    this.lastMealEnd,
  });
}

@immutable
class BiteEvent {
  final int index;
  final DateTime timestamp;
  final double weightGrams;
  final double foodTempC;
  final double tremorMagnitude; // rad/s magnitude near bite
  final BiteEventType type;

  const BiteEvent({
    required this.index,
    required this.timestamp,
    required this.weightGrams,
    required this.foodTempC,
    required this.tremorMagnitude,
    required this.type,
  });
}

enum BiteEventType { valid, missed, anomaly }

@immutable
class TemperatureStats {
  final double foodTempC;
  final double heaterTempC;

  const TemperatureStats({required this.foodTempC, required this.heaterTempC});
}

@immutable
class TremorMetrics {
  final double currentMagnitude; // rad/s
  final double peakFrequencyHz;
  final TremorLevel level;

  const TremorMetrics({
    required this.currentMagnitude,
    required this.peakFrequencyHz,
    required this.level,
  });
}

enum TremorLevel { low, moderate, high }

@immutable
class TrendDataPoint<T extends num> {
  final DateTime time;
  final T value;

  const TrendDataPoint(this.time, this.value);
}

@immutable
class TrendData {
  final List<TrendDataPoint<int>> bitesPerMeal;
  final List<TrendDataPoint<double>> avgMealDurationMin;
  final List<TrendDataPoint<int>> tremorIndexOverTime;

  const TrendData({
    required this.bitesPerMeal,
    required this.avgMealDurationMin,
    required this.tremorIndexOverTime,
  });
}

@immutable
class DeviceHealth {
  final int batteryPercent; // 0-100
  final double voltage;
  final int chargeCycles;
  final bool sensorsHealthy; // simplified for mock

  const DeviceHealth({
    required this.batteryPercent,
    required this.voltage,
    required this.chargeCycles,
    required this.sensorsHealthy,
  });
}

@immutable
class EnvironmentData {
  final double ambientTempC;
  final double humidityPercent;
  final double pressureHpa;

  const EnvironmentData({
    required this.ambientTempC,
    required this.humidityPercent,
    required this.pressureHpa,
  });
}
