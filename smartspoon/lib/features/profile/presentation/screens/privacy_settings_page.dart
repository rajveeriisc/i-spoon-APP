import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';
import 'package:smartspoon/features/devices/domain/services/smart_spoon_ble_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  // Data Collection
  bool _shareAnalytics = true;
  bool _personalizedRecs = true;

  // Notifications
  bool _emailNotifications = false;
  bool _pushNotifications = true;

  // Account Security
  bool _twoFactorAuth = false;
  bool _loginAlerts = true;

  // Background Tracking
  bool _backgroundTracking = false;

  @override
  void initState() {
    super.initState();
    _loadBackgroundTrackingState();
  }

  Future<void> _loadBackgroundTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundTracking = prefs.getBool('background_tracking_enabled') ?? false;
    });
  }

  Future<void> _toggleBackgroundTracking(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_tracking_enabled', value);
    setState(() {
      _backgroundTracking = value;
    });

    if (value) {
      await SmartSpoonBleService().startBackgroundMonitoring();
    } else {
      await SmartSpoonBleService().stopBackgroundMonitoring();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkBackgroundGradient
                  : AppTheme.backgroundGradient,
            ),
          ),
          const GeometricBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('DATA COLLECTION'),
                        const SizedBox(height: 12),
                        _buildSettingsCard([
                          _buildToggleRow(
                            icon: Icons.analytics_outlined,
                            title: 'Share Usage Analytics',
                            subtitle: 'Help us improve the app experience',
                            value: _shareAnalytics,
                            onChanged: (v) => setState(() => _shareAnalytics = v),
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            icon: Icons.recommend_outlined,
                            title: 'Personalized Recommendations',
                            subtitle: 'Get tailored meal and health tips',
                            value: _personalizedRecs,
                            onChanged: (v) => setState(() => _personalizedRecs = v),
                          ),
                        ]),

                        const SizedBox(height: 24),
                        _buildSectionHeader('NOTIFICATIONS'),
                        const SizedBox(height: 12),
                        _buildSettingsCard([
                          _buildToggleRow(
                            icon: Icons.email_outlined,
                            title: 'Email Notifications',
                            subtitle: 'Receive updates via email',
                            value: _emailNotifications,
                            onChanged: (v) => setState(() => _emailNotifications = v),
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            icon: Icons.notifications_outlined,
                            title: 'Push Notifications',
                            subtitle: 'Get real-time alerts on your device',
                            value: _pushNotifications,
                            onChanged: (v) => setState(() => _pushNotifications = v),
                          ),
                        ]),

                        const SizedBox(height: 24),
                        _buildSectionHeader('DEVICE TRACKING'),
                        const SizedBox(height: 12),
                        _buildSettingsCard([
                          _buildToggleRow(
                            icon: Icons.bluetooth_connected_rounded,
                            title: '24/7 Background Tracking',
                            subtitle: 'Allow iSpoon to track data while closed',
                            value: _backgroundTracking,
                            onChanged: _toggleBackgroundTracking,
                          ),
                        ]),

                        const SizedBox(height: 24),
                        _buildSectionHeader('ACCOUNT SECURITY'),
                        const SizedBox(height: 12),
                        _buildSettingsCard([
                          _buildToggleRow(
                            icon: Icons.verified_user_outlined,
                            title: 'Two-Factor Authentication',
                            subtitle: 'Add an extra layer of security',
                            value: _twoFactorAuth,
                            onChanged: (v) => setState(() => _twoFactorAuth = v),
                          ),
                          _buildDivider(),
                          _buildToggleRow(
                            icon: Icons.login_rounded,
                            title: 'Login Alerts',
                            subtitle: 'Get notified of new sign-ins',
                            value: _loginAlerts,
                            onChanged: (v) => setState(() => _loginAlerts = v),
                          ),
                        ]),

                        const SizedBox(height: 32),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [AppTheme.emerald, const Color(0xFF4338CA)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.emerald.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Privacy settings saved',
                                        style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onPrimary),
                                      ),
                                      backgroundColor: AppTheme.emerald,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                },
                                child: Center(
                                  child: Text(
                                    'Save Settings',
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Privacy Settings',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.emerald,
        letterSpacing: 1.8,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
      indent: 20,
      endIndent: 20,
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.emerald, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.emerald,
            inactiveThumbColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
