import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';

/// Debug screen to view and test MCU BLE communication
class McuDebugScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const McuDebugScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<McuDebugScreen> createState() => _McuDebugScreenState();
}

class _McuDebugScreenState extends State<McuDebugScreen> {
  late McuBleService _mcuService;
  final TextEditingController _tempController = TextEditingController();
  bool _isConnecting = true;
  String _statusMessage = 'Connecting to MCU...';

  @override
  void initState() {
    super.initState();
    // Use the shared McuBleService from Provider
    _mcuService = Provider.of<McuBleService>(context, listen: false);
    _connectToMcu();
  }

  Future<void> _connectToMcu() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Checking device connection...';
    });

    try {
      debugPrint('Checking connection for device ID: ${widget.deviceId}');

      // Get BleService to check if device is connected
      final bleService = Provider.of<BleService>(context, listen: false);

      // Check if device is connected via BleService
      if (!bleService.isDeviceConnected(widget.deviceId)) {
        setState(() {
          _isConnecting = false;
          _statusMessage =
              'Device not connected. Please connect from home screen first.';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Subscribing to MCU data stream...';
      });

      // Subscribe to data stream from already-connected device
      bool subscribed = await _mcuService.subscribeToDevice(widget.deviceId);

      setState(() {
        _isConnecting = false;
        _statusMessage = subscribed
            ? 'Connected and receiving data'
            : 'Failed to subscribe to data stream';
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _tempController.dispose();
    // Don't disconnect - keep connection alive for other screens
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _mcuService,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'MCU Debug',
            style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Log',
              onPressed: () {
                _mcuService.clearLog();
              },
            ),
          ],
        ),
        body: _isConnecting
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusMessage, style: GoogleFonts.manrope()),
                  ],
                ),
              )
            : Consumer<McuBleService>(
                builder: (context, service, _) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Real-time Sensor Data Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.battery_charging_full,
                                iconColor: _getBatteryColor(
                                  service.batteryLevel,
                                ),
                                label: 'Battery',
                                value: '${service.batteryLevel}%',
                                subtitle: service.batteryLevel < 20
                                    ? 'Low'
                                    : 'Good',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.thermostat,
                                iconColor: _getTempColor(service.temperature),
                                label: 'Food Temp',
                                value:
                                    '${service.temperature.toStringAsFixed(1)}°C',
                                subtitle: _getTempLabel(service.temperature),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Bite Count Card — large, easy to verify
                        _buildInfoCard(
                          icon: Icons.restaurant,
                          iconColor: AppTheme.emerald,
                          label: 'Hardware Bite Count (MCU)',
                          value: '${service.hardwareBiteCount}',
                          subtitle: service.hardwareBiteCount == 0
                              ? 'No bites or not connected'
                              : 'Bites detected by spoon',
                        ),
                        const SizedBox(height: 16),

                        // Connection Status
                        _buildStatusCard(service),
                        const SizedBox(height: 16),

                        // Current IMU Data
                        _buildSensorDataCard(service),
                        const SizedBox(height: 16),

                        // Raw Data Log
                        _buildRawDataLog(service),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 40),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.manrope(
                fontSize: 11, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level >= 60) return AppTheme.emerald;
    if (level >= 30) return AppTheme.amber;
    return AppTheme.rose;
  }

  Color _getTempColor(double temp) {
    if (temp >= 60) return AppTheme.rose;
    if (temp >= 35) return AppTheme.amber;
    return AppTheme.emerald;
  }

  String _getTempLabel(double temp) {
    if (temp >= 60) return 'Hot';
    if (temp >= 35) return 'Warm';
    if (temp >= 20) return 'Room Temp';
    return 'Cold';
  }

  Widget _buildStatusCard(McuBleService service) {
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _statusRow('Connected', service.isConnected ? 'YES' : 'NO',
                service.isConnected ? AppTheme.emerald : AppTheme.rose),
            _statusRow('Subscribed', service.isSubscribed ? 'YES' : 'NO',
                service.isSubscribed ? AppTheme.emerald : AppTheme.amber),
            _statusRow('Packets Received', '${service.receivedPackets}',
                Theme.of(context).colorScheme.onSurface),
            _statusRow('Packets/sec', service.packetsPerSecond.toStringAsFixed(1),
                service.packetsPerSecond > 0 ? AppTheme.emerald : AppTheme.amber),
            _statusRow('Last Packet',
                service.lastPacketTime != null
                    ? '${DateTime.now().difference(service.lastPacketTime!).inSeconds}s ago'
                    : 'None',
                Theme.of(context).colorScheme.onSurface),
            _statusRow('Hardware Bites', '${service.hardwareBiteCount}',
                service.hardwareBiteCount > 0 ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.manrope(fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          Text(value, style: GoogleFonts.manrope(
              fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildSensorDataCard(McuBleService service) {
    final data = service.currentData;
    if (data == null) {
      return PremiumGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Waiting for sensor data...',
            style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current IMU Data',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Accel: (${data.accelX.toStringAsFixed(3)}, ${data.accelY.toStringAsFixed(3)}, ${data.accelZ.toStringAsFixed(3)}) g',
              style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface),
            ),
            Text(
              'Gyro: (${data.gyroX.toStringAsFixed(2)}, ${data.gyroY.toStringAsFixed(2)}, ${data.gyroZ.toStringAsFixed(2)}) deg/s',
              style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawDataLog(McuBleService service) {
    final log = service.rawDataLog;
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Raw Data Log (Last 20)',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (log.isEmpty)
              Text('No data yet', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)))
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.black.withValues(alpha: 0.4) 
                      : const Color(0xFF0F172A).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                ),
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: log.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = log.length - 1 - index;
                    final String logEntry = log[reversedIndex];
                    final bool isError = logEntry.contains('ERROR') || logEntry.contains('FAIL'); // Example error check
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        logEntry,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: isError
                              ? AppTheme.rose
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
