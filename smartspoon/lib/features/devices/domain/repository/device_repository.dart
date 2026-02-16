// Simplified device repository for flutter_reactive_ble
// Most functionality moved to BleService

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

abstract class DeviceRepository {
  // Scanning handled by BleService now
  Stream<List<DiscoveredDevice>> scanForDevices();
  
  Future<void> stopScan();
  
  // Connection - using device ID instead of BluetoothDevice
  Future<bool> connectToDevice(String deviceId);
  
  Future<void> disconnectDevice(String deviceId);
}
