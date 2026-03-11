import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BLE Service — production-ready BLE manager.
///
/// Responsibilities:
/// - Permission requests (Android 6-14+, iOS)
/// - Adapter state monitoring
/// - Foreground scanning
/// - Persistent auto-reconnect via native layer (no timeout = autoConnect=true)
/// - Saved-device persistence (SharedPrefs)
///
/// Usage:
/// 1. Call `initialize()` once at app startup.
/// 2. Call `autoConnectToLastDevice()` after init to restore the last session.
/// 3. Use `startScan()` / `stopScan()` from the Add-Device UI.
/// 4. Call `connectToDevice()` when user taps a discovered device.
/// 5. Call `disconnectDevice()` explicitly — this disables auto-reconnect.
class BleService extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // ── Internal state ───────────────────────────────────────────────────────
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  BleStatus _adapterState = BleStatus.unknown;
  BleStatus get adapterState => _adapterState;
  bool get isBluetoothOn => _adapterState == BleStatus.ready;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final Map<String, DiscoveredDevice> _discoveredDevices = {};
  List<DiscoveredDevice> get discoveredDevices =>
      _discoveredDevices.values.toList();

  // Active connection subscriptions (one per deviceId)
  final Map<String, StreamSubscription<ConnectionStateUpdate>>
      _connectionSubscriptions = {};

  // Devices currently in DeviceConnectionState.connected
  final Map<String, DiscoveredDevice> _connectedDevices = {};
  List<String> get connectedDeviceIds => _connectedDevices.keys.toList();

  // Persisted device list
  final List<SavedBleDevice> _previousDevices = [];
  List<SavedBleDevice> get previousDevices =>
      List.unmodifiable(_previousDevices);

  StreamSubscription<BleStatus>? _adapterStateSubscription;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  static const String _storageKey = 'ble_saved_devices';
  static const String _primaryIdKey = 'smart_spoon_id';

  bool _isInitialized = false;
  bool _autoReconnectEnabled = false;
  bool _suspended = false; // true while app is backgrounded — suppresses onDone reconnect

  // ── Initialization ───────────────────────────────────────────────────────

  /// Must be called once at app startup (idempotent).
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    debugPrint('🔵 BLE: Initializing...');
    await _loadSavedDevices();

    _adapterStateSubscription = _ble.statusStream.listen((status) {
      debugPrint('🔵 BLE adapter: $status');
      final wasReady = _adapterState == BleStatus.ready;
      _adapterState = status;
      notifyListeners();

      // If BT came back on and we have auto-reconnect pending, kick it off
      if (!wasReady && status == BleStatus.ready && _autoReconnectEnabled) {
        _restartPendingAutoConnects();
      }
    });

    debugPrint('🔵 BLE: Initialized. Adapter: $_adapterState');
  }

  // ── Permissions ──────────────────────────────────────────────────────────

  /// Returns true when all required BLE permissions are granted.
  /// Requests any that are denied.
  Future<bool> checkAndRequestPermissions() async {
    debugPrint('🔵 BLE: Checking permissions...');
    try {
      if (Platform.isAndroid) {
        return await _checkAndroidPermissions();
      } else if (Platform.isIOS) {
        // flutter_reactive_ble triggers the iOS Bluetooth prompt automatically.
        // For continuous background tracking, we request Location Always.
        var locStatus = await Permission.locationAlways.status;
        if (!locStatus.isGranted) {
           await Permission.locationWhenInUse.request();
           await Permission.locationAlways.request();
        }
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('❌ BLE: Permission check error: $e');
      return false;
    }
  }

  Future<bool> _checkAndroidPermissions() async {
    // Android 12+ (API 31+): BLUETOOTH_SCAN + BLUETOOTH_CONNECT
    // Android 6-11 (API 23-30): ACCESS_FINE_LOCATION
    // Android 11+ Background BT: ACCESS_BACKGROUND_LOCATION (locationAlways)
    final int sdkInt = await _getAndroidSdkInt();

    List<Permission> required;
    if (sdkInt >= 31) {
      // Android 12+: Only need bluetooth permissions for finding/connecting
      required = [Permission.bluetoothScan, Permission.bluetoothConnect];
    } else {
      // Location is required for BLE scanning on Android < 12
      required = [Permission.location];
    }

    for (final perm in required) {
      if (await perm.isDenied || await perm.isRestricted) {
        final result = await perm.request();
        if (!result.isGranted) {
           debugPrint('⚠️ BLE: Permission not granted gracefully: $perm');
           return false;
        }
      }
      if (await perm.isPermanentlyDenied) {
        debugPrint('❌ BLE: Permission permanently denied: $perm — opening settings');
        await openAppSettings();
        return false;
      }
    }

    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted && !notifStatus.isPermanentlyDenied) {
      await Permission.notification.request();
    }
    
    debugPrint('✅ BLE: All permissions granted');
    return true;
  }

  /// Reads android.os.Build.VERSION.SDK_INT via shared_preferences fallback.
  /// Uses defaultTargetPlatform for a safe fallback if the method call fails.
  Future<int> _getAndroidSdkInt() async {
    // flutter_reactive_ble wraps native layer; we can use permission_handler's
    // built-in SDK detection indirectly. Here we read from device info.
    // Simple heuristic: if bluetoothScan permission object exists, SDK >= 31.
    try {
      final status = await Permission.bluetoothScan.status;
      // If the permission exists and is not permanentlyDenied from a prior run,
      // we are on API 31+
      if (status != PermissionStatus.permanentlyDenied) {
        return 31;
      }
      return 30;
    } catch (_) {
      // On older Android the permission object may throw or return granted directly
      return 30; // safe fallback — will request location
    }
  }

  // ── Scanning ─────────────────────────────────────────────────────────────

  /// Start a foreground scan. Automatically stops after [timeout].
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_isScanning) {
      debugPrint('⚠️ BLE: Scan already running');
      return;
    }
    if (!isBluetoothOn) {
      debugPrint('❌ BLE: Cannot scan — Bluetooth is off');
      return;
    }

    final hasPerms = await checkAndRequestPermissions();
    if (!hasPerms) {
      debugPrint('❌ BLE: Cannot scan — permissions denied');
      return;
    }

    try {
      debugPrint('🔍 BLE: Starting scan (${timeout.inSeconds}s)...');
      _isScanning = true;
      // Scan with empty services — shows all nearby BLE devices.
      _scanSubscription = _ble
          .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
          .listen(
        (device) {
          if (!_discoveredDevices.containsKey(device.id)) {
            debugPrint('📱 BLE: Found ${device.name} (${device.id})');
            _discoveredDevices[device.id] = device;
            notifyListeners();
          }
        },
        onError: (Object error) {
          debugPrint('❌ BLE: Scan error: $error');
          _isScanning = false;
          notifyListeners();
        },
        onDone: () {
          _isScanning = false;
          notifyListeners();
        },
      );

      Future.delayed(timeout, () {
        if (_isScanning) stopScan();
      });
    } catch (e) {
      debugPrint('❌ BLE: Error starting scan: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    debugPrint('🛑 BLE: Stopping scan');
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  // ── Manual Connection ────────────────────────────────────────────────────

  /// Connect to a device the user just tapped in the UI.
  /// Saves the device and enables auto-reconnect for it.
  Future<void> connectToDevice(DiscoveredDevice device) async {
    final deviceId = device.id;
    debugPrint('🔗 BLE: Connecting to ${device.name} ($deviceId)...');

    // ⚠️ CRITICAL: Stop scanning BEFORE connecting.
    // Android cannot reliably scan and connect simultaneously — the scan
    // causes the connection stream to immediately report "disconnected".
    if (_isScanning) {
      debugPrint('🛑 BLE: Stopping scan before connect...');
      await stopScan();
      // Give the radio a moment to fully stop scanning
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // ⚠️ CRITICAL: Cancel ALL other autoConnect streams before direct connect.
    // Android's BLE stack has limited GATT client slots. An open autoConnect=true
    // stream for another device (e.g. an old/offline I-SPOON) consumes a slot and
    // blocks the direct connect from succeeding.
    // We rebuild these streams after the connection is established.
    final otherAutoConnects = _connectionSubscriptions.keys
        .where((id) => id != deviceId && !_connectedDevices.containsKey(id))
        .toList();
    if (otherAutoConnects.isNotEmpty) {
      debugPrint('⏸️ BLE: Pausing ${otherAutoConnects.length} autoConnect stream(s) for direct connect');
      for (final id in otherAutoConnects) {
        await _connectionSubscriptions[id]?.cancel();
        _connectionSubscriptions.remove(id);
      }
      // Android needs time to fully close GATT clients and release slots.
      // BluetoothGatt.close() is async at native level — 2 s is safe.
      await Future.delayed(const Duration(milliseconds: 2000));
    }

    // Cancel stale stream for THIS device (same MAC reconnect).
    if (_connectionSubscriptions.containsKey(deviceId)) {
      debugPrint('⚠️ BLE: Cancelling stale stream for ${device.name} before reconnecting');
      await _connectionSubscriptions[deviceId]?.cancel();
      _connectionSubscriptions.remove(deviceId);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _autoReconnectEnabled = true;
    _startConnectionStream(deviceId, device.name, device: device, directConnect: true);

    // Wait up to 20 s for connection (15 s direct + 2 s GATT teardown buffer).
    // Do NOT throw if the subscription disappears — onDone already schedules
    // a background autoConnect retry. Just report failure to the UI caller.
    int waitMs = 0;
    while (!isDeviceConnected(deviceId) && waitMs < 20000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitMs += 100;
    }

    if (!isDeviceConnected(deviceId)) {
      throw Exception('Connection timed out — retrying in background');
    }
  }

  // ── Auto-Reconnect ───────────────────────────────────────────────────────

  /// Call once at startup. Loads the last paired device and begins persistent
  /// auto-reconnect using the native BLE stack (no timeout = autoConnect=true).
  Future<void> autoConnectToLastDevice() async {
    if (_previousDevices.isEmpty) {
      await _loadSavedDevices();
    }
    if (_previousDevices.isEmpty) {
      debugPrint('🔵 BLE: No saved devices — skipping auto-connect');
      return;
    }

    // Wait up to 10 s for the BT adapter to become ready
    if (_adapterState != BleStatus.ready) {
      debugPrint('⏳ BLE: Waiting for adapter...');
      int waited = 0;
      while (_adapterState != BleStatus.ready && waited < 10000) {
        await Future.delayed(const Duration(milliseconds: 250));
        waited += 250;
      }
      if (_adapterState != BleStatus.ready) {
        debugPrint('❌ BLE: Adapter not ready after 10 s — deferring auto-connect');
        // Will be triggered again via the adapter state listener when BT turns on
        _autoReconnectEnabled = true;
        return;
      }
    }

    final hasPerms = await checkAndRequestPermissions();
    if (!hasPerms) {
      debugPrint('❌ BLE: Auto-connect skipped — permissions denied');
      return;
    }

    _autoReconnectEnabled = true;
    _suspended = false; // Clear suspension flag — main isolate owns BLE again
    for (final device in _previousDevices) {
      debugPrint('🔄 BLE: Starting auto-connect for ${device.name}');
      _startConnectionStream(device.id, device.name);
    }
  }

  /// Re-kick any device that should be auto-reconnecting but has no active stream.
  void _restartPendingAutoConnects() {
    if (!_autoReconnectEnabled || _previousDevices.isEmpty) return;
    for (final device in _previousDevices) {
      if (!_connectionSubscriptions.containsKey(device.id)) {
        debugPrint('🔄 BLE: Restarting auto-connect after BT re-enabled: ${device.name}');
        _startConnectionStream(device.id, device.name);
      }
    }
  }

  /// Core connection stream.
  /// [directConnect] = true: sets a 15 s timeout → Android uses autoConnect=false
  ///   (immediate direct connection attempt). Use for user-initiated connects.
  /// [directConnect] = false: no timeout → Android uses autoConnect=true
  ///   (OS keeps scanning forever). Use for background auto-reconnect only.
  void _startConnectionStream(
    String deviceId,
    String deviceName, {
    DiscoveredDevice? device,
    bool directConnect = false,
  }) {
    if (_connectionSubscriptions.containsKey(deviceId)) {
      debugPrint('🔄 BLE: Stream already active for $deviceName — skipping');
      return;
    }

    debugPrint('🔄 BLE: Opening connection stream for $deviceName ($deviceId) [direct=$directConnect]');

    _connectionSubscriptions[deviceId] = _ble
        .connectToDevice(
      id: deviceId,
      connectionTimeout: directConnect
          ? const Duration(seconds: 15) // autoConnect=false on Android
          : null,                        // autoConnect=true (background reconnect)
    )
        .listen(
      (state) {
        debugPrint(
            '📡 BLE: $deviceName → ${state.connectionState}');
        switch (state.connectionState) {
          case DeviceConnectionState.connected:
            _onDeviceConnected(deviceId, deviceName, device);
            break;
          case DeviceConnectionState.disconnected:
            _onDeviceDisconnected(deviceId);
            // Do NOT cancel the subscription here — the native layer keeps
            // scanning for the device and will emit `connected` again.
            break;
          case DeviceConnectionState.connecting:
          case DeviceConnectionState.disconnecting:
            break;
        }
      },
      onError: (Object error) {
        debugPrint('❌ BLE: Connection error for $deviceName: $error');
        _onDeviceDisconnected(deviceId);
        _connectionSubscriptions.remove(deviceId)?.cancel();

        // Retry with direct connect — device is nearby (user just tapped it)
        if (_autoReconnectEnabled && !_suspended) {
          debugPrint('🔄 BLE: Retrying $deviceName in 3 s...');
          Future.delayed(const Duration(seconds: 3), () {
            if (_autoReconnectEnabled && !_suspended &&
                !_connectedDevices.containsKey(deviceId)) {
              _startConnectionStream(deviceId, deviceName, device: device,
                  directConnect: directConnect);
            }
          });
        }
      },
      onDone: () {
        debugPrint('⚠️ BLE: Stream closed for $deviceName');
        _onDeviceDisconnected(deviceId);
        _connectionSubscriptions.remove(deviceId)?.cancel();

        // Stream closed = device out of range; switch to background autoConnect
        if (_autoReconnectEnabled && !_suspended &&
            !_connectedDevices.containsKey(deviceId)) {
          debugPrint('🔄 BLE: Rebuilding stream for $deviceName in 3 s...');
          Future.delayed(const Duration(seconds: 3), () {
            if (_autoReconnectEnabled && !_suspended &&
                !_connectedDevices.containsKey(deviceId)) {
              _startConnectionStream(deviceId, deviceName, device: device,
                  directConnect: false);
            }
          });
        }
      },
    );
  }

  // ── Connection Events ────────────────────────────────────────────────────

  void _onDeviceConnected(
    String deviceId,
    String deviceName,
    DiscoveredDevice? device,
  ) {
    if (_connectedDevices.containsKey(deviceId)) return; // Already tracked

    debugPrint('✅ BLE: Connected to $deviceName ($deviceId)');

    // Build a DiscoveredDevice placeholder if we don't have scan data
    final resolved = device ??
        DiscoveredDevice(
          id: deviceId,
          name: deviceName,
          serviceData: const {},
          manufacturerData: Uint8List(0),
          rssi: 0,
          serviceUuids: const [],
        );

    _connectedDevices[deviceId] = resolved;
    _saveDevice(resolved); // Update lastConnected timestamp
    notifyListeners();

    // Restart any autoConnect streams that were paused to allow this direct connect.
    _restartPendingAutoConnects();
  }

  void _onDeviceDisconnected(String deviceId) {
    if (!_connectedDevices.containsKey(deviceId)) return;
    debugPrint('🔌 BLE: Disconnected from $deviceId');
    _connectedDevices.remove(deviceId);
    notifyListeners();
  }

  // ── Explicit Disconnect ──────────────────────────────────────────────────

  /// User-initiated disconnect. Stops auto-reconnect for this device.
  Future<void> disconnectDevice(String deviceId) async {
    debugPrint('🔌 BLE: Explicitly disconnecting $deviceId');
    _autoReconnectEnabled = false;
    await _connectionSubscriptions[deviceId]?.cancel();
    _connectionSubscriptions.remove(deviceId);
    _connectedDevices.remove(deviceId);
    notifyListeners();
  }

  /// Forget a device: remove from storage and disconnect.
  Future<void> forgetDevice(String deviceId) async {
    await removeSavedDevice(deviceId);
    await disconnectDevice(deviceId);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool isDeviceConnected(String deviceId) =>
      _connectedDevices.containsKey(deviceId);

  DiscoveredDevice? getDeviceById(String deviceId) =>
      _connectedDevices[deviceId] ?? _discoveredDevices[deviceId];

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _saveDevice(DiscoveredDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = SavedBleDevice(
        id: device.id,
        name: device.name.isNotEmpty ? device.name : 'Unknown Device',
        lastConnected: DateTime.now(),
      );

      final existing =
          _previousDevices.where((d) => d.id != saved.id).toList();
      existing.insert(0, saved);
      final toSave = existing.take(10).toList();

      await prefs.setStringList(
          _storageKey, toSave.map((d) => d.toString()).toList());
      await prefs.setString(_primaryIdKey, device.id);
      // Sync the bg-service list so SmartSpoonBleService reconnects all spoons
      await prefs.setString('smart_spoon_ids',
          jsonEncode(toSave.map((d) => d.id).toList()));

      _previousDevices
        ..clear()
        ..addAll(toSave);

      notifyListeners();
      debugPrint('💾 BLE: Saved device: ${device.name}');
    } catch (e) {
      debugPrint('❌ BLE: Error saving device: $e');
    }
  }

  Future<void> _loadSavedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];

      _previousDevices.clear();
      final cleaned = <String>[];
      for (final s in list) {
        final d = SavedBleDevice.fromString(s);
        if (d != null) {
          _previousDevices.add(d);
          cleaned.add(s);
        }
      }

      // If we removed any stale entries, persist the clean list
      if (cleaned.length != list.length) {
        await prefs.setStringList(_storageKey, cleaned);
        debugPrint('🧹 BLE: Cleaned ${list.length - cleaned.length} stale device(s) from storage');
      }

      debugPrint('📂 BLE: Loaded ${_previousDevices.length} saved devices');
    } catch (e) {
      debugPrint('❌ BLE: Error loading saved devices: $e');
    }
  }

  Future<void> removeSavedDevice(String deviceId) async {
    _previousDevices.removeWhere((d) => d.id == deviceId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _storageKey, _previousDevices.map((d) => d.toString()).toList());
      // Sync the bg-service list
      await prefs.setString('smart_spoon_ids',
          jsonEncode(_previousDevices.map((d) => d.id).toList()));
    } catch (e) {
      debugPrint('❌ BLE: Error removing saved device: $e');
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadSavedDevices();
    notifyListeners();
  }

  // ── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    for (final sub in _connectionSubscriptions.values) {
      sub.cancel();
    }
    _connectionSubscriptions.clear();
    super.dispose();
  }
}

// ── SavedBleDevice ───────────────────────────────────────────────────────────

class SavedBleDevice {
  final String id;
  final String name;
  final DateTime lastConnected;

  const SavedBleDevice({
    required this.id,
    required this.name,
    required this.lastConnected,
  });

  /// Serialised as "id|name|isoTimestamp"
  @override
  String toString() => '$id|$name|${lastConnected.toIso8601String()}';

  static SavedBleDevice? fromString(String s) {
    try {
      final parts = s.split('|');
      if (parts.length < 3) return null;
      return SavedBleDevice(
        id: parts[0],
        name: parts[1],
        lastConnected: DateTime.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String get formattedLastConnected {
    final diff = DateTime.now().difference(lastConnected);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
