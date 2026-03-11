import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/auth/index.dart'; // For UserProvider
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';
import 'package:smartspoon/features/notifications/providers/notification_provider.dart';
import 'package:smartspoon/features/notifications/presentation/screens/notification_screen.dart';
import 'package:smartspoon/features/profile/presentation/screens/edit_profile_screen.dart';
class PremiumHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showProfile;
  final bool showNotification;

  const PremiumHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showProfile = true,
    this.showNotification = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (showProfile) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const EditProfileScreen(),
                );
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                if (showProfile) ...[
                  Consumer<UserProvider>(
                    builder: (context, user, _) {
                      final name = (user.name ?? 'Guest').trim();
                      final initials = name.isNotEmpty
                          ? name
                              .split(RegExp(r'\s+'))
                              .where((s) => s.isNotEmpty)
                              .take(2)
                              .map((s) => s[0].toUpperCase())
                              .join()
                          : 'G';
                      final photoUrl = user.avatarUrl;

                      return Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.violet.withValues(alpha: 0.2),
                          border: Border.all(
                              color: AppTheme.violet, width: 1.5),
                        ),
                        child: ClipOval(
                          child: photoUrl != null && photoUrl.isNotEmpty
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Center(
                                    child: Text(
                                      initials,
                                      style: GoogleFonts.manrope(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initials,
                                    style: GoogleFonts.manrope(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                ],

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    Consumer<UserProvider>(
                      builder: (context, user, child) {
                        // If title contains 'User', replace with actual name
                        String displayTitle = title;
                        if (title == 'Good Morning,') {
                          final name = (user.name ?? 'Guest').trim();
                          final firstName = name.isNotEmpty
                              ? (name.contains(' ')
                                  ? name.split(RegExp(r'\s+'))[0]
                                  : name)
                              : 'Guest';
                          return Text(
                            '$title $firstName',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          );
                        }
                        return Text(
                          displayTitle,
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showNotification)
            Consumer<NotificationProvider>(
              builder: (context, notificationProvider, child) {
                final unreadCount = notificationProvider.unreadCount;
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationScreen(),
                      ),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PremiumIconBox(
                        icon: Icons.notifications_none,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 24,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
