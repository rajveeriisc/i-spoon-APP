import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/ble_repository.dart';
import '../domain/models.dart';
import '../infrastructure/ble_recent_repository.dart';

/// Controller for managing BLE device connections and state
/// Properly manages subscriptions and cleans up resources
class BleController with ChangeNotifier {
  final BleRepository _repo;
  final BleRecentRepository _recentRepo;
  
  // Store subscriptions for proper cleanup
  StreamSubscription<List<BleDeviceSummary>>? _scanSub;
  StreamSubscription<BleConnectionState>? _connSub;
  StreamSubscription<BleSensorPacket>? _sensorSub;
  
  BleController(this._repo, {BleRecentRepository? recentRepository})
    : _recentRepo = recentRepository ?? BleRecentRepository();

  List<BleDeviceSummary> devices = const [];
  BleConnectionState conn = const BleConnectionState(connected: false);
  BleSensorPacket? lastPacket;
  String? connectedDeviceId;
  String? lastDeviceName;
  bool _isScanning = false;
  bool _isConnecting = false;
  List<RecentDevice> recentDevices = const [];
  
  // Permission state
  bool _bluetoothPermissionGranted = false;
  bool _locationPermissionGranted = false;
  String? _permissionError;

  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isConnected => conn.connected;
  bool get hasPermissions =>
      _bluetoothPermissionGranted || _locationPermissionGranted;
  String? get permissionError => _permissionError;
  
  bool isDeviceConnected(String id) =>
      connectedDeviceId == id && conn.connected;

  /// Initialize the controller and start listening to BLE events
  void init() {
    // Store subscriptions for proper cleanup
    _scanSub = _repo.scan$.listen((d) {
      devices = d;
      notifyListeners();
    });
    
    _connSub = _repo.connection$.listen((c) {
      conn = c;
      if (!c.connected) {
        connectedDeviceId = null;
      }
      notifyListeners();
    });
    
    _sensorSub = _repo.sensor$.listen((p) {
      lastPacket = p;
      notifyListeners();
    });
    
    _loadRecent();
    // Check permissions before scanning
    _checkPermissions().then((_) {
      if (hasPermissions) {
        startScan();
      }
    });
  }
  
  /// Check if BLE permissions are granted
  Future<bool> _checkPermissions() async {
    try {
      // Check Bluetooth Scan (Android 12+) and Location (Android <= 11)
      final bluetoothStatus = await Permission.bluetoothScan.status;
      _bluetoothPermissionGranted = bluetoothStatus.isGranted;

      final locationStatus = await Permission.locationWhenInUse.status;
      _locationPermissionGranted = locationStatus.isGranted;

      final allowed = _bluetoothPermissionGranted || _locationPermissionGranted;
      _permissionError = allowed
          ? null
          : 'Bluetooth Scan or Location permission is required to scan for devices';

      notifyListeners();
      return allowed;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      _permissionError = 'Failed to check permissions';
      notifyListeners();
      return false;
    }
  }
  
  /// Request BLE permissions from user
  Future<bool> requestPermissions() async {
    try {
      // Request Bluetooth permission
      final bluetoothStatus = await Permission.bluetoothScan.request();
      _bluetoothPermissionGranted = bluetoothStatus.isGranted;
      
      if (bluetoothStatus.isPermanentlyDenied) {
        _permissionError = 'Bluetooth permission permanently denied. Please enable in settings.';
        notifyListeners();
        return false;
      }
      
      // Request Location permission
      final locationStatus = await Permission.locationWhenInUse.request();
      _locationPermissionGranted = locationStatus.isGranted;
      
      if (locationStatus.isPermanentlyDenied) {
        _permissionError = 'Location permission permanently denied. Please enable in settings.';
        notifyListeners();
        return false;
      }
      
      if (_bluetoothPermissionGranted || _locationPermissionGranted) {
        _permissionError = null;
        debugPrint('BLE permissions granted');
      } else {
        _permissionError = 'Please grant Bluetooth and Location permissions';
      }
      
      notifyListeners();
      return _bluetoothPermissionGranted || _locationPermissionGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      _permissionError = 'Failed to request permissions: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// Open app settings for permission management
  Future<void> openSettings() async {
    await openAppSettings();
  }
  
  @override
  void dispose() {
    debugPrint('BleController: Disposing');
    
    // Cancel all subscriptions
    _scanSub?.cancel();
    _scanSub = null;
    
    _connSub?.cancel();
    _connSub = null;
    
    _sensorSub?.cancel();
    _sensorSub = null;
    
    // Stop scan and dispose repository
    stopScan();
    _repo.dispose();
    
    super.dispose();
  }

  Future<void> _loadRecent() async {
    recentDevices = await _recentRepo.load();
    if (lastDeviceName == null && recentDevices.isNotEmpty) {
      lastDeviceName = recentDevices.first.name;
    }
    notifyListeners();
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    
    // Check permissions before scanning
    if (!hasPermissions) {
      debugPrint('BLE: Permissions not granted, cannot start scan');
      _permissionError = 'Please grant Bluetooth and Location permissions to scan for devices';
      notifyListeners();
      return;
    }
    
    _isScanning = true;
    notifyListeners();
    try {
      await _repo.startScan();
    } catch (e) {
      _isScanning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopScan() async {
    await _repo.stopScan();
    if (_isScanning) {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> connect(String id, {String? name}) async {
    if (_isConnecting || connectedDeviceId == id) return;
    _isConnecting = true;
    connectedDeviceId = id;
    lastDeviceName = _resolveName(id, name);
    notifyListeners();
    try {
      await _repo.connect(id);
      final resolvedName = _resolveName(id, name);
      if (resolvedName != null && resolvedName.isNotEmpty) {
        await _recentRepo.upsert(RecentDevice(id: id, name: resolvedName));
        await _loadRecent();
      }
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _repo.disconnect();
    connectedDeviceId = null;
    notifyListeners();
    await startScan();
  }

  Future<void> requestMtu(int mtu) => _repo.requestMtu(mtu);

  String? _resolveName(String id, String? provided) {
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    final live = devices.firstWhere(
      (d) => d.id == id,
      orElse: () => BleDeviceSummary(id: id, name: '', rssi: 0),
    );
    if (live.name.isNotEmpty) return live.name;
    final recent = recentDevices.firstWhere(
      (d) => d.id == id,
      orElse: () => RecentDevice(id: id, name: ''),
    );
    if (recent.name.isNotEmpty) return recent.name;
    return lastDeviceName;
  }
}
