import 'dart:async';
import 'package:flutter/foundation.dart';
import '../features/ble/application/ble_controller.dart';
import '../features/insights/application/insights_controller.dart';
import '../features/insights/domain/models.dart';

/// Unified Data Service - Bridges BLE data and Insights data
/// Ensures all pages show synchronized, real-time data
class UnifiedDataService with ChangeNotifier {
  final BleController _bleController;
  final InsightsController _insightsController;

  StreamSubscription? _bleSub;
  StreamSubscription? _insightsSub;

  // Unified state
  TemperatureStats? _temperature;
  MealSummary? _mealSummary;
  TremorMetrics? _tremorMetrics;
  List<BiteEvent> _biteEvents = [];

  UnifiedDataService({
    required BleController bleController,
    required InsightsController insightsController,
  })  : _bleController = bleController,
        _insightsController = insightsController {
    _init();
  }

  // Getters for unified data
  TemperatureStats? get temperature => _temperature;
  MealSummary? get mealSummary => _mealSummary;
  TremorMetrics? get tremorMetrics => _tremorMetrics;
  List<BiteEvent> get biteEvents => _biteEvents;

  // Computed getters
  double get foodTempC => _temperature?.foodTempC ?? _bleController.lastPacket?.temperatureC ?? 0;
  double get heaterTempC => _temperature?.heaterTempC ?? 60.0;
  int get totalBites => _mealSummary?.totalBites ?? _biteEvents.length;
  double get eatingPaceBpm => _mealSummary?.eatingPaceBpm ?? 0.0;
  int get tremorIndex => _mealSummary?.tremorIndex ?? 0;
  String get eatingSpeed {
    if (eatingPaceBpm < 2.5) return 'Slow';
    if (eatingPaceBpm < 4.0) return 'Medium';
    return 'Fast';
  }

  double get avgBiteTime {
    if (eatingPaceBpm == 0) return 0;
    return 60.0 / eatingPaceBpm; // Convert bites/min to seconds/bite
  }

  void _init() {
    // Listen to BLE controller changes
    _bleController.addListener(_onBleUpdate);

    // Listen to insights controller changes (for temperature, tremor, etc.)
    _insightsSub = Stream.periodic(const Duration(milliseconds: 500)).listen((_) {
      _syncFromInsights();
    });

    // Initial sync
    _syncFromInsights();
    _onBleUpdate();
  }

  void _onBleUpdate() {
    // Update temperature from BLE if available
    final bleTemp = _bleController.lastPacket?.temperatureC;
    if (bleTemp != null) {
      _temperature = TemperatureStats(
        foodTempC: bleTemp,
        heaterTempC: _temperature?.heaterTempC ?? 60.0,
      );
      notifyListeners();
    }
  }

  void _syncFromInsights() {
    bool hasChanges = false;

    // Sync temperature (prefer BLE, fallback to insights)
    final insightsTemp = _insightsController.temperature;
    if (insightsTemp != null) {
      final bleTemp = _bleController.lastPacket?.temperatureC;
      _temperature = TemperatureStats(
        foodTempC: bleTemp ?? insightsTemp.foodTempC,
        heaterTempC: insightsTemp.heaterTempC,
      );
      hasChanges = true;
    }

    // Sync meal summary
    if (_insightsController.summary != null &&
        _mealSummary != _insightsController.summary) {
      _mealSummary = _insightsController.summary;
      hasChanges = true;
    }

    // Sync tremor metrics
    if (_insightsController.tremor != null &&
        _tremorMetrics != _insightsController.tremor) {
      _tremorMetrics = _insightsController.tremor;
      hasChanges = true;
    }

    // Sync bite events (including empty state)
    if (_biteEvents != _insightsController.bites) {
      _biteEvents = _insightsController.bites;
      hasChanges = true;
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  /// Force sync all data
  void forceSync() {
    _syncFromInsights();
    _onBleUpdate();
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _insightsSub?.cancel();
    _bleController.removeListener(_onBleUpdate);
    super.dispose();
  }
}

