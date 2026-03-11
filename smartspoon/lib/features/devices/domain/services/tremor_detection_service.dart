import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:smartspoon/features/devices/domain/services/mcu_ble_service.dart';
import 'package:smartspoon/features/notifications/domain/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fftea/fftea.dart';
// ignore: unused_import
import 'package:vector_math/vector_math.dart' as vector;

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// Tremor Detection Result (per-bite or aggregated)
class TremorResult {
  final bool detected;
  final double frequency; // Hz
  final double amplitude; // cm or deg
  final double score; // Severity score (log power/RMS)
  final String source; // 'accel', 'gyro', or 'fusion'
  final DateTime timestamp;

  TremorResult({
    required this.detected,
    this.frequency = 0.0,
    this.amplitude = 0.0,
    this.score = 0.0,
    this.source = 'none',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TremorResult.empty() => TremorResult(detected: false);

  @override
  String toString() {
    return 'Tremor: ${detected ? "YES" : "NO"} | Freq: ${frequency.toStringAsFixed(1)}Hz | Amp: ${amplitude.toStringAsFixed(2)} | Score: ${score.toStringAsFixed(1)}';
  }
}

/// Internal: timestamped magnitude sample
class _MagSample {
  final double accelMag;
  final double gyroMag;
  final DateTime timestamp;
  _MagSample(this.accelMag, this.gyroMag, this.timestamp);
}

/// Internal: FFT frequency-domain point
class _FreqPoint {
  final double freq;
  final double power;
  _FreqPoint(this.freq, this.power);
}

/// Internal: peak info from PSD
class _PeakInfo {
  final double frequency;
  final double power;
  final double powerFraction;
  _PeakInfo(this.frequency, this.power, this.powerFraction);
}

/// Internal: data passed to compute isolate
class _FrameAnalysisData {
  final List<double> accel;
  final List<double> gyro;
  final int sampleRate;
  final int trimStartSamples;
  final int trimEndSamples;
  _FrameAnalysisData(this.accel, this.gyro, this.sampleRate, this.trimStartSamples, this.trimEndSamples);
}

// ─────────────────────────────────────────────────────────────────────────────
//  BITE FRAME STATE MACHINE
// ─────────────────────────────────────────────────────────────────────────────

enum _FrameState { idle, lifting, holding, returning }

/// Detects the motion pattern:  idle → lifting → holding → returning → complete
/// and emits the raw frame data for tremor analysis.
class _BiteFrameDetector {
  // Thresholds (tunable)
  // Lower lift threshold — ESP32 accel values in g, hand lift easily hits 1.1g
  static const double _liftThreshold = 1.1; // g — trigger lift detection
  // Wider hold window — hand naturally oscillates ±0.3g around 1g while holding
  static const double _holdLow = 0.6;       // g — lower bound for steady hold
  static const double _holdHigh = 1.5;      // g — upper bound for steady hold
  static const int _liftMinSamples = 3;     // 30 ms at 100 Hz — debounce
  // Shorter hold requirement — just need ~150ms of relative stability
  static const int _holdMinSamples = 15;    // 150 ms at 100 Hz
  static const int _returnMinSamples = 3;   // 30 ms debounce

  _FrameState _state = _FrameState.idle;
  int _stateCounter = 0;
  final List<_MagSample> _frameBuffer = [];

  // Max frame size: 30 seconds × 100 Hz = 3000 samples (safety cap)
  static const int _maxFrameSamples = 3000;

  /// Feed a new sample. Returns the completed frame if a bite cycle just finished.
  List<_MagSample>? feed(_MagSample sample) {
    // Always buffer while not idle
    if (_state != _FrameState.idle) {
      _frameBuffer.add(sample);
      if (_frameBuffer.length > _maxFrameSamples) {
        // Safety: too long, reset
        debugPrint('⚠️ Frame too long (>${_maxFrameSamples} samples), resetting');
        _reset();
        return null;
      }
    }

    switch (_state) {
      case _FrameState.idle:
        if (sample.accelMag > _liftThreshold) {
          _stateCounter++;
          if (_stateCounter >= _liftMinSamples) {
            _state = _FrameState.lifting;
            _stateCounter = 0;
            // Start buffering (include the lift samples)
            _frameBuffer.clear();
            _frameBuffer.add(sample);
            debugPrint('🔼 Lift detected, buffering frame...');
          }
        } else {
          _stateCounter = 0;
        }
        break;

      case _FrameState.lifting:
        // Wait for magnitude to settle into hold range
        if (sample.accelMag >= _holdLow && sample.accelMag <= _holdHigh) {
          _stateCounter++;
          if (_stateCounter >= _holdMinSamples) {
            _state = _FrameState.holding;
            _stateCounter = 0;
            debugPrint('✋ Hold detected (stable for ${_holdMinSamples * 10}ms)');
          }
        } else if (sample.accelMag > _holdHigh) {
          // Still lifting — reset hold counter
          _stateCounter = 0;
        } else {
          // Below hold range — possibly returning early
          _stateCounter = 0;
        }
        // Timeout: if lifting for > 5 seconds with no hold, reset
        if (_frameBuffer.length > 500) {
          debugPrint('⚠️ Lift timeout — no hold detected, resetting');
          _reset();
        }
        break;

      case _FrameState.holding:
        // Stay in hold until we detect return motion (spike above threshold)
        if (sample.accelMag > _liftThreshold) {
          _stateCounter++;
          if (_stateCounter >= _returnMinSamples) {
            _state = _FrameState.returning;
            _stateCounter = 0;
            debugPrint('🔽 Return detected');
          }
        } else {
          _stateCounter = 0;
        }
        break;

      case _FrameState.returning:
        // Wait for return to idle (magnitude settles)
        if (sample.accelMag >= _holdLow && sample.accelMag <= _holdHigh) {
          _stateCounter++;
          if (_stateCounter >= _returnMinSamples) {
            // Frame complete!
            final frame = List<_MagSample>.from(_frameBuffer);
            debugPrint('🎯 Bite frame complete: ${frame.length} samples (${(frame.length / 100).toStringAsFixed(1)}s)');
            _reset();
            return frame;
          }
        } else {
          _stateCounter = 0;
        }
        // Timeout: if returning for > 5 seconds, just complete
        if (_stateCounter == 0 && _frameBuffer.length > _maxFrameSamples - 100) {
          final frame = List<_MagSample>.from(_frameBuffer);
          _reset();
          return frame;
        }
        break;
    }

    return null;
  }

  void _reset() {
    _state = _FrameState.idle;
    _stateCounter = 0;
    _frameBuffer.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN SERVICE
// ─────────────────────────────────────────────────────────────────────────────

/// Optimized tremor detection using frame-based analysis.
///
/// Instead of analyzing a continuous rolling buffer, this service:
/// 1. Detects bite motion frames (lift → hold → return)
/// 2. Trims the first and last 3 seconds of each frame
/// 3. Bandpass-filters the trimmed data (3–12 Hz)
/// 4. Runs Welch PSD on the clean window
/// 5. Produces per-bite tremor results
class TremorDetectionService extends ChangeNotifier {
  final McuBleService _mcuService;
  StreamSubscription? _dataSubscription;

  // Constants
  static const int _sampleRate = 100; // 100 Hz
  static const int _trimStartSamples = 100; // 1 sec from start
  static const int _trimEndSamples = 125;   // 1.25 sec from end
  static const int _minUsableSamples = 100; // 1s minimum usable for Welch PSD

  // Frame detector
  final _BiteFrameDetector _frameDetector = _BiteFrameDetector();

  // Per-bite results history (kept for current meal)
  final List<TremorResult> perBiteResults = [];

  // Processing Control
  bool _isProcessing = false;
  DateTime? _lastNotificationTime;

  // Aggregated result (rolling average of last 5 bites)
  TremorResult _lastResult = TremorResult(detected: false);
  TremorResult get lastResult => _lastResult;

  // ── Fallback: continuous buffer (kept as secondary signal when no frames) ──
  final List<double> _accelMagBuffer = [];
  final List<double> _gyroMagBuffer = [];
  // 5s at 100Hz = 500 samples. BLE delivers ~50 samples/sec effective,
  // so this fills in ~10s — fast enough for live UI feedback.
  static const int _fallbackBufferSize = _sampleRate * 5; // 5 s
  DateTime? _lastFallbackTime;

  TremorDetectionService(this._mcuService) {
    _init();
  }

  void _init() {
    _dataSubscription = _mcuService.sensorBatchStream.listen((batch) {
      _processBatch(batch);
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  /// Clear per-bite history (call when meal ends)
  void clearBiteHistory() {
    perBiteResults.clear();
    _lastResult = TremorResult(detected: false);
    notifyListeners();
  }

  // ─── PROCESSING ─────────────────────────────────────────────────────────────

  void _processBatch(List<McuSensorData> batch) {
    for (final data in batch) {
      final sample = _MagSample(data.accelMagnitude, data.gyroMagnitude, data.timestamp);

      // Feed into frame detector
      final completedFrame = _frameDetector.feed(sample);
      if (completedFrame != null && !_isProcessing) {
        _analyzeFrame(completedFrame);
      }

      // Also feed fallback buffer
      _accelMagBuffer.add(data.accelMagnitude);
      _gyroMagBuffer.add(data.gyroMagnitude);
    }

    // Maintain fallback buffer size
    if (_accelMagBuffer.length > (_fallbackBufferSize * 1.5).toInt()) {
      int removeCount = _accelMagBuffer.length - _fallbackBufferSize;
      _accelMagBuffer.removeRange(0, removeCount);
      _gyroMagBuffer.removeRange(0, removeCount);
    }

    // Fallback: run every 5s as long as buffer has 10s of data.
    // This ensures live tremor readings in the UI even when the frame
    // detector hasn't completed a full bite cycle.
    if (_accelMagBuffer.length >= _fallbackBufferSize &&
        !_isProcessing &&
        (_lastFallbackTime == null ||
            DateTime.now().difference(_lastFallbackTime!).inSeconds >= 5)) {
      _runFallbackAnalysis();
    }
  }

  // ─── FRAME-BASED ANALYSIS (PRIMARY) ─────────────────────────────────────────

  Future<void> _analyzeFrame(List<_MagSample> frame) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final accelData = frame.map((s) => s.accelMag).toList();
      final gyroData = frame.map((s) => s.gyroMag).toList();

      debugPrint('🔬 Analyzing bite frame: ${frame.length} samples (${(frame.length / _sampleRate).toStringAsFixed(1)}s)');

      // Run analysis in compute isolate
      final result = await compute(
        _analyzeFrameIsolate,
        _FrameAnalysisData(accelData, gyroData, _sampleRate, _trimStartSamples, _trimEndSamples),
      );

      debugPrint('📊 Per-bite tremor: $result');

      // Store per-bite result
      perBiteResults.add(result);

      // Keep last 50 bites max
      if (perBiteResults.length > 50) {
        perBiteResults.removeAt(0);
      }

      // Update aggregated result (rolling average of last 5 bites)
      _lastResult = _aggregateResults(perBiteResults);
      notifyListeners();

      // Trigger notification if significant tremor
      if (result.detected && result.score > 2.0) {
        _triggerTremorNotification(result);
      }
    } catch (e) {
      debugPrint('❌ Frame analysis error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ─── FALLBACK CONTINUOUS ANALYSIS ───────────────────────────────────────────

  Future<void> _runFallbackAnalysis() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _lastFallbackTime = DateTime.now();

    try {
      final accelData = List<double>.from(_accelMagBuffer);
      final gyroData = List<double>.from(_gyroMagBuffer);

      debugPrint('🔄 Tremor fallback analysis: ${accelData.length} samples');

      // No trimming for fallback — but still use bandpass + Welch
      final result = await compute(
        _analyzeFrameIsolate,
        _FrameAnalysisData(accelData, gyroData, _sampleRate, 0, 0), // 0 trim
      );

      debugPrint('📊 Tremor fallback result: $result');
      _lastResult = result;
      notifyListeners();

      // Slide buffer: remove 2 seconds
      int removeCount = 2 * _sampleRate;
      if (_accelMagBuffer.length > removeCount) {
        _accelMagBuffer.removeRange(0, removeCount);
        _gyroMagBuffer.removeRange(0, removeCount);
      }
    } catch (e) {
      debugPrint('❌ Fallback analysis error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  // ─── AGGREGATION ────────────────────────────────────────────────────────────

  TremorResult _aggregateResults(List<TremorResult> results) {
    final detected = results.where((r) => r.detected).toList();
    if (detected.isEmpty) return TremorResult(detected: false);

    // Take last 5 detected bites
    final recent = detected.length > 5 ? detected.sublist(detected.length - 5) : detected;

    double avgFreq = recent.map((r) => r.frequency).reduce((a, b) => a + b) / recent.length;
    double avgAmp = recent.map((r) => r.amplitude).reduce((a, b) => a + b) / recent.length;
    double avgScore = recent.map((r) => r.score).reduce((a, b) => a + b) / recent.length;

    // Determine dominant source
    int accelCount = recent.where((r) => r.source == 'accel').length;
    String source = accelCount >= recent.length / 2 ? 'accel' : 'gyro';

    return TremorResult(
      detected: true,
      frequency: avgFreq,
      amplitude: avgAmp,
      score: avgScore,
      source: source,
    );
  }

  // ─── NOTIFICATION ───────────────────────────────────────────────────────────

  void _triggerTremorNotification(TremorResult result) {
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!).inMinutes < 5) {
      return;
    }
    _lastNotificationTime = now;

    NotificationService().showLocalAlert(
      title: 'Tremor Detected',
      body: 'A significant tremor was detected. Please take a moment to rest.',
      type: 'health_alerts',
      priority: 'HIGH',
      data: {
        'action_type': 'open_tremor_analysis',
        'action_data': {
          'frequency': result.frequency,
          'amplitude': result.amplitude,
          'score': result.score,
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STATIC / PURE FUNCTIONS  (run in compute isolate)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Main analysis entry point for a single frame (runs in isolate).
  static TremorResult _analyzeFrameIsolate(_FrameAnalysisData data) {
    int fs = data.sampleRate;
    var accel = data.accel;
    var gyro = data.gyro;

    // ── Step 1: Trim transient edges ──────────────────────────────────────
    if (data.trimStartSamples > 0 || data.trimEndSamples > 0) {
      final totalTrim = data.trimStartSamples + data.trimEndSamples;
      if (accel.length <= totalTrim + _minUsableSamples) {
        // Frame too short after trimming — skip
        return TremorResult(detected: false);
      }
      accel = accel.sublist(data.trimStartSamples, accel.length - data.trimEndSamples);
      gyro = gyro.sublist(data.trimStartSamples, gyro.length - data.trimEndSamples);
    }

    if (accel.length < _minUsableSamples) {
      return TremorResult(detected: false);
    }

    // ── Step 2: Bandpass filter (3–12 Hz) ────────────────────────────────
    final accelFilt = _bandpassFilter(accel, 3.0, 12.0, fs);
    final gyroFilt = _bandpassFilter(gyro, 3.0, 12.0, fs);

    // ── Step 3: Welch PSD ────────────────────────────────────────────────
    final accelPsd = _computeWelchPsd(accelFilt, fs);
    final gyroPsd = _computeWelchPsd(gyroFilt, fs);

    // ── Step 4: Peak detection in tremor band (3–12 Hz) ──────────────────
    final accelPeak = _detectPeak(accelPsd, 3.0, 12.0);
    final gyroPeak = _detectPeak(gyroPsd, 3.0, 12.0);

    // Thresholds — power fraction ≥ 15% (lowered from 30% to catch tremor during eating motion)
    // 30% is for resting tremor on a flat surface; during eating motion the signal
    // is spread across frequencies, so tremor rarely dominates 30% of total power.
    bool accelDetected = accelPeak != null && accelPeak.powerFraction > 0.15;
    bool gyroDetected  = gyroPeak  != null && gyroPeak.powerFraction  > 0.15;

    if (!accelDetected && !gyroDetected) {
      return TremorResult(detected: false);
    }

    // ── Step 5: Score and classify ───────────────────────────────────────
    bool useAccel = accelDetected;
    if (accelDetected && gyroDetected) {
      useAccel = accelPeak.powerFraction > gyroPeak.powerFraction;
    } else if (gyroDetected) {
      useAccel = false;
    }

    final peak = useAccel ? accelPeak! : gyroPeak!;
    final source = useAccel ? 'accel' : 'gyro';

    // Amplitude calculation
    double amplitude = 0.0;
    double f = peak.frequency;
    double P = peak.power;

    if (f > 0) {
      if (useAccel) {
        // Displacement from accel: A = √(2P) / (4π²f²) × 100 × 9.8
        // √(2P) gives sinusoid amplitude from one-sided PSD power
        amplitude = (math.sqrt(2 * P) / (4 * math.pi * math.pi * f * f)) * 100 * 9.8;
      } else {
        // Angular displacement: A = √(2P) / (2πf)
        amplitude = math.sqrt(2 * P) / (2 * math.pi * f);
      }
    }

    return TremorResult(
      detected: true,
      frequency: f,
      amplitude: amplitude,
      score: math.log(P + 1e-6),
      source: source,
    );
  }

  // ─── SIGNAL PROCESSING PRIMITIVES ───────────────────────────────────────────

  /// Bandpass filter: high-pass at fLow, then low-pass at fHigh (1st-order Butterworth each)
  static List<double> _bandpassFilter(List<double> input, double fLow, double fHigh, int fs) {
    // High-pass at fLow
    final hp = _highPassFilter(input, fLow, fs);
    // Low-pass at fHigh
    final bp = _lowPassFilter(hp, fHigh, fs);
    return bp;
  }

  static List<double> _highPassFilter(List<double> input, double cutoff, int fs) {
    double rc = 1.0 / (2.0 * math.pi * cutoff);
    double dt = 1.0 / fs;
    double alpha = rc / (rc + dt);

    final output = List<double>.filled(input.length, 0.0);
    for (int i = 1; i < input.length; i++) {
      output[i] = alpha * (output[i - 1] + input[i] - input[i - 1]);
    }
    return output;
  }

  static List<double> _lowPassFilter(List<double> input, double cutoff, int fs) {
    double rc = 1.0 / (2.0 * math.pi * cutoff);
    double dt = 1.0 / fs;
    double alpha = dt / (rc + dt);

    final output = List<double>.filled(input.length, 0.0);
    output[0] = input[0];
    for (int i = 1; i < input.length; i++) {
      output[i] = output[i - 1] + alpha * (input[i] - output[i - 1]);
    }
    return output;
  }

  /// Compute PSD using Welch's method (Hamming window, 50% overlap)
  static List<_FreqPoint> _computeWelchPsd(List<double> signal, int fs) {
    int nFFT = 256;
    if (signal.length < nFFT) {
      if (signal.length < 64) return [];
      nFFT = 64;
    }

    final fft = FFT(nFFT);
    final List<double> psdSum = List.filled(nFFT ~/ 2, 0.0);
    int count = 0;
    int step = nFFT ~/ 2; // 50% overlap

    for (int i = 0; i <= signal.length - nFFT; i += step) {
      final chunk = signal.sublist(i, i + nFFT);
      final windowed = _applyHammingWindow(chunk);
      final spectrum = fft.realFft(windowed);

      for (int j = 0; j < nFFT ~/ 2; j++) {
        double re = spectrum[j].x;
        double im = spectrum[j].y;
        psdSum[j] += re * re + im * im;
      }
      count++;
    }

    final double binWidth = fs / nFFT;
    final List<_FreqPoint> result = [];
    for (int i = 0; i < psdSum.length; i++) {
      if (count > 0) psdSum[i] /= count;
      result.add(_FreqPoint(i * binWidth, psdSum[i]));
    }
    return result;
  }

  static List<double> _applyHammingWindow(List<double> input) {
    final output = List<double>.from(input);
    final N = input.length;
    for (int i = 0; i < N; i++) {
      output[i] *= 0.54 - 0.46 * math.cos(2 * math.pi * i / (N - 1));
    }
    return output;
  }

  static _PeakInfo? _detectPeak(List<_FreqPoint> psd, double minFreq, double maxFreq) {
    _FreqPoint? maxPoint;
    double totalPower = 0.0;

    for (final p in psd) {
      totalPower += p.power;
      if (p.freq >= minFreq && p.freq <= maxFreq) {
        if (maxPoint == null || p.power > maxPoint.power) {
          maxPoint = p;
        }
      }
    }

    if (maxPoint == null || totalPower == 0.0) return null;
    return _PeakInfo(maxPoint.freq, maxPoint.power, maxPoint.power / totalPower);
  }
}
