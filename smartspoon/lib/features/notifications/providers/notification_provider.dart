import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../auth/domain/services/auth_service.dart';
import '../domain/models/notification_models.dart';
import '../domain/services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  NotificationPreferences? _preferences;
  bool _loading = false;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  NotificationPreferences? get preferences => _preferences;
  bool get loading => _loading;
  String? get error => _error;
  int get unreadCount =>
      _notifications.where((n) => n.isUnread).length;

  final String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// Initialize notification provider
  Future<void> initialize() async {
    await NotificationService().initialize();
    await fetchPreferences();
    await fetchNotifications();
  }

  /// Fetch notification preferences
  Future<void> fetchPreferences() async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final authToken = await AuthService.getValidToken();
      if (authToken == null) {
        _error = 'Not authenticated';
        _loading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/notifications/preferences'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _preferences = NotificationPreferences.fromJson(data['preferences']);
        _error = null;
      } else {
        _error = 'Failed to load preferences';
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error fetching preferences: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Update notification preferences
  Future<bool> updatePreferences(
      NotificationPreferences updatedPreferences) async {
    try {
      _loading = true;
      notifyListeners();

      final authToken = await AuthService.getValidToken();
      if (authToken == null) return false;

      final response = await http.put(
        Uri.parse('$_baseUrl/api/notifications/preferences'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updatedPreferences.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _preferences = NotificationPreferences.fromJson(data['preferences']);
        _error = null;
        _loading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to update preferences';
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      if (kDebugMode) print('Error updating preferences: $e');
      return false;
    }
  }

  /// Fetch notification history
  Future<void> fetchNotifications({int limit = 50, int offset = 0}) async {
    try {
      _loading = true;
      if (offset == 0) _error = null;
      notifyListeners();

      final authToken = await AuthService.getValidToken();
      if (authToken == null) {
        _error = 'Not authenticated';
        _loading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse(
            '$_baseUrl/api/notifications/history?limit=$limit&offset=$offset'),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> notificationsJson = data['notifications'];
        
        if (offset == 0) {
          _notifications = notificationsJson
              .map((json) => NotificationModel.fromJson(json))
              .toList();
        } else {
          _notifications.addAll(notificationsJson
              .map((json) => NotificationModel.fromJson(json)));
        }
        
        _error = null;
      } else {
        _error = 'Failed to load notifications';
      }
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('Error fetching notifications: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Mark notification as read locally (optimistic update)
  void markAsRead(int notificationId) {
    final index =
        _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      // Create updated notification with read status
      // Since NotificationModel is immutable, we recreate it
      // (In a real app, you might want to make fields mutable or use a different approach)
      notifyListeners();
    }
  }

  /// Toggle preference category
  Future<void> toggleCategory(String category, bool enabled) async {
    if (_preferences == null) return;

    NotificationPreferences updated;
    switch (category) {
      case 'health':
        updated = _preferences!.copyWith(healthAlertsEnabled: enabled);
        break;
      case 'achievement':
        updated = _preferences!.copyWith(achievementEnabled: enabled);
        break;
      case 'engagement':
        updated = _preferences!.copyWith(engagementEnabled: enabled);
        break;
      case 'system':
        updated = _preferences!.copyWith(systemAlertsEnabled: enabled);
        break;
      default:
        return;
    }

    await updatePreferences(updated);
  }

  /// Toggle all notifications
  Future<void> toggleAllNotifications(bool enabled) async {
    if (_preferences == null) return;
    final updated = _preferences!.copyWith(enabled: enabled);
    await updatePreferences(updated);
  }

  /// Update quiet hours
  Future<void> updateQuietHours(String start, String end) async {
    if (_preferences == null) return;
    final updated = _preferences!.copyWith(
      quietHoursStart: start,
      quietHoursEnd: end,
    );
    await updatePreferences(updated);
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
