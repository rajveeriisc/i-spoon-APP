import 'dart:async';
import 'models.dart';

abstract class BleRepository {
  Stream<List<BleDeviceSummary>> get scan$;
  Stream<BleConnectionState> get connection$;
  Stream<BleSensorPacket> get sensor$;

  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<void> requestMtu(int mtu);
}
