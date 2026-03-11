import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Override at build time with:
  ///   flutter run --dart-define=API_BASE_URL=https://your-backend.com
  ///   flutter build apk --dart-define=API_BASE_URL=https://your-backend.com
  ///
  /// For local dev, pass your current ngrok URL via --dart-define each session.
  /// Never hardcode tunnel URLs — they change and expose your backend publicly.
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    // No URL provided — backend calls will fail gracefully.
    // Run with: flutter run --dart-define=API_BASE_URL=https://your-tunnel.ngrok-free.app
    if (kDebugMode) {
      // ignore: avoid_print
      print('⚠️ AppConfig: API_BASE_URL not set. Pass it via --dart-define=API_BASE_URL=...');
    }
    return '';
  }

  /// API version prefix
  static const String apiVersion = '/api';

  /// Full API base URL with version
  static String get apiBaseUrl => '$baseUrl$apiVersion';

  /// Connection timeout for API calls
  static const Duration connectionTimeout = Duration(seconds: 30);

  /// Receive timeout for API calls
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Maximum retry attempts for failed requests
  static const int maxRetryAttempts = 3;

  /// Initial delay for exponential backoff
  static const Duration initialRetryDelay = Duration(milliseconds: 500);

  /// Enable debug logging
  static bool get enableDebugLogging => kDebugMode;

  /// Check if backend is configured
  static bool get isBackendConfigured {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    return fromEnv.isNotEmpty;
  }

  /// Get user-friendly configuration status message
  static String get configStatusMessage {
    if (!isBackendConfigured) return 'Please set API_BASE_URL via --dart-define=API_BASE_URL=...';
    if (kIsWeb) return 'Running on web - using localhost:5000';
    if (baseUrl.contains('10.0.2.2')) return 'Android Emulator - connecting to host machine';
    return 'Backend configured at $baseUrl';
  }
}
