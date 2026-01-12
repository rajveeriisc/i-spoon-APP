class Bite {
  final int? id;
  final String mealUuid;
  final DateTime timestamp;
  final double? tremorMagnitude;
  final double? tremorFrequency;
  final bool isValid;
  final int? sequenceNumber;
  final bool isSynced;

  Bite({
    this.id,
    required this.mealUuid,
    required this.timestamp,
    this.tremorMagnitude,
    this.tremorFrequency,
    this.isValid = true,
    this.sequenceNumber,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meal_uuid': mealUuid,
      'timestamp': timestamp.toIso8601String(),
      'tremor_magnitude': tremorMagnitude,
      'tremor_frequency': tremorFrequency,
      'is_valid': isValid ? 1 : 0,
      'sequence_number': sequenceNumber,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Bite.fromMap(Map<String, dynamic> map) {
    return Bite(
      id: map['id'],
      mealUuid: map['meal_uuid'],
      timestamp: DateTime.parse(map['timestamp']),
      tremorMagnitude: map['tremor_magnitude'],
      tremorFrequency: map['tremor_frequency'],
      isValid: (map['is_valid'] ?? 1) == 1,
      sequenceNumber: map['sequence_number'],
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }
}
