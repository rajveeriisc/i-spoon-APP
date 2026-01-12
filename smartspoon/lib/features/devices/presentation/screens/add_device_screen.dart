import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartspoon/features/devices/index.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final BleService _bleService = BleService();
  final List<BluetoothDevice> _devices = [];
  List<BluetoothDevice> _connectedDevices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _bleService.initialize();
    await _loadConnectedDevices();
    _startScan();
  }

  Future<void> _loadConnectedDevices() async {
    // Get currently connected devices from BLE service
    final connected = _bleService.connectedDevices;
    if (mounted) {
      setState(() {
        _connectedDevices = connected;
      });
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    // Request permissions
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Refresh connected devices before scanning
    await _loadConnectedDevices();

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final newDevices = <BluetoothDevice>[];
        for (var result in results) {
          if (!_devices.contains(result.device)) {
            newDevices.add(result.device);
          }
        }
        if (newDevices.isNotEmpty && mounted) {
          setState(() {
            _devices.addAll(newDevices);
          });
        }
      });
    } catch (e) {
      debugPrint('Scan error: $e');
    }

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connecting...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Use BLE service to connect (handles saving automatically)
      final success = await _bleService.connectToDevice(device);

      if (mounted) {
        if (success) {
          // Refresh connected devices list
          await _loadConnectedDevices();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.platformName}'),
              backgroundColor: Colors.green,
            ),
          );

          // Don't pop the screen - keep it open to show connected device
          // Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Device',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isScanning ? 'Scanning...' : 'Scan for devices',
                  style: GoogleFonts.lato(fontSize: 16),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Scan'),
                ),
              ],
            ),
          ),
          if (_isScanning) const LinearProgressIndicator(),
          Expanded(
            child: _devices.isEmpty && _connectedDevices.isEmpty
                ? Center(
                    child: Text(
                      _isScanning
                          ? 'Searching for devices...'
                          : 'No devices found',
                      style: GoogleFonts.lato(color: Colors.grey),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Connected Devices Section
                      if (_connectedDevices.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Connected Devices',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        ..._connectedDevices.map((device) {
                          return Card(
                            color: Colors.green.shade50,
                            child: ListTile(
                              leading: Icon(
                                Icons.bluetooth_connected,
                                color: Colors.green.shade700,
                              ),
                              title: Text(
                                device.platformName.isNotEmpty
                                    ? device.platformName
                                    : 'Unknown Device',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Connected • ${device.remoteId.toString()}',
                                style: TextStyle(color: Colors.green.shade700),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Connected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],

                      // Available Devices Section
                      if (_devices.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Available Devices',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ..._devices.map((device) {
                          // Check if this device is already connected
                          final isConnected = _connectedDevices.any(
                            (d) =>
                                d.remoteId.toString() ==
                                device.remoteId.toString(),
                          );

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.bluetooth),
                              title: Text(
                                device.platformName.isNotEmpty
                                    ? device.platformName
                                    : 'Unknown Device',
                              ),
                              subtitle: Text(device.remoteId.toString()),
                              trailing: ElevatedButton(
                                onPressed: isConnected
                                    ? null
                                    : () => _connectToDevice(device),
                                child: Text(
                                  isConnected ? 'Connected' : 'Connect',
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
