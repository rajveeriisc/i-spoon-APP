import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../auth/domain/services/auth_service.dart';

/// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _fcmToken;

  final String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permissions
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) print('Notification permissions granted');
      } else {
        if (kDebugMode) print('Notification permissions denied');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _fcm.getToken();
      if (kDebugMode) print('FCM Token: $_fcmToken');

      // Register token with backend
      if (_fcmToken != null) {
        await _registerFCMToken(_fcmToken!);
      }

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerFCMToken(newToken);
      });

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listen for notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _initialized = true;
      if (kDebugMode) print('NotificationService initialized');
    } catch (e) {
      if (kDebugMode) print('Error initializing NotificationService: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    // Create Android notification channels
    await _createAndroidChannels();
  }

  /// Create Android notification channels
  Future<void> _createAndroidChannels() async {
    const healthChannel = AndroidNotificationChannel(
      'health_alerts',
      'Health Alerts',
      description: 'Notifications about eating pace, tremors, and temperature',
      importance: Importance.high,
      playSound: true,
    );

    const achievementChannel = AndroidNotificationChannel(
      'achievements',
      'Achievements',
      description: 'Goal completions and milestones',
      importance: Importance.defaultImportance,
    );

    const engagementChannel = AndroidNotificationChannel(
      'engagement',
      'Reminders',
      description: 'Meal reminders and insights',
      importance: Importance.low,
    );

    const systemChannel = AndroidNotificationChannel(
      'system_alerts',
      'System Alerts',
      description: 'Battery, sync, and update notifications',
      importance: Importance.max,
      playSound: true,
    );

    final plugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (plugin != null) {
      await plugin.createNotificationChannel(healthChannel);
      await plugin.createNotificationChannel(achievementChannel);
      await plugin.createNotificationChannel(engagementChannel);
      await plugin.createNotificationChannel(systemChannel);
    }
  }

  /// Register FCM token with backend
  Future<void> _registerFCMToken(String token) async {
    try {
      final authToken = await AuthService.getValidToken();
      if (authToken == null) return;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/fcm-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) print('FCM token registered successfully');
      } else {
        if (kDebugMode) print('Failed to register FCM token: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('Error registering FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground message received: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
    }

    // Show local notification
    _showLocalNotification(message);

    // Mark as delivered
    if (message.data['notification_id'] != null) {
      // Could track delivery here if needed
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final priority = message.data['priority'] ?? 'LOW';
    final type = message.data['type'] ?? '';
    final channelId = _getChannelId(type);

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      importance: priority == 'CRITICAL' || priority == 'HIGH'
          ? Importance.high
          : Importance.defaultImportance,
      priority: priority == 'CRITICAL' || priority == 'HIGH'
          ? Priority.high
          : Priority.defaultPriority,
      playSound: priority == 'CRITICAL',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Handle notification tap (from background/terminated state)
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) print('Notification tapped: ${message.messageId}');

    final notificationId = message.data['notification_id'];
    if (notificationId != null) {
      markNotificationOpened(int.parse(notificationId));
    }

    // Navigate based on action_type
    final actionType = message.data['action_type'];
    if (actionType != null && actionType.isNotEmpty) {
      _navigateToScreen(actionType, message.data['action_data']);
      
      if (notificationId != null) {
        markNotificationActionTaken(int.parse(notificationId));
      }
    }
  }

  /// Handle local notification tap
  void _handleLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!);
      final notificationId = data['notification_id'];
      final actionType = data['action_type'];

      if (notificationId != null) {
        markNotificationOpened(int.parse(notificationId));
      }

      if (actionType != null && actionType.isNotEmpty) {
        _navigateToScreen(actionType, data['action_data']);
        
        if (notificationId != null) {
          markNotificationActionTaken(int.parse(notificationId));
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error handling local notification tap: $e');
    }
  }

  /// Navigate to appropriate screen based on action type
  void _navigateToScreen(String actionType, dynamic actionData) {
    // TODO: Implement navigation using NavigatorKey or GetIt service
    if (kDebugMode) print('Navigate to: $actionType with data: $actionData');
    // Example:
    // if (actionType == 'open_insights') {
    //   navigatorKey.currentState?.pushNamed('/insights');
    // }
  }

  /// Get channel ID based on notification type
  String _getChannelId(String type) {
    if (type.contains('alert') || type.contains('spike') || type.contains('temperature')) {
      return 'health_alerts';
    }
    if (type.contains('goal') || type.contains('streak') || type.contains('best')) {
      return 'achievements';
    }
    if (type.contains('reminder') || type.contains('insight') || type.contains('inactive')) {
      return 'engagement';
    }
    if (type.contains('battery') || type.contains('sync') || type.contains('firmware')) {
      return 'system_alerts';
    }
    return 'default';
  }

  /// Get channel name
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'health_alerts':
        return 'Health Alerts';
      case 'achievements':
        return 'Achievements';
      case 'engagement':
        return 'Reminders';
      case 'system_alerts':
        return 'System Alerts';
      default:
        return 'Notifications';
    }
  }

  /// Mark notification as opened (API call)
  Future<void> markNotificationOpened(int notificationId) async {
    try {
      final authToken = await AuthService.getValidToken();
      if (authToken == null) return;

      await http.post(
        Uri.parse('$_baseUrl/api/notifications/$notificationId/opened'),
        headers: {'Authorization': 'Bearer $authToken'},
      );
    } catch (e) {
      if (kDebugMode) print('Error marking notification opened: $e');
    }
  }

  /// Mark notification action taken (API call)
  Future<void> markNotificationActionTaken(int notificationId) async {
    try {
      final authToken = await AuthService.getValidToken();
      if (authToken == null) return;

      await http.post(
        Uri.parse('$_baseUrl/api/notifications/$notificationId/action'),
        headers: {'Authorization': 'Bearer $authToken'},
      );
    } catch (e) {
      if (kDebugMode) print('Error marking notification action: $e');
    }
  }

  /// Get FCM token
  String? get fcmToken => _fcmToken;
}
