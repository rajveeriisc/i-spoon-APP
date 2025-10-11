import 'package:flutter/foundation.dart';

class UserProvider with ChangeNotifier {
  int? id;
  String? email;
  String? name;
  String? phone;
  String? location;
  String? bio;
  String? dietType;
  String? activityLevel;
  List<String> allergies = const [];
  int? dailyGoal;
  bool? notificationsEnabled;
  String? emergencyContact;
  String? avatarUrl;

  void setFromMap(Map<String, dynamic> user) {
    id = user['id'] as int?;
    email = user['email'] as String?;
    name = user['name'] as String?;
    phone = user['phone'] as String?;
    location = user['location'] as String?;
    bio = user['bio'] as String?;
    dietType = user['diet_type'] as String?;
    activityLevel = user['activity_level'] as String?;
    if (user['allergies'] is List) {
      allergies = List<String>.from(user['allergies'] as List);
    }
    dailyGoal = user['daily_goal'] as int?;
    notificationsEnabled = user['notifications_enabled'] as bool?;
    emergencyContact = user['emergency_contact'] as String?;
    avatarUrl = user['avatar_url'] as String?;
    notifyListeners();
  }

  void clear() {
    id = null;
    email = null;
    name = null;
    phone = null;
    location = null;
    bio = null;
    dietType = null;
    activityLevel = null;
    allergies = const [];
    dailyGoal = null;
    notificationsEnabled = null;
    emergencyContact = null;
    avatarUrl = null;
    notifyListeners();
  }
}
