import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// MCU BLE Data Model
class McuSensorData {
  final int accelX;
  final int accelY;
  final int accelZ;
  final int gyroX;
  final int gyroY;
  final int gyroZ;
  final double temperature;
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
    required this.timestamp,
    required this.rawData,
  });

  /// Parse raw BLE data string
  /// Format: "AX:123 AY:456 AZ:789 GX:12 GY:34 GZ:56 T=25.50C"
  factory McuSensorData.fromRawString(String raw) {
    final parts = raw.split(' ');
    
    int ax = 0, ay = 0, az = 0;
    int gx = 0, gy = 0, gz = 0;
    double temp = 0.0;

    try {
      for (var part in parts) {
        if (part.startsWith('AX:')) {
          ax = int.tryParse(part.substring(3)) ?? 0;
        } else if (part.startsWith('AY:')) {
          ay = int.tryParse(part.substring(3)) ?? 0;
        } else if (part.startsWith('AZ:')) {
          az = int.tryParse(part.substring(3)) ?? 0;
        } else if (part.startsWith('GX:')) {
          gx = int.tryParse(part.substring(3)) ?? 0;
        } else if (part.startsWith('GY:')) {
          gy = int.tryParse(part.substring(3)) ?? 0;
        } else if (part.startsWith('GZ:')) {
          gz = int.tryParse(part.substring(3)) ?? 0;
        } else if (part.startsWith('T=')) {
          // Remove 'C' at the end and parse
          String tempStr = part.substring(2).replaceAll('C', '');
          temp = double.tryParse(tempStr) ?? 0.0;
        }
      }
    } catch (e) {
      debugPrint('Error parsing MCU data: $e');
    }

    return McuSensorData(
      accelX: ax,
      accelY: ay,
      accelZ: az,
      gyroX: gx,
      gyroY: gy,
      gyroZ: gz,
      temperature: temp,
      timestamp: DateTime.now(),
      rawData: raw,
    );
  }

  @override
  String toString() {
    return 'Accel($accelX,$accelY,$accelZ) Gyro($gyroX,$gyroY,$gyroZ) Temp:$temperature°C';
  }
}

/// MCU BLE Service for I-Spoon device communication
class McuBleService extends ChangeNotifier {
  static final McuBleService _instance = McuBleService._internal();
  factory McuBleService() => _instance;
  McuBleService._internal();
  // Service and Characteristic UUIDs from MCU firmware
  static final Guid serviceUuid = Guid('99887766-5544-3322-1100-ffeeddccbbaa');
  static final Guid readNotifyCharUuid = Guid('9a887766-5544-3322-1100-ffeeddccbbaa');
  static final Guid writeCharUuid = Guid('9b887766-5544-3322-1100-ffeeddccbbaa');

  BluetoothCharacteristic? _notifyChar;
  BluetoothCharacteristic? _writeChar;
  StreamSubscription? _dataSubscription;

  // Current state
  McuSensorData? _currentData;
  McuSensorData? get currentData => _currentData;
  
  // Internal state for accumulating partial updates
  // int _ax = 0, _ay = 0, _az = 0;
  // int _gx = 0, _gy = 0, _gz = 0;
  double _temp = 0.0;
  
  bool _isHeaterOn = false;
  bool get isHeaterOn => _isHeaterOn;

  int _batteryLevel = 0;
  int get batteryLevel => _batteryLevel;

  // Raw data log (last 50 entries)
  final List<String> _rawDataLog = [];
  List<String> get rawDataLog => List.unmodifiable(_rawDataLog);

  // Connection status
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  DateTime? _lastUiUpdate;

  /// Connect to MCU device and discover services
  Future<bool> connect(BluetoothDevice device) async {
    try {
      debugPrint('🔵 MCU BLE: Connecting to ${device.platformName}...');

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      debugPrint('🔵 MCU BLE: Found ${services.length} services');

      // Find our custom service
      BluetoothService? targetService;
      for (var service in services) {
        debugPrint('🔵 Service: ${service.uuid}');
        if (service.uuid == serviceUuid) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        debugPrint('❌ MCU BLE: Custom service not found!');
        return false;
      }

      debugPrint('✅ MCU BLE: Found target service');

      // Find characteristics
      for (var char in targetService.characteristics) {
        debugPrint('🔵 Characteristic: ${char.uuid}');
        if (char.uuid == readNotifyCharUuid) {
          _notifyChar = char;
          debugPrint('✅ Found READ/NOTIFY characteristic');
        } else if (char.uuid == writeCharUuid) {
          _writeChar = char;
          debugPrint('✅ Found WRITE characteristic');
        }
      }

      if (_notifyChar == null || _writeChar == null) {
        debugPrint('❌ MCU BLE: Required characteristics not found!');
        return false;
      }

      _isConnected = true;
      notifyListeners();
      
      debugPrint('✅ MCU BLE: Successfully connected');
      return true;
    } catch (e) {
      debugPrint('❌ MCU BLE Connection error: $e');
      return false;
    }
  }

  /// Subscribe to notifications from MCU
  Future<bool> subscribeToData() async {
    if (_notifyChar == null) {
      debugPrint('❌ MCU BLE: Notify characteristic not available');
      return false;
    }

    try {
      // First, subscribe to the value stream BEFORE enabling notifications
      // This ensures we don't miss any data
      _dataSubscription = _notifyChar!.onValueReceived.listen(
        (value) {
          // debugPrint('🔔 MCU BLE: Notification received (${value.length} bytes)');
          if (value.isNotEmpty) {
            _handleIncomingData(value);
          }
        },
        onError: (error) {
          debugPrint('❌ MCU BLE: Stream error: $error');
        },
        cancelOnError: false,
      );

      // Now enable notifications on the characteristic
      await _notifyChar!.setNotifyValue(true);
      debugPrint('✅ MCU BLE: Notifications enabled');

      _isSubscribed = true;
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('❌ MCU BLE: Subscribe error: $e');
      _dataSubscription?.cancel();
      _dataSubscription = null;
      return false;
    }
  }

  // Stream for batched sensor data (for analysis) - REMOVED
  // final _sensorBatchController = StreamController<List<McuSensorData>>.broadcast();
  // Stream<List<McuSensorData>> get sensorBatchStream => _sensorBatchController.stream;
  
  // Internal buffer for raw batching - REMOVED
  // final List<_RawPacket> _rawBatchBuffer = [];
  
  // IMU Processing Control - REMOVED
  // bool _isImuProcessingEnabled = false;
  // Timer? _warmupTimer;

  DateTime? _lastDataProcessTime;

  /// Handle incoming data from MCU
  void _handleIncomingData(List<int> data) {
    final now = DateTime.now();
    // Throttle processing to max 10Hz (every 100ms) to prevent main thread blocking
    // We only need Temp/Battery/Heater which change slowly.
    if (_lastDataProcessTime != null && now.difference(_lastDataProcessTime!).inMilliseconds < 100) {
      return;
    }
    _lastDataProcessTime = now;

    try {
      // 1. Minimal processing on arrival: Decode and Timestamp
      String rawString = utf8.decode(data, allowMalformed: true).trim();
      
      // 2. IMMEDIATE: Process Critical Low-Frequency Data (Temp/Battery/Heater)
      bool criticalUpdate = false;
      if (rawString.contains('T=') || rawString.contains('H:') || rawString.contains('BATT:')) {
         _parseCriticalData(rawString);
         criticalUpdate = true;
      }

      // 3. DELAYED: Process High-Frequency IMU Data - REMOVED
      
      // Throttle UI updates to ~5Hz (every 200ms)
      if (_lastUiUpdate == null || now.difference(_lastUiUpdate!).inMilliseconds > 200) {
        _lastUiUpdate = now;
        notifyListeners();
      }
      
    } catch (e) {
      debugPrint('❌ MCU BLE: Receive error: $e');
    }
  }

  DateTime? _lastHeaterCommandTime;

  /// Helper to parse only Temp, Heater, Battery
  void _parseCriticalData(String raw) {
      final parts = raw.split(' ');
      for (var part in parts) {
        if (part.startsWith('T=')) {
          String tempStr = part.substring(2).replaceAll('C', '');
          _temp = double.tryParse(tempStr) ?? _temp;
        } else if (part.startsWith('H:')) {
           // Skip update if we recently sent a command (ignore stale data for 2s)
           if (_lastHeaterCommandTime != null && 
               DateTime.now().difference(_lastHeaterCommandTime!).inMilliseconds < 2000) {
             continue;
           }

           if (part.contains('ON')) {
             _isHeaterOn = true;
           } else if (part.contains('OFF')) _isHeaterOn = false;
        } else if (part.startsWith('BATT:')) {
          final battVal = part.substring(5).replaceAll('%', '');
          final level = int.tryParse(battVal);
          if (level != null) _batteryLevel = level;
        }
      }
  }

  /// Parse and process the accumulated raw data - REMOVED
  // void _processRawBatch() { ... }

  /// Send raw command string to MCU
  Future<bool> sendCommand(String command) async {
    if (_writeChar == null) {
      debugPrint('❌ MCU BLE: Write characteristic not available');
      return false;
    }

    try {
      List<int> data = utf8.encode(command);
      debugPrint('📤 MCU TX: "$command"');
      await _writeChar!.write(data, withoutResponse: true);
      return true;
    } catch (e) {
      debugPrint('❌ MCU BLE: Write error: $e');
      return false;
    }
  }

  /// Set Heater ON/OFF (Manual Override)
  Future<bool> setHeaterState(bool on) async {
    // Optimistic update
    _isHeaterOn = on;
    _lastHeaterCommandTime = DateTime.now(); // Suppress incoming updates for a bit
    notifyListeners();
    // Firmware expects "ON" or "OFF"
    return await sendCommand(on ? 'ON' : 'OFF');
  }

  /// Set Heater to AUTO mode (Clear Override)
  Future<bool> setHeaterAuto() async {
    return await sendCommand('HEATER_AUTO');
  }

  /// Send temperature set point to MCU
  /// Format: "TEMP:25.5"
  Future<bool> setTemperature(double temperature) async {
    String tempString = temperature.toStringAsFixed(1);
    return await sendCommand('TEMP:$tempString');
  }

  /// Manually read current value from characteristic
  Future<String?> readCurrentValue() async {
    if (_notifyChar == null) return null;
    try {
      List<int> value = await _notifyChar!.read();
      if (value.isEmpty) return null;
      String rawString = utf8.decode(value, allowMalformed: true);
      _handleIncomingData(value);
      return rawString;
    } catch (e) {
      debugPrint('❌ MCU BLE: Read error: $e');
      return null;
    }
  }

  /// Clear raw data log
  void clearLog() {
    _rawDataLog.clear();
    notifyListeners();
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    try {
      await _dataSubscription?.cancel();
      _dataSubscription = null;
      
      // _warmupTimer?.cancel();
      // _isImuProcessingEnabled = false;

      if (_notifyChar != null && _isSubscribed) {
        await _notifyChar!.setNotifyValue(false);
      }

      _notifyChar = null;
      _writeChar = null;
      _currentData = null;
      _isConnected = false;
      _isSubscribed = false;

      notifyListeners();
      debugPrint('✅ MCU BLE: Disconnected');
    } catch (e) {
      debugPrint('❌ MCU BLE: Disconnect error: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    // _sensorBatchController.close();
    super.dispose();
  }
}

// class _RawPacket {
//   final DateTime timestamp;
//   final String data;
//   _RawPacket(this.timestamp, this.data);
// }

