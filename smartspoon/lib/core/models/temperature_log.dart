class TemperatureLog {
  final int? id;
  final String mealUuid;
  final DateTime timestamp;
  final double? foodTempC;
  final double? ambientTempC;
  final bool isSynced;

  TemperatureLog({
    this.id,
    required this.mealUuid,
    required this.timestamp,
    this.foodTempC,
    this.ambientTempC,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meal_uuid': mealUuid,
      'timestamp': timestamp.toIso8601String(),
      'food_temp_c': foodTempC,
      'ambient_temp_c': ambientTempC,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory TemperatureLog.fromMap(Map<String, dynamic> map) {
    return TemperatureLog(
      id: map['id'],
      mealUuid: map['meal_uuid'],
      timestamp: DateTime.parse(map['timestamp']),
      foodTempC: map['food_temp_c'], 
      ambientTempC: map['ambient_temp_c'],
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }
}
