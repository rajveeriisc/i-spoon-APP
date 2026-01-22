import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartspoon/core/config/app_config.dart';

/// Simple JWT decoder for extracting token expiry
class _JWTDecoder {
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode the payload (second part)
      final payload = parts[1];
      // Add padding if needed for base64 decoding
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JWT decode error: $e');
      return null;
    }
  }

  static DateTime? getExpiry(String token) {
    final payload = decodePayload(token);
    if (payload == null) return null;

    final exp = payload['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    }
    return null;
  }
}

class AuthService {
  AuthService._();

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static final Map<String, String?> _memoryStorage = <String, String?>{};

  static DateTime? _tokenExpiry;
  static Timer? _refreshTimer;

  static Future<void> _setItem(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      _memoryStorage[key] = value;
    }
  }

  static Future<String?> _getItem(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return _memoryStorage[key];
    }
  }

  static Future<void> _removeItem(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      _memoryStorage.remove(key);
    }
  }

  static String get baseUrl => AppConfig.baseUrl;
  static String get apiBaseUrl => AppConfig.apiBaseUrl;

  /// Check backend connectivity
  static Future<bool> checkBackendHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/api/health');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('Backend health check failed: $e');
      return false;
    }
  }

  static const _accessTokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';

  static Future<void> _saveTokensFromResponse(Map<String, dynamic> data) async {
    final tokens = data['tokens'];
    final tokenFromRoot = data['token'];
    final accessToken = tokenFromRoot is String
        ? tokenFromRoot
        : tokens is Map<String, dynamic>
        ? tokens['accessToken'] as String?
        : null;
    final refreshToken = tokens is Map<String, dynamic>
        ? tokens['refreshToken'] as String?
        : data['refreshToken'] as String?;

    if (accessToken != null) {
      await _setItem(_accessTokenKey, accessToken);
      _scheduleTokenRefresh(accessToken);
    }
    if (refreshToken != null) {
      await _setItem(_refreshTokenKey, refreshToken);
    }
  }

  static Future<String?> _refreshAccessToken() async {
    final refreshToken = await _getItem(_refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final uri = Uri.parse('$apiBaseUrl/auth/refresh');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(AppConfig.connectionTimeout);

      final data = _decodeBody(resp.body);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        await _saveTokensFromResponse(data);
        return data['token'] as String?;
      }

      throw AuthException(_extractErrorMessage(data));
    } catch (e) {
      debugPrint('Refresh token request failed: $e');
      await logout(silent: true);
      return null;
    }
  }

  /// Manually save access token (e.g. for Firebase-only auth)
  static Future<void> saveToken(String token) async {
    await _setItem(_accessTokenKey, token);
    _scheduleTokenRefresh(token);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/auth/login');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(AppConfig.connectionTimeout);

    final Map<String, dynamic> data = _decodeBody(resp.body);
    if (resp.statusCode == 200) {
      await _saveTokensFromResponse(data);
      return data;
    }
    throw AuthException(_extractErrorMessage(data));
  }

  /// Schedule automatic token refresh before expiry
  static void _scheduleTokenRefresh(String token) {
    try {
      _refreshTimer?.cancel();

      final expiry = _JWTDecoder.getExpiry(token);
      if (expiry == null) {
        debugPrint('Could not decode token expiry, using default');
        _tokenExpiry = DateTime.now().add(const Duration(days: 7));
      } else {
        _tokenExpiry = expiry;
        debugPrint('Token expires at: $_tokenExpiry');
      }

      final now = DateTime.now();
      final refreshAt = _tokenExpiry!.subtract(const Duration(hours: 1));
      final delay = refreshAt.difference(now);

      if (delay.isNegative) {
        debugPrint('Token already expired or expiring soon');
        _refreshAccessToken();
        return;
      }

      debugPrint('Token refresh scheduled in ${delay.inMinutes} minutes');

      _refreshTimer = Timer(delay, () async {
        debugPrint('Refreshing token via backend...');
        await _refreshAccessToken();
      });
    } catch (e) {
      debugPrint('Failed to schedule token refresh: $e');
    }
  }

  /// Check if token is expired or expiring soon
  static bool isTokenExpiringSoon() {
    if (_tokenExpiry == null) return true;
    final now = DateTime.now();
    final daysUntilExpiry = _tokenExpiry!.difference(now).inDays;
    return daysUntilExpiry < 1; // Less than 1 day remaining
  }

  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/auth/signup');
    final body = {
      'email': email.trim(),
      'password': password,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    };
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(AppConfig.connectionTimeout);
    final Map<String, dynamic> data = _decodeBody(resp.body);
    if (resp.statusCode == 201) {
      return data;
    }
    throw AuthException(_extractErrorMessage(data));
  }

  // Social login (Google, etc.)
  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String email,
    required String name,
    required String firebaseUid,
    String? avatarUrl,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/auth/social');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'provider': provider,
            'email': email,
            'name': name,
            'firebase_uid': firebaseUid,
            'avatar_url': avatarUrl,
          }),
        )
        .timeout(AppConfig.connectionTimeout);
    final data = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      await _saveTokensFromResponse(data);
      return data;
    }
    throw AuthException(_extractErrorMessage(data));
  }

  /// Verify Firebase ID Token with Backend and get Backend JWT
  ///
  /// AUTH FLOW:
  /// 1. Called from login_screen.dart after Firebase sign-in succeeds
  /// 2. POST request to backend: /api/auth/firebase/verify
  /// 3. Backend verifies token with Firebase Admin SDK
  /// 4. Backend upserts user in PostgreSQL database
  /// 5. Backend generates JWT tokens (accessToken + refreshToken)
  /// 6. This function saves tokens to FlutterSecureStorage
  /// 7. Returns backend user data and tokens
  ///
  /// CALLED BY: login_screen.dart → _login() and _signInWithGoogle()
  /// NEXT STEP: login_screen.dart calls getMe() to fetch user profile,
  ///            then navigates to HomePage
  static Future<Map<String, dynamic>> verifyFirebaseToken({
    required String idToken,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/auth/firebase/verify');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(AppConfig.connectionTimeout);
    final data = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      await _saveTokensFromResponse(data);
      return data;
    }
    throw AuthException(_extractErrorMessage(data));
  }

  static Future<void> logout({bool silent = false}) async {
    // Cancel token refresh timer
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _tokenExpiry = null;

    final refreshToken = await _getItem(_refreshTokenKey);

    if (!silent && refreshToken != null) {
      try {
        final uri = Uri.parse('$apiBaseUrl/auth/logout');
        await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      } catch (e) {
        debugPrint('Logout request failed: $e');
      }
    }

    await _removeItem(_refreshTokenKey);
    await _removeItem(_accessTokenKey);
  }

  static Future<String?> getToken() => _getItem(_accessTokenKey);

  /// Validate if stored token is still valid
  static Future<bool> isTokenValid() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return false;

      // Decode and check expiry
      final expiry = _JWTDecoder.getExpiry(token);
      if (expiry == null) return false;

      final now = DateTime.now();
      if (now.isBefore(expiry.subtract(const Duration(minutes: 5)))) {
        return true;
      }

      final refreshed = await _refreshAccessToken();
      return refreshed != null;
    } catch (e) {
      debugPrint('Token validation error: $e');
      return false;
    }
  }

  /// Get current user ID from stored token
  static Future<String?> getUserId() async {
    final token = await getToken();
    if (token == null) return null;
    final payload = _JWTDecoder.decodePayload(token);
    return payload?['id'] as String?;
  }

  static Completer<String?>? _refreshCompleter;

  /// Get token only if it's valid, otherwise clear it
  static Future<String?> getValidToken() async {
    // Prevent multiple parallel refresh calls
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final token = await getToken();
    if (token == null) {
      _refreshCompleter = Completer<String?>();
      try {
        final newToken = await _refreshAccessToken();
        _refreshCompleter!.complete(newToken);
        return newToken;
      } catch (e) {
        _refreshCompleter!.complete(null);
        return null;
      } finally {
        _refreshCompleter = null;
      }
    }

    final isValid = await isTokenValid();
    if (!isValid) {
      _refreshCompleter = Completer<String?>();
      try {
        final newToken = await _refreshAccessToken();
        _refreshCompleter!.complete(newToken);
        return newToken;
      } catch (e) {
        _refreshCompleter!.complete(null);
        return null;
      } finally {
        _refreshCompleter = null;
      }
    }

    return token;
  }

  static Future<Map<String, dynamic>> updateProfile({
    required Map<String, dynamic> data,
  }) async {
    final token = await getValidToken();
    if (token == null) throw AuthException('Not authenticated');
    final uri = Uri.parse('$apiBaseUrl/users/me');
    final resp = await http
        .put(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        )
        .timeout(AppConfig.connectionTimeout);
    final body = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    throw AuthException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> getMe() async {
    final token = await getValidToken();
    if (token == null) throw AuthException('Not authenticated');
    final uri = Uri.parse('$apiBaseUrl/users/me');
    final resp = await http
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(AppConfig.connectionTimeout);
    final body = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    throw AuthException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await getValidToken();
    if (token == null) throw AuthException('Not authenticated');
    final uri = Uri.parse('$apiBaseUrl/users/me/avatar');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    final mimeType =
        lookupMimeType(filename, headerBytes: bytes) ?? 'image/jpeg';
    final parts = mimeType.split('/');
    request.files.add(
      http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: filename,
        contentType: MediaType(parts.first, parts.last),
      ),
    );
    final streamed = await request.send().timeout(
      const Duration(seconds: 30),
    ); // Longer timeout for file uploads
    final resp = await http.Response.fromStream(streamed);
    final body = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    throw AuthException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> removeAvatar() async {
    final token = await getValidToken();
    if (token == null) throw AuthException('Not authenticated');
    final uri = Uri.parse('$apiBaseUrl/users/me/avatar');
    final resp = await http
        .delete(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(AppConfig.connectionTimeout);
    final body = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    throw AuthException(_extractErrorMessage(body));
  }

  // Trends/stats removed per requirements

  // Forgot password: request reset link via email
  static Future<void> requestPasswordReset({required String email}) async {
    final uri = Uri.parse('$apiBaseUrl/auth/forgot');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(AppConfig.connectionTimeout);
    // backend always returns 200 with generic message; treat 2xx as OK
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final data = _decodeBody(resp.body);
      throw AuthException(_extractErrorMessage(data));
    }
  }

  // Reset password using token from email
  static Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/auth/reset');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token, 'password': newPassword}),
        )
        .timeout(AppConfig.connectionTimeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final data = _decodeBody(resp.body);
      throw AuthException(_extractErrorMessage(data));
    }
  }

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      final dynamic parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
      return {'message': parsed.toString()};
    } catch (_) {
      return {'message': body};
    }
  }

  static String _extractErrorMessage(Map<String, dynamic> data) {
    if (data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
      final Map errMap = data['errors'] as Map;
      return errMap.values.first.toString();
    }
    return (data['message'] as String?) ?? 'Request failed';
  }

  // Web-only helpers removed
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
