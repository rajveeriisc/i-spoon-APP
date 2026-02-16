import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BLE Service for managing Bluetooth Low Energy devices
///
/// This service handles:
/// - BLE adapter state
/// - Device scanning
/// - Device connection/disconnection
/// - Previously connected devices storage
/// - Real-time connection status monitoring
class BleService extends ChangeNotifier {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // Bluetooth adapter state
  BleStatus _adapterState = BleStatus.unknown;
  BleStatus get adapterState => _adapterState;
  bool get isBluetoothOn => _adapterState == BleStatus.ready;

  // Scanning state
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Discovered devices during scan
  final Map<String, DiscoveredDevice> _discoveredDevices = {};
  List<DiscoveredDevice> get discoveredDevices =>
      _discoveredDevices.values.toList();

  // Connected devices
  final Map<String, StreamSubscription<ConnectionStateUpdate>>
  _connectionSubscriptions = {};
  final Map<String, DiscoveredDevice> _connectedDevices = {};
  List<String> get connectedDeviceIds => _connectedDevices.keys.toList();

  // Previously connected devices (from storage)
  final List<SavedBleDevice> _previousDevices = [];
  List<SavedBleDevice> get previousDevices => _previousDevices;

  // Subscriptions
  StreamSubscription<BleStatus>? _adapterStateSubscription;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  // Storage key for previously connected devices
  static const String _storageKey = 'ble_saved_devices';

  /// Initialize BLE service
  Future<void> initialize() async {
    debugPrint('🔵 BLE Service: Initializing...');

    // Load saved devices from storage
    await _loadSavedDevices();

    // Listen to adapter state changes
    _adapterStateSubscription = _ble.statusStream.listen((status) {
      debugPrint('🔵 BLE Adapter State: $status');
      _adapterState = status;
      notifyListeners();
    });

    debugPrint('🔵 BLE Service: Initialized. Adapter: $_adapterState');
  }

  /// Check and request Bluetooth permissions
  Future<bool> checkAndRequestPermissions() async {
    debugPrint('🔵 BLE Service: Checking permissions...');

    try {
      // Check Bluetooth Scan permission (Android 12+)
      if (await Permission.bluetoothScan.isDenied) {
        final result = await Permission.bluetoothScan.request();
        if (!result.isGranted) {
          debugPrint('❌ Bluetooth Scan permission denied');
          return false;
        }
      }

      // Check Bluetooth Connect permission (Android 12+)
      if (await Permission.bluetoothConnect.isDenied) {
        final result = await Permission.bluetoothConnect.request();
        if (!result.isGranted) {
          debugPrint('❌ Bluetooth Connect permission denied');
          return false;
        }
      }

      debugPrint('✅ All BLE permissions granted');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Start scanning for BLE devices
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_isScanning) {
      debugPrint('⚠️ Scan already in progress');
      return;
    }

    if (!isBluetoothOn) {
      debugPrint('❌ Bluetooth is off');
      // On some platforms we might want to prompt user, but reactive_ble doesn't have a direct helper
      // Just notify listeners/UI can handle
    }

    // Check permissions
    final hasPermissions = await checkAndRequestPermissions();
    if (!hasPermissions) {
      debugPrint('❌ Required permissions not granted');
      return;
    }

    try {
      debugPrint('🔍 Starting BLE scan...');
      _isScanning = true;
      _discoveredDevices.clear();
      notifyListeners();

      // Start scanning
      _scanSubscription = _ble.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen(
        (device) {
          if (device.name.isNotEmpty) {
            if (!_discoveredDevices.containsKey(device.id)) {
              debugPrint('📱 Found device: ${device.name} (${device.id})');
              _discoveredDevices[device.id] = device;
              notifyListeners();
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Scan error: $error');
          _isScanning = false;
          notifyListeners();
        },
      );

      // Auto-stop after timeout
      Future.delayed(timeout, () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      debugPrint('❌ Error starting scan: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      debugPrint('🛑 Stopping BLE scan...');
      await _scanSubscription?.cancel();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error stopping scan: $e');
    }
  }

  /// Connect to a BLE device
  Future<void> connectToDevice(DiscoveredDevice device) async {
    final deviceId = device.id;
    debugPrint('🔗 Connecting to ${device.name} ($deviceId)...');

    // If already connecting/connected, we usually want to return.
    // BUT if the user is explicitly retrying or the state is stale, we should clear it.
    // For now, if called again, we will CANCEL the previous attempt and start over.
    if (_connectionSubscriptions.containsKey(deviceId)) {
      debugPrint('⚠️ Connection attempt in progress for $deviceId. Cancelling old subscription to retry.');
      await _connectionSubscriptions[deviceId]?.cancel();
      _connectionSubscriptions.remove(deviceId);
    }

    try {
      _connectionSubscriptions[deviceId] = _ble
          .connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 15),
      )
          .listen(
        (connectionState) {
          debugPrint(
            '📡 Connection state for ${device.name}: ${connectionState.connectionState}',
          );

          if (connectionState.connectionState ==
              DeviceConnectionState.connected) {
            _onDeviceConnected(device);
          } else if (connectionState.connectionState ==
              DeviceConnectionState.disconnected) {
            _onDeviceDisconnected(deviceId);
          }
        },
        onError: (Object error) {
          debugPrint('❌ Connection error for $deviceId: $error');
          _onDeviceDisconnected(deviceId);
        },
      );
    } catch (e) {
      debugPrint('❌ Error initiating connection: $e');
      _onDeviceDisconnected(deviceId); // Ensure cleanup
    }
  }

  void _onDeviceConnected(DiscoveredDevice device) {
    if (!_connectedDevices.containsKey(device.id)) {
      debugPrint('✅ Connected to ${device.name}');
      _connectedDevices[device.id] = device;
      _saveDevice(device);
      notifyListeners();
    }
  }

  void _onDeviceDisconnected(String deviceId) {
    if (_connectedDevices.containsKey(deviceId)) {
      debugPrint('🔌 Disconnected from $deviceId');
      _connectedDevices.remove(deviceId);
      // Clean up subscription if we consider it fully disconnected
      // Depending on requirement, we might want to keep retrying or just clean up
      _connectionSubscriptions[deviceId]?.cancel();
      _connectionSubscriptions.remove(deviceId);
      notifyListeners();
    }
  }

  /// Disconnect from a BLE device
  Future<void> disconnectDevice(String deviceId) async {
    try {
      debugPrint('🔌 Disconnecting from $deviceId...');
      // Cancelling the subscription disconnects the device in reactive_ble
      await _connectionSubscriptions[deviceId]?.cancel();
      _connectionSubscriptions.remove(deviceId);
      _connectedDevices.remove(deviceId);
      notifyListeners();
      debugPrint('✅ Disconnected from $deviceId');
    } catch (e) {
      debugPrint('❌ Error disconnecting device: $e');
    }
  }

  /// Check if a device is connected
  bool isDeviceConnected(String deviceId) {
    return _connectedDevices.containsKey(deviceId);
  }

  /// Get device by ID
  DiscoveredDevice? getDeviceById(String deviceId) {
    return _connectedDevices[deviceId] ?? _discoveredDevices[deviceId];
  }

  /// Save a device to previously connected list
  Future<void> _saveDevice(DiscoveredDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDevice = SavedBleDevice(
        id: device.id,
        name: device.name.isNotEmpty ? device.name : 'Unknown Device',
        lastConnected: DateTime.now(),
      );

      // Load existing devices
      final existing =
          _previousDevices.where((d) => d.id != savedDevice.id).toList();

      // Add new device at the beginning
      existing.insert(0, savedDevice);

      // Keep only last 10 devices
      final toSave = existing.take(10).toList();

      // Save to storage using pipe-separated format
      final stringList = toSave.map((d) => d.toString()).toList();
      await prefs.setStringList(_storageKey, stringList);

      // Update in-memory list
      _previousDevices.clear();
      _previousDevices.addAll(toSave);

      notifyListeners();
      debugPrint('💾 Saved device: ${device.name}');
    } catch (e) {
      debugPrint('❌ Error saving device: $e');
    }
  }

  /// Load saved devices from storage
  Future<void> _loadSavedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];

      _previousDevices.clear();
      for (var jsonStr in jsonList) {
        try {
          final device = SavedBleDevice.fromJsonString(jsonStr);
          if (device != null) {
            _previousDevices.add(device);
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing saved device: $e');
        }
      }

      debugPrint('📂 Loaded ${_previousDevices.length} saved devices');
    } catch (e) {
      debugPrint('❌ Error loading saved devices: $e');
    }
  }

  /// Remove a device from saved list
  Future<void> removeSavedDevice(String deviceId) async {
    try {
      _previousDevices.removeWhere((d) => d.id == deviceId);

      final prefs = await SharedPreferences.getInstance();
      final stringList = _previousDevices.map((d) => d.toString()).toList();
      await prefs.setStringList(_storageKey, stringList);

      notifyListeners();
      debugPrint('🗑️ Removed saved device: $deviceId');
    } catch (e) {
      debugPrint('❌ Error removing saved device: $e');
    }
  }

  /// Refresh device lists - mostly for UI update
  Future<void> refresh() async {
    // reactive_ble handles state via streams, so we just reload saved devices
    await _loadSavedDevices();
    notifyListeners();
  }

  /// Auto-connect to the last connected device
  Future<void> autoConnectToLastDevice() async {
    if (_previousDevices.isEmpty) return;

    // Try to connect to the most recent device
    final lastDevice = _previousDevices.first;
    debugPrint(
      '🔄 Auto-connecting to last device: ${lastDevice.name} (${lastDevice.id})',
    );

    // To connect, we need to know it's advertising or just try connecting by ID.
    // reactive_ble allows connecting by ID without scanning if the OS knows it or it's advertising.
    // However, for robust auto-reconnect, scanning is often preferred to ensure it's in range.
    // Here we will try to connect directly.

    // We fabricate a DiscoveredDevice to pass to connectToDevice
    // This is a bit of a hack since we don't have the full DiscoveredDevice object,
    // but connectToDevice really only needs the ID.
    // Note: serviceData, manufacturerData etc will be empty.
    final device = DiscoveredDevice(
      id: lastDevice.id,
      name: lastDevice.name,
      serviceData: {},
      manufacturerData: Uint8List(0),
      rssi: 0,
      serviceUuids: [],
    );

    connectToDevice(device);
  }

  /// Forget a device (remove from saved list)
  Future<void> forgetDevice(String deviceId) async {
    await removeSavedDevice(deviceId);
    await disconnectDevice(deviceId);
  }

  @override
  void dispose() {
    debugPrint('🔵 BLE Service: Disposing...');
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();

    for (var subscription in _connectionSubscriptions.values) {
      subscription.cancel();
    }
    _connectionSubscriptions.clear();

    super.dispose();
  }
}

/// Model for saved BLE devices
class SavedBleDevice {
  final String id;
  final String name;
  final DateTime lastConnected;

  SavedBleDevice({
    required this.id,
    required this.name,
    required this.lastConnected,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lastConnected': lastConnected.toIso8601String(),
  };

  static SavedBleDevice? fromJson(Map<String, dynamic> json) {
    try {
      return SavedBleDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        lastConnected: DateTime.parse(json['lastConnected'] as String),
      );
    } catch (e) {
      debugPrint('Error parsing SavedBleDevice: $e');
      return null;
    }
  }

  static SavedBleDevice? fromJsonString(String jsonStr) {
    try {
      // Simple parsing for our storage format
      final parts = jsonStr.split('|');
      if (parts.length >= 3) {
        return SavedBleDevice(
          id: parts[0],
          name: parts[1],
          lastConnected: DateTime.parse(parts[2]),
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing SavedBleDevice from string: $e');
      return null;
    }
  }

  @override
  String toString() => '$id|$name|${lastConnected.toIso8601String()}';

  String get formattedLastConnected {
    final now = DateTime.now();
    final difference = now.difference(lastConnected);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}
