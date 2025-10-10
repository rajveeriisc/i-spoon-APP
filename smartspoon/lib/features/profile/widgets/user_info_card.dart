import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/services/auth_service.dart';
import 'package:smartspoon/state/user_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/ui/widgets/network_avatar.dart';

class ProfileUserInfoCard extends StatelessWidget {
  const ProfileUserInfoCard({super.key, required this.onEditProfile});

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
                  builder: (_, user, __) => NetworkAvatar(
                    radius: radius,
                    avatarUrl: user.avatarUrl,
                    displayName: user.name,
                  ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit Profile'),
            ),
          ],
        ),
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
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(e.toString())));
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
