import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import '../domain/ble_repository.dart';
import '../domain/models.dart';

class FlutterBluePlusRepository implements BleRepository {
  // Updated to match ESP32 firmware
  final Guid serviceUuid = Guid('87e3a34b-5a54-40bb-9d6a-355b9237d42b');
  final Guid temperatureCharacteristicUuid = Guid(
    'cdc7651d-88bd-4c0d-8c90-4572db5aa14b',
  );

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
        final adv = r.advertisementData;
        if (!adv.serviceUuids.contains(serviceUuid)) {
          continue;
        }
        final d = r.device;
        final name = d.platformName.isNotEmpty
            ? d.platformName
            : adv.localName.isNotEmpty
            ? adv.localName
            : 'SmartSpoon';
        found[d.remoteId.str] = BleDeviceSummary(
          id: d.remoteId.str,
          name: name,
          rssi: r.rssi,
        );
      }
      _scanCtrl.add(found.values.toList());
    });
    await FlutterBluePlus.startScan(withServices: [serviceUuid]);
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
    print('BLE: Connecting to $deviceId');
    try {
      await _device!.connect(timeout: const Duration(seconds: 8));
    } on PlatformException catch (e) {
      // If already connected, continue to set up listeners/subscriptions
      if (e.code != 'already_connected') rethrow;
      print('BLE: already_connected, will proceed to subscribe');
    } catch (_) {
      rethrow;
    }
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

    // Ensure we are subscribed even if state was already connected
    await _subscribeNotifications();
  }

  Future<void> _subscribeNotifications() async {
    if (_device == null) return;
    final services = await _device!.discoverServices();

    for (final s in services) {
      if (s.uuid != serviceUuid) continue;
      print('BLE: Found target service $serviceUuid');
      for (final c in s.characteristics) {
        if (c.uuid == temperatureCharacteristicUuid) {
          print(
            'BLE: Found temperature characteristic $temperatureCharacteristicUuid',
          );
          // Attempt to enable notifications even if properties.notify is false.
          try {
            await c.setNotifyValue(true);
            print('BLE: setNotifyValue(true) called');
          } catch (_) {}

          _notifySub?.cancel();
          _notifySub = c.onValueReceived.listen((data) {
            if (data.isEmpty) return;
            final now = DateTime.now();
            final valueStr = utf8.decode(data, allowMalformed: true).trim();
            print('BLE RX: $valueStr');
            double? temp;
            try {
              final obj = jsonDecode(valueStr);
              if (obj is Map && obj['food_temp'] != null) {
                final dynamic v = obj['food_temp'];
                if (v is num) temp = v.toDouble();
                if (v is String) temp = double.tryParse(v);
              }
            } catch (_) {
              temp = double.tryParse(valueStr);
            }
            _sensorCtrl.add(
              BleSensorPacket(ts: now, temperatureC: temp, batteryPct: null),
            );
          });

          // Perform an initial read to update UI immediately
          try {
            final data = await c.read();
            if (data.isNotEmpty) {
              final now = DateTime.now();
              final valueStr = utf8.decode(data, allowMalformed: true).trim();
              print('BLE initial read: $valueStr');
              double? temp;
              try {
                final obj = jsonDecode(valueStr);
                if (obj is Map && obj['food_temp'] != null) {
                  final dynamic v = obj['food_temp'];
                  if (v is num) temp = v.toDouble();
                  if (v is String) temp = double.tryParse(v);
                }
              } catch (_) {
                temp = double.tryParse(valueStr);
              }
              _sensorCtrl.add(
                BleSensorPacket(ts: now, temperatureC: temp, batteryPct: null),
              );
            }
          } catch (_) {}

          return;
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
