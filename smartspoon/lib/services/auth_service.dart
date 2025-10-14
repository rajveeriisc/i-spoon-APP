import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Cookie-based web helpers removed

class AuthService {
  AuthService._();

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  // In-memory fallback to avoid crashes on unsupported platforms (e.g., web/desktop)
  static final Map<String, String?> _memoryStorage = <String, String?>{};

  static Future<void> _setItem(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Fallback for platforms where secure storage is unavailable
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

  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator -> host machine
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  static String get baseUrl => _baseUrl;

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/login');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    final Map<String, dynamic> data = _decodeBody(resp.body);
    if (resp.statusCode == 200) {
      final token = data['token'] as String?;
      if (token != null) {
        await _setItem('auth_token', token);
      }
      return data;
    }
    throw AuthException(_extractErrorMessage(data));
  }

  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? name,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/signup');
    final body = {
      'email': email.trim(),
      'password': password,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    };
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
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
    final uri = Uri.parse('$_baseUrl/api/auth/social');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': provider,
        'email': email,
        'name': name,
        'firebase_uid': firebaseUid,
        'avatar_url': avatarUrl,
      }),
    );
    final data = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (data.containsKey('token')) {
        await _setItem('auth_token', data['token'] as String);
      }
      return data;
    }
    throw AuthException(_extractErrorMessage(data));
  }

  // Verify Firebase ID token with backend and receive backend JWT
  static Future<Map<String, dynamic>> verifyFirebaseToken({
    required String idToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/auth/firebase/verify');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    final data = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final token = data['token'] as String?;
      if (token != null) {
        await _setItem('auth_token', token);
      }
      return data;
    }
    throw AuthException(_extractErrorMessage(data));
  }

  static Future<void> logout() async {
    // nothing server-side to clear
    await _removeItem('auth_token');
  }

  static Future<String?> getToken() => _getItem('auth_token');

  static Future<Map<String, dynamic>> updateProfile({
    required Map<String, dynamic> data,
  }) async {
    final token = await getToken();
    if (token == null) throw AuthException('Not authenticated');
    final uri = Uri.parse('$_baseUrl/api/users/me');
    final resp = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    final body = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    throw AuthException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();
    if (token == null) throw AuthException('Not authenticated');
    final uri = Uri.parse('$_baseUrl/api/users/me');
    final resp = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final body = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    throw AuthException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await getToken();
    if (token == null) throw AuthException('Not authenticated');
    final uri = Uri.parse('$_baseUrl/api/users/me/avatar');
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
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    final body = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    throw AuthException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> removeAvatar() async {
    final token = await getToken();
    if (token == null) throw AuthException('Not authenticated');
    final uri = Uri.parse('$_baseUrl/api/users/me/avatar');
    final resp = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = _decodeBody(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) return body;
    throw AuthException(_extractErrorMessage(body));
  }

  // Trends/stats removed per requirements

  // Forgot password: request reset link via email
  static Future<void> requestPasswordReset({required String email}) async {
    final uri = Uri.parse('$_baseUrl/api/auth/forgot');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );
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
    final uri = Uri.parse('$_baseUrl/api/auth/reset');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'password': newPassword}),
    );
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
