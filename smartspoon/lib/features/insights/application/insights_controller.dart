import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/insights_repository.dart';
import '../domain/models.dart';
import '../infrastructure/live_insights_repository.dart';
import '../domain/services/unified_data_service.dart';

class InsightsController with ChangeNotifier {
  final InsightsRepository _repository;
  UnifiedDataService? _unifiedDataService; // Added to blend live data
  Timer? _tremorRefreshTimer;

  InsightsController(this._repository);

  MealSummary? _summary;
  List<BiteEvent> _bites = const [];
  TemperatureStats? _temperature;
  TremorMetrics? _tremor;
  DeviceHealth? _deviceHealth;
  EnvironmentData? _environment;
  TrendData? _trends;
  List<DailyBiteSummary> _dailySummaries = const [];
  List<DailyTremorSummary> _tremorSummaries = const [];

  StreamSubscription? _tempSub;
  StreamSubscription? _tremorSub;
  StreamSubscription? _healthSub;
  StreamSubscription? _envSub;
  StreamSubscription? _authSub;

  MealSummary? get summary => _summary;
  List<BiteEvent> get bites => _bites;
  TemperatureStats? get temperature => _temperature;
  TremorMetrics? get tremor => _tremor;
  DeviceHealth? get deviceHealth => _deviceHealth;
  EnvironmentData? get environment => _environment;
  TrendData? get trends => _trends;

  List<DailyBiteSummary> get dailySummaries {
    // If we have live data, dynamically update or inject today's summary
    if (_unifiedDataService != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final liveBites = _unifiedDataService!.totalBites;

      // Build live meal map
      final liveMealBites = {
        'Breakfast': _unifiedDataService!.breakfastTotalBites,
        'Lunch': _unifiedDataService!.lunchTotalBites,
        'Dinner': _unifiedDataService!.dinnerTotalBites,
        'Snacks': _unifiedDataService!.snackTotalBites,
      };

      // Find today's summary index
      final todayIdx = _dailySummaries.indexWhere((s) => 
        s.date.year == now.year && s.date.month == now.month && s.date.day == now.day);
      
      if (todayIdx != -1) {
        // Update existing today entry with live data.
        // Keep totalBites and mealBites consistent: use whichever source has a
        // higher total so the graph bar and the table rows always match.
        final current = _dailySummaries[todayIdx];
        final updatedList = List<DailyBiteSummary>.from(_dailySummaries);
        final liveMealTotal = liveMealBites.values.fold(0, (a, b) => a + b);
        final useLive = liveMealTotal >= current.totalBites;
        updatedList[todayIdx] = current.copyWith(
          totalBites: useLive ? liveMealTotal : current.totalBites,
          mealBites: useLive ? liveMealBites : current.mealBites,
        );
        return updatedList;
      } else if (liveBites > 0) {
        // No today entry in DB yet — create one from live data
        final liveToday = DailyBiteSummary(
          date: today,
          totalBites: liveBites,
          avgMealDurationMin: 0,
          totalDurationMin: 0,
          avgPaceBpm: _unifiedDataService!.eatingSpeedBpm,
          mealBites: liveMealBites,
        );
        return [..._dailySummaries, liveToday];
      }
    }
    return _dailySummaries;
  }

  List<DailyTremorSummary> get tremorSummaries => _tremorSummaries;

  void setUnifiedDataService(UnifiedDataService service) {
    _unifiedDataService = service;
    _unifiedDataService?.addListener(notifyListeners);
  }

  Future<void> init() async {
    // If the repository supports async initialisation (backfill), await it FIRST
    // so daily_summaries are complete before we read from them in fetchHistory.
    final repo = _repository;
    if (repo is LiveInsightsRepository) {
      await repo.initAsync();
    }
    await fetchHistory(90); // Fetch all 3 months so details pages have data
    _subscribeLive();

    // Re-fetch history once Firebase Auth is fully restored (cold-start race fix).
    // On the initial fetchHistory() above, LiveInsightsRepository._currentUserId may
    // return '' because Firebase hasn't restored the session yet → empty results.
    // This listener fires ~200ms later with the real UID so historical data shows up.
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        debugPrint('[IC] Auth restored (uid=${user.uid}), backfilling + re-fetching history...');
        // Re-run backfill now that we have a real user ID (was skipped on cold-start)
        final repo = _repository;
        if (repo is LiveInsightsRepository) {
          await repo.initAsync();
        }
        await fetchHistory(90);
        _authSub?.cancel(); // Only need to fire once per app launch
      }
    });
    // Refresh tremor summaries every 30 seconds for real-time table updates
    _tremorRefreshTimer?.cancel();
    _tremorRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshTremorSummaries();
    });
  }

  Future<void> _refreshTremorSummaries() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 90));
    _tremorSummaries = await _repository.getDailyTremorSummaries(
      start: start,
      end: now,
    );
    notifyListeners();
  }

  Future<void> fetchHistory(int days) async {
    _summary = await _repository.getLastMealSummary(); // Always latest
    
    final now = DateTime.now();
    
    // For trends/charts (Eating Pattern)
    final historyStart = now.subtract(Duration(days: days));
    
    _dailySummaries = await _repository.getDailyBiteSummaries(
      start: historyStart,
      end: now,
    );
    
    _tremorSummaries = await _repository.getDailyTremorSummaries(
      start: historyStart,
      end: now,
    );
    
    // For granular timeline (Bites)
    // We might want to limit this if range is huge, but for now matching the range
    _bites = await _repository.getBiteEvents(start: historyStart, end: now);
    
    notifyListeners();
  }

  void _subscribeLive() {
    _tempSub = _repository.live.temperature$.listen((t) {
      _temperature = t;
      notifyListeners();
    });
    _tremorSub = _repository.live.tremor$.listen((tr) {
      _tremor = tr;
      notifyListeners();
    });
    _healthSub = _repository.live.deviceHealth$.listen((h) {
      _deviceHealth = h;
      notifyListeners();
    });
    _envSub = _repository.live.environment$.listen((e) {
      _environment = e;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _tremorRefreshTimer?.cancel();
    _tempSub?.cancel();
    _tremorSub?.cancel();
    _healthSub?.cancel();
    _envSub?.cancel();
    _authSub?.cancel();
    _unifiedDataService?.removeListener(notifyListeners);
    super.dispose();
  }
  
  /// Fetch detailed meal records for a specific date (for analysis page)
  Future<List<MealSummary>> getMealsForDate(DateTime date) async {
    return _repository.getMealsForDate(date);
  }

  /// Fetch tremor data for a specific date range (for history page)
  Future<List<DailyTremorSummary>> fetchTremorDataForRange(int days) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    
    final summaries = await _repository.getDailyTremorSummaries(
      start: start,
      end: now,
    );
    
    return summaries;
  }
}
