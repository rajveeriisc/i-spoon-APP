import 'package:smartspoon/features/auth/domain/models/user_model.dart';

/// Abstract repository interface for authentication operations
abstract class AuthRepository {
  /// Login with email and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  });

  /// Sign up with email and password
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    String? name,
  });

  /// Verify Firebase ID token and get backend JWT
  Future<Map<String, dynamic>> verifyFirebaseToken({
    required String idToken,
  });

  /// Social login (Google, etc.)
  Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String email,
    required String name,
    required String firebaseUid,
    String? avatarUrl,
  });

  /// Logout
  Future<void> logout({bool silent = false});

  /// Get current user profile
  Future<UserModel> getMe();

  /// Update user profile
  Future<UserModel> updateProfile({
    required Map<String, dynamic> data,
  });

  /// Upload user avatar
  Future<Map<String, dynamic>> uploadAvatar({
    required List<int> bytes,
    required String filename,
  });

  /// Remove user avatar
  Future<Map<String, dynamic>> removeAvatar();

  /// Request password reset email
  Future<void> requestPasswordReset({required String email});

  /// Reset password with token
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  /// Get current auth token
  Future<String?> getToken();

  /// Check if token is valid
  Future<bool> isTokenValid();

  /// Get valid token (refresh if needed)
  Future<String?> getValidToken();
}
