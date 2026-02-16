import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:smartspoon/features/devices/domain/services/tremor_detection_service.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Comprehensive BLE data visualization screen
class BleSettingsScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const BleSettingsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<BleSettingsScreen> createState() => _BleSettingsScreenState();
}

class _BleSettingsScreenState extends State<BleSettingsScreen> {
  late McuBleService _mcuService;
  bool _isConnecting = true;
  bool _showRawData = false;
  String _statusMessage = 'Connecting to device...';

  @override
  void initState() {
    super.initState();
    // Use the shared McuBleService from Provider
    _mcuService = Provider.of<McuBleService>(context, listen: false);
    _connectToDevice();
  }

  Future<void> _connectToDevice() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Checking device connection...';
    });

    try {
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
        _statusMessage = 'Subscribing to data stream...';
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
    // Don't disconnect - keep connection alive for other screens
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _mcuService,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'BLE Data Monitor',
            style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reconnect',
              onPressed: _connectToDevice,
            ),
          ],
        ),
        body: _isConnecting
            ? _buildLoadingState()
            : Consumer<McuBleService>(
                builder: (context, service, _) {
                  if (!service.isConnected) {
                    return _buildDisconnectedState();
                  }
                  return _buildDataView(service, isDarkMode);
                },
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: GoogleFonts.lato(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'Device Disconnected',
            style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _statusMessage,
            style: GoogleFonts.lato(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _connectToDevice,
            icon: const Icon(Icons.refresh),
            label: const Text('Reconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataView(McuBleService service, bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Info Header
          _buildDeviceHeader(service, isDarkMode),
          const SizedBox(height: 20),

          // Overview Cards
          _buildOverviewCards(service, isDarkMode),
          const SizedBox(height: 20),

          // Packet Statistics
          _buildPacketStats(service, isDarkMode),
          const SizedBox(height: 20),
          
          // Tremor Analysis
          _buildTremorSection(isDarkMode),
          const SizedBox(height: 20),

          // IMU Samples Table
          _buildImuSamplesSection(service, isDarkMode),
          const SizedBox(height: 20),

          // Packet Structure Info
          _buildPacketStructure(isDarkMode),
          const SizedBox(height: 20),

          // Raw Data Viewer
          _buildRawDataViewer(service, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildDeviceHeader(McuBleService service, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              service.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
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
                  widget.deviceName,
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  service.isConnected
                      ? 'Connected & Streaming'
                      : 'Disconnected',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: service.isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              service.isConnected ? 'LIVE' : 'OFFLINE',
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildOverviewCards(McuBleService service, bool isDarkMode) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.battery_charging_full,
                iconColor: _getBatteryColor(service.batteryLevel),
                label: 'Battery',
                value: '${service.batteryLevel}%',
                subtitle: service.batteryLevel < 20 ? 'Low' : 'Good',
                isDarkMode: isDarkMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.thermostat,
                iconColor: _getTempColor(service.temperature),
                label: 'Temperature',
                value: '${service.temperature.toStringAsFixed(1)}°C',
                subtitle: _getTempLabel(service.temperature),
                isDarkMode: isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          icon: Icons.access_time,
          iconColor: AppTheme.turquoise,
          label: 'Last Packet',
          value: service.lastPacketTime != null
              ? _formatTimestamp(service.lastPacketTime!)
              : 'N/A',
          subtitle: service.lastPacketTime != null
              ? '${DateTime.now().difference(service.lastPacketTime!).inMilliseconds}ms ago'
              : 'Waiting...',
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 36),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.lato(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildPacketStats(McuBleService service, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF233044) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.transparent
              : AppTheme.sky.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppTheme.turquoise, size: 24),
              const SizedBox(width: 8),
              Text(
                'Packet Statistics',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            'Total Packets',
            '${service.receivedPackets}',
            Icons.inventory_2,
          ),
          _buildStatRow(
            'Packets/sec',
            service.packetsPerSecond.toStringAsFixed(1),
            Icons.speed,
          ),
          _buildStatRow(
            'Data Rate',
            '${service.dataRate.toStringAsFixed(0)} B/s',
            Icons.data_usage,
          ),
          _buildStatRow(
            'Expected Size',
            '127 bytes/packet',
            Icons.info_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.lato(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildImuSamplesSection(McuBleService service, bool isDarkMode) {
    final data = service.currentData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF233044) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.transparent
              : AppTheme.sky.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, color: AppTheme.turquoise, size: 24),
              const SizedBox(width: 8),
              Text(
                'Current IMU Data',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (data == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Waiting for sensor data...',
                  style: GoogleFonts.lato(color: Colors.grey),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppTheme.turquoise.withOpacity(0.1),
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      'Axis',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Accel (g)',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Gyro (°/s)',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: [
                  _buildDataRow('X', data.accelX, data.gyroX),
                  _buildDataRow('Y', data.accelY, data.gyroY),
                  _buildDataRow('Z', data.accelZ, data.gyroZ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.sky.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.turquoise),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing last sample from 10-sample packet',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: Colors.grey[600],
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

  DataRow _buildDataRow(String axis, double accel, double gyro) {
    return DataRow(
      cells: [
        DataCell(
          Text(axis, style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        ),
        DataCell(
          Text(accel.toStringAsFixed(3), style: GoogleFonts.robotoMono()),
        ),
        DataCell(
          Text(gyro.toStringAsFixed(2), style: GoogleFonts.robotoMono()),
        ),
      ],
    );
  }

  Widget _buildPacketStructure(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF233044) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.transparent
              : AppTheme.sky.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.architecture, color: AppTheme.turquoise, size: 24),
              const SizedBox(width: 8),
              Text(
                'Packet Structure (127 bytes)',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStructureItem('Byte 0', 'Battery Level', 'uint8 (0-100%)'),
          _buildStructureItem(
            'Bytes 1-2',
            'Temperature',
            'int16 LE (°C × 100)',
          ),
          _buildStructureItem(
            'Bytes 3-6',
            'Timestamp',
            'uint32 LE (milliseconds)',
          ),
          _buildStructureItem(
            'Bytes 7-126',
            '10 IMU Samples',
            'Each 12 bytes:',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSubItem('ax, ay, az', 'int16 × 3 (÷1000 → g)'),
                _buildSubItem('gx, gy, gz', 'int16 × 3 (÷100 → °/s)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStructureItem(String bytes, String field, String format) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              bytes,
              style: GoogleFonts.robotoMono(
                fontSize: 12,
                color: AppTheme.turquoise,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  format,
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem(String field, String format) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('• ', style: TextStyle(color: Colors.grey[600])),
          Text(
            field,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            format,
            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRawDataViewer(McuBleService service, bool isDarkMode) {
    final rawPacket = service.lastRawPacket;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF233044) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.transparent
              : AppTheme.sky.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.code, color: AppTheme.turquoise, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Raw Packet Data',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (rawPacket != null)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy to clipboard',
                      onPressed: () => _copyRawData(rawPacket),
                    ),
                  IconButton(
                    icon: Icon(
                      _showRawData ? Icons.expand_less : Icons.expand_more,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        _showRawData = !_showRawData;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          if (_showRawData) ...[
            const SizedBox(height: 12),
            if (rawPacket == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No packet data available',
                    style: GoogleFonts.lato(color: Colors.grey),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _formatHexDump(rawPacket),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: Colors.greenAccent,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatHexDump(List<int> data) {
    final buffer = StringBuffer();
    for (int i = 0; i < data.length; i += 16) {
      // Offset
      buffer.write('${i.toRadixString(16).padLeft(4, '0')}:  ');

      // Hex values
      for (int j = 0; j < 16; j++) {
        if (i + j < data.length) {
          buffer.write('${data[i + j].toRadixString(16).padLeft(2, '0')} ');
        } else {
          buffer.write('   ');
        }
        if (j == 7) buffer.write(' ');
      }

      buffer.write('\n');
    }
    return buffer.toString();
  }

  void _copyRawData(List<int> data) {
    final hexString = data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    Clipboard.setData(ClipboardData(text: hexString));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Raw data copied to clipboard',
          style: GoogleFonts.lato(),
        ),
        backgroundColor: AppTheme.turquoise,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTremorSection(bool isDarkMode) {
    // DO NOT use Consumer - causes crashes
    // Read data once without listening
    final tremorService = Provider.of<TremorDetectionService>(context, listen: false);
    final result = tremorService.lastResult;
    
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.waves, color: AppTheme.turquoise, size: 24),
              const SizedBox(width: 8),
              Text(
                'Tremor Analysis',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Manual refresh button
              IconButton(
                icon: Icon(Icons.refresh, size: 20),
                onPressed: () {
                  setState(() {}); // Rebuild to get latest data
                },
                tooltip: 'Refresh',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: result.detected ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result.detected ? 'DETECTED' : 'NORMAL',
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: result.detected ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
           if (result.frequency == 0 && !result.detected)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Collecting data for analysis...\n(Needs ~10s of motion)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildTremorMetric(
                    'Frequency',
                    '${result.frequency.toStringAsFixed(1)} Hz',
                    Icons.graphic_eq,
                    AppTheme.turquoise,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTremorMetric(
                    'Amplitude',
                    result.amplitude.toStringAsFixed(2),
                    Icons.show_chart,
                    AppTheme.coral,
                    isDarkMode,
                  ),
                ),
              ],
            ),
          if (result.detected) ...[
            const SizedBox(height: 12),
            Text(
              'Source: ${result.source.toUpperCase()}',
              style: GoogleFonts.lato(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTremorMetric(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  Color _getBatteryColor(int level) {
    if (level >= 60) return Colors.green;
    if (level >= 30) return Colors.orange;
    return Colors.red;
  }

  Color _getTempColor(double temp) {
    if (temp >= 60) return Colors.red;
    if (temp >= 35) return Colors.orange;
    return Colors.blue;
  }

  String _getTempLabel(double temp) {
    if (temp >= 60) return 'Hot';
    if (temp >= 35) return 'Warm';
    if (temp >= 20) return 'Room Temp';
    return 'Cold';
  }
}
