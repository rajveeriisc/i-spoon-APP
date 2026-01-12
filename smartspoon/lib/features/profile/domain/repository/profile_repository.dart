import 'package:smartspoon/features/profile/domain/models/profile_model.dart';

/// Abstract repository for profile operations
abstract class ProfileRepository {
  /// Get user profile
  Future<ProfileModel> getProfile();

  /// Update user profile
  Future<ProfileModel> updateProfile(Map<String, dynamic> data);

  /// Upload profile avatar
  Future<String> uploadAvatar({
    required List<int> bytes,
    required String filename,
  });

  /// Remove profile avatar
  Future<void> removeAvatar();

  /// Update privacy settings
  Future<void> updatePrivacySettings(Map<String, dynamic> settings);

  /// Get privacy settings
  Future<Map<String, dynamic>> getPrivacySettings();
}
