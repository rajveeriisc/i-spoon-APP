import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen>
    with SingleTickerProviderStateMixin {
  // BLE state
  bool _isScanning = false;
  bool _bluetoothEnabled = false;
  final List<ScanResult> _scanResults = [];
  List<BluetoothDevice> _connectedDevices = [];
  StreamSubscription? _scanSubscription;
  StreamSubscription? _adapterStateSubscription;
  late AnimationController _animationController;
  int _filterIndex = 0; // 0: All, 1: Nearby, 2: Connected

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initBluetooth();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _animationController.dispose();
    if (_isScanning) {
      FlutterBluePlus.stopScan();
    }
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    try {
      // Check if Bluetooth is available on this device
      if (await FlutterBluePlus.isSupported == false) {
        if (mounted) {
          setState(() {
            _bluetoothEnabled = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bluetooth is not supported on this device'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Get initial state first with timeout
      final adapterState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 3),
      );

      if (mounted) {
        setState(() {
          _bluetoothEnabled = adapterState == BluetoothAdapterState.on;
        });
        print('Bluetooth state initialized: $_bluetoothEnabled');
      }

      // Then listen for changes
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (mounted) {
          setState(() {
            _bluetoothEnabled = state == BluetoothAdapterState.on;
          });
          print('Bluetooth state changed: $_bluetoothEnabled');
        }
      });

      // Get already connected devices
      final connectedDevices = FlutterBluePlus.connectedDevices;
      if (mounted) {
        setState(() {
          _connectedDevices = connectedDevices;
        });
      }
    } catch (e) {
      print('Error initializing Bluetooth: $e');
      if (mounted) {
        setState(() {
          _bluetoothEnabled = false;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Request location permission (required for BLE scanning on Android)
    final locationStatus = await Permission.location.status;
    if (locationStatus.isDenied) {
      final result = await Permission.location.request();
      if (!result.isGranted && !result.isLimited) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required for BLE scanning'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
    }

    if (await Permission.location.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDialog();
      }
      return;
    }

    // Request Bluetooth permission (Android 12+)
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Location permission is permanently denied. Please enable it from app settings to scan for BLE devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startScan() async {
    // Double check Bluetooth state before scanning
    try {
      final currentState = await FlutterBluePlus.adapterState.first;
      if (currentState != BluetoothAdapterState.on) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable Bluetooth to scan for devices'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bluetooth error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    await _requestPermissions();

    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    _animationController.repeat();

    try {
      // Listen to scan results
      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) {
          setState(() {
            // Update or add new devices
            for (var result in results) {
              final index = _scanResults.indexWhere(
                (r) => r.device.remoteId == result.device.remoteId,
              );
              if (index >= 0) {
                _scanResults[index] = result;
              } else {
                _scanResults.add(result);
              }
            }
            // Sort by RSSI (signal strength)
            _scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
          });
        },
        onError: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scan error: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: true,
      );

      // Wait for scan to complete
      await FlutterBluePlus.isScanning.where((val) => val == false).first;

      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        _animationController.stop();
        _animationController.reset();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        _animationController.stop();
        _animationController.reset();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start scan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      // Stop scanning before connecting
      if (_isScanning) {
        await FlutterBluePlus.stopScan();
        setState(() {
          _isScanning = false;
        });
        _animationController.stop();
        _animationController.reset();
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      await device.connect(timeout: const Duration(seconds: 10));

      // Discover services (prepare for future data transmission)
      await device.discoverServices();

      // Update connected devices list
      setState(() {
        if (!_connectedDevices.contains(device)) {
          _connectedDevices.add(device);
        }
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connected to ${device.platformName.isNotEmpty ? device.platformName : "Unknown Device"}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        if (e.code == 'already_connected') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device is already connected'),
              backgroundColor: Colors.blueAccent,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection failed: ${e.message}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      setState(() {
        _connectedDevices.remove(device);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Disconnected from ${device.platformName.isNotEmpty ? device.platformName : "Unknown Device"}',
            ),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnect failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  bool _isDeviceConnected(BluetoothDevice device) {
    return _connectedDevices.any((d) => d.remoteId == device.remoteId);
  }

  @override
  Widget build(BuildContext context) {
    // final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: const BackButton(),
        title: const Text(
          'Add Device',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),

              const SizedBox(height: 24),

              if (_connectedDevices.isNotEmpty)
                _buildConnectedCarousel(context),

              _buildFilterChips(context),
              const SizedBox(height: 8),
              _buildNearbyHeader(context),
              const SizedBox(height: 12),

              if (_scanResults.isEmpty && !_isScanning)
                _buildEmptyState(context),

              if (_scanResults.isNotEmpty)
                ..._scanResults.map((result) {
                  final device = result.device;
                  final isConnected = _isDeviceConnected(device);
                  if (_filterIndex == 2 && !isConnected)
                    return const SizedBox.shrink();
                  if (_filterIndex == 1 && isConnected)
                    return const SizedBox.shrink();
                  return _ModernDeviceCard(
                    name: device.platformName.isNotEmpty
                        ? device.platformName
                        : 'Unknown Device',
                    id: device.remoteId.toString(),
                    rssi: result.rssi,
                    connected: isConnected,
                    onTap: () => _showDeviceSheet(
                      device: device,
                      rssi: result.rssi,
                      connected: isConnected,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(40),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(36),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.bluetooth_searching,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a Smart Spoon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan nearby and connect to start tracking.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _startScan,
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : RotationTransition(
                    turns: _animationController,
                    child: const Icon(Icons.sync),
                  ),
            label: Text(_isScanning ? 'Scanning' : 'Scan'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // _buildStatusChips removed per request; Scan button covers the state

  Widget _buildFilterChips(BuildContext context) {
    InputChip _filter(String label, int idx) => InputChip(
      label: Text(label),
      selected: _filterIndex == idx,
      onSelected: (_) => setState(() => _filterIndex = idx),
    );
    return Row(
      children: [
        _filter('All', 0),
        const SizedBox(width: 8),
        _filter('Nearby', 1),
        const SizedBox(width: 8),
        _filter('Connected', 2),
      ],
    );
  }

  Widget _buildConnectedCarousel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Connected Devices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _connectedDevices
                .map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _ConnectedCard(
                      name: d.platformName.isNotEmpty
                          ? d.platformName
                          : 'Unknown Device',
                      id: d.remoteId.toString(),
                      onDisconnect: () => _disconnectDevice(d),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNearbyHeader(BuildContext context) {
    final count = _scanResults.length;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Nearby Devices${count > 0 ? ' ($count)' : ''}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(40),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
          ),
          const SizedBox(height: 12),
          Text(
            'No devices found',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap Scan to search for nearby BLE devices',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceSheet({
    required BluetoothDevice device,
    required int rssi,
    required bool connected,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(36),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bluetooth,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.platformName.isNotEmpty
                              ? device.platformName
                              : 'Unknown Device',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          device.remoteId.toString(),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(160),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SignalBars(rssi: rssi),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (connected) {
                          await _disconnectDevice(device);
                        } else {
                          await _connectToDevice(device);
                        }
                      },
                      child: Text(connected ? 'Disconnect' : 'Connect'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  final String name;
  final String id;
  final VoidCallback onDisconnect;
  const _ConnectedCard({
    required this.name,
    required this.id,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(36),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bluetooth_connected,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(160),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDisconnect,
              child: const Text('Disconnect'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int rssi;
  const _SignalBars({required this.rssi});

  @override
  Widget build(BuildContext context) {
    int level;
    if (rssi >= -60) {
      level = 4;
    } else if (rssi >= -70) {
      level = 3;
    } else if (rssi >= -80) {
      level = 2;
    } else {
      level = 1;
    }
    Color active = Theme.of(context).colorScheme.primary;
    Color inactive = Theme.of(context).colorScheme.onSurface.withAlpha(60);
    return Row(
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Container(
            width: 4,
            height: 6 + (i + 1) * 4,
            decoration: BoxDecoration(
              color: i < level ? active : inactive,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _ModernDeviceCard extends StatelessWidget {
  final String name;
  final String id;
  final int rssi;
  final bool connected;
  final VoidCallback onTap;
  const _ModernDeviceCard({
    required this.name,
    required this.id,
    required this.rssi,
    required this.connected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(40),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color:
                (connected
                        ? Colors.teal
                        : Theme.of(context).colorScheme.primary)
                    .withAlpha(36),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            connected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: connected
                ? Colors.teal
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            _SignalBars(rssi: rssi),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(160),
        ),
      ),
    );
  }
}
