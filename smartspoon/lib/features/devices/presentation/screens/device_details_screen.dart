import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/features/devices/presentation/screens/ble_settings_screen.dart';
import 'package:smartspoon/features/devices/presentation/screens/mcu_debug_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          deviceName,
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'BLE Settings',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device Info Card
            _buildDeviceInfoCard(isDarkMode),
            const SizedBox(height: 20),

            // Quick Actions
            Text(
              'Quick Actions',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // BLE Data Monitor Button
            _buildActionCard(
              context,
              icon: Icons.monitor_heart,
              title: 'BLE Data Monitor',
              subtitle: 'View real-time packet data and statistics',
              color: AppTheme.turquoise,
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
            const SizedBox(height: 12),

            // MCU Debug Screen Button
            _buildActionCard(
              context,
              icon: Icons.bug_report,
              title: 'MCU Debug Console',
              subtitle: 'Advanced debugging and raw data logs',
              color: AppTheme.sky,
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
    );
  }

  Widget _buildDeviceInfoCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [AppTheme.navy, AppTheme.navy.withOpacity(0.8)]
              : [AppTheme.turquoise, AppTheme.sky],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bluetooth_connected,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: GoogleFonts.lato(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart Spoon Device',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.fingerprint, 'Device ID', deviceId),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.check_circle, 'Status', 'Connected'),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.lato(
            fontSize: 13,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.white),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF233044) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.transparent
              : AppTheme.sky.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }
}
