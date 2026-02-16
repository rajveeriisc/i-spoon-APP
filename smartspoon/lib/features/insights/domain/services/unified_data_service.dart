import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:smartspoon/core/models/meal.dart';
import 'package:smartspoon/core/services/database_service.dart';
import 'package:smartspoon/core/services/sync_service.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/auth/domain/services/auth_service.dart';
import 'package:smartspoon/features/devices/domain/services/tremor_detection_service.dart';

/// Unified Data Service - Provides data from insights and real-time BLE
class UnifiedDataService with ChangeNotifier {
  InsightsController? insightsController;
  final McuBleService _mcuService;
  final TremorDetectionService _tremorService;
  final MotionAnalysisService _motionService = MotionAnalysisService();

  // Heater Timer
  DateTime? _heaterStartTime;
  Timer? _usageTimer;

  // Temperature Settings
  double _heaterActivationTemp =
      15.0; // Default: turn on heater when food temp drops below 15°C
  double _maxHeaterTemp = 40.0; // Default: max heater temperature 40°C

  UnifiedDataService({
    this.insightsController,
    required McuBleService mcuService,
    required TremorDetectionService tremorService,
  })  : _mcuService = mcuService,
        _tremorService = tremorService {
    
    // Poll BLE data + tremor every 5 seconds for safe UI updates
    _startPeriodicRefresh();

    // Listen to BLE sensor batch stream and forward to motion analysis (for bites)
    // Throttled to 2Hz (every 500ms) to avoid overwhelming the main thread
    // Raw stream fires at 30Hz — processing every packet causes ANR
    DateTime _lastProcessTime = DateTime.now();
    _mcuService.sensorBatchStream.listen((packet) {
      final now = DateTime.now();
      if (now.difference(_lastProcessTime).inMilliseconds >= 500) {
        _lastProcessTime = now;
        _motionService.processPacket(packet);
      }
    });
    // Bite count is read on-demand via the periodic 5-second refresh (no per-bite rebuilds)
  }

  // Periodic refresh timer (every 1 second) — pushes battery/temp/tremor to UI
  Timer? _periodicRefreshTimer;

  void _startPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Collect temp reading during active session
      if (isSessionActive && _mcuService.currentData != null) {
        _addTempReading(_mcuService.currentData!.temperature);
      }
      // Push tremor + BLE data update to UI
      _onTremorUpdate();
    });
  }

  // Real-time data from BLE with fallback to 0/empty (no random data)
  double get foodTempC => _mcuService.currentData?.temperature ?? 0.0;

  // Heater temp is not currently in McuSensorData, assuming 0 until implemented
  double get heaterTempC => 0.0;

  // Heater Status (Local State)
  bool _localHeaterState = false;
  bool get isHeaterOn => _localHeaterState;

  // Temperature Settings Getters
  double get heaterActivationTemp => _heaterActivationTemp;
  double get maxHeaterTemp => _maxHeaterTemp;

  // Heater Usage Duration
  Duration get heaterUsageDuration {
    if (!isHeaterOn || _heaterStartTime == null) return Duration.zero;
    return DateTime.now().difference(_heaterStartTime!);
  }

  // Battery Level
  int get batteryLevel => _mcuService.batteryLevel;

  // Bite Count - Live from Motion Analysis
  int get biteCount => _motionService.currentBiteCount;
  int get totalBites => biteCount; // Alias for compatibility

  // Eating Speed - Live from Motion Analysis (BPM)
  double get eatingSpeedBpm => _motionService.currentEatingSpeedBpm;

  // Average Bite Time (s)
  double get avgBiteTime {
    if (totalBites == 0) return 0.0;
    // We need session duration.
    if (!isSessionActive || _sessionStartTime == null) return 0.0;
    final durationSec = DateTime.now().difference(_sessionStartTime!).inSeconds;
    return durationSec / totalBites;
  }

  // Eating Speed (bites/min) - Legacy getter
  double get eatingSpeed => eatingSpeedBpm;

  // Tremor Index - Uses new TremorDetectionService
  // Map score (log power) or amplitude to 0-3 scale for UI
  // Tremor Index - Uses new TremorDetectionService
  // Map score (log power) or amplitude to 0-3 scale for UI
  // Display Logic: Hold the last positive detection for 3 seconds to avoid UI flickering
  TremorResult _cachedDisplayResult = TremorResult.empty();
  DateTime _lastPositiveDetectionTime = DateTime.fromMillisecondsSinceEpoch(0);

  TremorResult get lastTremorResult {
    final current = _tremorService.lastResult;
    
    if (current.detected) {
      _cachedDisplayResult = current;
      _lastPositiveDetectionTime = DateTime.now();
      return current;
    }
    
    // If undiagnosed (false) but we had a detection within last 3 seconds, show it
    if (DateTime.now().difference(_lastPositiveDetectionTime).inSeconds < 3) {
      return _cachedDisplayResult;
    }
    
    return current;
  }
  
  // Tremor Index - Uses cached result for stability
  // Map score (log power) or amplitude to 0-3 scale for UI
  double get tremorIndex {
    final result = this.lastTremorResult; // Use the stable getter
    if (!result.detected) return 0.0;
    
    // Map amplitude to 0-3 scale
    // 0 = none, 1 = mild, 2 = moderate, 3 = severe
    // Based on empirical data: Strong shake ~ 200-250.
    // Divisor 100.0:
    // Amp 50 (Mild) -> 0.5 (Low)
    // Amp 150 (Moderate) -> 1.5 (Moderate)
    // Amp 250 (Strong) -> 2.5 (High)
    double val = result.amplitude / 100.0;
    if (val > 3.0) val = 3.0;
    return val;
  }

  // Control Methods
  Future<bool> setHeaterState(bool on) async {
    // Local update only - no BLE command
    _localHeaterState = on;

    if (on) {
      _heaterStartTime = DateTime.now();
      _startUsageTimer();
    } else {
      _heaterStartTime = null;
      _stopUsageTimer();
    }
    notifyListeners();

    return true; // Simulate success
  }

  Future<bool> setTemperature(double temp) async {
    // Simulated only for now
    return true;
  }

  /// Set heater activation threshold (0-30°C)
  /// Heater will turn on when food temperature drops below this value
  Future<bool> setHeaterActivationTemp(double temp) async {
    if (temp < 0 || temp > 30) return false;
    _heaterActivationTemp = temp;
    notifyListeners();
    // BLE command removed for stability
    return true;
  }

  /// Set maximum heater temperature (20-60°C)
  Future<bool> setMaxHeaterTemp(double temp) async {
    if (temp < 20 || temp > 60) return false;
    _maxHeaterTemp = temp;
    notifyListeners();
    // BLE command removed for stability
    return true;
  }

  void _stopUsageTimer() {
    _usageTimer?.cancel();
    _usageTimer = null;
  }

  // Session State
  DateTime? _sessionStartTime;
  String? _currentMealUuid;
  final List<Object> _currentSessionBites = [];
  final List<double> _sessionTempReadings = []; // Store raw values for averaging
  
  // Buffer for session tremor data
  final List<TremorResult> _sessionTremorReadings = [];

  bool get isSessionActive => _sessionStartTime != null;

  /// Public method to trigger UI updates
  void notifyUpdate() => notifyListeners();

  // Tremor Update Listener
  DateTime? _lastRecordedTremorTime;

  void _onTremorUpdate() {
    final result = _tremorService.lastResult;
    debugPrint('🔍 Tremor Update: Detected=${result.detected}, Freq=${result.frequency.toStringAsFixed(1)}, Amp=${result.amplitude.toStringAsFixed(3)}, Score=${result.score.toStringAsFixed(1)}');
    notifyListeners();
    
    // Accumulate data if session is active
    if (isSessionActive && _tremorService.lastResult.detected) {
      final result = _tremorService.lastResult;
      // Prevent duplicates (since polling is 5s but analysis is 10s)
      if (_lastRecordedTremorTime == null || 
          result.timestamp.isAfter(_lastRecordedTremorTime!)) {
        _sessionTremorReadings.add(result);
        _lastRecordedTremorTime = result.timestamp;
        debugPrint('📊 Tremor recorded: ${result.toString()}');
      }
    }
  }

  /// Start a new meal session
  Future<void> startSession() async {
    if (isSessionActive) return;

    _sessionStartTime = DateTime.now();
    _currentMealUuid = const Uuid().v4();
    _currentSessionBites.clear();
    _sessionTempReadings.clear();
    _sessionTremorReadings.clear();
    _lastRecordedTremorTime = null; // Reset duplicate check logic

    // Start motion analysis meal session (legacy bite detection)
    _motionService.startMeal();

    notifyListeners();
  }

  /// End current session and save to Database
  Future<void> endSession() async {
    if (!isSessionActive) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(_sessionStartTime!);
    final sessionDurationSeconds = duration.inSeconds;

    // End motion analysis meal session
    _motionService.endMeal();

    // Calculate Average Temperature
    double? avgTemp;
    if (_sessionTempReadings.isNotEmpty) {
      final sum = _sessionTempReadings.reduce((a, b) => a + b);
      avgTemp = sum / _sessionTempReadings.length;
    }

    // Get current user ID
    final userId = await AuthService.getUserId() ?? 'offline_user';

    // Calculate Tremor Index from accumulated results
    int finalTremorIndex = 0;
    if (_sessionTremorReadings.isNotEmpty) {
       // Average the normalized index
       double totalScore = 0;
       for (var r in _sessionTremorReadings) {
         // Map amplitude to 0-3
         double val = (r.amplitude / 5.0) * 3.0;
         if (val > 3.0) val = 3.0;
         totalScore += val;
       }
       finalTremorIndex = (totalScore / _sessionTremorReadings.length).round();
    }

    // Calculate eating speed (bites per minute)
    final eatingSpeed = sessionDurationSeconds > 0
        ? (_motionService.currentBiteCount / sessionDurationSeconds) * 60.0
        : 0.0;

    // Create Meal object
    final meal = Meal(
      uuid: _currentMealUuid!,
      userId: userId, // Uses actual user ID
      startedAt: _sessionStartTime!,
      endedAt: endTime,
      mealType: _getMealTypeByTime(),
      totalBites: _motionService.currentBiteCount,
      avgPaceBpm: eatingSpeed, // Calculate average pace
      tremorIndex: finalTremorIndex,
      durationMinutes: sessionDurationSeconds / 60.0,
      avgFoodTemp: avgTemp,
    );

    // Save to SQLite
    final db = DatabaseService();
    await db.insertMeal(meal);

    // Trigger Sync
    SyncService().syncMeals();

    _sessionStartTime = null;
    _currentMealUuid = null;
    _sessionTempReadings.clear();
    _sessionTremorReadings.clear();
    notifyListeners();
  }



  void _startUsageTimer() {
    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Use debounced notification if high frequency updates are expected elsewhere
      // For seconds timer, it's okay, but let's be safe.
      notifyListeners();
    });
  }

  // Memory Safety: Limit stored temperature readings
  void _addTempReading(double temp) {
    if (temp <= 0) return;
    _sessionTempReadings.add(temp);
    // Keep only last 1000 readings (approx 16 mins at 1Hz) to prevent overflow
    if (_sessionTempReadings.length > 1000) {
      _sessionTempReadings.removeRange(0, _sessionTempReadings.length - 1000);
    }
  }

  // Helper: Determine Meal Type based on time of day
  String _getMealTypeByTime() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'Breakfast';
    if (hour >= 11 && hour < 16) return 'Lunch';
    if (hour >= 16 && hour < 22) return 'Dinner';
    return 'Snack';
  }

  @override
  void dispose() {
    _stopUsageTimer();
    _periodicRefreshTimer?.cancel();
    _motionService.dispose();
    super.dispose();
  }
}
