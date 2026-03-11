import 'package:flutter/foundation.dart';

class UserProvider with ChangeNotifier {
  int?    id;
  String? email;
  String? name;
  String? phone;
  String? gender;
  String? location;
  int?    age;
  String? avatarUrl;

  bool? _notificationsEnabled;
  bool? get notificationsEnabled => _notificationsEnabled;
  set notificationsEnabled(bool? value) {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    notifyListeners();
  }

  void setFromMap(Map<String, dynamic> user) {
    id                    = user['id'] as int?;
    email                 = user['email'] as String?;
    name                  = user['name'] as String?;
    phone                 = user['phone'] as String?;
    gender                = user['gender'] as String?;
    location              = user['location'] as String?;
    age                   = user['age'] as int?;
    _notificationsEnabled = user['notifications_enabled'] as bool?;
    avatarUrl             = user['avatar_url'] as String?;
    notifyListeners();
  }

  void clear() {
    id                    = null;
    email                 = null;
    name                  = null;
    phone                 = null;
    gender                = null;
    location              = null;
    age                   = null;
    _notificationsEnabled = null;
    avatarUrl             = null;
    notifyListeners();
  }
}
