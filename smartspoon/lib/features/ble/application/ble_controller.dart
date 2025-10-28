import 'package:flutter/foundation.dart';
import '../domain/ble_repository.dart';
import '../domain/models.dart';
import '../infrastructure/ble_recent_repository.dart';

class BleController with ChangeNotifier {
  final BleRepository _repo;
  final BleRecentRepository _recentRepo;
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

  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isConnected => conn.connected;
  bool isDeviceConnected(String id) =>
      connectedDeviceId == id && conn.connected;

  void init() {
    _repo.scan$.listen((d) {
      devices = d;
      notifyListeners();
    });
    _repo.connection$.listen((c) {
      conn = c;
      if (!c.connected) {
        connectedDeviceId = null;
      }
      notifyListeners();
    });
    _repo.sensor$.listen((p) {
      lastPacket = p;
      notifyListeners();
    });
    _loadRecent();
    startScan();
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
    _isScanning = true;
    notifyListeners();
    try {
      await _repo.startScan();
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() => _repo.stopScan();

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
