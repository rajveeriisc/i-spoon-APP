import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/pages/edit_profile_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartspoon/pages/login_screen.dart';
import 'package:smartspoon/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/state/user_provider.dart';
import 'package:smartspoon/main.dart';
import 'package:smartspoon/pages/terms_page.dart';
import 'package:smartspoon/features/core/widgets/network_avatar.dart';
import 'package:smartspoon/features/profile/widgets/profile_section_card.dart';
import 'package:smartspoon/features/profile/widgets/profile_list_item.dart';
import 'package:smartspoon/features/profile/widgets/user_info_card.dart';
import 'package:smartspoon/features/profile/widgets/faq_section_card.dart';
import 'package:smartspoon/features/profile/widgets/faq_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          ProfileUserInfoCard(
            onEditProfile: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
          const SizedBox(height: 30),
          const HealthPreferencesCard(),
          const SizedBox(height: 30),

          const AppSettingsCard(),
          const SizedBox(height: 30),
          const HelpSupportCard(),
          const SizedBox(height: 30),
          const FaqSectionCard(),
          const SizedBox(height: 30),
          const AppInfoCard(),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await AuthService.logout();
                } catch (_) {
                  // ignore storage errors on web
                }
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserInfoCard extends StatelessWidget {
  const UserInfoCard({super.key, required this.onEditProfile});

  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final double radius = (constraints.maxWidth * 0.22).clamp(
              48.0,
              72.0,
            );
            return Stack(
              alignment: Alignment.bottomRight,
              children: [
                Consumer<UserProvider>(
                  builder: (_, user, __) =>
                      NetworkAvatar(radius: radius, avatarUrl: user.avatarUrl),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _showAvatarPicker(context),
                      child: Padding(
                        padding: EdgeInsets.all(
                          (radius * 0.18).clamp(6.0, 10.0),
                        ),
                        child: Icon(
                          Icons.photo_camera,
                          size: (radius * 0.32).clamp(16.0, 22.0),
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 15),
        Consumer<UserProvider>(
          builder: (_, user, __) {
            final name = (user.name ?? '').trim();
            return Text(
              name.isNotEmpty ? name : 'Your Name',
              style: GoogleFonts.lato(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        const SizedBox(height: 5),
        Consumer<UserProvider>(
          builder: (_, user, __) {
            final email = (user.email ?? '').trim();
            return Text(
              email.isNotEmpty ? email : 'your@email.com',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        _AvatarActions(onEditProfile: onEditProfile),
      ],
    );
  }
}

// Avatar upload helpers
Future<void> _pickAndUpload(BuildContext context, ImageSource source) async {
  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1024,
  );
  if (file == null) return;
  final bytes = await file.readAsBytes();
  try {
    final resp = await AuthService.uploadAvatar(
      bytes: bytes,
      filename: file.name,
    );
    final user = resp['user'] as Map<String, dynamic>?;
    if (user != null && context.mounted) {
      final updated = Map<String, dynamic>.from(user);
      final url = updated['avatar_url'];
      if (url is String && url.isNotEmpty) {
        updated['avatar_url'] =
            '$url?v=${DateTime.now().millisecondsSinceEpoch}';
      }
      Provider.of<UserProvider>(context, listen: false).setFromMap(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    }
  } on AuthException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Upload failed')));
  }
}

void _showAvatarPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUpload(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Capture with Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUpload(context, ImageSource.camera);
              },
            ),
          ],
        ),
      );
    },
  );
}

class _AvatarActions extends StatelessWidget {
  const _AvatarActions({required this.onEditProfile});
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: onEditProfile,
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit Profile'),
        ),
      ],
    );
  }
}

class HealthPreferencesCard extends StatelessWidget {
  const HealthPreferencesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Health & Eating Preferences',
      children: [
        Consumer<UserProvider>(
          builder: (_, user, __) => ProfileListItem(
            icon: Icons.track_changes,
            title: 'Daily Goal',
            value: user.dailyGoal != null ? '${user.dailyGoal} Bites' : '—',
          ),
        ),
        const ProfileListItem(
          icon: Icons.local_fire_department,
          title: 'Current Streak',
          value: '—',
        ),
        Consumer<UserProvider>(
          builder: (_, user, __) => ProfileListItem(
            icon: Icons.restaurant_menu,
            title: 'Diet Type',
            value: (user.dietType ?? '').isNotEmpty ? user.dietType! : '—',
          ),
        ),
      ],
    );
  }
}

class AppSettingsCard extends StatelessWidget {
  const AppSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'App Settings',
      children: [
        Consumer<ThemeProvider>(
          builder: (_, theme, __) => ProfileListItem(
            icon: Icons.color_lens,
            title: 'Theme',
            value: theme.themeMode == ThemeMode.dark ? 'Dark' : 'Light',
            isToggle: true,
            toggleValue: theme.themeMode == ThemeMode.dark,
            onToggle: (_) => theme.toggleTheme(),
          ),
        ),
        Consumer<UserProvider>(
          builder: (context, user, __) => ProfileListItem(
            icon: Icons.notifications,
            title: 'Notifications',
            value: (user.notificationsEnabled ?? true) ? 'On' : 'Off',
            isToggle: true,
            toggleValue: user.notificationsEnabled ?? true,
            onToggle: (val) async {
              try {
                final res = await AuthService.updateProfile(
                  data: {'notifications_enabled': val},
                );
                final u = res['user'] as Map<String, dynamic>?;
                if (u != null) {
                  Provider.of<UserProvider>(
                    context,
                    listen: false,
                  ).setFromMap(u);
                }
              } catch (_) {}
            },
          ),
        ),
        const ProfileListItem(
          icon: Icons.privacy_tip,
          title: 'Privacy Settings',
          value: '',
        ),
      ],
    );
  }
}

class HelpSupportCard extends StatelessWidget {
  const HelpSupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Help & Support',
      children: [
        ProfileListItem(
          icon: Icons.quiz,
          title: 'FAQ',
          value: '',
          onTap: () {
            debugPrint('FAQ tapped - navigating to FaqPage');
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FaqPage()));
          },
        ),
        ProfileListItem(
          icon: Icons.feedback,
          title: 'Send Feedback',
          value: '',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Feedback: support@smartspoon.app')),
            );
          },
        ),
        ProfileListItem(
          icon: Icons.support_agent,
          title: 'Contact Support',
          value: '',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact: support@smartspoon.app')),
            );
          },
        ),
      ],
    );
  }
}

class AppInfoCard extends StatelessWidget {
  const AppInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'App Info',
      children: [
        const ProfileListItem(
          icon: Icons.info,
          title: 'App Version',
          value: '1.0.0',
        ),
        ProfileListItem(
          icon: Icons.description,
          title: 'Terms & Policy',
          value: '',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TermsPage()));
          },
        ),
      ],
    );
  }
}

// Activity & Achievements removed per requirements
