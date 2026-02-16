/// Device data model
class DeviceModel {
  final String id;
  final String name;
  final String? macAddress;
  final String? deviceType;
  final bool isConnected;
  final DateTime? lastConnected;
  final String? userDeviceId;
  final bool? heaterActive;
  final double? heaterActivationTemp;
  final double? heaterMaxTemp;

  DeviceModel({
    required this.id,
    required this.name,
    this.macAddress,
    this.deviceType,
    this.isConnected = false,
    this.lastConnected,
    this.userDeviceId,
    this.heaterActive,
    this.heaterActivationTemp,
    this.heaterMaxTemp,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Device',
      macAddress: json['mac_address'] as String? ?? json['macAddress'] as String?,
      deviceType: json['device_type'] as String? ?? json['deviceType'] as String?,
      isConnected: json['is_connected'] as bool? ?? json['isConnected'] as bool? ?? false,
      lastConnected: json['last_connected'] != null
          ? DateTime.tryParse(json['last_connected'].toString())
          : json['lastConnected'] != null
              ? DateTime.tryParse(json['lastConnected'].toString())
              : null,
      userDeviceId: json['user_device_id']?.toString() ?? (json['id']?.toString()), // Default to id if user_device_id missing in specific contexts
      heaterActive: json['heater_active'] as bool?,
      heaterActivationTemp: json['heater_activation_temp'] != null ? double.tryParse(json['heater_activation_temp'].toString()) : null,
      heaterMaxTemp: json['heater_max_temp'] != null ? double.tryParse(json['heater_max_temp'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (macAddress != null) 'mac_address': macAddress,
      if (deviceType != null) 'device_type': deviceType,
      'is_connected': isConnected,
      if (lastConnected != null) 'last_connected': lastConnected!.toIso8601String(),
      if (userDeviceId != null) 'user_device_id': userDeviceId,
      if (heaterActive != null) 'heater_active': heaterActive,
      if (heaterActivationTemp != null) 'heater_activation_temp': heaterActivationTemp,
      if (heaterMaxTemp != null) 'heater_max_temp': heaterMaxTemp,
    };
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? macAddress,
    String? deviceType,
    bool? isConnected,
    DateTime? lastConnected,
    String? userDeviceId,
    bool? heaterActive,
    double? heaterActivationTemp,
    double? heaterMaxTemp,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      deviceType: deviceType ?? this.deviceType,
      isConnected: isConnected ?? this.isConnected,
      lastConnected: lastConnected ?? this.lastConnected,
      userDeviceId: userDeviceId ?? this.userDeviceId,
      heaterActive: heaterActive ?? this.heaterActive,
      heaterActivationTemp: heaterActivationTemp ?? this.heaterActivationTemp,
      heaterMaxTemp: heaterMaxTemp ?? this.heaterMaxTemp,
    );
  }
}

/// Sensor data model (from MCU BLE Service)
class SensorDataModel {
  final int accelX;
  final int accelY;
  final int accelZ;
  final int gyroX;
  final int gyroY;
  final int gyroZ;
  final double temperature;
  final DateTime timestamp;
  final String rawData;

  SensorDataModel({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.temperature,
    required this.timestamp,
    required this.rawData,
  });

  Map<String, dynamic> toJson() {
    return {
      'accel_x': accelX,
      'accel_y': accelY,
      'accel_z': accelZ,
      'gyro_x': gyroX,
      'gyro_y': gyroY,
      'gyro_z': gyroZ,
      'temperature': temperature,
      'timestamp': timestamp.toIso8601String(),
      'raw_data': rawData,
    };
  }
}
