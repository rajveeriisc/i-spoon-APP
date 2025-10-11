import 'package:flutter/foundation.dart';

@immutable
class BleDeviceSummary {
  final String id; // MAC/UUID depending on platform
  final String name;
  final int rssi;
  const BleDeviceSummary({
    required this.id,
    required this.name,
    required this.rssi,
  });
}

@immutable
class BleConnectionState {
  final bool connected;
  final int? mtu;
  const BleConnectionState({required this.connected, this.mtu});
}

@immutable
class BleSensorPacket {
  final DateTime ts;
  final double? temperatureC;
  final double? batteryPct;
  const BleSensorPacket({required this.ts, this.temperatureC, this.batteryPct});
}
