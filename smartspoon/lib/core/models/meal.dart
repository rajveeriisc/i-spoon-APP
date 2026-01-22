import 'package:uuid/uuid.dart';

class Meal {
  final int? id; // SQLite ID
  final String uuid; // Sync ID
  final int? serverId; // Backend ID
  final String userId;
  final String? deviceId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? mealType; // Breakfast, Lunch, Dinner, Snack
  final int totalBites;
  final double? avgPaceBpm;
  final int? tremorIndex;
  final double? durationMinutes;
  final double? avgFoodTemp; // Average temperature during meal
  final bool isSynced;
  final bool dirty;
  final DateTime createdAt;
  final DateTime updatedAt;

  Meal({
    this.id,
    String? uuid,
    this.serverId,
    required this.userId,
    this.deviceId,
    required this.startedAt,
    this.endedAt,
    this.mealType,
    this.totalBites = 0,
    this.avgPaceBpm,
    this.tremorIndex,
    this.durationMinutes,
    this.avgFoodTemp,
    this.isSynced = false,
    this.dirty = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Meal copyWith({
    int? id,
    String? uuid,
    int? serverId,
    String? userId,
    String? deviceId,
    DateTime? startedAt,
    DateTime? endedAt,
    String? mealType,
    int? totalBites,
    double? avgPaceBpm,
    int? tremorIndex,
    double? durationMinutes,
    double? avgFoodTemp,
    bool? isSynced,
    bool? dirty,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meal(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      mealType: mealType ?? this.mealType,
      totalBites: totalBites ?? this.totalBites,
      avgPaceBpm: avgPaceBpm ?? this.avgPaceBpm,
      tremorIndex: tremorIndex ?? this.tremorIndex,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      avgFoodTemp: avgFoodTemp ?? this.avgFoodTemp,
      isSynced: isSynced ?? this.isSynced,
      dirty: dirty ?? this.dirty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'server_id': serverId,
      'user_id': userId,
      'device_id': deviceId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'meal_type': mealType,
      'total_bites': totalBites,
      'avg_pace_bpm': avgPaceBpm,
      'tremor_index': tremorIndex,
      'duration_minutes': durationMinutes,
      'avg_food_temp_c': avgFoodTemp, // Fixed column name
      'is_synced': isSynced ? 1 : 0,
      'dirty': dirty ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map['id'],
      uuid: map['uuid'],
      serverId: map['server_id'],
      userId: map['user_id'],
      deviceId: map['device_id'],
      startedAt: DateTime.parse(map['started_at']),
      endedAt: map['ended_at'] != null ? DateTime.parse(map['ended_at']) : null,
      mealType: map['meal_type'],
      totalBites: map['total_bites'] ?? 0,
      avgPaceBpm: map['avg_pace_bpm'],
      tremorIndex: map['tremor_index'],
      durationMinutes: map['duration_minutes'],
      avgFoodTemp: map['avg_food_temp_c'], // Fixed column name
      isSynced: (map['is_synced'] ?? 0) == 1,
      dirty: (map['dirty'] ?? 0) == 1,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }
}
