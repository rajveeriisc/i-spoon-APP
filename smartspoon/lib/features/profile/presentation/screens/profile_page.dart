import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/auth/index.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/providers/theme_provider.dart';
import 'package:smartspoon/features/profile/presentation/widgets/profile_redesign_widgets.dart';

import 'package:smartspoon/features/profile/presentation/screens/faq_page.dart';
import 'package:smartspoon/features/profile/presentation/screens/help_center_page.dart';
import 'package:smartspoon/features/profile/presentation/widgets/feedback_modals.dart';
import 'package:smartspoon/features/profile/presentation/screens/daily_bites_screen.dart';
import 'package:smartspoon/features/profile/presentation/screens/privacy_policy_page.dart';
import 'package:smartspoon/features/profile/presentation/screens/terms_page.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/services/database_service.dart';
import 'package:smartspoon/features/insights/domain/services/unified_data_service.dart';
import 'package:smartspoon/features/notifications/providers/notification_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final unifiedData = context.watch<UnifiedDataService>();
    final safeGoal = unifiedData.dailyBiteGoal > 0 ? unifiedData.dailyBiteGoal : 1;
    final progressVal = unifiedData.totalBites / safeGoal;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : null,
              gradient: isDark
                  ? null
                  : AppTheme.backgroundGradient,
            ),
          ),
          if (!isDark) const GeometricBackground(),
          
          SafeArea(
            child: Consumer<UserProvider>(
              builder: (context, user, _) {
                return SingleChildScrollView(
                  child: Column(
                    children: [

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 2. Stats Section
                            Text('Your Daily Goals', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                            const SizedBox(height: 12),
                            ProfileCard(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: StatsCard(
                                        icon: Icons.track_changes,
                                        value: '${unifiedData.dailyBiteGoal}', 
                                        label: 'Daily Target',
                                        isUp: true,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const DailyBitesScreen()),
                                          );
                                        },
                                      ),
                                    ),
                                    VerticalDivider(
                                      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                      thickness: 1,
                                    ),
                                    Expanded(
                                      child: StatsCard(
                                        icon: Icons.local_fire_department,
                                        value: '${unifiedData.currentStreak}', 
                                        label: 'Day Streak',
                                        isUp: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // 3. Goals Section
                            Text('Your Progress', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                            const SizedBox(height: 12),
                            ProfileCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Daily Bite Goal', style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                                      Text(
                                        '${(progressVal * 100).toInt().clamp(0, 100)}%', 
                                        style: GoogleFonts.manrope(color: AppTheme.emerald, fontWeight: FontWeight.bold)
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ProfileProgressBar(progress: progressVal.clamp(0.0, 1.0)),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${unifiedData.totalBites} / ${unifiedData.dailyBiteGoal} bites toward target limit today',
                                    style: GoogleFonts.manrope(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // 4. App Settings
                            Text('Settings', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                            const SizedBox(height: 12),
                            ProfileCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                              child: Column(
                                children: [
                                  Consumer<ThemeProvider>(
                                    builder: (_, theme, child) => SettingsRow(
                                      icon: Icons.dark_mode_outlined,
                                      title: 'Dark Mode',
                                      trailing: Switch(
                                        value: theme.themeMode == ThemeMode.dark,
                                        thumbColor: WidgetStateProperty.resolveWith((states) {
                                          if (states.contains(WidgetState.selected)) {
                                            return AppTheme.emerald;
                                          }
                                          return Colors.grey;
                                        }),
                                        trackColor: WidgetStateProperty.resolveWith((states) {
                                           if (states.contains(WidgetState.selected)) {
                                             return AppTheme.emerald.withValues(alpha: 0.5);
                                           }
                                           return null;
                                        }),
                                        onChanged: (_) => theme.toggleTheme(),
                                      ),
                                    ),
                                  ),
                                  Consumer<NotificationProvider>(
                                    builder: (context, notifProvider, _) {
                                      // Prefer backend preference if loaded, fall back to UserProvider flag
                                      final isEnabled = notifProvider.preferences?.enabled
                                          ?? user.notificationsEnabled
                                          ?? true;
                                      return SettingsRow(
                                        icon: Icons.notifications_none,
                                        title: 'Notifications',
                                        trailing: notifProvider.loading
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppTheme.emerald,
                                                ),
                                              )
                                            : Switch(
                                                value: isEnabled,
                                                thumbColor: WidgetStateProperty.resolveWith((states) {
                                                  if (states.contains(WidgetState.selected)) {
                                                    return AppTheme.emerald;
                                                  }
                                                  return Colors.grey;
                                                }),
                                                trackColor: WidgetStateProperty.resolveWith((states) {
                                                  if (states.contains(WidgetState.selected)) {
                                                    return AppTheme.emerald.withValues(alpha: 0.5);
                                                  }
                                                  return null;
                                                }),
                                                onChanged: (val) async {
                                                  await notifProvider.toggleAllNotifications(val);
                                                  // Keep UserProvider in sync for other screens
                                                  if (context.mounted) {
                                                    Provider.of<UserProvider>(context, listen: false)
                                                        .notificationsEnabled = val;
                                                  }
                                                },
                                              ),
                                      );
                                    },
                                  ),
                                  SettingsRow(
                                    icon: Icons.language,
                                    title: 'Language',
                                    trailing: Row(
                                      children: [
                                        Text('English', style: GoogleFonts.manrope(color: const Color(0xFF94A3B8), fontSize: 13)),
                                        Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                      ],
                                    ),
                                    showBorder: false,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // 5. Help & Feedback
                            Text('Support', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
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
                                    showBorder: false,
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
      
                            // 6. Legal
                            Text('Legal', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface)),
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
                              child: Column(
                                children: [
                                  SettingsRow(
                                    icon: Icons.logout,
                                    title: 'Log Out',
                                    isDestructive: true,
                                    showBorder: true,
                                    onTap: () async {
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
                                  SettingsRow(
                                    icon: Icons.delete_forever,
                                    title: 'Erase Local Dummy Data',
                                    isDestructive: true,
                                    showBorder: false,
                                    onTap: () async {
                                      try {
                                        // Uses dynamic to avoid breaking if import is missing
                                        final db = DatabaseService();
                                        await db.clearDatabase();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Fake data wiped! Restart the app to see the empty state.')),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                'Version 1.0.0',
                                style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 80), // Bottom padding for nav bar if needed
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
