import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../domain/ble_repository.dart';
import '../domain/models.dart';

/// BLE repository implementation using flutter_blue_plus
/// Handles device scanning, connection, and sensor data streaming
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

  // Prevent concurrent subscription attempts
  bool _isSubscribing = false;
  bool _isDisposed = false;

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

  /// Subscribe to BLE notifications from the temperature characteristic
  /// Prevents concurrent subscriptions and includes proper timeout handling
  Future<void> _subscribeNotifications() async {
    if (_device == null || _isDisposed) return;

    // Prevent concurrent subscription attempts
    if (_isSubscribing) {
      debugPrint('BLE: Subscription already in progress, skipping');
      return;
    }

    _isSubscribing = true;

    try {
      final services = await _device!.discoverServices().timeout(
        const Duration(seconds: 10),
      );

      for (final s in services) {
        if (s.uuid != serviceUuid) continue;
        debugPrint('BLE: Found target service $serviceUuid');

        for (final c in s.characteristics) {
          if (c.uuid == temperatureCharacteristicUuid) {
            debugPrint(
              'BLE: Found temperature characteristic $temperatureCharacteristicUuid',
            );

            // Cancel existing subscription before creating new one
            await _notifySub?.cancel();
            _notifySub = null;

            // Attempt to enable notifications
            try {
              await c.setNotifyValue(true).timeout(const Duration(seconds: 5));
              debugPrint('BLE: Notifications enabled successfully');
            } catch (e) {
              debugPrint('BLE: Failed to enable notifications: $e');
              // Continue anyway - some devices work without explicit notify enable
            }

            _notifySub = c.onValueReceived.listen(
              (data) {
                if (data.isEmpty || _isDisposed) return;
                _handleSensorData(data);
              },
              onError: (error) {
                debugPrint('BLE: Notification stream error: $error');
              },
              cancelOnError: false,
            );

            // Perform an initial read to update UI immediately
            try {
              final data = await c.read().timeout(const Duration(seconds: 3));
              if (data.isNotEmpty && !_isDisposed) {
                _handleSensorData(data);
              }
            } catch (e) {
              debugPrint('BLE: Initial read failed: $e');
            }

            return;
          }
        }
      }

      debugPrint('BLE: Temperature characteristic not found');
    } catch (e) {
      debugPrint('BLE: Failed to subscribe to notifications: $e');
    } finally {
      _isSubscribing = false;
    }
  }

  /// Parse and handle incoming sensor data
  void _handleSensorData(List<int> data) {
    try {
      final now = DateTime.now();
      final valueStr = utf8.decode(data, allowMalformed: true).trim();
      debugPrint('BLE RX: $valueStr');

      double? temp;
      try {
        final obj = jsonDecode(valueStr);
        if (obj is Map && obj['food_temp'] != null) {
          final dynamic v = obj['food_temp'];
          if (v is num) {
            temp = v.toDouble();
          } else if (v is String) {
            temp = double.tryParse(v);
          }
        }
      } catch (_) {
        // Fallback: try parsing as plain number
        temp = double.tryParse(valueStr);
      }

      if (!_isDisposed) {
        _sensorCtrl.add(
          BleSensorPacket(ts: now, temperatureC: temp, batteryPct: null),
        );
      }
    } catch (e) {
      debugPrint('BLE: Error handling sensor data: $e');
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

  /// Dispose of all resources and clean up connections
  /// Must be called when the repository is no longer needed
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    debugPrint('BLE: Disposing repository');

    // Stop scanning first
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('BLE: Error stopping scan: $e');
    }

    // Cancel all subscriptions
    await _scanSub?.cancel();
    _scanSub = null;

    await _notifySub?.cancel();
    _notifySub = null;

    await _connSub?.cancel();
    _connSub = null;

    // Disconnect device
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (e) {
        debugPrint('BLE: Error disconnecting device: $e');
      }
      _device = null;
    }

    // Close stream controllers last
    await _scanCtrl.close();
    await _connCtrl.close();
    await _sensorCtrl.close();

    debugPrint('BLE: Repository disposed');
  }
}
