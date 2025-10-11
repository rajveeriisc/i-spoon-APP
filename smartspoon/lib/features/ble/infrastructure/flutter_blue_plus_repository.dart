import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../domain/ble_repository.dart';
import '../domain/models.dart';

class FlutterBluePlusRepository implements BleRepository {
  final StreamController<List<BleDeviceSummary>> _scanCtrl =
      StreamController.broadcast();
  final StreamController<BleConnectionState> _connCtrl =
      StreamController.broadcast();
  final StreamController<BleSensorPacket> _sensorCtrl =
      StreamController.broadcast();

  BluetoothDevice? _device;
  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _notifySub;

  @override
  Stream<List<BleDeviceSummary>> get scan$ => _scanCtrl.stream;
  @override
  Stream<BleConnectionState> get connection$ => _connCtrl.stream;
  @override
  Stream<BleSensorPacket> get sensor$ => _sensorCtrl.stream;

  @override
  Future<void> startScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    final Map<String, BleDeviceSummary> found = {};
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final d = r.device;
        found[d.remoteId.str] = BleDeviceSummary(
          id: d.remoteId.str,
          name: d.platformName.isNotEmpty ? d.platformName : 'Unknown',
          rssi: r.rssi,
        );
      }
      _scanCtrl.add(found.values.toList());
    });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
  }

  @override
  Future<void> connect(String deviceId) async {
    await stopScan();
    _device = BluetoothDevice.fromId(deviceId);
    await _device!.connect(timeout: const Duration(seconds: 8));
    _connCtrl.add(const BleConnectionState(connected: true, mtu: null));

    _connSub?.cancel();
    _connSub = _device!.connectionState.listen((s) async {
      if (s == BluetoothConnectionState.connected) {
        _connCtrl.add(const BleConnectionState(connected: true, mtu: null));
        await _subscribeNotifications();
      } else {
        _connCtrl.add(const BleConnectionState(connected: false, mtu: null));
      }
    });
  }

  Future<void> _subscribeNotifications() async {
    if (_device == null) return;
    final services = await _device!.discoverServices();
    // Nordic UART Service UUIDs (from PRD)
    final nusService = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
    // Assume notify characteristic contains sensor JSON; adjust as firmware defines
    for (final s in services) {
      if (s.uuid == nusService) {
        for (final c in s.characteristics) {
          if (c.properties.notify) {
            await c.setNotifyValue(true);
            _notifySub?.cancel();
            _notifySub = c.onValueReceived.listen((data) {
              try {
                final now = DateTime.now();
                // Very simple demo parse: temperature in first two bytes (little-endian, *0.1)
                double? temp;
                if (data.length >= 2) {
                  final v = data[0] | (data[1] << 8);
                  temp = v / 10.0;
                }
                _sensorCtrl.add(BleSensorPacket(ts: now, temperatureC: temp));
              } catch (_) {}
            });
            return;
          }
        }
      }
    }
  }

  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }
    _device = null;
    _connCtrl.add(const BleConnectionState(connected: false));
  }

  @override
  Future<void> requestMtu(int mtu) async {
    if (_device != null) {
      try {
        await _device!.requestMtu(mtu);
        _connCtrl.add(const BleConnectionState(connected: true));
      } catch (_) {}
    }
  }

  void dispose() {
    _scanCtrl.close();
    _connCtrl.close();
    _sensorCtrl.close();
  }
}
