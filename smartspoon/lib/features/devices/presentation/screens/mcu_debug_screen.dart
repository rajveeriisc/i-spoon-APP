import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Debug screen to view and test MCU BLE communication
class McuDebugScreen extends StatefulWidget {
  final BluetoothDevice device;

  const McuDebugScreen({super.key, required this.device});

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
    _mcuService = McuBleService();
    _connectToMcu();
  }

  Future<void> _connectToMcu() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to MCU...';
    });

    try {
      // Connect and discover services
      bool connected = await _mcuService.connect(widget.device);
      
      if (!connected) {
        setState(() {
          _isConnecting = false;
          _statusMessage = 'Failed to connect to MCU service';
        });
        return;
      }

      // Subscribe to notifications
      bool subscribed = await _mcuService.subscribeToData();
      
      setState(() {
        _isConnecting = false;
        _statusMessage = subscribed 
            ? 'Connected and receiving data' 
            : 'Connected but subscription failed';
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _sendTemperature() async {
    final temp = double.tryParse(_tempController.text);
    if (temp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid temperature value')),
      );
      return;
    }

    bool success = await _mcuService.setTemperature(temp);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Temperature set to ${temp.toStringAsFixed(1)}°C' 
              : 'Failed to send temperature'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Don't dispose the singleton service!
    // _mcuService.dispose(); 
    _tempController.dispose();
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
            style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Manual Read',
              onPressed: () async {
                final value = await _mcuService.readCurrentValue();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value != null 
                          ? 'Read: $value' 
                          : 'Failed to read value'),
                      backgroundColor: value != null ? Colors.green : Colors.orange,
                    ),
                  );
                }
              },
            ),
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
                    Text(_statusMessage, style: GoogleFonts.lato()),
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
                        // Status Card
                        _buildStatusCard(service),
                        const SizedBox(height: 16),

                        // Heater Control (Replaces Temp Control)
                        _buildHeaterControl(service),
                        const SizedBox(height: 16),

                        // Current Sensor Data
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

  Widget _buildStatusCard(McuBleService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Status',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Device', widget.device.platformName),
            _buildStatusRow(
              'Connected',
              service.isConnected ? 'Yes' : 'No',
              service.isConnected ? Colors.green : Colors.red,
            ),
            _buildStatusRow(
              'Subscribed',
              service.isSubscribed ? 'Yes' : 'No',
              service.isSubscribed ? Colors.green : Colors.red,
            ),
            _buildStatusRow(
              'Data Received',
              service.rawDataLog.isNotEmpty ? 'Yes (${service.rawDataLog.length})' : 'None yet',
              service.rawDataLog.isNotEmpty ? Colors.green : Colors.orange,
            ),
            const Divider(),
            _buildStatusRow('Service UUID', '${McuBleService.serviceUuid.toString().substring(0, 8)}...'),
            const SizedBox(height: 8),
            if (!service.isSubscribed && service.isConnected)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notifications not subscribed. Try reconnecting.',
                        style: GoogleFonts.lato(fontSize: 12, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.lato(color: Colors.grey)),
          Text(
            value,
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaterControl(McuBleService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heater Control',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Heater State',
                  style: GoogleFonts.lato(fontSize: 16),
                ),
                Switch(
                  value: service.isHeaterOn,
                  onChanged: (value) {
                    service.setHeaterState(value);
                  },
                  activeThumbColor: Colors.red,
                ),
              ],
            ),
            Text(
              service.isHeaterOn ? 'Sending "ON" command' : 'Sending "OFF" command',
              style: GoogleFonts.lato(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorDataCard(McuBleService service) {
    final data = service.currentData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Sensor Data',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (data == null)
              Text(
                'Waiting for data...',
                style: GoogleFonts.lato(color: Colors.grey),
              )
            else ...[
              _buildSensorRow('🌡️ Temperature', '${data.temperature.toStringAsFixed(2)}°C'),
              _buildSensorRow('🔥 Heater Status', service.isHeaterOn ? 'ON' : 'OFF'),
              _buildSensorRow('🔋 Battery', '${service.batteryLevel}%'),
              const Divider(),
              Text(
                'Accelerometer (mg)',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
              _buildSensorRow('  X', '${data.accelX}'),
              _buildSensorRow('  Y', '${data.accelY}'),
              _buildSensorRow('  Z', '${data.accelZ}'),
              const Divider(),
              Text(
                'Gyroscope (dps)',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple,
                ),
              ),
              _buildSensorRow('  X', '${data.gyroX}'),
              _buildSensorRow('  Y', '${data.gyroY}'),
              _buildSensorRow('  Z', '${data.gyroZ}'),
              const Divider(),
              Text(
                'Last Update: ${_formatTime(data.timestamp)}',
                style: GoogleFonts.lato(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.lato()),
          Text(
            value,
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w600,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawDataLog(McuBleService service) {
    final log = service.rawDataLog;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Raw Data Log (${log.length}/50)',
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (log.isNotEmpty)
                  TextButton(
                    onPressed: () => _mcuService.clearLog(),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (log.isEmpty)
              Text(
                'No data received yet',
                style: GoogleFonts.lato(color: Colors.grey),
              )
            else
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: log.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = log.length - 1 - index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText(
                        log[reversedIndex],
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: Colors.greenAccent,
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}


