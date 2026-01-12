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

    // ✅ Using ngrok for easy access from any device!
    // ngrok URL (auto-configured):
    return 'https://jennine-lambent-harper.ngrok-free.dev';
    
    // 💡 For Android Emulator (localhost):
    // return 'http://10.0.2.2:5000';
    
    // 💡 For Physical Device:
    // 1. Find your computer's IP address:
    //    - Windows: Open CMD, type "ipconfig", look for "IPv4 Address"
    //    - Mac: Open Terminal, type "ifconfig | grep inet"
    // 2. Uncomment and update the line below:
    // return 'http://YOUR_COMPUTER_IP:5000';  // e.g., 'http://192.168.1.100:5000'
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
    // Accept 10.0.2.2 as valid configuration for emulator
    return !url.contains('your_local_ip') && !url.contains('localhost');
  }

  /// Get user-friendly configuration status message
  static String get configStatusMessage {
    if (kIsWeb) {
      return 'Running on web - using localhost:5000';
    }
    if (baseUrl.contains('10.0.2.2')) {
      return 'Android Emulator - connecting to host machine';
    }
    if (baseUrl.contains('ngrok')) {
      return 'Using ngrok tunnel at $baseUrl';
    }
    if (isBackendConfigured) {
      return 'Backend configured at $baseUrl';
    }
    return 'Please update backend URL in lib/config/app_config.dart';
  }
}
