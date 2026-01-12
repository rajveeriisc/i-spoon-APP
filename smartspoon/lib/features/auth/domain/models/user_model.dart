/// User data model
class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final String? firebaseUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.firebaseUid,
    this.createdAt,
    this.updatedAt,
  });

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      firebaseUid: json['firebase_uid'] as String? ?? json['firebaseUid'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString())
          : json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString())
              : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'].toString())
              : null,
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? firebaseUid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name)';
  }
}
