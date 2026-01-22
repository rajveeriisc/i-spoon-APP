import 'package:flutter/foundation.dart';

class UserProvider with ChangeNotifier {
  int? id;
  String? email;
  String? name;
  String? phone;
  String? location;
  int? dailyGoal;
  bool? notificationsEnabled;
  String? avatarUrl;
  
  // Extended fields for Profile Redesign
  int? age;
  String? gender;
  double? weight;

  void setFromMap(Map<String, dynamic> user) {
    id = user['id'] as int?;
    email = user['email'] as String?;
    name = user['name'] as String?;
    phone = user['phone'] as String?;
    location = user['location'] as String?;
    dailyGoal = user['daily_goal'] as int?;
    notificationsEnabled = user['notifications_enabled'] as bool?;
    avatarUrl = user['avatar_url'] as String?;
    
    // Parse extended fields (check root first, then nested in profile_metadata)
    age = user['age'] as int?;
    gender = user['gender'] as String?;
    weight = (user['weight'] as num?)?.toDouble();

    if (user['profile_metadata'] != null) {
      final meta = user['profile_metadata'];
      if (meta is Map) {
         if (age == null && meta['age'] != null) age = meta['age'] as int;
         if (gender == null && meta['gender'] != null) gender = meta['gender'] as String;
         if (weight == null && meta['weight'] != null) weight = (meta['weight'] as num).toDouble();
      }
    }
    
    notifyListeners();
  }

  void clear() {
    id = null;
    email = null;
    name = null;
    phone = null;
    location = null;
    dailyGoal = null;
    notificationsEnabled = null;
    avatarUrl = null;
    age = null;
    gender = null;
    weight = null;
    notifyListeners();
  }
}
