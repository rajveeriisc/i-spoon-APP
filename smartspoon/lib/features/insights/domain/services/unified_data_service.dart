import 'dart:async';
import 'dart:math' as dart_math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:smartspoon/core/models/meal.dart';
import 'package:smartspoon/core/models/bite.dart';
import 'package:smartspoon/core/services/database_service.dart';
import 'package:smartspoon/core/services/sync_service.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/auth/domain/services/auth_service.dart';
import 'package:smartspoon/features/devices/domain/services/tremor_detection_service.dart';
import 'package:smartspoon/features/devices/domain/services/smart_spoon_ble_service.dart'
    show kBgBiteCount, kBgAvgAccel, kBgUpdatedAt, kBgBattery, kBgTemperature;
import 'package:shared_preferences/shared_preferences.dart';

/// Unified Data Service - Provides data from insights and real-time BLE
class UnifiedDataService extends ChangeNotifier with WidgetsBindingObserver {
  InsightsController? insightsController;
  final McuBleService _mcuService;
  final TremorDetectionService _tremorService;
  final MotionAnalysisService _motionService = MotionAnalysisService();

  // Heater Timer
  DateTime? _heaterStartTime;
  Timer? _usageTimer;

  // Rolling bite timestamps for stable speed calculation (3-min window)
  final List<DateTime> _biteTimestamps = [];
  double _smoothedSpeedBpm = 0.0;

  // Background BLE data (written by isolate, polled every 10s)
  Timer? _bgPollTimer;
  int _bgBiteCount = 0;
  double _bgAvgAccel = 0;
  int _bgBattery = 0;
  double _bgTemperature = 0;
  DateTime? _bgLastUpdate;

  /// True when we're receiving data from the background isolate
  bool get isReceivingBgData =>
      _bgLastUpdate != null &&
      DateTime.now().difference(_bgLastUpdate!).inSeconds < 30;
  int get bgBiteCount => _bgBiteCount;
  double get bgAvgAccel => _bgAvgAccel;
  int get bgBattery => _bgBattery;
  double get bgTemperature => _bgTemperature;
  DateTime? get bgLastUpdate => _bgLastUpdate;

  double _targetHeaterTemp = 40.0; // Default: target heater temperature 40°C

  // Goals (Persisted in SharedPreferences)
  double _breakfastGoal = 12.5;
  double _lunchGoal = 12.5;
  double _dinnerGoal = 12.5;
  double _snackGoal = 12.5;

  double get breakfastGoal => _breakfastGoal;
  double get lunchGoal => _lunchGoal;
  double get dinnerGoal => _dinnerGoal;
  double get snackGoal => _snackGoal;
  int get dailyBiteGoal => (_breakfastGoal + _lunchGoal + _dinnerGoal + _snackGoal).toInt();
  
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _breakfastGoal = prefs.getDouble('breakfastGoal') ?? 12.5;
    _lunchGoal = prefs.getDouble('lunchGoal') ?? 12.5;
    _dinnerGoal = prefs.getDouble('dinnerGoal') ?? 12.5;
    _snackGoal = prefs.getDouble('snackGoal') ?? 12.5;
    notifyListeners();
  }

  Future<void> setDailyGoals(double breakfast, double lunch, double dinner, double snack) async {
    _breakfastGoal = breakfast;
    _lunchGoal = lunch;
    _dinnerGoal = dinner;
    _snackGoal = snack;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('breakfastGoal', breakfast);
    await prefs.setDouble('lunchGoal', lunch);
    await prefs.setDouble('dinnerGoal', dinner);
    await prefs.setDouble('snackGoal', snack);
    notifyListeners();
  }


  // App cycle management
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (isSessionActive) {
        debugPrint('📱 App backgrounded/killed. Auto-saving meal session to prevent data loss...');
        // endSession() is async — on app kill the process may freeze before awaits complete.
        // The meal row is already upserted after every bite (in _onTremorUpdate), so
        // bite data is safe. We still call endSession() to update final stats if there's time.
        endSession().catchError((e) => debugPrint('[UDS] endSession on background error: $e'));
      }
    }
  }

  UnifiedDataService({
    this.insightsController,
    required McuBleService mcuService,
    required TremorDetectionService tremorService,
  })  : _mcuService = mcuService,
        _tremorService = tremorService {
    
    // Register lifecycle observer to prevent ghost sessions on app kill
    WidgetsBinding.instance.addObserver(this);
    
    // Poll BLE data + tremor every 5 seconds for safe UI updates
    _startPeriodicRefresh();

    // Direct listen to MCU service for ultra-fast UI updates
    _mcuService.addListener(_onMcuUpdate);

    // Listen to TremorDetectionService so UI updates immediately when a
    // tremor result arrives — without waiting for a hardware bite event.
    _tremorService.addListener(_onTremorServiceUpdate);

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

    // Poll background isolate results every 10s
    _bgPollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollBgData());

    // Load today's aggregated data from SQLite on startup
    _loadTodaySnapshot();
    _loadPrefs(); // Load saved goals

    // Re-load snapshot once Firebase Auth session is restored (cold-start race fix).
    // On first call above, currentUser is null → userId = 'demo_user' → 0 rows returned.
    // This listener fires ~200ms later with the real UID so the actual data shows up.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        debugPrint('[UDS] Auth restored (uid=${user.uid}), reloading today snapshot...');
        _loadTodaySnapshot();
      }
    });
  }

  void _onMcuUpdate() {
    // We intentionally DO NOT auto-end the meal session on disconnect here anymore.
    // This allows the user to transiently disconnect/reconnect and have new bites
    // seamlessly continue attaching to the exact same Meal record.
    notifyListeners();
  }

  void _onTremorServiceUpdate() {
    // TremorDetectionService produced a new result — push it to UI immediately.
    notifyListeners();
  }

  /// Poll SharedPreferences for data written by the background BLE isolate.
  /// Runs every 10s. Only meaningful when the foreground BLE is not connected.
  Future<void> _pollBgData() async {
    // Skip if foreground BLE is delivering live data
    if (_mcuService.isConnected) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final updatedAt = prefs.getInt(kBgUpdatedAt);
      if (updatedAt == null) return;

      final updated = DateTime.fromMillisecondsSinceEpoch(updatedAt);
      // Ignore stale data older than 60s
      if (DateTime.now().difference(updated).inSeconds > 60) return;
      // Only process if newer than last poll
      if (_bgLastUpdate != null && !updated.isAfter(_bgLastUpdate!)) return;

      _bgBiteCount   = prefs.getInt(kBgBiteCount)       ?? _bgBiteCount;
      _bgAvgAccel    = prefs.getDouble(kBgAvgAccel)     ?? _bgAvgAccel;
      _bgBattery     = prefs.getInt(kBgBattery)         ?? _bgBattery;
      _bgTemperature = prefs.getDouble(kBgTemperature)  ?? _bgTemperature;
      _bgLastUpdate  = updated;

      debugPrint('[UDS] BG data polled: bites=$_bgBiteCount avgAccel=${_bgAvgAccel.toStringAsFixed(3)} temp=${_bgTemperature.toStringAsFixed(1)}°C');

      // If a session is active, merge background bite count
      if (isSessionActive && _bgBiteCount > _lastHardwareBiteCount) {
        _lastHardwareBiteCount = _bgBiteCount;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[UDS] BG poll error: $e');
    }
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

  // ─── TODAY'S SNAPSHOT ────────────────────────────────────────────────────────
  // Loaded from daily_summaries on startup and after each session ends.
  // Used as fallback when no BLE session is active.

  int    _todayBites       = 0;
  int    _todayBreakfastBites = 0;
  int    _todayLunchBites     = 0;
  int    _todayDinnerBites    = 0;
  int    _todaySnackBites     = 0;
  double _todayEatingMin   = 0;
  double _todayAvgTemp     = 0;
  int    _todayTremorBites = 0; // tremor_low_count + moderate + high combined
  int    _todayTremorHigh  = 0;

  /// Public callable — refreshes today's data snapshot from the DB.
  void refreshTodaySnapshot() => _loadTodaySnapshot();

  Future<void> _loadTodaySnapshot() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo_user';
      final today  = DateTime.now();
      final db     = DatabaseService();
      final rows   = await db.getDailySummaries(
        userId: userId,
        start:  DateTime(today.year, today.month, today.day),
        end:    today,
      );
      if (rows.isNotEmpty) {
        final r = rows.first;
        _todayBites       = (r['total_bites']       as num?)?.toInt()    ?? 0;
        _todayBreakfastBites = (r['breakfast_bites'] as num?)?.toInt() ?? 0;
        _todayLunchBites     = (r['lunch_bites']     as num?)?.toInt() ?? 0;
        _todayDinnerBites    = (r['dinner_bites']    as num?)?.toInt() ?? 0;
        _todaySnackBites     = (r['snack_bites']     as num?)?.toInt() ?? 0;
        _todayEatingMin   = (r['total_eating_min']  as num?)?.toDouble() ?? 0;
        _todayAvgTemp     = (r['avg_food_temp_c']   as num?)?.toDouble() ?? 0;
        _todayTremorBites = ((r['tremor_low_count'] as num?)?.toInt() ?? 0) +
                            ((r['tremor_moderate_count'] as num?)?.toInt() ?? 0) +
                            ((r['tremor_high_count'] as num?)?.toInt() ?? 0);
        _todayTremorHigh  = (r['tremor_high_count'] as num?)?.toInt() ?? 0;
        notifyListeners();
        debugPrint('[UDS] Today snapshot: $_todayBites bites, ${_todayEatingMin.toStringAsFixed(1)} min, ${_todayAvgTemp.toStringAsFixed(1)}°C avg temp');
      }
    } catch (e) {
      debugPrint('[UDS] Could not load today snapshot: $e');
    }
  }

  // Getters that combine live session data + today's DB snapshot
  // When a session IS active  → shows live session value (prefer hardware bite count over software)
  // When no session is active → shows today's total from daily_summaries
  int get totalBites {
    if (isSessionActive && _mcuService.hardwareBiteCount == 0) {
      return _todayBites + _motionService.currentBiteCount;
    }
    return _todayBites + _uncommittedBites; // Database total + any pending hardware bites
  }

  // Getters for specific meal types combining DB and live session
  int _getLiveBitesForMeal(String mealType) {
    int liveBites = _uncommittedBites;

    // Fallback: check if session is active with software bite detection ONLY
    if (isSessionActive && _currentMealUuid != null && _mcuService.hardwareBiteCount == 0) {
      liveBites = _motionService.currentBiteCount;
    }

    // Only add these live unsaved bites to the meal type if it corresponds to right now
    final currentMeal = _getMealTypeByTime();
    if (currentMeal == mealType) {
      return liveBites;
    }
    return 0;
  }

  int get breakfastTotalBites => _todayBreakfastBites + _getLiveBitesForMeal('Breakfast');
  int get lunchTotalBites     => _todayLunchBites     + _getLiveBitesForMeal('Lunch');
  int get snackTotalBites     => _todaySnackBites     + _getLiveBitesForMeal('Snack');
  int get dinnerTotalBites    => _todayDinnerBites    + _getLiveBitesForMeal('Dinner');
  
  int get biteCount => totalBites;

  int get currentStreak {
    if (insightsController == null || insightsController!.dailySummaries.isEmpty) return 0;
    
    // Sort descending by date
    final summaries = List<DailyBiteSummary>.from(insightsController!.dailySummaries)
      ..sort((a, b) => b.date.compareTo(a.date));
      
    int streak = 0;
    DateTime expectedDate = DateTime.now();
    bool foundToday = false;

    // Check if they have bites today:
    if (totalBites > 0) {
      streak = 1;
      expectedDate = expectedDate.subtract(const Duration(days: 1));
      foundToday = true;
    }

    for (var summary in summaries) {
      // Ignore today if we already counted it above OR if it's 0 (maybe not synced yet)
      if (summary.date.year == DateTime.now().year && summary.date.month == DateTime.now().month && summary.date.day == DateTime.now().day) {
        if (!foundToday && summary.totalBites > 0) {
           streak = 1;
           expectedDate = expectedDate.subtract(const Duration(days: 1));
           foundToday = true;
        }
        continue;
      }

      if (summary.date.year == expectedDate.year && 
          summary.date.month == expectedDate.month && 
          summary.date.day == expectedDate.day) {
        if (summary.totalBites > 0) {
          streak++;
          expectedDate = expectedDate.subtract(const Duration(days: 1));
        } else {
          break; // streak broke
        }
      } else if (summary.date.isBefore(expectedDate)) {
        break; // streak broke (missed a day)
      }
    }

    return streak;
  }

  double get avgBiteTime {
    if (isSessionActive) {
      final count = totalBites;
      if (count == 0 || _sessionStartTime == null) return 0.0;
      return DateTime.now().difference(_sessionStartTime!).inSeconds / count;
    }
    // When no session: show avg seconds per bite based on today's history
    if (_todayBites == 0 || _todayEatingMin == 0) return 0.0;
    return (_todayEatingMin * 60) / _todayBites;
  }

  // Real-time data from BLE with fallback to today's avg from DB
  double get foodTempC {
    final live = _mcuService.currentData?.temperature ?? 0.0;
    if (live > 0) return live;
    return _todayAvgTemp; // fallback: today's average food temperature
  }

  // Heater temp — not yet exposed via BLE; returns 0 until implemented
  double get heaterTempC => 0.0;

  // Heater Status (Local State)
  bool _localHeaterState = false;
  bool get isHeaterOn => _localHeaterState;

  // Temperature Settings Getters
  double get targetHeaterTemp => _targetHeaterTemp;
  double get maxHeaterTemp => _targetHeaterTemp; // Keeping for backward compatibility or rename everywhere

  // Heater Usage Duration
  Duration get heaterUsageDuration {
    if (!isHeaterOn || _heaterStartTime == null) return Duration.zero;
    return DateTime.now().difference(_heaterStartTime!);
  }

  // Battery Level — live from BLE
  int get batteryLevel => _mcuService.batteryLevel;

  // Eating Speed — rolling 3-min window, exponentially smoothed
  double get eatingSpeedBpm => _smoothedSpeedBpm;
  double get eatingSpeed => _smoothedSpeedBpm;

  /// Recomputes speed from a 3-minute sliding window of bite timestamps,
  /// then applies exponential smoothing (α=0.3) to prevent jumpy values.
  void _updateSmoothedSpeed() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 3));
    _biteTimestamps.removeWhere((t) => t.isBefore(cutoff));

    double raw = 0.0;
    if (_biteTimestamps.length >= 2) {
      // Window duration in minutes from oldest to now
      final windowMin = DateTime.now()
              .difference(_biteTimestamps.first)
              .inSeconds /
          60.0;
      if (windowMin > 0) raw = _biteTimestamps.length / windowMin;
    } else if (_biteTimestamps.length == 1 && _sessionStartTime != null) {
      // Only one bite so far — use time since session start
      final elapsedMin =
          DateTime.now().difference(_sessionStartTime!).inSeconds / 60.0;
      if (elapsedMin > 0) raw = 1.0 / elapsedMin;
    }

    // Exponential smoothing: new = α×raw + (1−α)×old  (α=0.3 → slow response)
    _smoothedSpeedBpm = _smoothedSpeedBpm == 0.0
        ? raw
        : 0.3 * raw + 0.7 * _smoothedSpeedBpm;
  }


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

    // Primary: use log-power score mapped to 0–3 scale.
    // score = ln(P + 1e-6); typical range: -14 (noise) to +2 (strong tremor)
    // Map [-10, 2] → [0, 3]
    double scoreVal = ((result.score + 10.0) / 12.0 * 3.0).clamp(0.0, 3.0);

    // Secondary: amplitude-based (cm or deg) — use as floor so it doesn't hide real tremor
    double ampVal = (result.amplitude / 80.0).clamp(0.0, 3.0);

    // Return whichever is higher (most sensitive)
    return scoreVal > ampVal ? scoreVal : ampVal;
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

  /// Set target heater temperature (20-60°C)
  Future<bool> setMaxHeaterTemp(double temp) async {
    if (temp < 20 || temp > 60) return false;
    _targetHeaterTemp = temp;
    notifyListeners();
    // BLE command handled by UI
    return true;
  }

  void _stopUsageTimer() {
    _usageTimer?.cancel();
    _usageTimer = null;
  }

  // Session State
  DateTime? _sessionStartTime;
  String? _currentMealUuid;
  bool _isEndingSession = false; // Guard against concurrent endSession() calls
  final List<double> _sessionTempReadings = []; // Store raw values for averaging

  // Per-bite tracking: last hardware bite_count we saw; used to detect new bites
  int _lastHardwareBiteCount = 0;

  bool get isSessionActive => _sessionStartTime != null;
  /// Returns the current meal type based on time of day:
  /// - When session is active, or
  /// - When hardware bite data is flowing from the device
  String? get currentMealType {
    if (isSessionActive || _mcuService.hardwareBiteCount > 0) {
      return _getMealTypeByTime();
    }
    return null;
  }

  /// Public method to trigger UI updates
  void notifyUpdate() => notifyListeners();

  bool _hwBiteInitialized = false;
  int _uncommittedBites = 0; // Buffer for instant UI feedback while async DB write happens

  void _onTremorUpdate() {
    notifyListeners();

    final currentHwCount = _mcuService.hardwareBiteCount;

    // === STEP 1: Baseline (first time we see hardware data) ===
    // The Arduino counter is absolute and never resets (starts at 0 on power toggle).
    // We record this as the baseline so we only count NEW bites from this session.
    if (!_hwBiteInitialized) {
      _lastHardwareBiteCount = currentHwCount;
      _hwBiteInitialized = true;
      debugPrint('🔑 Baselined hardware bite count at $currentHwCount (ignoring historical bites).');
      return;
    }

    // === STEP 2: Detect new bites since last check ===
    if (currentHwCount <= _lastHardwareBiteCount) {
      return; // No new bites — tremor stats computed from bites table in DB, no in-memory accumulation needed
    }

    final newBites = currentHwCount - _lastHardwareBiteCount;

    // === STEP 3: Auto-start session if needed (same tick, don't return) ===
    // Guard: don't start a new session while endSession() is running its DB ops.
    // Without this, the 1s timer fires mid-endSession (after _sessionStartTime=null),
    // sees !isSessionActive, and creates a duplicate meal record.
    if (!isSessionActive && !_isEndingSession) {
      _sessionStartTime = DateTime.now();
      _currentMealUuid = const Uuid().v4();
      _sessionTempReadings.clear();
      _biteTimestamps.clear();
      _smoothedSpeedBpm = 0.0;
      _motionService.startMeal();
      debugPrint('🍽️ Auto-started meal session (${_getMealTypeByTime()}).');
    }

    // === STEP 4: Record bite delta ===
    final now = DateTime.now();
    final tremorResult = _tremorService.lastResult;

    // Immediately show in UI via buffer
    _uncommittedBites += newBites;
    _lastHardwareBiteCount = currentHwCount;

    // Capture session state synchronously before any async gap.
    // endSession() may run concurrently and null out _sessionStartTime/_currentMealUuid.
    final mealUuid = _currentMealUuid!;
    final sessionStart = _sessionStartTime!; // safe: we just confirmed isSessionActive above
    final capturedMealType = _getMealTypeByTime();
    // Use Firebase UID synchronously — same source as endSession() fallback
    final capturedUserId = FirebaseAuth.instance.currentUser?.uid ?? 'offline_user';

    // Record timestamps for rolling speed calculation
    for (int i = 0; i < newBites; i++) {
      _biteTimestamps.add(now.subtract(Duration(seconds: newBites - 1 - i)));
    }
    _updateSmoothedSpeed();

    final bites = List.generate(newBites, (i) {
      return Bite(
        mealUuid: mealUuid,
        timestamp: now.subtract(Duration(seconds: newBites - 1 - i)),
        sequenceNumber: _lastHardwareBiteCount - newBites + i + 1,
        foodTempC: _mcuService.temperature > 0 ? _mcuService.temperature : null,
        tremorMagnitude: tremorResult.detected ? tremorResult.amplitude : null,
        tremorFrequency: tremorResult.detected ? tremorResult.frequency : null,
        isValid: true,
        isSynced: false,
      );
    });

    DatabaseService().insertBites(bites).then((_) async {
      debugPrint('[UDS] ✅ Saved $newBites new bite(s). Total HW count: $currentHwCount');
      _uncommittedBites = (_uncommittedBites - newBites).clamp(0, 9999);

      // Single DB query: count + tremor averages + temp — all computed from bites table.
      // This is the source of truth. No in-memory accumulation needed.
      final stats = await DatabaseService().getMealStats(mealUuid);
      final count = (stats['total_bites'] as num?)?.toInt() ?? 0;

      // Update per-meal buckets for live UI display
      if (capturedMealType == 'Breakfast') _todayBreakfastBites = count;
      else if (capturedMealType == 'Lunch') _todayLunchBites = count;
      else if (capturedMealType == 'Snack') _todaySnackBites = count;
      else _todayDinnerBites = count;
      _todayBites = _todayBreakfastBites + _todayLunchBites + _todaySnackBites + _todayDinnerBites;

      // Compute tremor index from DB-averaged magnitude (0-3 scale, same as endSession).
      // Amplitude is stored in g (0.0–~2.0). Use sqrt scaling so moderate tremors
      // (amp ~0.1–0.3g) map to index 1–2 rather than being floored to 0.
      // Reference: amp=0.05→idx≈1, amp=0.15→idx≈1, amp=0.5→idx≈2, amp=1.0+→idx=3
      final avgMag = (stats['avg_tremor_magnitude'] as num?)?.toDouble() ?? 0.0;
      final tremorIdx = avgMag > 0.02
          ? (dart_math.sqrt(avgMag / 1.0) * 3.0).clamp(0.0, 3.0).round()
          : 0;
      final avgFoodTemp = (stats['avg_food_temp'] as num?)?.toDouble() ?? 0.0;

      // Upsert the meal row with current cumulative stats — survives app kill.
      // endSession() will overwrite with identical formula + final duration/temp.
      final inProgressMeal = Meal(
        uuid: mealUuid,
        userId: capturedUserId,
        startedAt: sessionStart,
        mealType: capturedMealType,
        totalBites: count,
        tremorIndex: tremorIdx,
        avgFoodTemp: avgFoodTemp > 0 ? avgFoodTemp : null,
      );
      await DatabaseService().insertMeal(inProgressMeal);
      debugPrint('[UDS] 💾 Meal upserted: $count bites, tremor=$tremorIdx, avgMag=${avgMag.toStringAsFixed(3)}');

      notifyListeners();
    }).catchError((e) {
      debugPrint('[UDS] ❌ Error saving bites: $e');
    });
  }

  /// Start a new meal session
  Future<void> startSession() async {
    if (isSessionActive) return;

    _sessionStartTime = DateTime.now();
    _currentMealUuid = const Uuid().v4();
    _sessionTempReadings.clear();
    _biteTimestamps.clear();
    _smoothedSpeedBpm = 0.0;
    _lastHardwareBiteCount = _mcuService.hardwareBiteCount; // Sync to current MCU count so we only track new bites

    // Start motion analysis meal session (legacy bite detection)
    _motionService.startMeal();

    notifyListeners();
  }

  /// End current session and save to Database
  Future<void> endSession() async {
    // Guard: prevent concurrent calls (background kill + user tap simultaneously)
    if (!isSessionActive || _isEndingSession) return;
    _isEndingSession = true;

    // Capture session state synchronously FIRST before any awaits.
    // This also prevents _onTremorUpdate from starting new bites on this session.
    final endTime = DateTime.now();
    final capturedStartTime = _sessionStartTime!;
    final capturedMealUuid = _currentMealUuid!;
    final capturedMealType = _getMealTypeByTime();
    final sessionDurationSeconds = endTime.difference(capturedStartTime).inSeconds;

    // Clear session immediately so _onTremorUpdate stops adding bites to this session
    _sessionStartTime = null;
    _currentMealUuid = null;
    _uncommittedBites = 0; // Reset buffer — final count comes from DB
    _biteTimestamps.clear();
    _smoothedSpeedBpm = 0.0;

    // End motion analysis meal session
    _motionService.endMeal();

    try {
      // Get user ID — Firebase UID first, JWT fallback
      final userId = FirebaseAuth.instance.currentUser?.uid
          ?? await AuthService.getUserId()
          ?? 'offline_user';

      // Single source of truth: compute ALL stats from the bites table.
      // This is identical to the formula used in the in-progress upserts above,
      // ensuring the final meal record is consistent with what was shown live.
      final stats = await DatabaseService().getMealStats(capturedMealUuid);
      final dbBiteCount = (stats['total_bites'] as num?)?.toInt() ?? 0;
      final avgMag      = (stats['avg_tremor_magnitude'] as num?)?.toDouble() ?? 0.0;
      final avgFoodTemp = (stats['avg_food_temp'] as num?)?.toDouble() ?? 0.0;

      // Tremor index: AVG magnitude mapped to 0-3 scale.
      // Same formula as in-progress upsert so live and stored values always match.
      final finalTremorIndex = avgMag > 0.02
          ? (dart_math.sqrt(avgMag / 1.0) * 3.0).clamp(0.0, 3.0).round()
          : 0;

      // Eating speed from DB count + actual elapsed time
      final eatingSpeed = (sessionDurationSeconds > 0 && dbBiteCount > 0)
          ? (dbBiteCount / sessionDurationSeconds) * 60.0
          : 0.0;

      // Final meal record — overwrites in-progress upsert with complete stats
      final meal = Meal(
        uuid: capturedMealUuid,
        userId: userId,
        startedAt: capturedStartTime,
        endedAt: endTime,
        mealType: capturedMealType,
        totalBites: dbBiteCount,
        avgPaceBpm: eatingSpeed,
        tremorIndex: finalTremorIndex,
        durationMinutes: sessionDurationSeconds / 60.0,
        avgFoodTemp: avgFoodTemp > 0 ? avgFoodTemp : null,
      );

      final db = DatabaseService();
      await db.insertMeal(meal);

      // Rebuild daily_summaries for correct date (handles midnight-crossing sessions)
      await db.rebuildDailySummary(userId, capturedStartTime);

      // Reload snapshot so UI shows updated totals immediately
      await _loadTodaySnapshot();

      // Trigger background sync to server
      SyncService().syncMeals();

      debugPrint('[UDS] ✅ Session ended: $dbBiteCount bites, ${sessionDurationSeconds}s, user=$userId');
    } finally {
      // Always clean up session state and reset baseline, even if an error occurred
      _sessionTempReadings.clear();
      _lastHardwareBiteCount = _mcuService.hardwareBiteCount;
      _isEndingSession = false;
      notifyListeners();
    }
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
    if (hour < 11) return 'Breakfast';
    if (hour >= 11 && hour < 15) return 'Lunch';
    if (hour >= 15 && hour < 18) return 'Snack';
    return 'Dinner';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mcuService.removeListener(_onMcuUpdate);
    _tremorService.removeListener(_onTremorServiceUpdate);
    _stopUsageTimer();
    _periodicRefreshTimer?.cancel();
    _bgPollTimer?.cancel();
    _motionService.dispose();
    super.dispose();
  }
}
