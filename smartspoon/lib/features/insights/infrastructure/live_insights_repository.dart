import 'dart:async';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/core/services/database_service.dart';
import 'package:smartspoon/core/models/meal.dart';
import 'package:smartspoon/core/services/mock_data_service.dart';

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
    final tremorIndex = _dataService.tremorIndex;
    // Map 0-100 index to TremorLevel
    TremorLevel level;
    if (tremorIndex < 10) {
      level = TremorLevel.low;
    } else if (tremorIndex < 45) {
      level = TremorLevel.moderate;
    } else {
      level = TremorLevel.high;
    }
    
    _tremorCtrl.add(TremorMetrics(
      currentMagnitude: tremorIndex / 20.0, // Rough mapping for display
      peakFrequencyHz: 0.0, // Not calculated yet
      level: level,
    ));

    // 3. Device Health
    _healthCtrl.add(DeviceHealth(
      batteryPercent: _dataService.batteryLevel,
      voltage: 3.7, // Fixed for now
      chargeCycles: 0,
      sensorsHealthy: true,
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
    _initData();
  }
  
  Future<void> _initData() async {
    // Auto-seed mock data for demo purposes if DB is empty
    await MockDataService().seedDatabase(days: 90);
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
    // Determine number of days
    final days = end.difference(start).inDays + 1;
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
    final meals = await _db.getMeals(limit: 500);
    
    // Filter and Group by Date
    final Map<String, List<Meal>> grouped = {};
    
    for (var m in meals) {
      if (m.startedAt.isBefore(start) || m.startedAt.isAfter(end.add(const Duration(days: 1)))) continue;
      
      final key = "${m.startedAt.year}-${m.startedAt.month}-${m.startedAt.day}";
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(m);
    }
    
    final summaries = <DailyBiteSummary>[];
    
    grouped.forEach((key, dayMeals) {
      int totalBites = 0;
      double totalDuration = 0;
      double avgPaceSum = 0;
      
      final Map<String, int> mealBites = {
        'Breakfast': 0, 'Lunch': 0, 'Dinner': 0, 'Snacks': 0
      };
      
      for (var m in dayMeals) {
        totalBites += m.totalBites;
        totalDuration += m.durationMinutes ?? 0;
        avgPaceSum += m.avgPaceBpm ?? 0;
        
        // Categorize if type is missing (simple logic)
        String type = m.mealType ?? 'Snacks';
        if (m.mealType == null) {
          final h = m.startedAt.hour;
          if (h >= 5 && h < 11) type = 'Breakfast';
          else if (h >= 11 && h < 16) type = 'Lunch';
          else if (h >= 16 && h < 22) type = 'Dinner';
        }
        
        mealBites[type] = (mealBites[type] ?? 0) + m.totalBites;
      }
      
      summaries.add(DailyBiteSummary(
        date: dayMeals.first.startedAt, // Approximate date
        totalBites: totalBites,
        avgMealDurationMin: dayMeals.isNotEmpty ? totalDuration / dayMeals.length : 0,
        totalDurationMin: totalDuration,
        avgPaceBpm: dayMeals.isNotEmpty ? avgPaceSum / dayMeals.length : 0,
        mealBites: mealBites,
      ));
    });
    
    return summaries;
  }

  @override
  Future<List<DailyTremorSummary>> getDailyTremorSummaries({
    required DateTime start,
    required DateTime end,
  }) async {
    // Use the new SQL aggregation for accurate bite-level stats
    final stats = await _db.getDailyTremorStats(start: start, end: end);
    
    final summaries = <DailyTremorSummary>[];
    
    for (var row in stats) {
      final dateStr = row['date'] as String;
      final avgFreq = (row['avg_frequency'] as num?)?.toDouble() ?? 0.0;
      final avgMagQuery = (row['avg_magnitude'] as num?)?.toDouble() ?? 0.0;
      final peakMagQuery = (row['peak_magnitude'] as num?)?.toDouble() ?? 0.0;
      
      // Extract tremor level counts
      final lowCount = (row['low_count'] as num?)?.toInt() ?? 0;
      final moderateCount = (row['moderate_count'] as num?)?.toInt() ?? 0;
      final highCount = (row['high_count'] as num?)?.toInt() ?? 0;
      
      final date = DateTime.parse(dateStr);
      
      final level = avgMagQuery < 0.6
          ? TremorLevel.low
          : avgMagQuery < 1.4
              ? TremorLevel.moderate
              : TremorLevel.high;

      summaries.add(DailyTremorSummary(
        date: date,
        avgMagnitude: avgMagQuery,
        peakMagnitude: peakMagQuery,
        avgFrequencyHz: avgFreq,
        dominantLevel: level,
        tremorLevelCounts: {
          'low': lowCount,
          'moderate': moderateCount,
          'high': highCount,
        },
      ));
    }
     
    return summaries;
  }

  @override
  Future<List<MealSummary>> getMealsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    // We reuse getMeals but filter locally for simplicity, or we could add a date range query to DatabaseService
    // Given the scale, fetching recent 100 and filtering is safe enough for MVP
    final allMeals = await _db.getMeals(limit: 100); 
    
    final dayMeals = allMeals.where((m) => 
      m.startedAt.isAfter(startOfDay.subtract(const Duration(seconds: 1))) && 
      m.startedAt.isBefore(endOfDay)
    ).toList();

    return dayMeals.map((m) => MealSummary(
      totalBites: m.totalBites,
      eatingPaceBpm: m.avgPaceBpm ?? 0.0,
      tremorIndex: m.tremorIndex ?? 0,
      lastMealStart: m.startedAt,
      lastMealEnd: m.endedAt,
      mealType: m.mealType ?? 'Snack', // Default to Snack if unknown
      durationMinutes: m.durationMinutes ?? 0.0,
    )).toList();
  }
}

