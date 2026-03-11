import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/core/services/database_service.dart';

/// Real implementation of LiveTelemetrySource that adapts UnifiedDataService
class RealLiveTelemetrySource implements LiveTelemetrySource {
  final UnifiedDataService _dataService;
  
  final _tempCtrl = StreamController<TemperatureStats>.broadcast();
  final _tremorCtrl = StreamController<TremorMetrics>.broadcast();
  final _healthCtrl = StreamController<DeviceHealth>.broadcast();
  final _envCtrl = StreamController<EnvironmentData>.broadcast();

  RealLiveTelemetrySource(this._dataService) {
    // Listen to UnifiedDataService updates and push to streams
    _dataService.addListener(_onDataChanged);
  }

  void _onDataChanged() {
    // 1. Temperature
    _tempCtrl.add(TemperatureStats(
      foodTempC: _dataService.foodTempC,
      heaterTempC: _dataService.heaterTempC,
    ));

    // 2. Tremor
    final result = _dataService.lastTremorResult;

    // Map amplitude to TremorLevel — unified with DB thresholds (0.6 / 1.4)
    final magnitude = result.amplitude / 100.0;
    TremorLevel level;
    if (magnitude < 0.6) {
      level = TremorLevel.low;
    } else if (magnitude < 1.4) {
      level = TremorLevel.moderate;
    } else {
      level = TremorLevel.high;
    }
    
    _tremorCtrl.add(TremorMetrics(
      currentMagnitude: magnitude, // Scaled (amplitude / 100.0), range 0–3, matches DB thresholds
      peakFrequencyHz: result.frequency,
      level: level,
    ));

    // 3. Device Health
    _healthCtrl.add(DeviceHealth(
      batteryPercent: _dataService.batteryLevel,
      voltage: 3.7, // Fixed for now
      chargeCycles: 0,
      sensorsHealthy: true,
      batteryStatus: _dataService.batteryLevel > 20 ? 'Good' : 'Low',
      lastSync: DateTime.now(),
    ));

    // 4. Environment (Mock for now as we don't have sensors)
    _envCtrl.add(const EnvironmentData(
      ambientTempC: 25.0,
      humidityPercent: 50.0,
      pressureHpa: 1013.0,
    ));
  }

  void dispose() {
    _dataService.removeListener(_onDataChanged);
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

/// Hybrid Repository: Real Live Data + Mock Historical Data
class LiveInsightsRepository implements InsightsRepository {
  late final RealLiveTelemetrySource _live;
  final UnifiedDataService _dataService;

  LiveInsightsRepository(this._dataService) {
    _live = RealLiveTelemetrySource(_dataService);
    // NOTE: async init is exposed via initAsync() so callers can await it.
    // Do NOT call _initData() here — let InsightsController.init() await it.
  }

  /// Must be awaited before fetchHistory() so backfill completes first.
  Future<void> initAsync() async {
    final db = DatabaseService();
    final userId = _currentUserId;
    if (userId.isEmpty) return;

    // Backfill daily_summaries for any meal dates that are missing a summary row.
    await db.backfillMissingSummaries(userId);

    // Reload today's snapshot in UnifiedDataService so home cards reflect reality.
    _dataService.refreshTodaySnapshot();
  }

  @override
  LiveTelemetrySource get live => _live;

  void dispose() {
    _live.dispose();
  }

  // --- Real Offline History Data ---

  final DatabaseService _db = DatabaseService();

  @override
  Future<MealSummary> getLastMealSummary() async {
    // Try to get the latest meal from DB
    final meals = await _db.getMeals(limit: 1);
    
    if (meals.isNotEmpty) {
      final last = meals.first;
      return MealSummary(
        totalBites: last.totalBites,
        eatingPaceBpm: last.avgPaceBpm ?? 0.0,
        tremorIndex: last.tremorIndex ?? 0,
        lastMealStart: last.startedAt,
        lastMealEnd: last.endedAt,
      );
    }
    
    return const MealSummary(
      totalBites: 0,
      eatingPaceBpm: 0.0,
      tremorIndex: 0,
    );
  }

  @override
  Future<List<BiteEvent>> getBiteEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    // Fetch bites for meals in this range
    // For now returning empty or we need a complex query to join meals+bites
    return [];
  }

  @override
  Future<TrendData> getTrends({
    required DateTime start,
    required DateTime end,
  }) async {
    final meals = await _db.getMeals(limit: 1000); // Fetch enough history
    
    // Filter by date range
    final rangeMeals = meals.where((m) => 
      m.startedAt.isAfter(start.subtract(const Duration(days: 1))) && 
      m.startedAt.isBefore(end.add(const Duration(days: 1)))
    ).toList();
    
    final List<TrendDataPoint<int>> bites = [];
    final List<TrendDataPoint<double>> duration = [];
    final List<TrendDataPoint<int>> tremor = [];
    
    // Group by day for trends? Or per meal? 
    // Usually trends are per day or per meal point. Assuming per meal point for now.
    for (var m in rangeMeals) {
      bites.add(TrendDataPoint<int>(m.startedAt, m.totalBites));
      if (m.durationMinutes != null) {
        duration.add(TrendDataPoint<double>(m.startedAt, m.durationMinutes!));
      }
      if (m.tremorIndex != null) {
        tremor.add(TrendDataPoint<int>(m.startedAt, m.tremorIndex!));
      }
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
    // Fast path: read from pre-aggregated daily_summaries table.
    // Falls back to empty list if table doesn't exist yet (new install before first meal).
    final userId = _currentUserId;
    final rows = await _db.getDailySummaries(
      userId: userId,
      start: start,
      end: end,
    );

    return rows.map((r) {
      final dateStr = r['date'] as String; // "YYYY-MM-DD" local date
      // Parse as LOCAL midnight — DateTime.parse("YYYY-MM-DD") creates UTC midnight
      // which causes day-mismatch in non-UTC timezones (e.g. IST, EST).
      final parts = dateStr.split('-');
      final date = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final totalBites = (r['total_bites'] as num?)?.toInt() ?? 0;
      final totalMinutes = (r['total_eating_min'] as num?)?.toDouble() ?? 0.0;
      // Compute bpm from aggregated data: bites / total_minutes.
      // avg_pace_bpm per meal is not stored in daily_summaries, so we derive it.
      final avgPace = (totalMinutes > 0 && totalBites > 0)
          ? totalBites / totalMinutes
          : 0.0;
      return DailyBiteSummary(
        date: date,
        totalBites: totalBites,
        avgMealDurationMin: totalMinutes,
        totalDurationMin: totalMinutes,
        avgPaceBpm: avgPace,
        mealBites: {
          'Breakfast': (r['breakfast_bites'] as num?)?.toInt() ?? 0,
          'Lunch':     (r['lunch_bites']     as num?)?.toInt() ?? 0,
          'Dinner':    (r['dinner_bites']    as num?)?.toInt() ?? 0,
          'Snacks':    (r['snack_bites']     as num?)?.toInt() ?? 0,
        },
      );
    }).toList();
  }

  @override
  Future<List<DailyTremorSummary>> getDailyTremorSummaries({
    required DateTime start,
    required DateTime end,
  }) async {
    // Primary: read pre-aggregated tremor counts from daily_summaries.
    final userId = _currentUserId;
    final rows = await _db.getDailySummaries(userId: userId, start: start, end: end);

    // Secondary: per-meal-type breakdown — only computed on demand (Tremor History page).
    final mealStats = await _db.getMealTypeTremorStats(start: start, end: end);
    final Map<String, Map<String, DailyTremorSummary>> breakdowns = {};
    for (final row in mealStats) {
      final dateStr = row['date'] as String;
      final mealType = row['meal_type'] as String? ?? 'Snacks';
      final avgMag = (row['avg_magnitude'] as num?)?.toDouble() ?? 0.0;
      breakdowns.putIfAbsent(dateStr, () => {})[mealType] = DailyTremorSummary(
        date: _parseLocalDate(dateStr),
        avgMagnitude: avgMag,
        avgFrequencyHz: (row['avg_frequency'] as num?)?.toDouble() ?? 0.0,
        dominantLevel: avgMag < 0.6 ? TremorLevel.low : avgMag < 1.4 ? TremorLevel.moderate : TremorLevel.high,
        tremorLevelCounts: {
          'low':      (row['low_count']      as num?)?.toInt() ?? 0,
          'moderate': (row['moderate_count'] as num?)?.toInt() ?? 0,
          'high':     (row['high_count']     as num?)?.toInt() ?? 0,
        },
      );
    }

    return rows.map((r) {
      final dateStr = r['date'] as String;
      final avgMag = (r['avg_tremor_magnitude'] as num?)?.toDouble() ?? 0.0;
      final avgFreq = (r['avg_tremor_frequency'] as num?)?.toDouble() ?? 0.0;
      final level = avgMag < 0.6 ? TremorLevel.low : avgMag < 1.4 ? TremorLevel.moderate : TremorLevel.high;
      return DailyTremorSummary(
        date: _parseLocalDate(dateStr),
        avgMagnitude: avgMag,
        avgFrequencyHz: avgFreq,
        dominantLevel: level,
        tremorLevelCounts: {
          'low':      (r['tremor_low_count']      as num?)?.toInt() ?? 0,
          'moderate': (r['tremor_moderate_count'] as num?)?.toInt() ?? 0,
          'high':     (r['tremor_high_count']     as num?)?.toInt() ?? 0,
        },
        mealBreakdown: breakdowns[dateStr],
      );
    }).toList();
  }

  @override
  Future<List<MealSummary>> getMealsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay   = startOfDay.add(const Duration(days: 1));
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // Use SQL date-range query — filtered by userId to prevent cross-user leakage
    final meals = await _db.getMealsForDateRange(startOfDay, endOfDay,
        userId: userId);

    return meals.map((m) => MealSummary(
      totalBites:     m.totalBites,
      eatingPaceBpm:  m.avgPaceBpm ?? 0.0,
      tremorIndex:    m.tremorIndex ?? 0,
      lastMealStart:  m.startedAt,
      lastMealEnd:    m.endedAt,
      mealType:       (m.mealType == 'Snack' ? 'Snacks' : m.mealType) ?? 'Snacks',
      durationMinutes: m.durationMinutes ?? 0.0,
    )).toList();
  }

  /// Single source of truth for current user ID across all queries.
  /// Falls back to empty string so DB queries return empty (safe) rather than
  /// leaking data from another user.
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Parse a "YYYY-MM-DD" string as LOCAL midnight.
  /// DateTime.parse("YYYY-MM-DD") creates UTC midnight which causes day-off
  /// mismatches when the device timezone is ahead or behind UTC.
  static DateTime _parseLocalDate(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(
      int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}

