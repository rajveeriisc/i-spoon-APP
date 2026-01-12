import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:smartspoon/features/devices/domain/models/device_model.dart';

/// Abstract repository for device operations
abstract class DeviceRepository {
  /// Scan for available BLE devices
  Stream<List<ScanResult>> scanForDevices();

  /// Stop scanning
  Future<void> stopScan();

  /// Connect to a device
  Future<bool> connectToDevice(BluetoothDevice device);

  /// Disconnect from device
  Future<void> disconnect();

  /// Get connected device
  DeviceModel? getConnectedDevice();

  /// Check if device is connected
  bool isConnected();

  /// Subscribe to sensor data
  Future<bool> subscribeToData();

  /// Send command to device
  Future<bool> sendCommand(String command);

  /// Set heater state
  Future<bool> setHeaterState(bool on);

  /// Set heater to auto mode
  Future<bool> setHeaterAuto();

  /// Set temperature setpoint
  Future<bool> setTemperature(double temperature);

  /// Get current sensor data
  SensorDataModel? getCurrentSensorData();

  /// Get battery level
  int getBatteryLevel();

  /// Check if heater is on
  bool isHeaterOn();
}
