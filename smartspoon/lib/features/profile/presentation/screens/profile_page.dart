import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/auth/index.dart';
import 'package:smartspoon/core/providers/theme_provider.dart';
import 'package:smartspoon/features/profile/presentation/widgets/profile_redesign_widgets.dart';
import 'package:smartspoon/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:smartspoon/features/profile/presentation/screens/faq_page.dart';
import 'package:smartspoon/features/profile/presentation/screens/help_center_page.dart';
import 'package:smartspoon/features/profile/presentation/widgets/feedback_modals.dart';
import 'package:smartspoon/features/profile/presentation/screens/daily_bites_screen.dart';
import 'package:smartspoon/features/profile/presentation/screens/privacy_policy_page.dart';
import 'package:smartspoon/features/profile/presentation/screens/terms_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfileBackground, // #F5F7FA
      body: Consumer<UserProvider>(
        builder: (context, user, _) {
          return SingleChildScrollView(
            // No padding here because Header needs to be full width
            child: Column(
              children: [
                // 1. Profile Header (240px)
                ProfileHeader(
                  avatarUrl: user.avatarUrl ?? 'https://via.placeholder.com/150', // Fallback
                  name: user.name ?? 'Smart Spooner',
                  email: user.email ?? 'user@example.com',
                  onEdit: () {
                    // Open EditProfileModal (90% height)
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const EditProfileScreen(), // Rewritten as modal container
                    );
                  },
                ),
                
                const SizedBox(height: 12), // Margin bottom: 12px

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Stats Section
                      // Requires horizontal scroll or simple row. Spec says StatsCard width 140px fixed.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            StatsCard(
                              icon: Icons.track_changes,
                              value: '${user.dailyGoal ?? 50}', 
                              label: 'Daily Bites',
                              isUp: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const DailyBitesScreen()),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            StatsCard(
                              icon: Icons.local_fire_department,
                              value: '12', 
                              label: 'Day Streak',
                              isUp: true,
                            ),
                            const SizedBox(width: 12),
                            // Weight StatsCard removed
                            // StatsCard(
                            //   icon: Icons.scale,
                            //   value: '${user.weight ?? 70}kg', 
                            //   label: 'Weight',
                            //   isUp: false, 
                            // ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 3. Goals Section
                      Text('Your Progress', style: kTitleStyle),
                      const SizedBox(height: 12),
                      ProfileCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Daily Bite Goal', style: kBodyStyle.copyWith(fontWeight: FontWeight.w600)),
                                Text(
                                  '${((40 / (user.dailyGoal ?? 50)) * 100).toInt()}%', 
                                  style: kBodyStyle.copyWith(color: kProfilePrimary, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ProfileProgressBar(progress: 40 / (user.dailyGoal ?? 50)),
                            const SizedBox(height: 8),
                            Text(
                              '40 / ${user.dailyGoal ?? 50} bites consumed today', 
                              style: kSubtitleStyle
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 4. App Settings
                      Text('Settings', style: kTitleStyle),
                      const SizedBox(height: 12),
                      ProfileCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        child: Column(
                          children: [
                            Consumer<ThemeProvider>(
                              builder: (_, theme, __) => SettingsRow(
                                icon: Icons.dark_mode_outlined,
                                title: 'Dark Mode',
                                trailing: Switch(
                                  value: theme.themeMode == ThemeMode.dark,
                                  activeThumbColor: kProfilePrimary,
                                  onChanged: (_) => theme.toggleTheme(),
                                ),
                              ),
                            ),
                            SettingsRow(
                              icon: Icons.notifications_none,
                              title: 'Notifications',
                              trailing: Switch(
                                value: user.notificationsEnabled ?? true,
                                activeThumbColor: kProfilePrimary,
                                onChanged: (val) {
                                  // Simplified toggle logic handle
                                },
                              ),
                            ),
                            SettingsRow(
                              icon: Icons.language,
                              title: 'Language',
                              trailing: Row(
                                children: [
                                  Text('English', style: kSubtitleStyle),
                                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 5. Help & Feedback
                      Text('Support', style: kTitleStyle),
                      const SizedBox(height: 12),
                      ProfileCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        child: Column(
                          children: [
                            SettingsRow(
                              icon: Icons.help_outline, 
                              title: 'Help Center',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterPage())),
                            ),
                            SettingsRow(
                              icon: Icons.question_answer_outlined, 
                              title: 'FAQ',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqPage())),
                            ),
                            SettingsRow(
                              icon: Icons.chat_bubble_outline, 
                              title: 'Send Feedback',
                              onTap: () => FeedbackModals.showFeedbackModal(context),
                            ),
                            SettingsRow(
                              icon: Icons.star_outline, 
                              title: 'Rate App',
                              onTap: () => FeedbackModals.showRateAppModal(context),
                              showBorder: false, // Last item
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // 6. Legal
                      Text('Legal', style: kTitleStyle),
                      const SizedBox(height: 12),
                      ProfileCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        child: Column(
                          children: [
                            SettingsRow(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy Policy',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
                            ),
                            SettingsRow(
                              icon: Icons.description_outlined,
                              title: 'Terms of Service',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage())),
                              showBorder: false,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Logout
                      ProfileCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        child: SettingsRow(
                          icon: Icons.logout,
                          title: 'Log Out',
                          isDestructive: true,
                          onTap: () async {
                              // Logout Logic
                              try {
                                final fb = FirebaseAuthService();
                                await fb.signOut();
                                await AuthService.logout();
                              } catch (_) {}
                              
                              if (context.mounted) {
                                Provider.of<UserProvider>(context, listen: false).clear();
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  (route) => false,
                                );
                              }
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          'Version 1.0.0',
                          style: kSubtitleStyle,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
