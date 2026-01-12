import 'dart:async';
import 'package:smartspoon/features/devices/index.dart';

/// Service responsible for analyzing raw IMU data to detect bites and measure tremor.
/// 
/// Algorithms:
/// - Bite Detection: State machine (Stable -> Motion -> Rotation -> Stable)
/// - Tremor Index: Power Spectral Density (PSD) ratio in 4-12Hz band
class MotionAnalysisService {
  static final MotionAnalysisService _instance = MotionAnalysisService._internal();
  factory MotionAnalysisService() => _instance;
  MotionAnalysisService._internal();

  // Configuration
  // static const int _sampleRate = 50; // Hz
  // static const int _windowSize = 128; // Samples for FFT (approx 2.5s)
  
  // State Machine for Bite Detection - REMOVED
  // _BiteState _biteState = _BiteState.idle;
  // DateTime _lastStateChange = DateTime.now();
  int _biteCount = 0;
  
  // Data Buffers - REMOVED
  // final List<double> _gyroMagBuffer = [];
  // final List<McuSensorData> _rawBuffer = [];

  // Streams
  final _biteCountController = StreamController<int>.broadcast();
  final _tremorIndexController = StreamController<double>.broadcast();
  
  Stream<int> get biteCountStream => _biteCountController.stream;
  Stream<double> get tremorIndexStream => _tremorIndexController.stream;

  // Current Metrics
  int get currentBiteCount => _biteCount;
  double _currentTremorIndex = 0.0;
  double get currentTremorIndex => _currentTremorIndex;

  /// Process a batch of sensor data (Called from McuBleService)
  void processBatch(List<McuSensorData> batch) {
    // _processBatch(batch); // Logic Removed
  }

  /// Process a batch of data - REMOVED
  // void _processBatch(List<McuSensorData> batch) { ... }

  /// Bite Detection State Machine - REMOVED
  // void _updateBiteDetection(double accMag, double gyroMag, McuSensorData data) { ... }

  // void _transitionTo(_BiteState newState, DateTime time) { ... }

  // void _incrementBiteCount() { ... }

  /// Tremor Analysis on Batch - REMOVED
  // void _computeTremorIndexFromBatch(List<double> gyroMags) { ... }
  
  void reset() {
    _biteCount = 0;
    _biteCountController.add(0);
    _currentTremorIndex = 0;
    _tremorIndexController.add(0);
    // _rawBuffer.clear();
    // _gyroMagBuffer.clear();
  }

  void dispose() {
    _biteCountController.close();
    _tremorIndexController.close();
  }
}

// enum _BiteState { idle, lifting, rotating, eating } // REMOVED
