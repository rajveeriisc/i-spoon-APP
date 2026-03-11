import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:smartspoon/core/config/app_config.dart';
import 'package:smartspoon/features/auth/domain/services/auth_service.dart';
import 'package:smartspoon/main.dart'; // Import navigatorKey

/// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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
  Completer<void>? _initCompleter;
  String? _fcmToken;

  final String _baseUrl = AppConfig.apiBaseUrl;

  /// Initialize notification service.
  /// Concurrent callers wait for the same initialization — only one runs.
  Future<void> initialize() async {
    if (_initialized) return;

    // If init is already in progress, wait for it instead of running again.
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();

    try {
      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

      // Get FCM token — on iOS the APNs token may not be ready immediately,
      // so we retry a few times with a short delay before giving up.
      _fcmToken = await _getFcmTokenSafely();
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
      _initCompleter!.complete();
    } catch (e) {
      if (kDebugMode) print('Error initializing NotificationService: $e');
      _initCompleter!.completeError(e);
      _initCompleter = null; // Allow retry on next call if init failed
    }
  }

  /// Safely get the FCM token, retrying on iOS if APNs token isn't ready yet.
  Future<String?> _getFcmTokenSafely() async {
    // On iOS the APNs token is registered asynchronously after app launch.
    // Calling getToken() before it's ready throws apns-token-not-set.
    // We retry up to 6 times with exponential backoff (2s, 4s, 8s, 16s, 32s, 32s).
    final maxAttempts = Platform.isIOS ? 6 : 2;
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final token = await _fcm.getToken();
        if (token != null) return token;
      } catch (e) {
        if (kDebugMode) print('FCM token attempt ${i + 1} failed: $e');
      }
      if (i < maxAttempts - 1) {
        // Exponential backoff: 2s, 4s, 8s, 16s, 32s (capped)
        final delaySeconds = (2 << i).clamp(2, 32);
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
    // Token unavailable right now — onTokenRefresh listener above will deliver it later
    if (kDebugMode) print('FCM token unavailable after $maxAttempts attempts — relying on onTokenRefresh');
    return null;
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

    // Explicitly request permission for Android 13+ via local notifications plugin
    // This is more reliable than FCM's requestPermission on some devices
    final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
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
      
      // If no auth token (user not logged in), we can't register the FCM token yet.
      // This is expected during onboarding/login screens.
      if (authToken == null) {
          if (kDebugMode) print('ℹ️ User not logged in. Skipping FCM token registration.');
          return;
      }

      final url = Uri.parse('$_baseUrl/notifications/fcm-token');
      if (kDebugMode) print('Registering FCM Token at: $url');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) print('✅ FCM token registered successfully');
      } else {
        if (kDebugMode) print('⚠️ Failed to register FCM token: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) print('❌ Error registering FCM token: $e\n$stackTrace');
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

  /// Explicitly show a local alert from any service
  Future<void> showLocalAlert({
    required String title,
    required String body,
    String type = 'default',
    String priority = 'DEFAULT',
    Map<String, dynamic>? data,
  }) async {
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
      playSound: priority == 'CRITICAL' || priority == 'HIGH',
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
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: data != null ? jsonEncode(data) : null,
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
    if (kDebugMode) print('Navigate to: $actionType with data: $actionData');
    
    // Use the global navigator key to navigate
    // Note: This requires a GlobalKey<NavigatorState> to be set up in main.dart
    // For now, we'll just log the action. Implement navigation when GlobalKey is available.
    
    // Example implementation (uncomment when GlobalKey is set up):
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    // Parse action data if needed
    Map<String, dynamic>? parsedData;
    if (actionData is String) {
      try {
        parsedData = jsonDecode(actionData);
      } catch (e) {
        if (kDebugMode) print('Error parsing action data: $e');
      }
    } else if (actionData is Map) {
      parsedData = Map<String, dynamic>.from(actionData);
    }
    
    switch (actionType) {
      case 'open_insights':
        Navigator.of(context).pushNamed('/insights');
        break;
      case 'open_tremor_analysis':
        // Note: Assuming routes are set up or using direct push
        // Navigator.of(context).pushNamed('/tremor-analysis', arguments: parsedData);
        if (kDebugMode) print('Navigating to tremor analysis with $parsedData');
        break;
      case 'open_temperature':
        // Navigator.of(context).pushNamed('/temperature', arguments: parsedData);
        break;
      case 'open_profile':
        // Navigator.of(context).pushNamed('/profile');
        break;
      default:
        if (kDebugMode) print('Unknown action type: $actionType');
    }
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

      final url = Uri.parse('$_baseUrl/notifications/$notificationId/opened');
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) print('✅ Notification $notificationId marked as opened');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error marking notification opened: $e');
    }
  }

  /// Mark notification action taken (API call)
  Future<void> markNotificationActionTaken(int notificationId) async {
    try {
      final authToken = await AuthService.getValidToken();
      if (authToken == null) return;

      final url = Uri.parse('$_baseUrl/notifications/$notificationId/action');
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $authToken'},
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) print('✅ Notification $notificationId action recorded');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error marking notification action: $e');
    }
  }



  /// Get FCM token
  String? get fcmToken => _fcmToken;
}
