import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static String get baseUrl {
    // Check for build-time override
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    // Platform-specific defaults for local testing
    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    // TODO: Update this IP to your local machine's IP address
    // Example: return 'http://192.168.1.100:5000';
    return 'http://10.121.55.85:5000';
  }

  /// API version prefix (removed for local testing)
  static const String apiVersion = '/api';

  /// Full API base URL with version
  static String get apiBaseUrl => '$baseUrl$apiVersion';

  /// Connection timeout for API calls
  static const Duration connectionTimeout = Duration(seconds: 10);

  /// Receive timeout for API calls
  static const Duration receiveTimeout = Duration(seconds: 10);

  /// Maximum retry attempts for failed requests
  static const int maxRetryAttempts = 3;

  /// Initial delay for exponential backoff
  static const Duration initialRetryDelay = Duration(milliseconds: 500);

  /// Enable debug logging
  static bool get enableDebugLogging => kDebugMode;

  /// Check if backend is configured
  static bool get isBackendConfigured {
    final url = baseUrl.toLowerCase();
    // Check if URL contains placeholder or default values
    return !url.contains('your_local_ip') &&
        !url.contains('localhost') &&
        !url.contains('10.121.55.85');
  }

  /// Get user-friendly configuration status message
  static String get configStatusMessage {
    if (kIsWeb) {
      return 'Running on web - using localhost:5000';
    }
    if (isBackendConfigured) {
      return 'Backend configured at $baseUrl';
    }
    return 'Please update backend URL in lib/config/app_config.dart';
  }
}
