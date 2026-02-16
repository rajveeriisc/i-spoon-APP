import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/core/widgets/app_card.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:smartspoon/features/devices/presentation/screens/ble_settings_screen.dart';

/// BLE Device Card - Shows connected device with battery and status
class SpoonConnectedCard extends StatefulWidget {
  const SpoonConnectedCard({super.key});

  @override
  State<SpoonConnectedCard> createState() => _SpoonConnectedCardState();
}

class _SpoonConnectedCardState extends State<SpoonConnectedCard> {
  late BleService _bleService;

  @override
  void initState() {
    super.initState();
    // Use the shared services from Provider
    _bleService = Provider.of<BleService>(context, listen: false);
  }

  void _navigateToAddDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDeviceScreen()),
    );
  }

  void _navigateToDeviceDetails() {
    // Get the connected device info
    final connectedIds = _bleService.connectedDeviceIds;
    if (connectedIds.isEmpty) return;

    final id = connectedIds.first;
    final device = _bleService.getDeviceById(id);
    final deviceName = device?.name ?? 'I-Spoon Device';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BleSettingsScreen(
          deviceId: id,
          deviceName: deviceName.isEmpty ? 'I-Spoon Device' : deviceName,
        ),
      ),
    );
  }

  Future<void> _handleReconnect() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Attempting to reconnect...')));
    await _bleService.autoConnectToLastDevice();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _bleService,
      builder: (context, _) {
        final connectedIds = _bleService.connectedDeviceIds;
        final savedDevices = _bleService.previousDevices;
        // Read battery from UnifiedDataService (updates every 5s, not 5x/sec)
        final dataService = Provider.of<UnifiedDataService>(context);
        final batteryLevel = dataService.batteryLevel;

        final isConnected = connectedIds.isNotEmpty;
        final hasLastDevice = savedDevices.isNotEmpty;

        // 1. Initial State: No devices ever connected
        if (!isConnected && !hasLastDevice) {
          return _buildNoDeviceCard();
        }

        // 2. Determine which device to show
        // If connected, show the first connected device
        // If not connected, show the last saved device
        String deviceName = 'Unknown Device';
        String lastConnectedText = '';

        if (isConnected) {
          final id = connectedIds.first;
          final device = _bleService.getDeviceById(id);
          deviceName = device?.name ?? 'I-Spoon Device';
          if (deviceName.isEmpty) deviceName = 'I-Spoon Device';
        } else if (hasLastDevice) {
          final last = savedDevices.first;
          deviceName = last.name;
          lastConnectedText = last.formattedLastConnected;
        }

        return _buildStatusCard(
          isConnected: isConnected,
          deviceName: deviceName,
          lastConnectedText: lastConnectedText,
          batteryLevel: batteryLevel,
        );
      },
    );
  }

  Widget _buildNoDeviceCard() {
    return InkWell(
      onTap: _navigateToAddDevice,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bluetooth_searching,
                size: 32,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Device Connected',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to add your I-Spoon device',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle, color: Colors.grey.shade400, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required bool isConnected,
    required String deviceName,
    required String lastConnectedText,
    required int batteryLevel,
  }) {
    return InkWell(
      onTap: isConnected ? _navigateToDeviceDetails : _navigateToAddDevice,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Device name and status row
            Row(
              children: [
                // Device icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bluetooth_connected,
                    size: 32,
                    color: isConnected
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 16),

                // Device name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isConnected ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isConnected ? 'Connected' : 'Not Connected',
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: isConnected
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status icon
                Icon(
                  isConnected ? Icons.check_circle : Icons.cancel,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 28,
                ),
              ],
            ),

            // Divider
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),

            // Battery or Last Connected row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side - Battery or Last Connected
                if (isConnected) ...[
                  Row(
                    children: [
                      Icon(
                        _getBatteryIcon(batteryLevel),
                        size: 20,
                        color: _getBatteryColor(batteryLevel),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        batteryLevel > 0
                            ? 'Battery: $batteryLevel%'
                            : 'Battery: N/A',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Last: $lastConnectedText',
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],

                // Right side - Action button
                TextButton.icon(
                  onPressed: isConnected
                      ? _navigateToDeviceDetails
                      : _handleReconnect,
                  icon: Icon(
                    isConnected ? Icons.settings : Icons.refresh,
                    size: 16,
                  ),
                  label: Text(
                    isConnected ? 'Settings' : 'Reconnect',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBatteryIcon(int level) {
    if (level == 0) return Icons.battery_unknown;
    if (level > 90) return Icons.battery_full;
    if (level > 70) return Icons.battery_6_bar;
    if (level > 50) return Icons.battery_5_bar;
    if (level > 30) return Icons.battery_3_bar;
    if (level > 10) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int level) {
    if (level == 0) return Colors.grey;
    if (level > 30) return Colors.green;
    if (level > 10) return Colors.orange;
    return Colors.red;
  }
}

/// Temperature Display Card
class TemperatureCard extends StatelessWidget {
  const TemperatureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UnifiedDataService>(
      builder: (context, dataService, _) {
        return AppCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TemperatureItem(
                icon: Icons.thermostat,
                label: 'Food Temp',
                value: '${(dataService.foodTempC).toStringAsFixed(1)}°C',
                color: const Color(0xFFFFA726),
              ),
              Container(
                height: 60,
                width: 2,
                color: Colors.grey.withValues(alpha: 0.2),
              ),
              _TemperatureItem(
                icon: Icons.local_fire_department,
                label: 'Heater Temp',
                value: '${(dataService.heaterTempC).toStringAsFixed(1)}°C',
                color: const Color(0xFFEF5350),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemperatureItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _TemperatureItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 32, color: color),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Eating Analysis Card
class EatingAnalysisCard extends StatelessWidget {
  const EatingAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UnifiedDataService>(
      builder: (context, dataService, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MealsAnalysisPage(),
                ),
              );
            },
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Eating Analysis",
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _AnalysisItem(
                        icon: Icons.local_dining,
                        value: (dataService.totalBites).toString(),
                        label: 'Total Bites',
                        color: const Color(0xFF7E57C2),
                      ),
                      _AnalysisItem(
                        icon: Icons.timer,
                        value:
                            '${(dataService.avgBiteTime).toStringAsFixed(1)}s',
                        label: 'Avg/Bite',
                        color: const Color(0xFFEC407A),
                      ),
                      _AnalysisItem(
                        icon: Icons.speed,
                        value: dataService.eatingSpeed.toStringAsFixed(1),
                        label: 'Speed',
                        color: const Color(0xFFEF5350),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnalysisItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _AnalysisItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 28, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

/// Daily Tip Card
class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      gradient: const LinearGradient(
        colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline,
            size: 40,
            color: Color(0xFF388E3C),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tip',
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mindful eating can help you recognize true hunger and fullness cues more effectively.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF2E7D32)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Motivation Card
class MotivationCard extends StatelessWidget {
  const MotivationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      gradient: const LinearGradient(
        colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_border, size: 40, color: Color(0xFFD81B60)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivation',
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF880E4F),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '"Slow down, savor life, and nourish your body with intention."',
                  style: TextStyle(fontSize: 14, color: Color(0xFFC2185B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
