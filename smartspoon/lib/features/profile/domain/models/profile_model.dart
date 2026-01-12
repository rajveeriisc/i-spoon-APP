/// Profile data model
class ProfileModel {
  final String id;
  final String email;
  final String? name;
  final String? phone;
  final String? avatarUrl;
  final Map<String, dynamic>? preferences;

  ProfileModel({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.avatarUrl,
    this.preferences,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      preferences: json['preferences'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (preferences != null) 'preferences': preferences,
    };
  }

  ProfileModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? avatarUrl,
    Map<String, dynamic>? preferences,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferences: preferences ?? this.preferences,
    );
  }
}
