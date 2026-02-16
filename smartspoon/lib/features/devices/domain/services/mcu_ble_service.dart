import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'ble_service.dart';

/// MCU BLE Data Model
class McuSensorData {
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  double temperature; // Made mutable so we can update it after parsing
  final DateTime timestamp;
  final String rawData;

  McuSensorData({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.temperature,
    DateTime? timestamp,
    String? rawData,
  }) : timestamp = timestamp ?? DateTime.now(),
       rawData = rawData ?? '';

  /// Calculate acceleration magnitude (in g)
  double get accelMagnitude =>
      (accelX * accelX + accelY * accelY + accelZ * accelZ);

  /// Calculate gyroscope magnitude (in deg/s)
  double get gyroMagnitude => (gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);

  /// Calculate linear acceleration (subtract gravity)
  double get linearAccel => (accelMagnitude - 1.0).abs();

  @override
  String toString() {
    return 'Accel(${accelX.toStringAsFixed(3)},${accelY.toStringAsFixed(3)},${accelZ.toStringAsFixed(3)}) '
        'Gyro(${gyroX.toStringAsFixed(3)},${gyroY.toStringAsFixed(3)},${gyroZ.toStringAsFixed(3)}) '
        'Temp:${temperature.toStringAsFixed(2)}°C';
  }
}

/// MCU BLE Service using flutter_reactive_ble
class McuBleService extends ChangeNotifier {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final BleService _bleService = BleService(); // Singleton access

  // UUIDs for MCU service and characteristics
  final Uuid serviceUuid = Uuid.parse('12345678-1234-1234-1234-1234567890ab');
  final Uuid imuCharUuid = Uuid.parse('12345678-1234-1234-1234-1234567890ac');

  // Connection and subscription streams
  StreamSubscription<List<int>>? _characteristicSubscription;

  String? _connectedDeviceId;
  bool _isConnected = false;
  bool _isSubscribed = false;

  // Sensor data
  McuSensorData? _currentData;
  double _temp = 0.0;
  int _batteryLevel = 0;

  // Data queue for background processing
  final List<List<int>> _dataQueue = [];
  Timer? _processingTimer;
  Timer? _pollingTimer; // Timer for polling data when stationary
  int _receivedPackets = 0;

  // Raw data log (last 20 entries)
  final List<String> _rawDataLog = [];

  // Additional tracking for settings screen
  List<int>? _lastRawPacket;
  DateTime? _lastPacketTime;
  int _packetsInLastSecond = 0;
  DateTime _lastSecondTimestamp = DateTime.now();
  int _totalBytesReceived = 0;
  double _currentPacketsPerSecond = 0.0;
  double _currentDataRate = 0.0;
  
  // Rate limiting for notifications
  DateTime _lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Stream for batched sensor data (for analysis)
  final _sensorBatchController =
      StreamController<List<McuSensorData>>.broadcast();
  Stream<List<McuSensorData>> get sensorBatchStream =>
      _sensorBatchController.stream;

  // Public getters
  bool get isConnected => _isConnected;
  bool get isSubscribed => _isSubscribed;
  int get batteryLevel => _batteryLevel;
  double get temperature => _temp;
  McuSensorData? get currentData => _currentData;
  List<String> get rawDataLog => List.unmodifiable(_rawDataLog);

  // Additional getters for settings screen
  List<int>? get lastRawPacket => _lastRawPacket;
  DateTime? get lastPacketTime => _lastPacketTime;
  int get receivedPackets => _receivedPackets;
  double get packetsPerSecond => _currentPacketsPerSecond;
  double get dataRate => _currentDataRate; // bytes per second

  McuBleService() {
    // Listen to BleService for connection updates
    _bleService.addListener(_onBleServiceChanged);
    // Check initial state in case already connected
    _onBleServiceChanged();
  }

  /// Handle updates from BleService
  void _onBleServiceChanged() {
    final connectedIds = _bleService.connectedDeviceIds;
    
    // If we are connected to a device that BleService says is disconnected, clean up
    if (_connectedDeviceId != null &&
        !connectedIds.contains(_connectedDeviceId)) {
      debugPrint('⚠️ MCU BLE: BleService reports device $_connectedDeviceId disconnected. Cleaning up.');
      disconnect();
    }

    // If we are NOT subscribed but BleService has a connection, try to subscribe
    // We assume the first connected device is the one we want (single device support for now)
    if (!_isSubscribed && connectedIds.isNotEmpty) {
      final deviceId = connectedIds.first;
      // Avoid re-subscribing if we are already trying or just disconnected explicitly?
      // For now, auto-subscribe logic:
      if (_connectedDeviceId != deviceId) {
         subscribeToDevice(deviceId);
      } else if (!_isSubscribed) {
         // Retry subscription if ID matches but not subscribed?
         // Be careful not to create a loop. subscribeToDevice checks _isSubscribed.
         subscribeToDevice(deviceId);
      }
    }
  }

  /// Subscribe to an already-connected device for data streaming
  /// This assumes BleService has already established the connection
  Future<bool> subscribeToDevice(String deviceId) async {
    try {
      // Check if already subscribed to this device
      if (_connectedDeviceId == deviceId && _isSubscribed) {
        // Ensure data processor is running
        if (_processingTimer == null || !_processingTimer!.isActive) {
          _startDataProcessor();
        }
        return true;
      }

      debugPrint('🔵 MCU BLE: Subscribing to device $deviceId...');
      _connectedDeviceId = deviceId;

      // Request higher MTU for throughput
      try {
        debugPrint('🔵 MCU BLE: Requesting MTU 512...');
        await _ble.requestMtu(deviceId: deviceId, mtu: 512);
        debugPrint('✅ MCU BLE: MTU request sent');
      } catch (e) {
        debugPrint('⚠️ MCU BLE: MTU request failed (ignoring): $e');
      }
      
      // Subscribe to data characteristic
      final success = await subscribeToData();
      
      if (success) {
        _isConnected = true;
      } else {
        _isConnected = false;
        _connectedDeviceId = null; 
      }
      notifyListeners();
      return success;
    } catch (e, stackTrace) {
      debugPrint('❌ MCU BLE: Subscribe error: $e');
      debugPrint('Stack trace: $stackTrace');
      _isConnected = false;
      _connectedDeviceId = null;
      notifyListeners();
      return false;
    }
  }

  /// Subscribe to IMU characteristic notifications
  Future<bool> subscribeToData() async {
    if (_connectedDeviceId == null) {
      debugPrint('❌ MCU BLE: No device ID set, cannot subscribe');
      return false;
    }

    try {
      debugPrint('🔔 MCU BLE: Starting subscription to IMU characteristic...');

      final characteristic = QualifiedCharacteristic(
        serviceId: serviceUuid,
        characteristicId: imuCharUuid,
        deviceId: _connectedDeviceId!,
      );

      // Subscribe using flutter_reactive_ble
      _characteristicSubscription = _ble
          .subscribeToCharacteristic(characteristic)
          .listen(
            (data) {
              if (data.isNotEmpty) {
                 debugPrint('📦 BLE Packet: ${data.length} bytes'); 
                 _dataQueue.add(data);
                 if (_dataQueue.length > 200) {
                   _dataQueue.removeAt(0);
                 }
              }
            },
            onError: (error) {
              debugPrint('❌ MCU BLE: Subscription error: $error');
              
              // CRITICAL: Do not disconnect on Read errors (polling)
              if (error.toString().contains('CHARACTERISTIC_READ')) {
                 debugPrint('⚠️ MCU BLE: Ignoring Read error in subscription stream');
                 return;
              }

              // If subscription errors, we are likely disconnected
              disconnect();
            },
            onDone: () {
               debugPrint('❌ MCU BLE: Subscription stream closed');
               disconnect();
            }
          );

      _isSubscribed = true;
      debugPrint('✅ MCU BLE: Successfully subscribed to notifications');

      // Start background data processor
      _startDataProcessor();

      // Start polling for stationary updates (every 3 seconds)
      _startPolling();

      // notifyListeners will be called by caller
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ MCU BLE: Subscribe error: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Start background worker to process queued data
  void _startDataProcessor() {
    _processingTimer?.cancel();
    // Run at 5Hz (200ms) to process queued data without overwhelming the main thread
    // Previously 30Hz (33ms) which caused ANR on home screen
    _processingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _processQueuedData();
    });
    debugPrint('✅ Data processor started (5Hz)');
  }
  
  /// Stop background worker
  void _stopDataProcessor() {
    _processingTimer?.cancel();
    _processingTimer = null;
    _pollingTimer?.cancel(); // Stop polling
    _pollingTimer = null;
    _dataQueue.clear();
    debugPrint('✅ Data processor stopped');
  }

  /// Start polling data when stationary
  void _startPolling() {
    _pollingTimer?.cancel();
    _consecutiveReadErrors = 0; // Reset errors
    // Check every 5 seconds if we need to poll
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // SMART POLLING: Only read if we haven't received data recently
      // This prevents conflicts between notifications and read requests
      final now = DateTime.now();
      if (_lastPacketTime == null || now.difference(_lastPacketTime!).inSeconds >= 5) {
        debugPrint('🔍 MCU BLE: No data for 5s, polling...');
        readData();
      }
    });
    debugPrint('✅ Smart polling started (5s check)'); 
  }

  int _consecutiveReadErrors = 0;

  /// Explicitly read data from the characteristic (for stationary updates)
  Future<void> readData() async {
    if (!_isConnected || _connectedDeviceId == null) return;
    try {
      final characteristic = QualifiedCharacteristic(
        serviceId: serviceUuid,
        characteristicId: imuCharUuid,
        deviceId: _connectedDeviceId!,
      );
      final response = await _ble.readCharacteristic(characteristic);
      if (response.isNotEmpty) {
        _consecutiveReadErrors = 0; // Success
        // Parse as single packet
        final now = DateTime.now();
        final samples = _parseMcuPacket(response, now);
        if (samples.isNotEmpty) {
          _currentData = samples.last;
          _lastPacketTime = now; // Update timestamp for smart polling
          _temp = _currentData!.temperature;
          // Battery is updated inside parse
          // Notify listeners immediately for polled data
          notifyListeners();
        }
      }
    } catch (e) {
      _consecutiveReadErrors++;
      debugPrint('⚠️ MCU BLE: Read error: $e');
      
      if (_consecutiveReadErrors >= 3) {
        debugPrint('❌ MCU BLE: Too many read errors ($e), stopping polling to prevent instability.');
        _pollingTimer?.cancel();
        _pollingTimer = null;
      }
    }
  }

  /// Process data from the queue in batches
  void _processQueuedData() {
    if (_dataQueue.isEmpty) {
       // Log occasionally to confirm processor is alive
       if (_processingTimer != null && _processingTimer!.tick % 50 == 0) {
          debugPrint('⏳ BLE Queue Empty');
       }
       return;
    }

    final batch = <McuSensorData>[];
    final now = DateTime.now();
    int processedCount = 0;
    int processedBytes = 0;

    while (_dataQueue.isNotEmpty && processedCount < 50) {
      final data = _dataQueue.removeAt(0);
      processedBytes += data.length;
      
      final parsedSamples = _parseMcuPacket(data, now);
      if (parsedSamples.isNotEmpty) {
        batch.addAll(parsedSamples);
        _currentData = parsedSamples.last; 
        _temp = parsedSamples.last.temperature;
      }
      processedCount++;
    }

    if (batch.isNotEmpty) {
      _sensorBatchController.add(batch); 
    }

    // Update stats
    _receivedPackets += processedCount;
    _totalBytesReceived += processedBytes;
    _lastPacketTime = now;

    // Calculate packets per second and data rate
    _packetsInLastSecond += processedCount;
    if (now.difference(_lastSecondTimestamp).inSeconds >= 1) {
      _currentPacketsPerSecond = _packetsInLastSecond /
          now.difference(_lastSecondTimestamp).inSeconds;
      _currentDataRate = _totalBytesReceived /
          now.difference(_lastSecondTimestamp).inSeconds;
      _packetsInLastSecond = 0;
      _totalBytesReceived = 0;
      _lastSecondTimestamp = now;
    }

    // Throttle UI updates to once per second
    if (now.difference(_lastNotifyTime).inMilliseconds > 1000) {
      _lastNotifyTime = now;
      notifyListeners();
    }
  }

  /// Parse a raw BLE packet into a list of McuSensorData (one per sample)
  List<McuSensorData> _parseMcuPacket(List<int> data, DateTime packetTimestamp) {
    if (data.length < 20) {
      // debugPrint('⚠️ MCU BLE: Packet too short: ${data.length} bytes');
      return [];
    }

    try {
      _lastRawPacket = data;

      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      final byteData = ByteData.sublistView(bytes);
      int offset = 0;

      // 1. Battery (1 byte)
      _batteryLevel = byteData.getUint8(offset);
      offset += 1;

      // 2. Temperature (2 bytes, int16, little-endian)
      final tempRaw = byteData.getInt16(offset, Endian.little);
      final temperature = tempRaw / 100.0;
      offset += 2;

      // 3. Timestamp (4 bytes)
      offset += 4;

      // 4. IMU Data
      int remainingBytes = data.length - offset;
      int sampleCount = remainingBytes ~/ 12; 
      
      if (sampleCount == 0) return [];

      List<McuSensorData> samples = [];
      const int sampleIntervalMs = 10; 

      for (int i = 0; i < sampleCount; i++) {
        final accelX = byteData.getInt16(offset, Endian.little) / 1000.0;
        offset += 2;
        final accelY = byteData.getInt16(offset, Endian.little) / 1000.0;
        offset += 2;
        final accelZ = byteData.getInt16(offset, Endian.little) / 1000.0;
        offset += 2;

        final gyroX = byteData.getInt16(offset, Endian.little) / 1000.0;
        offset += 2;
        final gyroY = byteData.getInt16(offset, Endian.little) / 1000.0;
        offset += 2;
        final gyroZ = byteData.getInt16(offset, Endian.little) / 1000.0;
        offset += 2;

        final sampleTime = packetTimestamp.subtract(
          Duration(milliseconds: (sampleCount - 1 - i) * sampleIntervalMs)
        );

        samples.add(McuSensorData(
          accelX: accelX,
          accelY: accelY,
          accelZ: accelZ,
          gyroX: gyroX,
          gyroY: gyroY,
          gyroZ: gyroZ,
          temperature: temperature,
          timestamp: sampleTime,
          rawData: (i == 0) ? data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ') : null,
        ));
      }

      // Log raw data occasionally
      if (_rawDataLog.length >= 20) {
        _rawDataLog.removeAt(0);
      }
      _rawDataLog.add(
          '${packetTimestamp.toIso8601String()} - $sampleCount samples - ${data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');

      return samples;
    } catch (e) {
      debugPrint('❌ MCU BLE: Error parsing packet: $e');
      return [];
    }
  }

  /// Disconnect from the device and stop all subscriptions/timers
  Future<void> disconnect() async {
    debugPrint('🔴 MCU BLE: Disconnecting...');
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    _stopDataProcessor();
    _isConnected = false;
    _isSubscribed = false;
    _connectedDeviceId = null;
    _currentData = null;
    _receivedPackets = 0;
    _lastPacketTime = null;
    _lastRawPacket = null;
    _packetsInLastSecond = 0;
    _totalBytesReceived = 0;
    _currentPacketsPerSecond = 0.0;
    _currentDataRate = 0.0;
    notifyListeners();
    debugPrint('🔴 MCU BLE: Disconnected.');
  }

  void clearLog() {
    _rawDataLog.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _bleService.removeListener(_onBleServiceChanged);
    _characteristicSubscription?.cancel();
    _stopDataProcessor();
    _sensorBatchController.close();
    super.dispose();
  }
}
