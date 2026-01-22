import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:smartspoon/core/models/meal.dart';
import 'package:smartspoon/core/services/database_service.dart';
import 'package:smartspoon/core/services/sync_service.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/auth/domain/services/auth_service.dart';

/// Unified Data Service - Provides data from insights and real-time BLE
class UnifiedDataService with ChangeNotifier {
  InsightsController? insightsController;
  final McuBleService _mcuService = McuBleService();
  final MotionAnalysisService _motionService = MotionAnalysisService();

  // Heater Timer
  DateTime? _heaterStartTime;
  Timer? _usageTimer;

  // Temperature Settings
  double _heaterActivationTemp = 15.0; // Default: turn on heater when food temp drops below 15°C
  double _maxHeaterTemp = 40.0; // Default: max heater temperature 40°C

  UnifiedDataService({this.insightsController}) {
    _mcuService.addListener(() {
      notifyListeners();
      // Collect temperature if session is active (sampling logic)
      if (isSessionActive && _mcuService.currentData != null) {
         // Use safe method to add reading
         _addTempReading(_mcuService.currentData!.temperature);
      }
    });

    // Listen to Motion Analysis updates
    _motionService.biteCountStream.listen((count) {
      notifyListeners();
    });
    
    _motionService.tremorIndexStream.listen((index) {
      notifyListeners();
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

  // Total bites - Live from Motion Analysis
  int get totalBites => _motionService.currentBiteCount;

  // Avg bite time - currently not calculated, returning 0
  double get avgBiteTime => 0.0;

  // Eating speed - derived from data or default to 'Unknown'
  String get eatingSpeed => 'Unknown';
  
  // Tremor Index - Live from Motion Analysis
  double get tremorIndex => _motionService.currentTremorIndex;

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

  bool get isSessionActive => _sessionStartTime != null;

  /// Public method to trigger UI updates
  void notifyUpdate() => notifyListeners();

  // ... (Existing getters)

  // ... (Existing implementation)

  /// Start a new meal session
  Future<void> startSession() async {
    if (isSessionActive) return;
    
    _sessionStartTime = DateTime.now();
    _currentMealUuid = const Uuid().v4();
    _currentSessionBites.clear();
    _sessionTempReadings.clear();
    
    // Reset motion service counters
    _motionService.reset();
    
    notifyListeners();
  }

  /// End current session and save to Database
  Future<void> endSession() async {
    if (!isSessionActive) return;
    
    final endTime = DateTime.now();
    final duration = endTime.difference(_sessionStartTime!);
    
    // Calculate Average Temperature
    double? avgTemp;
    if (_sessionTempReadings.isNotEmpty) {
      final sum = _sessionTempReadings.reduce((a, b) => a + b);
      avgTemp = sum / _sessionTempReadings.length;
    }

    // Get current user ID
    final userId = await AuthService.getUserId() ?? 'offline_user';

    // Create Meal object
    final meal = Meal(
      uuid: _currentMealUuid!,
      userId: userId, // Uses actual user ID
      startedAt: _sessionStartTime!,
      endedAt: endTime,
      totalBites: totalBites,
      tremorIndex: tremorIndex.round(),
      durationMinutes: duration.inMinutes.toDouble(),
      avgPaceBpm: avgBiteTime > 0 ? 60 / avgBiteTime : 0,
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
    notifyListeners();
  }

  // Optimize Timer: Debounce notifications to avoid UI jank
  Timer? _debounceTimer;
  void _notifyDebounced() {
    if (_debounceTimer?.isActive ?? false) return;
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      notifyListeners();
    });
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

  // ... (Rest of existing methods)
  
  @override
  void dispose() {
    _stopUsageTimer();
    insightsController?.removeListener(notifyListeners);
    _mcuService.removeListener(notifyListeners);
    _motionService.dispose();
    super.dispose();
  }
}
