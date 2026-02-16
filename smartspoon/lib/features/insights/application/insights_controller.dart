import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/insights_repository.dart';
import '../domain/models.dart';

class InsightsController with ChangeNotifier {
  final InsightsRepository _repository;
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

  MealSummary? get summary => _summary;
  List<BiteEvent> get bites => _bites;
  TemperatureStats? get temperature => _temperature;
  TremorMetrics? get tremor => _tremor;
  DeviceHealth? get deviceHealth => _deviceHealth;
  EnvironmentData? get environment => _environment;
  TrendData? get trends => _trends;
  List<DailyBiteSummary> get dailySummaries => _dailySummaries;
  List<DailyTremorSummary> get tremorSummaries => _tremorSummaries;

  Future<void> init() async {
    await fetchHistory(90); // Fetch all 3 months so details pages have data
    _subscribeLive();
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
    // Dispose mock repository if available (no-op for others)
    try {
      // ignore: avoid_dynamic_calls
      (_repository as dynamic).dispose();
      // ignore: empty_catches
    } catch (_) {}
  // ... existing methods ...
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
