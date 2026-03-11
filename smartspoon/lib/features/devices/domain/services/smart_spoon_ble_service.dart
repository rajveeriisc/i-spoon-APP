import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smartspoon/firebase_options.dart';
import 'package:geolocator/geolocator.dart';

// ─── Service UUIDs — must match ESP32 firmware exactly ────────
const String kMcuServiceUuid = 'ab907856-3412-3412-3412-341278563412';
const String kMcuCharUuid    = 'ac907856-3412-3412-3412-341278563412';

/// SharedPreferences key for storing the list of paired spoon device IDs.
const String _kSpoonDeviceIdsKey = 'smart_spoon_ids';

// ─── SharedPreferences keys for background→foreground data bridge ─────────
/// Written by background isolate, read by foreground UnifiedDataService.
const String kBgBiteCount   = 'bg_bite_count';    // int
const String kBgAvgAccel    = 'bg_avg_accel';     // double (average accel magnitude)
const String kBgUpdatedAt   = 'bg_updated_at';    // int (millisecondsSinceEpoch)
const String kBgBattery     = 'bg_battery';       // int (0–100)
const String kBgTemperature = 'bg_temperature';   // double (°C)

/// SmartSpoonBleService — background BLE coordinator.
///
/// Supports multiple simultaneous spoon connections.
///
/// Responsibilities:
/// - Android: Starts a persistent foreground service (separate Dart isolate)
///   that connects to all saved spoons and uploads raw data to Firestore.
/// - iOS: Keeps connection requests alive on the main thread for all spoons.
///   The `bluetooth-central` background mode allows iOS to wake the app
///   when data arrives on a subscribed characteristic.
///
/// KEY DESIGN DECISIONS:
/// - Only runs when the app is in the background / terminated.
/// - Coordinates with [BleService] to AVOID double-connecting when the app is
///   in the foreground (Android isolate is a separate Dart VM — no shared state,
///   so the foreground-service upload path is intentionally separate from the
///   in-process McuBleService path).
class SmartSpoonBleService {
  static final SmartSpoonBleService _instance =
      SmartSpoonBleService._internal();
  factory SmartSpoonBleService() => _instance;
  SmartSpoonBleService._internal();

  // iOS-only: per-device connection & data subscriptions
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final Map<String, StreamSubscription<ConnectionStateUpdate>> _iosConnectionSubs = {};
  final Map<String, StreamSubscription<List<int>>> _iosDataSubs = {};
  StreamSubscription<Position>? _locationSub;
  List<String> _spoonDeviceIds = [];
  bool _iosMonitoringActive = false;
  Timer? _heartbeatTimer;

  // ── Public API ────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      try {
        FlutterForegroundTask.sendDataToTask({'action': 'heartbeat'});
      } catch (e) {
        // ignore
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Call once at app startup, after Firebase is initialized.
  /// Loads all saved device IDs and sets up platform-specific background tracking.
  Future<void> startBackgroundMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    _spoonDeviceIds = _loadDeviceIds(prefs);

    if (_spoonDeviceIds.isEmpty) {
      // Migrate legacy single-device key if present
      final legacy = prefs.getString('smart_spoon_id');
      if (legacy != null && legacy.isNotEmpty) {
        _spoonDeviceIds = [legacy];
        await _saveDeviceIds(prefs, _spoonDeviceIds);
        await prefs.remove('smart_spoon_id');
        debugPrint('🔵 BG BLE: Migrated legacy device ID $legacy');
      } else {
        debugPrint('🔵 BG BLE: No paired devices — background monitoring skipped');
        return;
      }
    }

    debugPrint('🔵 BG BLE: Starting background monitoring for ${_spoonDeviceIds.length} device(s)');

    if (Platform.isAndroid) {
      await _initAndroidForegroundService();
      _startHeartbeat();
      debugPrint('🔵 BG BLE: Foreground service tracking started');
    } else if (Platform.isIOS) {
      _startIosConnectionRequests();
    }
  }

  /// Call when the app comes to the foreground.
  Future<void> onAppForegrounded() async {
    debugPrint('🔵 BG BLE: App foregrounded');
    if (Platform.isAndroid) {
      _startHeartbeat();
    }
    // iOS: keep connections running when foregrounded
  }

  /// Call when the app goes to the background.
  Future<void> onAppBackgrounded() async {
    debugPrint('🔵 BG BLE: App backgrounded');
    if (Platform.isAndroid) {
      _stopHeartbeat();
      FlutterForegroundTask.sendDataToTask({'action': 'resume'});
    } else if (Platform.isIOS) {
      if (_spoonDeviceIds.isNotEmpty && !_iosMonitoringActive) {
        _startIosConnectionRequests();
      }
    }
  }

  Future<void> stopBackgroundMonitoring() async {
    debugPrint('🔵 BG BLE: Stopping background monitoring');
    _stopHeartbeat();
    if (Platform.isAndroid) {
      await FlutterForegroundTask.stopService();
    }
    await _stopIosConnectionRequests();
  }

  // ── iOS Connection Requests ────────────────────────────────────────────────

  void _startIosConnectionRequests() {
    if (_spoonDeviceIds.isEmpty || _iosMonitoringActive) return;
    _iosMonitoringActive = true;
    debugPrint('🍎 iOS BLE: Starting background connection requests for ${_spoonDeviceIds.length} device(s)');
    _startIosLocationHack();
    for (final id in _spoonDeviceIds) {
      _iosConnect(id);
    }
  }

  Future<void> _startIosLocationHack() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        _locationSub ??= Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            distanceFilter: 100,
          ),
        ).listen((_) {});
        debugPrint('🍎 iOS BLE: Location stream started to keep app awake');
      }
    } catch (e) {
      debugPrint('🍎 iOS BLE: Location stream err: $e');
    }
  }

  void _iosConnect(String deviceId) {
    if (!_iosMonitoringActive) return;

    final serviceUuid = Uuid.parse(kMcuServiceUuid);
    final charUuid = Uuid.parse(kMcuCharUuid);

    _iosConnectionSubs[deviceId]?.cancel();
    _iosConnectionSubs.remove(deviceId);

    debugPrint('🍎 iOS BLE: Attempting connection to $deviceId');

    final sub = _ble
        .connectToDevice(
      id: deviceId,
      servicesWithCharacteristicsToDiscover: {
        serviceUuid: [charUuid]
      },
      connectionTimeout: const Duration(seconds: 15),
    )
        .listen(
      (state) {
        if (state.connectionState == DeviceConnectionState.connected) {
          debugPrint('🍎 iOS BLE: Connected to $deviceId in background');
          _iosDataSubs[deviceId]?.cancel();
          _iosDataSubs[deviceId] = _ble
              .subscribeToCharacteristic(QualifiedCharacteristic(
                serviceId: serviceUuid,
                characteristicId: charUuid,
                deviceId: deviceId,
              ))
              .listen(
            (data) => _uploadRawData(data),
            onError: (Object e) {
              debugPrint('🍎 iOS BLE: Data stream error on $deviceId: $e');
              _iosDataSubs[deviceId]?.cancel();
              _iosDataSubs.remove(deviceId);
              if (_iosMonitoringActive) {
                Future.delayed(const Duration(seconds: 3), () => _iosConnect(deviceId));
              }
            },
            onDone: () {
              debugPrint('🍎 iOS BLE: Data stream closed for $deviceId');
              _iosDataSubs[deviceId]?.cancel();
              _iosDataSubs.remove(deviceId);
              if (_iosMonitoringActive) {
                Future.delayed(const Duration(seconds: 3), () => _iosConnect(deviceId));
              }
            },
          );
        } else if (state.connectionState == DeviceConnectionState.disconnected) {
          debugPrint('🍎 iOS BLE: $deviceId disconnected — will retry');
          _iosDataSubs[deviceId]?.cancel();
          _iosDataSubs.remove(deviceId);
        }
      },
      onError: (Object e) {
        debugPrint('🍎 iOS BLE: Connection error on $deviceId: $e');
        _iosDataSubs[deviceId]?.cancel();
        _iosDataSubs.remove(deviceId);
        _iosConnectionSubs[deviceId]?.cancel();
        _iosConnectionSubs.remove(deviceId);
        if (_iosMonitoringActive) {
          Future.delayed(const Duration(seconds: 3), () => _iosConnect(deviceId));
        }
      },
      onDone: () {
        debugPrint('🍎 iOS BLE: Connection stream ended for $deviceId — retrying in 3 s');
        _iosConnectionSubs[deviceId]?.cancel();
        _iosConnectionSubs.remove(deviceId);
        if (_iosMonitoringActive) {
          Future.delayed(const Duration(seconds: 3), () => _iosConnect(deviceId));
        }
      },
    );

    _iosConnectionSubs[deviceId] = sub;
  }

  Future<void> _stopIosConnectionRequests() async {
    _iosMonitoringActive = false;
    for (final sub in _iosDataSubs.values) {
      await sub.cancel();
    }
    for (final sub in _iosConnectionSubs.values) {
      await sub.cancel();
    }
    await _locationSub?.cancel();
    _iosDataSubs.clear();
    _iosConnectionSubs.clear();
    _locationSub = null;
    debugPrint('🍎 iOS BLE: All background connection requests stopped');
  }

  // ── Android Foreground Service ────────────────────────────────────────────

  Future<void> _initAndroidForegroundService() async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'spoon_ble_channel',
          channelName: 'Smart Spoon',
          channelDescription: 'Keeps BLE connection alive in the background',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(10000),
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );

      final alreadyIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!alreadyIgnoring) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) {
        await FlutterForegroundTask.startService(
          notificationTitle: 'i-Spoon',
          notificationText: 'Looking for your Smart Spoon…',
          callback: _foregroundEntryPoint,
        );
        debugPrint('🤖 Android FGS: Service started');
      } else {
        debugPrint('🤖 Android FGS: Service already running');
      }
    } catch (e) {
      debugPrint('❌ Android FGS: Failed to start: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _foregroundEntryPoint() {
    FlutterForegroundTask.setTaskHandler(SpoonTaskHandler());
  }
}

// ─── SharedPreferences helpers ────────────────────────────────────────────────

List<String> _loadDeviceIds(SharedPreferences prefs) {
  try {
    final json = prefs.getString(_kSpoonDeviceIdsKey);
    if (json == null || json.isEmpty) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  } catch (_) {
    return [];
  }
}

Future<void> _saveDeviceIds(SharedPreferences prefs, List<String> ids) async {
  await prefs.setString(_kSpoonDeviceIdsKey, jsonEncode(ids));
}

// ─── Android Isolate Task Handler ────────────────────────────────────────────
//
// This class runs in a SEPARATE Dart isolate from the main UI.
// It has NO access to any Provider, BleService, or McuBleService instances.
// It maintains its own BLE connections purely for background data upload.

class SpoonTaskHandler extends TaskHandler {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final Uuid _serviceUuid = Uuid.parse(kMcuServiceUuid);
  final Uuid _charUuid    = Uuid.parse(kMcuCharUuid);

  List<String> _deviceIds = [];

  // Per-device connection state
  final Map<String, StreamSubscription<ConnectionStateUpdate>> _connSubs = {};
  final Map<String, StreamSubscription<List<int>>> _dataSubs = {};
  final Map<String, DeviceConnectionState> _states = {};
  final Map<String, bool> _connecting = {};

  DateTime _lastHeartbeat = DateTime.now();

  // Packet accumulator — parsed inline, written to SharedPrefs every 10s
  int _bgBiteCount = 0;
  double _bgAccelSum = 0;
  int _bgAccelSamples = 0;
  int _bgBattery = 0;
  double _bgTemperature = 0;
  DateTime _lastBgWrite = DateTime.fromMillisecondsSinceEpoch(0);

  // ── TaskHandler lifecycle ─────────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (e) {
      debugPrint('[BG] Firebase init failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    _deviceIds = _loadDeviceIds(prefs);

    // Migrate legacy single-device key
    if (_deviceIds.isEmpty) {
      final legacy = prefs.getString('smart_spoon_id');
      if (legacy != null && legacy.isNotEmpty) {
        _deviceIds = [legacy];
        await _saveDeviceIds(prefs, _deviceIds);
        await prefs.remove('smart_spoon_id');
      }
    }

    if (_deviceIds.isEmpty) {
      debugPrint('[BG] No paired devices — foreground service idle');
      return;
    }

    debugPrint('[BG] Started by $starter — ${_deviceIds.length} device(s) — waiting for background confirmation');
    // Do not immediately connect here to avoid GATT race with foreground app.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final diff = DateTime.now().difference(_lastHeartbeat);
    if (diff.inSeconds > 15) {
      // App is backgrounded: rebuild any dead streams
      for (final id in _deviceIds) {
        if (_connSubs[id] == null && _connecting[id] != true) {
          _connecting[id] = false;
          debugPrint('[BG] Tick: app backgrounded, rebuilding BLE stream for $id');
          _connectAndStream(id);
        }
      }
    } else {
      // App is foregrounded: yield BLE radio
      final hasActiveConnections = _connSubs.isNotEmpty ||
          _connecting.values.any((v) => v);
      if (hasActiveConnections) {
        debugPrint('[BG] Tick: app foregrounded, yielding all BLE streams');
        _tearDownAllBle();
      }
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final action = data['action'] as String?;
      if (action == 'heartbeat') {
        _lastHeartbeat = DateTime.now();
        final hasActive = _connSubs.isNotEmpty || _connecting.values.any((v) => v);
        if (hasActive) {
          debugPrint('[BG] Heartbeat rx: app foregrounded, yielding BLE streams');
          _tearDownAllBle();
        }
      } else if (action == 'resume') {
        for (final id in _deviceIds) {
          if (_connSubs[id] == null && _connecting[id] != true) {
            _connecting[id] = false;
            _connectAndStream(id);
          }
        }
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _tearDownAllBle();
  }

  // ── BLE Logic ─────────────────────────────────────────────────────────────

  void _connectAndStream(String deviceId) {
    if (_connSubs[deviceId] != null || _connecting[deviceId] == true) return;
    _connecting[deviceId] = true;

    _states[deviceId] = DeviceConnectionState.connecting;
    _updateNotification();

    _connSubs[deviceId] = _ble
        .connectToDevice(
      id: deviceId,
      servicesWithCharacteristicsToDiscover: {
        _serviceUuid: [_charUuid]
      },
      connectionTimeout: null, // autoConnect=true — OS keeps retrying in background
    )
        .listen(
      (update) => _onConnectionState(deviceId, update),
      onError: (Object e) {
        debugPrint('[BG] BLE error on $deviceId: $e');
        _states[deviceId] = DeviceConnectionState.disconnected;
        _connecting[deviceId] = false;
        _cleanUpConnSub(deviceId);
        Future.delayed(const Duration(seconds: 3), () => _connectAndStream(deviceId));
      },
      onDone: () {
        debugPrint('[BG] BLE stream done for $deviceId');
        _states[deviceId] = DeviceConnectionState.disconnected;
        _connecting[deviceId] = false;
        _cleanUpConnSub(deviceId);
        Future.delayed(const Duration(seconds: 3), () => _connectAndStream(deviceId));
      },
    );
  }

  void _onConnectionState(String deviceId, ConnectionStateUpdate update) {
    _states[deviceId] = update.connectionState;
    debugPrint('[BG] $deviceId state: ${update.connectionState}');

    switch (update.connectionState) {
      case DeviceConnectionState.connected:
        _connecting[deviceId] = false;
        _updateNotification();
        _subscribeToData(deviceId);
        _triggerNotification(deviceId: deviceId, connected: true);
        break;

      case DeviceConnectionState.disconnected:
        _updateNotification();
        _dataSubs[deviceId]?.cancel();
        _dataSubs.remove(deviceId);
        _triggerNotification(deviceId: deviceId, connected: false);
        break;

      default:
        break;
    }
  }

  void _subscribeToData(String deviceId) {
    _dataSubs[deviceId]?.cancel();
    _dataSubs[deviceId] = _ble
        .subscribeToCharacteristic(QualifiedCharacteristic(
          serviceId: _serviceUuid,
          characteristicId: _charUuid,
          deviceId: deviceId,
        ))
        .listen(
      (data) => _processPacket(data),
      onError: (Object e) {
        debugPrint('[BG] Data stream error on $deviceId: $e');
        _dataSubs[deviceId]?.cancel();
        _dataSubs.remove(deviceId);
      },
      onDone: () {
        debugPrint('[BG] Data stream closed for $deviceId');
        _dataSubs[deviceId]?.cancel();
        _dataSubs.remove(deviceId);
      },
    );
  }

  /// Parse a 129-byte ESP32 packet inline and accumulate stats.
  /// Writes results to SharedPreferences every 10 seconds.
  void _processPacket(List<int> data) {
    if (data.length < 9) return;
    try {
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      final bd = ByteData.sublistView(bytes);

      _bgBattery = bd.getUint8(0);

      // 129-byte packed struct
      int biteCount;
      int imuOffset;
      if (data.length == 129) {
        final tempRaw = bd.getInt16(1, Endian.little);
        _bgTemperature = tempRaw / 100.0;
        biteCount = bd.getUint16(7, Endian.little);
        imuOffset = 9;
      } else if (data.length == 132) {
        final tempRaw = bd.getInt16(2, Endian.little);
        _bgTemperature = tempRaw / 100.0;
        biteCount = bd.getUint16(8, Endian.little);
        imuOffset = 12;
      } else {
        final tempRaw = bd.getInt16(1, Endian.little);
        _bgTemperature = tempRaw / 100.0;
        biteCount = 0;
        imuOffset = 7;
      }

      if (biteCount > _bgBiteCount) _bgBiteCount = biteCount;

      // Accumulate accel magnitude from each IMU sample (int16÷1000 = g)
      final remaining = data.length - imuOffset;
      final sampleCount = remaining ~/ 12;
      for (int i = 0; i < sampleCount; i++) {
        final o = imuOffset + i * 12;
        final ax = bd.getInt16(o,     Endian.little) / 1000.0;
        final ay = bd.getInt16(o + 2, Endian.little) / 1000.0;
        final az = bd.getInt16(o + 4, Endian.little) / 1000.0;
        _bgAccelSum += sqrt(ax * ax + ay * ay + az * az);
        _bgAccelSamples++;
      }
    } catch (e) {
      debugPrint('[BG] Packet parse error: $e');
    }

    // Write to SharedPreferences every 10 seconds
    final now = DateTime.now();
    if (now.difference(_lastBgWrite).inSeconds >= 10) {
      _lastBgWrite = now;
      _writeBgStats();
    }
  }

  Future<void> _writeBgStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final avgAccel = _bgAccelSamples > 0 ? _bgAccelSum / _bgAccelSamples : 0.0;
      await prefs.setInt(kBgBiteCount, _bgBiteCount);
      await prefs.setDouble(kBgAvgAccel, avgAccel);
      await prefs.setInt(kBgUpdatedAt, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(kBgBattery, _bgBattery);
      await prefs.setDouble(kBgTemperature, _bgTemperature);
      // Reset accumulator after writing
      _bgAccelSum = 0;
      _bgAccelSamples = 0;
      debugPrint('[BG] Stats written: bites=$_bgBiteCount avgAccel=${avgAccel.toStringAsFixed(3)} temp=${_bgTemperature.toStringAsFixed(1)}°C bat=$_bgBattery%');
    } catch (e) {
      debugPrint('[BG] SharedPrefs write failed: $e');
    }
  }

  void _tearDownAllBle() {
    for (final sub in _dataSubs.values) {
      sub.cancel();
    }
    for (final sub in _connSubs.values) {
      sub.cancel();
    }
    _dataSubs.clear();
    _connSubs.clear();
    _connecting.clear();
    for (final id in _deviceIds) {
      _states[id] = DeviceConnectionState.disconnected;
    }
  }

  void _cleanUpConnSub(String deviceId) {
    _connSubs[deviceId]?.cancel();
    _connSubs.remove(deviceId);
  }

  void _updateNotification() {
    final connectedCount = _states.values
        .where((s) => s == DeviceConnectionState.connected)
        .length;
    final text = connectedCount > 0
        ? 'Connected to $connectedCount spoon(s)'
        : 'Looking for your Smart Spoon…';
    FlutterForegroundTask.updateService(
      notificationTitle: 'i-Spoon',
      notificationText: text,
    );
  }

  void _triggerNotification({required String deviceId, required bool connected}) {
    FlutterForegroundTask.updateService(
      notificationTitle: connected ? 'i-Spoon — Connected' : 'i-Spoon',
      notificationText: connected
          ? 'Your Smart Spoon is ready.'
          : 'Connection lost — searching…',
    );
  }

  // Notification callbacks — required by TaskHandler interface
  @override
  void onNotificationButtonPressed(String id) {}
  @override
  void onNotificationPressed() {}
}

// ─── iOS background data handler ─────────────────────────────────────────────
// On iOS the app runs on the main isolate even in the background, so we write
// directly to SharedPreferences (same as the Android isolate does).

int _iosBgBiteCount = 0;
double _iosAccelSum = 0;
int _iosAccelSamples = 0;
int _iosBattery = 0;
double _iosTemperature = 0;
DateTime _iosLastWrite = DateTime.fromMillisecondsSinceEpoch(0);

Future<void> _uploadRawData(List<int> data) async {
  if (data.length < 9) return;
  try {
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    final bd = ByteData.sublistView(bytes);

    _iosBattery = bd.getUint8(0);

    int biteCount;
    int imuOffset;
    if (data.length == 129) {
      _iosTemperature = bd.getInt16(1, Endian.little) / 100.0;
      biteCount = bd.getUint16(7, Endian.little);
      imuOffset = 9;
    } else if (data.length == 132) {
      _iosTemperature = bd.getInt16(2, Endian.little) / 100.0;
      biteCount = bd.getUint16(8, Endian.little);
      imuOffset = 12;
    } else {
      _iosTemperature = bd.getInt16(1, Endian.little) / 100.0;
      biteCount = 0;
      imuOffset = 7;
    }

    if (biteCount > _iosBgBiteCount) _iosBgBiteCount = biteCount;

    final remaining = data.length - imuOffset;
    final sampleCount = remaining ~/ 12;
    for (int i = 0; i < sampleCount; i++) {
      final o = imuOffset + i * 12;
      final ax = bd.getInt16(o,     Endian.little) / 1000.0;
      final ay = bd.getInt16(o + 2, Endian.little) / 1000.0;
      final az = bd.getInt16(o + 4, Endian.little) / 1000.0;
      _iosAccelSum += sqrt(ax * ax + ay * ay + az * az);
      _iosAccelSamples++;
    }
  } catch (e) {
    debugPrint('[iOS BG] Packet parse error: $e');
  }

  final now = DateTime.now();
  if (now.difference(_iosLastWrite).inSeconds >= 10) {
    _iosLastWrite = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      final avgAccel = _iosAccelSamples > 0 ? _iosAccelSum / _iosAccelSamples : 0.0;
      await prefs.setInt(kBgBiteCount, _iosBgBiteCount);
      await prefs.setDouble(kBgAvgAccel, avgAccel);
      await prefs.setInt(kBgUpdatedAt, now.millisecondsSinceEpoch);
      await prefs.setInt(kBgBattery, _iosBattery);
      await prefs.setDouble(kBgTemperature, _iosTemperature);
      _iosAccelSum = 0;
      _iosAccelSamples = 0;
      debugPrint('[iOS BG] Stats written: bites=$_iosBgBiteCount avgAccel=${avgAccel.toStringAsFixed(3)}');
    } catch (e) {
      debugPrint('[iOS BG] SharedPrefs write failed: $e');
    }
  }
}
