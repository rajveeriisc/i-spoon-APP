import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:smartspoon/features/devices/domain/services/mcu_ble_service.dart';
import 'package:fftea/fftea.dart';
// ignore: unused_import
import 'package:vector_math/vector_math.dart' as vector;

/// Tremor Detection Result
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

/// Service for detecting tremors using spectral analysis (Welch's method)
class TremorDetectionService extends ChangeNotifier {
  final McuBleService _mcuService;
  StreamSubscription? _dataSubscription;

  // Constants
  static const int _targetSampleRate = 100; // MCU sends batched data ~100Hz effective
  static const int _bufferSeconds = 10; 
  static const int _bufferSize = _targetSampleRate * _bufferSeconds; // ~1000 samples
  
  // Buffers
  final List<double> _accelMagBuffer = [];
  final List<double> _gyroMagBuffer = [];
  
  // Processing Control
  bool _isProcessing = false;
  DateTime? _lastProcessTime;
  
  // Result
  TremorResult _lastResult = TremorResult(detected: false);
  TremorResult get lastResult => _lastResult;

  TremorDetectionService(this._mcuService) {
    _init();
  }

  void _init() {
    // Listen to the batch stream from MCU service
    // Throttled to 5Hz to avoid main-thread overload (raw stream is 30Hz)
    DateTime lastBatchTime = DateTime.now();
    _dataSubscription = _mcuService.sensorBatchStream.listen((batch) {
      final now = DateTime.now();
      if (now.difference(lastBatchTime).inMilliseconds >= 200) {
        lastBatchTime = now;
        _processBatch(batch);
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  /// Process new batch of sensor data
  void _processBatch(List<McuSensorData> batch) {
    // ALWAYS buffer data, even if processing
    for (final data in batch) {
      // Calculate magnitudes (Preprocessing)
      // Accel (g), Gyro (deg/s)
      double accelMag = data.accelMagnitude; 
      double gyroMag = data.gyroMagnitude; 

      _accelMagBuffer.add(accelMag);
      _gyroMagBuffer.add(gyroMag);
    }

    // Maintain buffer size
    if (_accelMagBuffer.length > _bufferSize * 1.5) {
      int removeCount = _accelMagBuffer.length - _bufferSize;
      _accelMagBuffer.removeRange(0, removeCount);
      _gyroMagBuffer.removeRange(0, removeCount);
    }
    
    // DEBUG: Log buffer status
    if (_accelMagBuffer.length % 50 == 0 && batch.isNotEmpty) {
       debugPrint('🌊 Tremor Buffer: ${_accelMagBuffer.length}/$_bufferSize. Last Mag: ${batch.last.accelMagnitude.toStringAsFixed(2)}');
    }

    // Trigger processing every ~10 seconds if buffer is full
    // AND handled by the analysis guard
    if (_accelMagBuffer.length >= _bufferSize) {
      if (!_isProcessing && (_lastProcessTime == null || 
          DateTime.now().difference(_lastProcessTime!).inSeconds >= 10)) {
        _runAnalysis();
      }
    }
  }

  Future<void> _runAnalysis() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _lastProcessTime = DateTime.now();

    try {
      debugPrint('⚡ Starting Tremor Analysis...');
      // Copy data
      final accelData = List<double>.from(_accelMagBuffer);
      final gyroData = List<double>.from(_gyroMagBuffer);
      
      // Run analysis in compute isolate
      final result = await compute(_analyzeSignal, _AnalysisData(accelData, gyroData, _targetSampleRate));
      
      debugPrint('⚡ Analysis Completed: $result');
      
      _lastResult = result;
      notifyListeners();
      
      // Slide buffer: remove 2s of data (approx 60 samples at 30Hz)
      int removeCount = 2 * _targetSampleRate;
      if (_accelMagBuffer.length > removeCount) {
         _accelMagBuffer.removeRange(0, removeCount);
         _gyroMagBuffer.removeRange(0, removeCount);
      }
      
    } catch (e) {
      debugPrint('❌ Tremor Analysis Error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Static analysis function (pure)
  static TremorResult _analyzeSignal(_AnalysisData data) {
    int fs = data.sampleRate;
    
    // 1. High-pass filter (0.5Hz)
    final accelFilt = _highPassFilter(data.accel, 0.5, fs);
    final gyroFilt = _highPassFilter(data.gyro, 0.5, fs);

    // 2. Stage 1: Candidate Freq Estimation using Welch
    final accelPsd = _computeWelchPsd(accelFilt, fs);
    final gyroPsd = _computeWelchPsd(gyroFilt, fs);

    // Analyze Peaks (3-12Hz - Tremor Band)
    final accelPeak = _detectPeak(accelPsd, 3.0, 12.0);
    final gyroPeak = _detectPeak(gyroPsd, 3.0, 12.0);

    // Thresholds
    // Lowered to 0.05 for easier testing
    bool accelDetected = accelPeak != null && accelPeak.powerFraction > 0.05;
    bool gyroDetected = gyroPeak != null && gyroPeak.powerFraction > 0.05;

    if (!accelDetected && !gyroDetected) {
      return TremorResult(detected: false);
    }

    // Determine primary source
    bool useAccel = accelDetected;
    if (accelDetected && gyroDetected) {
       useAccel = accelPeak.powerFraction > gyroPeak.powerFraction;
    } else if (gyroDetected) {
       useAccel = false;
    }

    final peak = useAccel ? accelPeak! : gyroPeak!;
    final source = useAccel ? 'accel' : 'gyro';
    
    // Amplitude Calculation
    double amplitude = 0.0;
    double f = peak.frequency;
    double P = peak.power;

    if (f > 0) {
      if (useAccel) {
         // Approx displacement from accel (double integration approx)
         // A_t (cm) approx
         amplitude = (math.sqrt(P) / (4 * math.pi * math.pi * f * f)) * 100 * 9.8; 
      } else {
         // A_r (deg) approx
         amplitude = math.sqrt(P) / (2 * math.pi * f);
      }
    }

    return TremorResult(
      detected: true,
      frequency: f,
      amplitude: amplitude,
      score: math.log(P + 1e-6), // Log power
      source: source,
    );
  }

  static List<double> _highPassFilter(List<double> input, double cutoff, int fs) {
     // butterworth 1st order high pass
     // y[i] = a * (y[i-1] + x[i] - x[i-1])
     double rc = 1.0 / (2.0 * math.pi * cutoff);
     double dt = 1.0 / fs;
     double alpha = rc / (rc + dt);
     
     final output = List<double>.filled(input.length, 0.0);
     output[0] = 0;
     
     for (int i = 1; i < input.length; i++) {
        output[i] = alpha * (output[i-1] + input[i] - input[i-1]);
     }
     
     return output;
  }

  /// Compute PSD using Welch's method (simplified)
  static List<_FreqPoint> _computeWelchPsd(List<double> signal, int fs) {
    // Determine FFT size (power of 2)
    int nFFT = 256; 
    if (signal.length < nFFT) {
      if (signal.length < 64) return []; // Too short
      nFFT = 64; 
    }

    final fft = FFT(nFFT);
    
    // Segment and average
    final List<double> psdSum = List.filled(nFFT ~/ 2, 0.0);
    int count = 0;
    
    // 50% overlap
    int step = nFFT ~/ 2;
    
    for (int i = 0; i <= signal.length - nFFT; i += step) {
      final chunk = signal.sublist(i, i + nFFT);
      final windowed = _applyHammingWindow(chunk);
      
      // fftea returns Complex numbers
      final spectrum = fft.realFft(windowed);
      
      // Calculate magnitude squared (Power)
      for (int j = 0; j < nFFT ~/ 2; j++) {
        // Magnitude = sqrt(re^2 + im^2)
        // Power = Magnitude^2 = re^2 + im^2
        double re = spectrum[j].x;
        double im = spectrum[j].y;
        double power = re * re + im * im;
        psdSum[j] += power;
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
      // Hamming window: 0.54 - 0.46 * cos(2*pi*n / (N-1))
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

class _AnalysisData {
  final List<double> accel;
  final List<double> gyro;
  final int sampleRate;
  _AnalysisData(this.accel, this.gyro, this.sampleRate);
}

class _FreqPoint {
  final double freq;
  final double power;
  _FreqPoint(this.freq, this.power);
}

class _PeakInfo {
  final double frequency;
  final double power;
  final double powerFraction;
  _PeakInfo(this.frequency, this.power, this.powerFraction);
}
