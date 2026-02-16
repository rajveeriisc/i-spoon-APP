import 'dart:async';
import 'dart:math';
import '../domain/insights_repository.dart';
import '../domain/models.dart';

class _MockLive implements LiveTelemetrySource {
  late final StreamController<TemperatureStats> _tempCtrl;
  late final StreamController<TremorMetrics> _tremorCtrl;
  late final StreamController<DeviceHealth> _healthCtrl;
  late final StreamController<EnvironmentData> _envCtrl;
  Timer? _timer;
  int _tick = 0;

  _MockLive() {
    _tempCtrl = StreamController.broadcast();
    _tremorCtrl = StreamController.broadcast();
    _healthCtrl = StreamController.broadcast();
    _envCtrl = StreamController.broadcast();
    _timer = Timer.periodic(const Duration(milliseconds: 800), _onTick);
  }

  void _onTick(Timer t) {
    _tick++;
    final baseFood = 42 + 6 * sin(_tick / 6);
    final baseHeater = 58 + 4 * sin(_tick / 5);
    _tempCtrl.add(
      TemperatureStats(foodTempC: baseFood, heaterTempC: baseHeater),
    );

    final tremMag = (0.3 + 1.5 * max(0, sin(_tick / 7))).clamp(0.1, 2.2);
    final level = tremMag < 0.5
        ? TremorLevel.low
        : tremMag < 1.5
        ? TremorLevel.moderate
        : TremorLevel.high;
    _tremorCtrl.add(
      TremorMetrics(
        currentMagnitude: tremMag,
        peakFrequencyHz: 5.0 + 1.0 * sin(_tick / 9),
        level: level,
      ),
    );

    final batt = max(5, 82 - (_tick ~/ 120));
    _healthCtrl.add(
      DeviceHealth(
        batteryPercent: batt,
        voltage: 3.8,
        chargeCycles: 23,
        sensorsHealthy: true,
      ),
    );

    _envCtrl.add(
      const EnvironmentData(
        ambientTempC: 24,
        humidityPercent: 45,
        pressureHpa: 1013,
      ),
    );
  }

  void dispose() {
    _timer?.cancel();
    _tempCtrl.close();
    _tremorCtrl.close();
    _healthCtrl.close();
    _envCtrl.close();
  }

  @override
  Stream<TemperatureStats> get temperature$ => _tempCtrl.stream;

  @override
  Stream<TremorMetrics> get tremor$ => _tremorCtrl.stream;

  @override
  Stream<DeviceHealth> get deviceHealth$ => _healthCtrl.stream;

  @override
  Stream<EnvironmentData> get environment$ => _envCtrl.stream;
}

class MockInsightsRepository implements InsightsRepository {
  late final _MockLive _live;

  MockInsightsRepository() {
    _live = _MockLive();
  }

  void dispose() => _live.dispose();

  @override
  LiveTelemetrySource get live => _live;

  @override
  Future<MealSummary> getLastMealSummary() async {
    return const MealSummary(
      totalBites: 47,
      eatingPaceBpm: 3.2,
      tremorIndex: 25,
    );
  }

  @override
  Future<List<BiteEvent>> getBiteEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    final events = <BiteEvent>[];
    final total = 47;
    final baseTime = start;
    final rnd = Random(7);
    for (var i = 0; i < total; i++) {
      final t = baseTime.add(Duration(seconds: 15 * i + rnd.nextInt(6)));
      final type = i % 13 == 0
          ? BiteEventType.anomaly
          : (i % 9 == 0 ? BiteEventType.missed : BiteEventType.valid);
      events.add(
        BiteEvent(
          index: i + 1,
          timestamp: t,
          foodTempC: 40 + rnd.nextDouble() * 8,
          tremorMagnitude: 0.2 + rnd.nextDouble() * 1.6,
          type: type,
        ),
      );
    }
    return events;
  }

  @override
  Future<TrendData> getTrends({
    required DateTime start,
    required DateTime end,
  }) async {
    final List<TrendDataPoint<int>> bites = [];
    final List<TrendDataPoint<double>> duration = [];
    final List<TrendDataPoint<int>> tremor = [];
    final rnd = Random(21);
    var cursor = start;
    while (cursor.isBefore(end)) {
      bites.add(TrendDataPoint<int>(cursor, 35 + rnd.nextInt(20)));
      duration.add(TrendDataPoint<double>(cursor, 12 + rnd.nextDouble() * 10));
      tremor.add(TrendDataPoint<int>(cursor, 15 + rnd.nextInt(30)));
      cursor = cursor.add(const Duration(days: 1));
    }
    return TrendData(
      bitesPerMeal: bites,
      avgMealDurationMin: duration,
      tremorIndexOverTime: tremor,
    );
  }

  @override
  Future<List<DailyBiteSummary>> getDailyBiteSummaries({
    required DateTime start,
    required DateTime end,
  }) async {
    final summaries = <DailyBiteSummary>[];
    final rnd = Random(42);
    var cursor = DateTime(start.year, start.month, start.day);
    while (!cursor.isAfter(end)) {
      final bites = 30 + rnd.nextInt(25);
      final avgDuration = 10 + rnd.nextDouble() * 8;
      final totalDuration = avgDuration * (1 + rnd.nextDouble() * 2);
      final pace = avgDuration <= 0 ? 0 : bites / avgDuration;
      
      // Generate meal breakdown
      final breakfast = (bites * 0.3).round();
      final lunch = (bites * 0.4).round();
      final dinner = (bites * 0.2).round();
      final snacks = bites - breakfast - lunch - dinner;

      summaries.add(
        DailyBiteSummary(
          date: cursor,
          totalBites: bites,
          avgMealDurationMin: double.parse(avgDuration.toStringAsFixed(1)),
          totalDurationMin: double.parse(totalDuration.toStringAsFixed(1)),
          avgPaceBpm: double.parse(pace.toStringAsFixed(2)),
          mealBites: {
            'Breakfast': breakfast,
            'Lunch': lunch,
            'Dinner': dinner,
            'Snacks': snacks,
          },
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return summaries;
  }

  @override
  Future<List<DailyTremorSummary>> getDailyTremorSummaries({
    required DateTime start,
    required DateTime end,
  }) async {
    final rnd = Random(99);
    final entries = <DailyTremorSummary>[];
    var cursor = DateTime(start.year, start.month, start.day);
    
    // Helper to generate random summary for a meal/day
    DailyTremorSummary generateSummary(DateTime date, Random r) {
      final avgMag = 0.3 + r.nextDouble() * 1.2;
      final peakMag = avgMag + r.nextDouble() * 0.8;
      final avgFreq = 4.5 + r.nextDouble() * 2.0;
      final level = peakMag < 0.6
          ? TremorLevel.low
          : peakMag < 1.4
              ? TremorLevel.moderate
              : TremorLevel.high;
              
      return DailyTremorSummary(
        date: date,
        avgMagnitude: double.parse(avgMag.toStringAsFixed(2)),
        peakMagnitude: double.parse(peakMag.toStringAsFixed(2)),
        avgFrequencyHz: double.parse(avgFreq.toStringAsFixed(2)),
        dominantLevel: level,
      );
    }

    while (!cursor.isAfter(end)) {
      // 1. Generate overall summary
      final overall = generateSummary(cursor, rnd);
      
      // 2. Generate meal breakdown
      final breakdown = <String, DailyTremorSummary>{};
      for (final meal in ['Breakfast', 'Lunch', 'Snacks', 'Dinner']) {
        breakdown[meal] = generateSummary(cursor, rnd);
      }

      entries.add(
        DailyTremorSummary(
          date: cursor,
          avgMagnitude: overall.avgMagnitude,
          peakMagnitude: overall.peakMagnitude,
          avgFrequencyHz: overall.avgFrequencyHz,
          dominantLevel: overall.dominantLevel,
          mealBreakdown: breakdown,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return entries;
  }


  @override
  Future<List<MealSummary>> getMealsForDate(DateTime date) async {
    final rnd = Random(date.millisecondsSinceEpoch);
    final count = 3 + rnd.nextInt(2); // 3-4 meals
    final summaries = <MealSummary>[];
    
    // Base times for meals
    final times = [
      DateTime(date.year, date.month, date.day, 8, 30),
      DateTime(date.year, date.month, date.day, 13, 0),
      DateTime(date.year, date.month, date.day, 19, 30),
      DateTime(date.year, date.month, date.day, 16, 0), // Snack
    ];
    final types = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

    for (var i = 0; i < count; i++) {
       final bites = 20 + rnd.nextInt(40);
       final duration = 10 + rnd.nextDouble() * 15;
       final pace = bites / duration;
       
       summaries.add(MealSummary(
         totalBites: bites,
         eatingPaceBpm: double.parse(pace.toStringAsFixed(1)),
         tremorIndex: 10 + rnd.nextInt(30),
         lastMealStart: times[i],
         lastMealEnd: times[i].add(Duration(minutes: duration.toInt())),
         mealType: types[i],
         durationMinutes: double.parse(duration.toStringAsFixed(1)),
       ));
    }
    
    return summaries;
  }
}
