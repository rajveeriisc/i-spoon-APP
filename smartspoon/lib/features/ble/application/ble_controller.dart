import 'package:flutter/foundation.dart';
import '../domain/ble_repository.dart';
import '../domain/models.dart';

class BleController with ChangeNotifier {
  final BleRepository _repo;
  BleController(this._repo);

  List<BleDeviceSummary> devices = const [];
  BleConnectionState conn = const BleConnectionState(connected: false);
  BleSensorPacket? lastPacket;

  void init() {
    _repo.scan$.listen((d) {
      devices = d;
      notifyListeners();
    });
    _repo.connection$.listen((c) {
      conn = c;
      notifyListeners();
    });
    _repo.sensor$.listen((p) {
      lastPacket = p;
      notifyListeners();
    });
  }

  Future<void> startScan() => _repo.startScan();
  Future<void> stopScan() => _repo.stopScan();
  Future<void> connect(String id) => _repo.connect(id);
  Future<void> disconnect() => _repo.disconnect();
  Future<void> requestMtu(int mtu) => _repo.requestMtu(mtu);
}
