import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/insights_repository.dart';
import '../domain/models.dart';

class InsightsController with ChangeNotifier {
  final InsightsRepository _repository;

  InsightsController(this._repository);

  MealSummary? _summary;
  List<BiteEvent> _bites = const [];
  TemperatureStats? _temperature;
  TremorMetrics? _tremor;
  DeviceHealth? _deviceHealth;
  EnvironmentData? _environment;
  TrendData? _trends;

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

  Future<void> init() async {
    await _loadStaticData();
    _subscribeLive();
  }

  Future<void> _loadStaticData() async {
    _summary = await _repository.getLastMealSummary();
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    _bites = await _repository.getBiteEvents(start: start, end: now);
    _trends = await _repository.getTrends(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
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
    super.dispose();
  }
}
