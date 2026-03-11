import 'dart:async';
import 'dart:math' show sqrt;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'ble_service.dart';
import 'smart_spoon_ble_service.dart'; // For kMcuServiceUuid / kMcuCharUuid

/// Parsed data from one MCU sample (1/10 of a BLE packet).
class McuSensorData {
  final double accelX, accelY, accelZ;
  final double gyroX, gyroY, gyroZ;
  double temperature; // mutable: updated after header parsing
  final DateTime timestamp;

  McuSensorData({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.temperature,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get accelMagnitude =>
      sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
  double get gyroMagnitude =>
      sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);
  double get linearAccel => (accelMagnitude - 1.0).abs();

  @override
  String toString() =>
      'A(${accelX.toStringAsFixed(3)},${accelY.toStringAsFixed(3)},${accelZ.toStringAsFixed(3)}) '
      'G(${gyroX.toStringAsFixed(3)},${gyroY.toStringAsFixed(3)},${gyroZ.toStringAsFixed(3)}) '
      'T:${temperature.toStringAsFixed(2)}°C';
}

/// MCU BLE Service — subscribes to IMU/sensor data from ALL already-connected
/// Smart Spoon devices and surfaces merged data to the UI layer.
///
/// Design contract:
/// - [BleService] owns the GATT connections. This service ONLY subscribes to
///   characteristics once BleService reports devices as connected.
/// - It does NOT open its own connectToDevice() streams — that avoids duplicate
///   GATT connections and the "two instances competing" bug.
/// - When BleService disconnects a device, this service cleans up that device's
///   subscription but keeps other devices' subscriptions running.
/// - Data from ALL connected spoons is merged into a single stream/state.
///
/// Packet format (ESP32 C struct, 132 bytes new / 127 bytes legacy):
///
///   [0]     battery   uint8
///   [1]     padding   (132-byte only)
///   [2-3]   temp      int16  LE  (÷100 → °C)
///   [4-7]   timestamp uint32 LE
///   [8-9]   biteCount uint16 LE  (132-byte only)
///   [10-131] 10×IMU   int16×6 each (÷1000 → g / deg·s⁻¹)
class McuBleService extends ChangeNotifier {
  // ── Internal state ───────────────────────────────────────────────────────
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final BleService _bleService = BleService();

  // Per-device subscriptions
  final Map<String, StreamSubscription<List<int>>> _charSubs = {};
  final Map<String, bool> _subscribing = {}; // re-entrancy guard per device

  // Merged/latest sensor state (from whichever device sent data most recently)
  McuSensorData? _currentData;
  double _temp = 0.0;
  int _batteryLevel = 0;
  int _hardwareBiteCount = 0;

  // Packet queue & processor
  final List<List<int>> _queue = [];
  Timer? _processorTimer;

  // Stats for debug screen
  List<int>? _lastRawPacket;
  DateTime? _lastPacketTime;
  int _receivedPackets = 0;
  double _packetsPerSecond = 0.0;
  double _dataRateBytesPerSec = 0.0;
  int _packetsThisSecond = 0;
  int _bytesThisSecond = 0;
  DateTime _statWindowStart = DateTime.now();

  // Rate-limit UI notifyListeners to 10 Hz (100 ms)
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  // Raw log (last 20 lines)
  final List<String> _rawLog = [];

  // Broadcast stream of batched sensor samples (for tremor / analytics)
  final StreamController<List<McuSensorData>> _batchController =
      StreamController<List<McuSensorData>>.broadcast();
  Stream<List<McuSensorData>> get sensorBatchStream =>
      _batchController.stream;

  // ── Public getters ───────────────────────────────────────────────────────
  bool get isConnected => _charSubs.isNotEmpty;
  bool get isSubscribed => _charSubs.isNotEmpty;
  /// Returns the first subscribed device ID, or null if none.
  String? get connectedDeviceId =>
      _charSubs.isNotEmpty ? _charSubs.keys.first : null;
  /// Returns all subscribed device IDs.
  Set<String> get subscribedDeviceIds => Set.unmodifiable(_charSubs.keys);
  int get batteryLevel => _batteryLevel;
  double get temperature => _temp;
  int get hardwareBiteCount => _hardwareBiteCount;
  McuSensorData? get currentData => _currentData;
  List<int>? get lastRawPacket => _lastRawPacket;
  DateTime? get lastPacketTime => _lastPacketTime;
  int get receivedPackets => _receivedPackets;
  double get packetsPerSecond => _packetsPerSecond;
  double get dataRate => _dataRateBytesPerSec;
  List<String> get rawDataLog => List.unmodifiable(_rawLog);

  // ── Constructor / lifecycle ──────────────────────────────────────────────

  McuBleService() {
    _bleService.addListener(_onBleServiceChanged);
    _onBleServiceChanged(); // Process current state on creation
  }

  @override
  void dispose() {
    _bleService.removeListener(_onBleServiceChanged);
    for (final sub in _charSubs.values) {
      sub.cancel();
    }
    _charSubs.clear();
    _stopProcessor();
    _batchController.close();
    super.dispose();
  }

  // ── BleService observer ──────────────────────────────────────────────────

  void _onBleServiceChanged() {
    final connected = _bleService.connectedDeviceIds;

    // Pause subscriptions for devices that have disconnected
    final toRemove = _charSubs.keys
        .where((id) => !connected.contains(id))
        .toList();
    for (final id in toRemove) {
      debugPrint('⚠️ MCU: BleService reports $id disconnected — pausing data sub');
      _pauseDataSubscription(id);
    }

    // Subscribe to newly connected devices not yet subscribed
    for (final id in connected) {
      if (!_charSubs.containsKey(id) && _subscribing[id] != true) {
        subscribeToDevice(id);
      }
    }
  }

  /// Pause only the data subscription for [deviceId].
  /// Keeps state for other devices intact.
  void _pauseDataSubscription(String deviceId) {
    _charSubs[deviceId]?.cancel();
    _charSubs.remove(deviceId);
    _subscribing.remove(deviceId);

    if (_charSubs.isEmpty) {
      _stopProcessor();
    }

    notifyListeners();

    // If BleService still reports the device as connected (e.g. characteristic
    // stream closed but GATT link is alive), schedule an immediate resubscribe
    // so data resumes without waiting for a disconnect/reconnect cycle.
    if (_bleService.connectedDeviceIds.contains(deviceId)) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (_subscribing[deviceId] != true &&
            !_charSubs.containsKey(deviceId) &&
            _bleService.connectedDeviceIds.contains(deviceId)) {
          debugPrint('🔄 MCU: Resubscribing after characteristic drop on $deviceId');
          subscribeToDevice(deviceId);
        }
      });
    }
  }

  // ── Subscription ─────────────────────────────────────────────────────────

  /// Subscribe to the IMU characteristic of an already-connected device.
  /// Safe to call for multiple devices simultaneously.
  Future<bool> subscribeToDevice(String deviceId) async {
    if (_subscribing[deviceId] == true) {
      debugPrint('⚠️ MCU: subscribeToDevice already in progress for $deviceId');
      return false;
    }
    // Already subscribed to this exact device
    if (_charSubs.containsKey(deviceId)) {
      if (_processorTimer == null || !_processorTimer!.isActive) {
        _startProcessor();
      }
      return true;
    }

    _subscribing[deviceId] = true;
    debugPrint('🔵 MCU: Subscribing to $deviceId…');

    try {
      // Request higher MTU — best-effort
      try {
        await _ble.requestMtu(deviceId: deviceId, mtu: 512);
        debugPrint('✅ MCU: MTU negotiated for $deviceId');
      } catch (_) {
        debugPrint('⚠️ MCU: MTU negotiation failed for $deviceId — continuing with default');
      }

      // Wait for GATT service discovery to settle post-connection.
      // Android needs 500ms+ after connected before GATT ops are reliable.
      await Future.delayed(const Duration(milliseconds: 600));

      // Discover the notifiable characteristic dynamically
      final characteristic = await _discoverNotifiableCharacteristic(deviceId);

      // Extra delay after discovery before subscribing — prevents silent
      // notification-enable failure on Android when GATT is still stabilising.
      await Future.delayed(const Duration(milliseconds: 300));
      if (characteristic == null) {
        debugPrint('❌ MCU: No notifiable characteristic found for $deviceId — aborting');
        _subscribing.remove(deviceId);
        notifyListeners();
        return false;
      }

      final sub = _ble.subscribeToCharacteristic(characteristic).listen(
        (data) {
          if (data.isNotEmpty) {
            _queue.add(data);
            // Cap queue to prevent unbounded growth (oldest discarded)
            if (_queue.length > 200) _queue.removeAt(0);
          }
        },
        onError: (Object error) {
          debugPrint('❌ MCU: Characteristic error on $deviceId: $error');
          _pauseDataSubscription(deviceId);
        },
        onDone: () {
          debugPrint('⚠️ MCU: Characteristic stream closed for $deviceId');
          _pauseDataSubscription(deviceId);
        },
      );

      _charSubs[deviceId] = sub;
      _subscribing.remove(deviceId);

      _startProcessor();

      debugPrint('✅ MCU: Subscribed to ${characteristic.characteristicId} on $deviceId');
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('❌ MCU: subscribeToDevice error for $deviceId: $e\n$st');
      _subscribing.remove(deviceId);
      notifyListeners();
      // Retry after 2 s if the GATT connection is still alive
      Future.delayed(const Duration(seconds: 2), () {
        if (_subscribing[deviceId] != true &&
            !_charSubs.containsKey(deviceId) &&
            _bleService.connectedDeviceIds.contains(deviceId)) {
          debugPrint('🔄 MCU: Retrying subscribe after error on $deviceId');
          subscribeToDevice(deviceId);
        }
      });
      return false;
    }
  }

  // ── Service discovery ────────────────────────────────────────────────────

  Future<QualifiedCharacteristic?> _discoverNotifiableCharacteristic(
      String deviceId) async {
    try {
      debugPrint('🔍 MCU: Discovering services on $deviceId…');
      await _ble.discoverAllServices(deviceId);
      final services = await _ble.getDiscoveredServices(deviceId);

      final targetServiceId = Uuid.parse(kMcuServiceUuid);
      final targetCharId = Uuid.parse(kMcuCharUuid);

      // First pass: match known UUID exactly
      for (final service in services) {
        if (service.id == targetServiceId) {
          for (final char in service.characteristics) {
            if (char.id == targetCharId && char.isNotifiable) {
              debugPrint('  ✅ MCU: Found known char $kMcuCharUuid');
              return QualifiedCharacteristic(
                serviceId: service.id,
                characteristicId: char.id,
                deviceId: deviceId,
              );
            }
          }
        }
      }

      // Second pass: any notifiable char in the known service
      for (final service in services) {
        if (service.id == targetServiceId) {
          for (final char in service.characteristics) {
            if (char.isNotifiable) {
              debugPrint('  ⚠️ MCU: Char UUID mismatch — using first notifiable in known service: ${char.id}');
              return QualifiedCharacteristic(
                serviceId: service.id,
                characteristicId: char.id,
                deviceId: deviceId,
              );
            }
          }
        }
      }

      // Last resort: hardcoded UUIDs
      debugPrint('⚠️ MCU: Known service not in discovery results — using hardcoded UUIDs');
      return QualifiedCharacteristic(
        serviceId: targetServiceId,
        characteristicId: targetCharId,
        deviceId: deviceId,
      );
    } catch (e) {
      debugPrint('❌ MCU: Service discovery error: $e — falling back to known UUIDs');
      return QualifiedCharacteristic(
        serviceId: Uuid.parse(kMcuServiceUuid),
        characteristicId: Uuid.parse(kMcuCharUuid),
        deviceId: deviceId,
      );
    }
  }

  // ── Data processor (5 Hz) ────────────────────────────────────────────────

  void _startProcessor() {
    if (_processorTimer?.isActive == true) return;
    _processorTimer?.cancel();
    // 5 Hz is smooth enough for UI updates and avoids ANR from main-thread load
    _processorTimer =
        Timer.periodic(const Duration(milliseconds: 200), (_) => _drain());
  }

  void _stopProcessor() {
    _processorTimer?.cancel();
    _processorTimer = null;
    _queue.clear();
  }

  void _drain() {
    if (_queue.isEmpty) return;

    final batch = <McuSensorData>[];
    final now = DateTime.now();
    int bytes = 0;
    int count = 0;

    while (_queue.isNotEmpty && count < 50) {
      final raw = _queue.removeAt(0);
      bytes += raw.length;
      count++;
      final samples = _parseMcuPacket(raw, now);
      if (samples.isNotEmpty) {
        batch.addAll(samples);
        _currentData = samples.last;
        _temp = samples.last.temperature;
      }
    }

    if (batch.isNotEmpty) {
      _batchController.add(batch);
    }

    // Update stats
    _receivedPackets += count;
    _packetsThisSecond += count;
    _bytesThisSecond += bytes;
    _lastPacketTime = now;

    final elapsed = now.difference(_statWindowStart).inMilliseconds;
    if (elapsed >= 1000) {
      _packetsPerSecond = _packetsThisSecond / (elapsed / 1000.0);
      _dataRateBytesPerSec = _bytesThisSecond / (elapsed / 1000.0);
      _packetsThisSecond = 0;
      _bytesThisSecond = 0;
      _statWindowStart = now;
    }

    // Throttle UI rebuilds to 10 Hz
    if (now.difference(_lastNotify).inMilliseconds >= 100) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  // ── Packet parsing ───────────────────────────────────────────────────────

  List<McuSensorData> _parseMcuPacket(List<int> data, DateTime ts) {
    if (data.length < 20) return [];

    try {
      _lastRawPacket = data;
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      final bd = ByteData.sublistView(bytes);
      int offset = 0;

      // ── Header ──────────────────────────────────────────────────────────
      // ESP32 firmware (current, 129 bytes):
      //   struct BlePacket {
      //     uint8_t  battery;       [0]     1 byte
      //     int16_t  temperature;   [1-2]   2 bytes  (×100 → °C)
      //     uint32_t timestamp;     [3-6]   4 bytes
      //     uint16_t bite_count;    [7-8]   2 bytes
      //     ImuSample samples[10];  [9-128] 120 bytes  (int16×6 each)
      //   }  Total = 129 bytes
      //
      // Legacy firmware (127 bytes, no bite count):
      //   [0]   battery  uint8
      //   [1-2] temp     int16 LE
      //   [3-6] ts       uint32 LE
      //   [7-126] 10×IMU
      //
      // Old firmware (132 bytes, explicit padding):
      //   [0]   battery  uint8
      //   [1]   _pad1
      //   [2-3] temp     int16 LE
      //   [4-7] ts       uint32 LE
      //   [8-9] bites    uint16 LE
      //   [10-11] _pad2
      //   [12-131] 10×IMU

      _batteryLevel = bd.getUint8(0);

      if (data.length == 129) {
        // Current ESP32 firmware — packed struct, no padding
        final tempRaw = bd.getInt16(1, Endian.little);
        _temp = tempRaw / 100.0;
        // skip timestamp [3-6]
        final newBiteCount = bd.getUint16(7, Endian.little);
        if (newBiteCount != _hardwareBiteCount) {
          _hardwareBiteCount = newBiteCount;
          debugPrint('🍴 MCU: Bite count → $_hardwareBiteCount');
        }
        offset = 9; // IMU samples start at byte 9
      } else if (data.length == 132) {
        // Old firmware — padded struct
        final tempRaw = bd.getInt16(2, Endian.little);
        _temp = tempRaw / 100.0;
        final newBiteCount = bd.getUint16(8, Endian.little);
        if (newBiteCount != _hardwareBiteCount) {
          _hardwareBiteCount = newBiteCount;
          debugPrint('🍴 MCU: Bite count → $_hardwareBiteCount');
        }
        offset = 12;
      } else {
        // Legacy firmware — no bite count
        final tempRaw = bd.getInt16(1, Endian.little);
        _temp = tempRaw / 100.0;
        offset = 7;
      }

      // ── IMU Samples ──────────────────────────────────────────────────────
      final remaining = data.length - offset;
      final sampleCount = remaining ~/ 12;
      if (sampleCount == 0) return [];

      const int sampleIntervalMs = 10; // 100 Hz firmware sample rate
      final samples = <McuSensorData>[];

      for (int i = 0; i < sampleCount; i++) {
        // Accel: firmware sends (accX * 1000) as milli-g → divide by 1000 to get g
        final ax = bd.getInt16(offset, Endian.little) / 1000.0; offset += 2;
        final ay = bd.getInt16(offset, Endian.little) / 1000.0; offset += 2;
        final az = bd.getInt16(offset, Endian.little) / 1000.0; offset += 2;
        // Gyro: firmware sends (gyrX * 100) as 0.01 dps units → divide by 100 to get dps
        final gx = bd.getInt16(offset, Endian.little) / 100.0; offset += 2;
        final gy = bd.getInt16(offset, Endian.little) / 100.0; offset += 2;
        final gz = bd.getInt16(offset, Endian.little) / 100.0; offset += 2;

        // Back-date each sample so they're evenly spaced before `ts`
        final sampleTs = ts.subtract(
            Duration(milliseconds: (sampleCount - 1 - i) * sampleIntervalMs));

        samples.add(McuSensorData(
          accelX: ax,
          accelY: ay,
          accelZ: az,
          gyroX: gx,
          gyroY: gy,
          gyroZ: gz,
          temperature: _temp,
          timestamp: sampleTs,
        ));
      }

      // Append to raw log (capped at 20 entries)
      if (_rawLog.length >= 20) _rawLog.removeAt(0);
      _rawLog.add(
          '${ts.toIso8601String()} — $sampleCount samples — '
          '${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

      return samples;
    } catch (e, st) {
      debugPrint('❌ MCU: Parse error: $e\n$st');
      return [];
    }
  }

  // ── Heater control ───────────────────────────────────────────────────────

  /// Send a heater command to the MCU via the NRF write characteristic.
  /// Sends to all connected devices.
  Future<bool> setHeaterParameters(int targetTemp, int maxTemp) async {
    if (_charSubs.isEmpty) {
      debugPrint('❌ MCU: Cannot set heater — not connected');
      return false;
    }
    // Safety: reject out-of-range temperatures before sending to hardware
    if (targetTemp > 0 && (targetTemp < 30 || targetTemp > 95)) {
      debugPrint('❌ MCU: Heater targetTemp $targetTemp out of safe range (30–95°C)');
      return false;
    }
    final payload = targetTemp > 0 ? 'ON $targetTemp' : 'OFF';
    debugPrint('🔥 MCU: Heater → "$payload" (${_charSubs.length} device(s))');

    bool anySuccess = false;
    for (final deviceId in _charSubs.keys) {
      try {
        final char = QualifiedCharacteristic(
          serviceId: Uuid.parse(kMcuServiceUuid),
          characteristicId: Uuid.parse(kMcuCharUuid),
          deviceId: deviceId,
        );
        await _ble.writeCharacteristicWithResponse(
            char, value: payload.codeUnits);
        anySuccess = true;
      } catch (e) {
        debugPrint('❌ MCU: Heater write failed on $deviceId: $e');
      }
    }
    return anySuccess;
  }

  // ── Explicit disconnect ──────────────────────────────────────────────────

  /// Disconnect all devices and clear all state.
  Future<void> disconnect() async {
    debugPrint('🔴 MCU: Disconnect all (${_charSubs.length} device(s))');
    for (final sub in _charSubs.values) {
      sub.cancel();
    }
    _charSubs.clear();
    _subscribing.clear();
    _stopProcessor();
    _currentData = null;
    _lastRawPacket = null;
    _lastPacketTime = null;
    _receivedPackets = 0;
    _packetsPerSecond = 0.0;
    _dataRateBytesPerSec = 0.0;
    _hardwareBiteCount = 0;
    notifyListeners();
  }

  /// Disconnect a specific device only.
  Future<void> disconnectDevice(String deviceId) async {
    debugPrint('🔴 MCU: Disconnect $deviceId');
    _charSubs[deviceId]?.cancel();
    _charSubs.remove(deviceId);
    _subscribing.remove(deviceId);
    if (_charSubs.isEmpty) {
      _stopProcessor();
    }
    notifyListeners();
  }

  void clearLog() {
    _rawLog.clear();
    notifyListeners();
  }
}
