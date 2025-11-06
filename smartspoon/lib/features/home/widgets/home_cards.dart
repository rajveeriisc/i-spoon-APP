import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/ble/application/ble_controller.dart';
import 'package:smartspoon/ui/widgets/app_card.dart';

class SpoonConnectedCard extends StatelessWidget {
  const SpoonConnectedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final controller = context.watch<BleController>();
    final isConnected = controller.conn.connected;
    final temperature = controller.lastPacket?.temperatureC;
    final deviceName = controller.lastDeviceName ?? 'SmartSpoon';
    final statusColor = isConnected ? Colors.green : Colors.redAccent;

    return AppCard(
      padding: EdgeInsets.all(screenWidth * 0.05),
      gradient: const LinearGradient(
        colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          _IconContainer(
            icon: Icons.ramen_dining,
            color: const Color(0xFF00ACC1),
            size: screenWidth * 0.08,
          ),
          SizedBox(width: screenWidth * 0.05),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00838F),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected ? 'Connected' : 'Not connected',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF00838F),
                      ),
                    ),
                  ],
                ),
                if (temperature != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Food Temp: ${temperature.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF00838F),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: controller.isScanning ? null : controller.startScan,
                icon: controller.isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(controller.isScanning ? 'Scanning…' : 'Scan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconContainer extends StatelessWidget {
  const _IconContainer({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}

class TemperatureDisplay extends StatelessWidget {
  const TemperatureDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dividerColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white24
        : Colors.grey.withValues(alpha: 0.20);

    return AppCard(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Consumer<BleController>(
            builder: (context, controller, _) {
              final temp = controller.lastPacket?.temperatureC;
              final formatted = temp != null
                  ? '${temp.toStringAsFixed(1)}°C'
                  : '--';
              return TemperatureColumn(
                icon: Icons.thermostat,
                label: 'Food Temp',
                temperature: formatted,
                color: const Color(0xFFFFA726),
                fontSize: screenWidth * 0.07,
              );
            },
          ),
          SizedBox(
            height: screenWidth * 0.2,
            child: VerticalDivider(color: dividerColor, thickness: 2),
          ),
          TemperatureColumn(
            icon: Icons.local_fire_department,
            label: 'Heater Temp',
            temperature: '60°C',
            color: const Color(0xFFEF5350),
            fontSize: screenWidth * 0.07,
          ),
        ],
      ),
    );
  }
}

class TemperatureColumn extends StatelessWidget {
  const TemperatureColumn({
    super.key,
    required this.icon,
    required this.label,
    this.temperature,
    required this.color,
    required this.fontSize,
  });

  final IconData icon;
  final String label;
  final String? temperature;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final displayValue = temperature ?? '--';
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(fontSize * 0.3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: fontSize * 0.8, color: color),
        ),
        SizedBox(height: fontSize * 0.3),
        Text(
          label,
          style: GoogleFonts.lato(fontSize: fontSize * 0.5, color: Colors.grey),
        ),
        SizedBox(height: fontSize * 0.2),
        Text(
          displayValue,
          style: GoogleFonts.lato(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class EatingAnalysisCard extends StatelessWidget {
  const EatingAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return AppCard(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Eating Analysis",
            style: GoogleFonts.lato(
              fontSize: screenWidth * 0.055,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenWidth * 0.06),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              InfoColumn(
                icon: Icons.local_dining,
                value: '156',
                unit: 'Total Bites',
                iconColor: Color(0xFF7E57C2),
              ),
              InfoColumn(
                icon: Icons.timer,
                value: '3.2s',
                unit: 'Avg/Bite',
                iconColor: Color(0xFFEC407A),
              ),
              InfoColumn(
                icon: Icons.speed,
                value: 'Medium',
                unit: 'Speed',
                iconColor: Color(0xFFEF5350),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InfoColumn extends StatelessWidget {
  const InfoColumn({
    super.key,
    required this.icon,
    required this.value,
    required this.unit,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String unit;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(screenWidth * 0.04),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, size: screenWidth * 0.1, color: iconColor),
        ),
        SizedBox(height: screenWidth * 0.04),
        Text(
          value,
          style: TextStyle(
            fontSize: screenWidth * 0.06,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: screenWidth * 0.02),
        Text(
          unit,
          style: TextStyle(color: Colors.grey, fontSize: screenWidth * 0.04),
        ),
      ],
    );
  }
}

class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return AppCard(
      padding: EdgeInsets.all(screenWidth * 0.05),
      gradient: const LinearGradient(
        colors: [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: screenWidth * 0.1,
            color: const Color(0xFF388E3C),
          ),
          SizedBox(width: screenWidth * 0.05),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tip',
                  style: GoogleFonts.lato(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                SizedBox(height: screenWidth * 0.02),
                Text(
                  'Mindful eating can help you recognize true hunger and fullness cues more effectively.',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MotivationCard extends StatelessWidget {
  const MotivationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return AppCard(
      padding: EdgeInsets.all(screenWidth * 0.05),
      gradient: const LinearGradient(
        colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Icon(
            Icons.favorite_border,
            size: screenWidth * 0.1,
            color: const Color(0xFFD81B60),
          ),
          SizedBox(width: screenWidth * 0.05),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivation',
                  style: GoogleFonts.lato(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF880E4F),
                  ),
                ),
                SizedBox(height: screenWidth * 0.02),
                Text(
                  '"Slow down, savor life, and nourish your body with intention."',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: const Color(0xFFC2185B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyDevices extends StatelessWidget {
  const MyDevices({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final controller = context.watch<BleController>();
    final devices = controller.devices;
    final isScanning = controller.isScanning;
    final isConnecting = controller.isConnecting;
    final connectedId = controller.connectedDeviceId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'My Devices',
              style: GoogleFonts.lato(
                fontSize: screenWidth * 0.055,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: isScanning ? null : controller.startScan,
              icon: isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(isScanning ? 'Scanning…' : 'Scan'),
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.05),
        ...devices.map(
          (d) => Padding(
            padding: EdgeInsets.only(bottom: screenWidth * 0.04),
            child: DeviceCard(
              deviceName: d.name,
              batteryLevel: controller.lastPacket?.batteryPct != null
                  ? '${controller.lastPacket!.batteryPct!.toStringAsFixed(0)}%'
                  : '—',
              lastUsed: controller.isDeviceConnected(d.id)
                  ? 'Connected now'
                  : 'Tap to connect',
              isConnected: controller.isDeviceConnected(d.id),
              busy: isConnecting && connectedId == d.id,
              onConnect: () => controller.connect(d.id, name: d.name),
              onDisconnect: controller.disconnect,
            ),
          ),
        ),
        if (devices.isEmpty && controller.recentDevices.isNotEmpty)
          ...controller.recentDevices.map(
            (r) => Padding(
              padding: EdgeInsets.only(bottom: screenWidth * 0.04),
              child: DeviceCard(
                deviceName: r.name,
                batteryLevel: '—',
                lastUsed: 'Recent device',
                isConnected: false,
                busy: isConnecting && connectedId == r.id,
                onConnect: () => controller.connect(r.id, name: r.name),
                onDisconnect: controller.disconnect,
              ),
            ),
          ),
        if (devices.isEmpty && controller.recentDevices.isEmpty)
          Text(
            isScanning
                ? 'Scanning for SmartSpoon devices…'
                : 'No devices yet. Tap Scan to search.',
            style: TextStyle(color: Colors.grey, fontSize: screenWidth * 0.04),
          ),
      ],
    );
  }
}

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.deviceName,
    required this.batteryLevel,
    required this.lastUsed,
    required this.isConnected,
    this.onConnect,
    this.onDisconnect,
    required this.busy,
  });

  final String deviceName;
  final String batteryLevel;
  final String lastUsed;
  final bool isConnected;
  final bool busy;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final padding = maxWidth * 0.05;
        final iconSize = maxWidth * 0.08;
        final screenWidth = MediaQuery.of(context).size.width;

        return AppCard(
          padding: EdgeInsets.all(padding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(padding * 0.6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.ramen_dining,
                  color: const Color(0xFF673AB7),
                  size: iconSize,
                ),
              ),
              SizedBox(width: padding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            deviceName,
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: padding * 0.5),
                        Icon(
                          isConnected ? Icons.wifi : Icons.wifi_off,
                          color: isConnected ? Colors.green : Colors.grey,
                          size: screenWidth * 0.05,
                        ),
                      ],
                    ),
                    SizedBox(height: padding * 0.5),
                    Row(
                      children: [
                        Icon(
                          Icons.battery_std,
                          size: screenWidth * 0.04,
                          color: Colors.grey,
                        ),
                        SizedBox(width: padding * 0.25),
                        Text(
                          batteryLevel,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        SizedBox(width: padding * 0.5),
                        Text(
                          '•',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                        SizedBox(width: padding * 0.5),
                        Flexible(
                          child: Text(
                            lastUsed,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: screenWidth * 0.035,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: padding),
              ElevatedButton(
                onPressed: busy
                    ? null
                    : isConnected
                    ? onDisconnect
                    : onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected
                      ? Colors.redAccent
                      : Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isConnected ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
        );
      },
    );
  }
}
