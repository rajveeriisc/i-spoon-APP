import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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

  // Bluetooth adapter state
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  BluetoothAdapterState get adapterState => _adapterState;
  bool get isBluetoothOn => _adapterState == BluetoothAdapterState.on;

  // Scanning state
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // Discovered devices during scan
  final Map<String, BluetoothDevice> _discoveredDevices = {};
  List<BluetoothDevice> get discoveredDevices =>
      _discoveredDevices.values.toList();

  // Connected devices
  final Map<String, BluetoothDevice> _connectedDevices = {};
  List<BluetoothDevice> get connectedDevices =>
      _connectedDevices.values.toList();

  // Previously connected devices (from storage)
  final List<SavedBleDevice> _previousDevices = [];
  List<SavedBleDevice> get previousDevices => _previousDevices;

  // Subscriptions
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final Map<String, StreamSubscription<BluetoothConnectionState>>
  _connectionSubscriptions = {};

  // Storage key for previously connected devices
  static const String _storageKey = 'ble_saved_devices';

  /// Initialize BLE service
  Future<void> initialize() async {
    debugPrint('🔵 BLE Service: Initializing...');

    // Load saved devices from storage
    await _loadSavedDevices();

    // Listen to adapter state changes
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      debugPrint('🔵 BLE Adapter State: $state');
      _adapterState = state;
      notifyListeners();
    });

    // Get initial adapter state
    _adapterState = await FlutterBluePlus.adapterState.first;

    // Load currently connected devices
    await _updateConnectedDevices();

    debugPrint('🔵 BLE Service: Initialized. Adapter: $_adapterState');
  }

  /// Check and request Bluetooth permissions
  /// For Android 12+ (API 31+): Only needs BLUETOOTH_SCAN and BLUETOOTH_CONNECT
  /// For Android < 12: Also needs BLUETOOTH and LOCATION
  Future<bool> checkAndRequestPermissions() async {
    debugPrint('🔵 BLE Service: Checking permissions...');

    try {
      // Android 12+ (API 31+) - Modern permissions
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

  /// Turn on Bluetooth (opens system settings)
  Future<void> turnOnBluetooth() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      debugPrint('❌ Error turning on Bluetooth: $e');
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
      throw Exception('Bluetooth is turned off');
    }

    // Check permissions
    final hasPermissions = await checkAndRequestPermissions();
    if (!hasPermissions) {
      throw Exception('Required permissions not granted');
    }

    try {
      debugPrint('🔍 Starting BLE scan...');
      _isScanning = true;
      _discoveredDevices.clear();
      notifyListeners();

      // Start scanning
      // androidUsesFineLocation: false because we use neverForLocation flag
      // This works for Android 12+ without location permissions
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          for (var result in results) {
            final device = result.device;
            final deviceId = device.remoteId.toString();

            // Only add devices with a valid name (I-Spoon devices)
            if (device.platformName.isNotEmpty) {
              if (!_discoveredDevices.containsKey(deviceId)) {
                debugPrint(
                  '📱 Found device: ${device.platformName} ($deviceId)',
                );
                _discoveredDevices[deviceId] = device;
                notifyListeners();
              }
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Scan error: $error');
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
      rethrow;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      debugPrint('🛑 Stopping BLE scan...');
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error stopping scan: $e');
    }
  }

  /// Connect to a BLE device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('🔗 Connecting to ${device.platformName}...');

      // Check if already connected
      final isConnected =
          await device.connectionState.first ==
          BluetoothConnectionState.connected;
      if (isConnected) {
        debugPrint('✅ Device already connected');
        return true;
      }

      // Connect with timeout
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      // Wait for connection to be established
      await device.connectionState
          .where((state) => state == BluetoothConnectionState.connected)
          .first
          .timeout(const Duration(seconds: 15));

      debugPrint('✅ Connected to ${device.platformName}');

      // Save device to previously connected list
      await _saveDevice(device);

      // Add to connected devices and monitor connection
      _connectedDevices[device.remoteId.toString()] = device;
      _monitorDeviceConnection(device);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error connecting to device: $e');
      return false;
    }
  }

  /// Disconnect from a BLE device
  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      debugPrint('🔌 Disconnecting from ${device.platformName}...');
      await device.disconnect();

      // Remove from connected devices
      _connectedDevices.remove(device.remoteId.toString());

      // Cancel connection monitoring
      _connectionSubscriptions[device.remoteId.toString()]?.cancel();
      _connectionSubscriptions.remove(device.remoteId.toString());

      notifyListeners();
      debugPrint('✅ Disconnected from ${device.platformName}');
    } catch (e) {
      debugPrint('❌ Error disconnecting device: $e');
    }
  }

  /// Monitor device connection state
  void _monitorDeviceConnection(BluetoothDevice device) {
    final deviceId = device.remoteId.toString();

    // Cancel existing subscription if any
    _connectionSubscriptions[deviceId]?.cancel();

    // Listen to connection state changes
    _connectionSubscriptions[deviceId] = device.connectionState.listen(
      (state) {
        debugPrint('📡 Device ${device.platformName} state: $state');

        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevices.remove(deviceId);
          _connectionSubscriptions[deviceId]?.cancel();
          _connectionSubscriptions.remove(deviceId);
          notifyListeners();
        } else if (state == BluetoothConnectionState.connected) {
          if (!_connectedDevices.containsKey(deviceId)) {
            _connectedDevices[deviceId] = device;
            notifyListeners();
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Connection monitoring error: $error');
      },
    );
  }

  /// Update list of connected devices
  Future<void> _updateConnectedDevices() async {
    try {
      final connected = FlutterBluePlus.connectedDevices;
      _connectedDevices.clear();

      for (var device in connected) {
        _connectedDevices[device.remoteId.toString()] = device;
        _monitorDeviceConnection(device);
      }

      notifyListeners();
      debugPrint('🔄 Updated connected devices: ${_connectedDevices.length}');
    } catch (e) {
      debugPrint('❌ Error updating connected devices: $e');
    }
  }

  /// Check if a device is connected
  bool isDeviceConnected(String deviceId) {
    return _connectedDevices.containsKey(deviceId);
  }

  /// Get device by ID
  BluetoothDevice? getDeviceById(String deviceId) {
    return _connectedDevices[deviceId] ?? _discoveredDevices[deviceId];
  }

  /// Save a device to previously connected list
  Future<void> _saveDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDevice = SavedBleDevice(
        id: device.remoteId.toString(),
        name: device.platformName.isNotEmpty
            ? device.platformName
            : 'Unknown Device',
        lastConnected: DateTime.now(),
      );

      // Load existing devices
      final existing = _previousDevices
          .where((d) => d.id != savedDevice.id)
          .toList();

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
      debugPrint('💾 Saved device: ${device.platformName}');
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

  /// Refresh device lists
  Future<void> refresh() async {
    await _updateConnectedDevices();
    await _loadSavedDevices();
  }

  /// Dispose service and clean up resources
  /// Auto-connect to the last connected device
  Future<void> autoConnectToLastDevice() async {
    if (_previousDevices.isEmpty) return;
    
    // Try to connect to the most recent device
    final lastDevice = _previousDevices.first;
    debugPrint('🔄 Auto-connecting to last device: ${lastDevice.name} (${lastDevice.id})');
    
    // We need to scan to find the device instance first if it's not known
    // But for now, let's just try to find it in known devices
    // This is a simplified implementation
    // In a real app, you might need to scan specifically for this ID
  }

  /// Forget a device (remove from saved list)
  Future<void> forgetDevice(String deviceId) async {
    await removeSavedDevice(deviceId);
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
