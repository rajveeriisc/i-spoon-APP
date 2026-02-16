import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:smartspoon/features/devices/index.dart';

/// Tremor features extracted from a packet of IMU data
class TremorFeatures {
  final double variance;
  final double rms;
  final DateTime timestamp;

  TremorFeatures({
    required this.variance,
    required this.rms,
    required this.timestamp,
  });
}

/// Meal session data
class MealSession {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  int biteCount;
  final List<TremorFeatures> tremorFeatures;

  MealSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.biteCount = 0,
    List<TremorFeatures>? tremorFeatures,
  }) : tremorFeatures = tremorFeatures ?? [];

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  /// Calculate final tremor index from accumulated features
  Map<String, double> calculateTremorIndex() {
    if (tremorFeatures.isEmpty) {
      return {'avg': 0.0, 'max': 0.0};
    }

    double avgVariance = tremorFeatures.map((f) => f.variance).reduce((a, b) => a + b) / tremorFeatures.length;
    double maxVariance = tremorFeatures.map((f) => f.variance).reduce(max);
    double avgRms = tremorFeatures.map((f) => f.rms).reduce((a, b) => a + b) / tremorFeatures.length;
    double maxRms = tremorFeatures.map((f) => f.rms).reduce(max);

    // Normalize to 0-3 scale (these thresholds may need tuning based on real data)
    // Higher variance/RMS = more tremor
    double avgTremorIndex = _normalizeTremorValue(avgVariance * 0.6 + avgRms * 0.4);
    double maxTremorIndex = _normalizeTremorValue(maxVariance * 0.6 + maxRms * 0.4);

    return {
      'avg': avgTremorIndex,
      'max': maxTremorIndex,
    };
  }

  /// Normalize tremor value to 0-3 scale
  double _normalizeTremorValue(double value) {
    // Adjust these thresholds based on real-world data
    const double minThreshold = 0.0;
    const double maxThreshold = 100.0;

    double normalized = ((value - minThreshold) / (maxThreshold - minThreshold)) * 3.0;
    return normalized.clamp(0.0, 3.0);
  }

  /// Get rolling average tremor for last N packets (for interim display)
  double getRollingTremorAverage({int lastNPackets = 5}) {
    if (tremorFeatures.isEmpty) return 0.0;

    final recentFeatures = tremorFeatures.length > lastNPackets
        ? tremorFeatures.sublist(tremorFeatures.length - lastNPackets)
        : tremorFeatures;

    double avgVariance = recentFeatures.map((f) => f.variance).reduce((a, b) => a + b) / recentFeatures.length;
    double avgRms = recentFeatures.map((f) => f.rms).reduce((a, b) => a + b) / recentFeatures.length;

    return _normalizeTremorValue(avgVariance * 0.6 + avgRms * 0.4);
  }

  Map<String, dynamic> toJson() {
    final tremorIndex = calculateTremorIndex();
    return {
      'meal_id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_minutes': duration.inMinutes,
      'bite_count': biteCount,
      'avg_tremor_index': tremorIndex['avg'],
      'max_tremor_index': tremorIndex['max'],
    };
  }
}

/// Service responsible for analyzing raw IMU data to detect bites and measure tremor.
/// 
/// Implementation follows the PRD specification:
/// - Bite Detection: Threshold-based detection using acceleration and gyroscope peaks
/// - Tremor Analysis: Feature extraction per packet, aggregation over meal
/// - Packet-based processing: Handles 20-sample packets at 25Hz (~0.8 seconds)
class MotionAnalysisService {
  static final MotionAnalysisService _instance = MotionAnalysisService._internal();
  factory MotionAnalysisService() => _instance;
  MotionAnalysisService._internal();

  // Configuration - Based on PRD

  static const Duration mealTimeout = Duration(minutes: 5); // Auto-end meal after 5 min of no motion

  // Bite Detection State (Disabled)
  DateTime? _lastBiteTime;
  
  // Meal Session
  MealSession? _currentMeal;
  Timer? _mealTimeoutTimer;

  // Streams
  final _biteCountController = StreamController<int>.broadcast();
  final _tremorIndexController = StreamController<double>.broadcast();
  final _mealSessionController = StreamController<MealSession?>.broadcast();
  

  Stream<int> get biteCountStream => _biteCountController.stream;
  Stream<double> get tremorIndexStream => _tremorIndexController.stream;
  Stream<MealSession?> get mealSessionStream => _mealSessionController.stream;

  // Current Metrics
  int get currentBiteCount => _currentMeal?.biteCount ?? 0;
  
  double get currentEatingSpeedBpm {
    final meal = _currentMeal;
    if (meal == null) return 0.0;
    
    // Use duration so far
    final durationMin = DateTime.now().difference(meal.startTime).inSeconds / 60.0;
    if (durationMin <= 0) return 0.0;
    
    return meal.biteCount / durationMin;
  }

  double get currentTremorIndex => _currentMeal?.getRollingTremorAverage() ?? 0.0;
  MealSession? get currentMeal => _currentMeal;
  bool get isMealActive => _currentMeal != null && _currentMeal!.endTime == null;

  /// Start a new meal session
  void startMeal() {
    if (isMealActive) {
      debugPrint('⚠️ Meal already active, ending previous meal first');
      endMeal();
    }

    _currentMeal = MealSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
    );

    _lastBiteTime = null;
    _biteCountController.add(0);
    _tremorIndexController.add(0.0);
    _mealSessionController.add(_currentMeal);

    debugPrint('🍽️ Meal session started: ${_currentMeal!.id}');
  }

  /// End the current meal session
  MealSession? endMeal() {
    if (_currentMeal == null) {
      debugPrint('⚠️ No active meal to end');
      return null;
    }

    _currentMeal!.endTime = DateTime.now();
    _mealTimeoutTimer?.cancel();

    final completedMeal = _currentMeal;
    debugPrint('✅ Meal session ended: ${completedMeal!.id}');
    debugPrint('   Duration: ${completedMeal.duration.inMinutes} min');
    debugPrint('   Bites: ${completedMeal.biteCount}');
    debugPrint('   Tremor: ${completedMeal.calculateTremorIndex()}');

    _mealSessionController.add(completedMeal);
    _currentMeal = null;

    return completedMeal;
  }

  /// Process a packet of IMU samples (typically 20 samples)
  /// This is called from McuBleService when data arrives
  void processPacket(List<McuSensorData> packet) {
    if (packet.isEmpty) return;
    if (!isMealActive) {
      // Auto-start meal on first motion
      startMeal();
    }

    // Reset meal timeout timer
    _resetMealTimeout();

    // 1. TREMOR FEATURE EXTRACTION - Extract features from this packet
    _extractTremorFeatures(packet);

    // 2. Update interim tremor display (rolling average)
    _tremorIndexController.add(currentTremorIndex);
  }

  /// Extract tremor features from a packet
  void _extractTremorFeatures(List<McuSensorData> packet) {
    if (packet.isEmpty) return;

    // Calculate gyroscope magnitudes for all samples
    List<double> gyroMags = packet.map((s) => s.gyroMagnitude).toList();

    // Calculate variance
    double mean = gyroMags.reduce((a, b) => a + b) / gyroMags.length;
    double variance = gyroMags
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / gyroMags.length;

    // Calculate RMS (Root Mean Square)
    double rms = sqrt(gyroMags
        .map((x) => x * x)
        .reduce((a, b) => a + b) / gyroMags.length);

    // Store features
    final features = TremorFeatures(
      variance: variance,
      rms: rms,
      timestamp: packet.last.timestamp,
    );

    _currentMeal!.tremorFeatures.add(features);
    
    // Memory Safety: Limit stored features (keep last 5000 ~ approx 1.5 min of data for calculation)
    // If you need full history for analysis, consider averaging or decimating old data
    if (_currentMeal!.tremorFeatures.length > 5000) {
      _currentMeal!.tremorFeatures.removeAt(0);
    }
  }

  /// Reset the meal timeout timer
  void _resetMealTimeout() {
    _mealTimeoutTimer?.cancel();
    _mealTimeoutTimer = Timer(mealTimeout, () {
      debugPrint('⏱️ Meal timeout - auto-ending meal');
      endMeal();
    });
  }

  /// Reset all state
  void reset() {
    _mealTimeoutTimer?.cancel();
    _currentMeal = null;
    _lastBiteTime = null;
    _biteCountController.add(0);
    _tremorIndexController.add(0.0);
    _mealSessionController.add(null);
  }

  void dispose() {
    _mealTimeoutTimer?.cancel();
    _biteCountController.close();
    _tremorIndexController.close();
    _mealSessionController.close();
  }
}
