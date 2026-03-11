class Bite {
  final int? id;
  final String mealUuid;
  final DateTime timestamp;
  final int? sequenceNumber;
  final double? tremorMagnitude;  // tremor amplitude in g — from TremorDetectionService
  final double? tremorFrequency;  // Hz   — from TremorDetectionService
  final double? foodTempC;        // °C   — from BLE temperature characteristic
  final bool isValid;
  final bool isSynced;

  Bite({
    this.id,
    required this.mealUuid,
    required this.timestamp,
    this.sequenceNumber,
    this.tremorMagnitude,
    this.tremorFrequency,
    this.foodTempC,
    this.isValid = true,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meal_uuid': mealUuid,
      'timestamp': timestamp.toIso8601String(),
      'sequence_number': sequenceNumber,
      'tremor_magnitude': tremorMagnitude,
      'tremor_frequency': tremorFrequency,
      'food_temp_c': foodTempC,
      'is_valid': isValid ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Bite.fromMap(Map<String, dynamic> map) {
    return Bite(
      id: map['id'],
      mealUuid: map['meal_uuid'],
      timestamp: DateTime.parse(map['timestamp']),
      sequenceNumber: map['sequence_number'],
      tremorMagnitude: map['tremor_magnitude'],
      tremorFrequency: map['tremor_frequency'],
      foodTempC: map['food_temp_c'],
      isValid: (map['is_valid'] ?? 1) == 1,
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }
}
