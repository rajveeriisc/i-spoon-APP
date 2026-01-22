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
  
  // Extended fields for Profile Redesign
  int? age;
  String? gender;
  double? weight;
  
  // Meal-specific goals
  int breakfastGoal = 15;
  int lunchGoal = 20;
  int dinnerGoal = 15;
  int snackGoal = 5;

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

    // Check for flattened fields (legacy or manual passed)
    if (user['breakfast_goal'] != null) breakfastGoal = user['breakfast_goal'] as int;
    if (user['lunch_goal'] != null) lunchGoal = user['lunch_goal'] as int;
    if (user['dinner_goal'] != null) dinnerGoal = user['dinner_goal'] as int;
    if (user['snack_goal'] != null) snackGoal = user['snack_goal'] as int;

    // Check for nested bite_goals (standard backend format)
    if (user['bite_goals'] != null) {
      final goals = user['bite_goals'];
      if (goals is Map) {
         if (goals['breakfast'] != null) breakfastGoal = goals['breakfast'] as int;
         if (goals['lunch'] != null) lunchGoal = goals['lunch'] as int;
         if (goals['dinner'] != null) dinnerGoal = goals['dinner'] as int;
         if (goals['snack'] != null) snackGoal = goals['snack'] as int;
         if (goals['daily'] != null) dailyGoal = goals['daily'] as int;
      } else if (goals is String) {
         // TODO: Handle string parsing if needed, but pg driver usually returns map
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
    bio = null;
    dietType = null;
    activityLevel = null;
    allergies = const [];
    dailyGoal = null;
    notificationsEnabled = null;
    emergencyContact = null;
    avatarUrl = null;
    breakfastGoal = 15;
    lunchGoal = 20;
    dinnerGoal = 15;
    snackGoal = 5;
    notifyListeners();
  }
}
