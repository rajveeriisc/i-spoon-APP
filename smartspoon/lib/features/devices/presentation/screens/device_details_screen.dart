import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/features/devices/domain/services/ble_service.dart';
import 'package:smartspoon/features/devices/presentation/screens/ble_settings_screen.dart';
import 'package:smartspoon/features/devices/presentation/screens/mcu_debug_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';

/// Device details screen with navigation to BLE settings and debug screens
class DeviceDetailsScreen extends StatelessWidget {
  final String deviceId;
  final String deviceName;

  const DeviceDetailsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Device Info Card
                        _buildDeviceInfoCard(context),
                        const SizedBox(height: 32),
          
                        // Quick Actions
                        Text(
                          'DEVICE MANAGEMENT',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emerald,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
          
                        // BLE Data Monitor Button
                        _buildActionCard(
                          context,
                          icon: Icons.monitor_heart_outlined,
                          title: 'BLE Data Monitor',
                          subtitle: 'View real-time packet data',
                          color: AppTheme.emerald,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BleSettingsScreen(
                                  deviceId: deviceId,
                                  deviceName: deviceName,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
          
                        // MCU Debug Screen Button
                        _buildActionCard(
                          context,
                          icon: Icons.bug_report_outlined,
                          title: 'MCU Debug Console',
                          subtitle: 'Advanced debugging logs',
                          color: AppTheme.emerald, // Sky blue
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => McuDebugScreen(
                                  deviceId: deviceId,
                                  deviceName: deviceName,
                                ),
                              ),
                            );
                          },
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Device Details',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface, size: 24),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BleSettingsScreen(
                    deviceId: deviceId,
                    deviceName: deviceName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(BuildContext context) {
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emerald.withValues(alpha: 0.2),
                        blurRadius: 12,
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.bluetooth_connected,
                    color: AppTheme.emerald,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: GoogleFonts.manrope(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Consumer<BleService>(
                        builder: (context, ble, _) {
                          final connected = ble.isDeviceConnected(deviceId);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (connected ? AppTheme.emerald : Colors.grey)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              connected ? 'Connected' : 'Disconnected',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: connected ? AppTheme.emerald : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            _buildInfoRow(context, Icons.fingerprint, 'Device ID', deviceId),
            const SizedBox(height: 12),
            _buildInfoRow(context, Icons.battery_charging_full, 'Battery', '85%'), // Mock data or fetch if available
            const SizedBox(height: 12),
            _buildInfoRow(context, Icons.update, 'Firmware', 'v1.2.0'),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 18),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.sourceCodePro( // Monospace for technical data
              fontSize: 13, 
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumGlassCard(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.98, 0.98));
  }
}

// Re-using the PremiumGlassCard definition locally for this screen as well

