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
  double? height;
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
    
    // Parse extended fields
    age = user['age'] as int?;
    gender = user['gender'] as String?;
    height = (user['height'] as num?)?.toDouble();
    weight = (user['weight'] as num?)?.toDouble();
    
    if (user['breakfast_goal'] != null) breakfastGoal = user['breakfast_goal'] as int;
    if (user['lunch_goal'] != null) lunchGoal = user['lunch_goal'] as int;
    if (user['dinner_goal'] != null) dinnerGoal = user['dinner_goal'] as int;
    if (user['snack_goal'] != null) snackGoal = user['snack_goal'] as int;
    
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
