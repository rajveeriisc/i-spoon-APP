import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartspoon/features/ble/infrastructure/ble_recent_repository.dart';
import 'package:smartspoon/features/ble/presentation/recent_section.dart';
import 'package:smartspoon/features/ble/presentation/connected_carousel.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/ble/application/ble_controller.dart';
import 'package:smartspoon/features/ble/presentation/add_device/widgets/scan_header.dart';
import 'package:smartspoon/features/ble/presentation/add_device/widgets/filter_chips.dart'
    as filter;
import 'package:smartspoon/features/ble/presentation/add_device/widgets/device_card.dart'
    as cards;

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
  List<BluetoothDevice> _connectedDevices = [];
  List<RecentDevice> _recentDevices = [];
  final BleRecentRepository _recentRepo = BleRecentRepository();
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
    _loadRecentDevices();
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
    // Android 12+ BLE permissions
    var scanStatus = await Permission.bluetoothScan.status;
    if (scanStatus.isDenied) {
      scanStatus = await Permission.bluetoothScan.request();
    }
    var connectStatus = await Permission.bluetoothConnect.status;
    if (connectStatus.isDenied) {
      connectStatus = await Permission.bluetoothConnect.request();
    }
  }

  // Location permission dialog removed; Android 12+ BLE does not require location

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

    // Ensure we have scan permission (Android 12+). We do not request location here.
    final hasScan = await Permission.bluetoothScan.isGranted;
    if (!hasScan) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing Bluetooth Scan permission'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    try {
      // Delegate scan to controller (repository handles service filtering)
      final ctrl = context.read<BleController>();
      await ctrl.startScan();
    } catch (e) {
      if (mounted) {
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
      // Stop scanning before connecting via controller (keeps state consistent)
      final ctrl = context.read<BleController>();
      await ctrl.stopScan();

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      // Use central BleController so repository subscribes and streams data to UI
      await ctrl.connect(device.remoteId.toString(), name: device.platformName);

      // Update connected devices list
      setState(() {
        if (!_connectedDevices.contains(device)) {
          _connectedDevices.add(device);
        }
      });

      // Save to recent list
      await _recentRepo.upsert(
        RecentDevice(
          id: device.remoteId.toString(),
          name: device.platformName.isNotEmpty
              ? device.platformName
              : 'Unknown Device',
        ),
      );
      await _loadRecentDevices();

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
      // Use central BleController so repository unsubscribes and state resets
      final ctrl = context.read<BleController>();
      await ctrl.disconnect();
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

  // Recent devices persistence (via repository)
  Future<void> _loadRecentDevices() async {
    try {
      final list = await _recentRepo.load();
      if (mounted) {
        setState(() => _recentDevices = list);
      }
    } catch (_) {}
  }

  // kept for future use if needed – currently connection state is sourced from controller

  @override
  Widget build(BuildContext context) {
    // final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
              Consumer<BleController>(
                builder: (context, ctrl, _) {
                  final isScanning = ctrl.isScanning;
                  if (isScanning) {
                    _animationController.repeat();
                  } else {
                    _animationController.stop();
                    _animationController.reset();
                  }
                  return ScanHeader(
                    isScanning: isScanning,
                    onScan: _startScan,
                    turns: _animationController,
                  );
                },
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 24),

              if (_connectedDevices.isNotEmpty)
                ConnectedCarousel(
                  devices: _connectedDevices,
                  onDisconnect: (d) => _disconnectDevice(d),
                ),

              filter.FilterChips(
                filterIndex: _filterIndex,
                onChanged: (idx) => setState(() => _filterIndex = idx),
              ),
              const SizedBox(height: 8),
              // Nearby header with dynamic count
              Consumer<BleController>(
                builder: (context, ctrl, _) =>
                    _buildNearbyHeader(context, count: ctrl.devices.length),
              ),
              const SizedBox(height: 12),

              Consumer<BleController>(
                builder: (context, ctrl, _) {
                  final list = ctrl.devices;
                  if (list.isEmpty && !_isScanning) {
                    return _buildEmptyState(context);
                  }
                  return Column(
                    children: list.map((d) {
                      final isConnected = ctrl.isDeviceConnected(d.id);
                      if (_filterIndex == 2 && !isConnected) {
                        return const SizedBox.shrink();
                      }
                      if (_filterIndex == 1 && isConnected) {
                        return const SizedBox.shrink();
                      }
                      return cards.DeviceCard(
                        name: d.name.isNotEmpty ? d.name : 'Unknown Device',
                        id: d.id,
                        rssi: d.rssi,
                        connected: isConnected,
                        onTap: () async {
                          // Show sheet requires BluetoothDevice; keep existing flow via scan results if available
                          try {
                            final dev = BluetoothDevice.fromId(d.id);
                            int rssi = d.rssi;
                            _showDeviceSheet(
                              device: dev,
                              rssi: rssi,
                              connected: isConnected,
                            );
                          } catch (_) {}
                        },
                      );
                    }).toList(),
                  );
                },
              ),

              // Previously connected devices
              RecentSection(
                devices: _recentDevices,
                onConnect: (d) async {
                  final dev = BluetoothDevice.fromId(d.id);
                  await _connectToDevice(dev);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyHeader(BuildContext context, {required int count}) {
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
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 48,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.47),
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
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.63),
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
                      ).colorScheme.primary.withValues(alpha: 0.14),
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
                            ).colorScheme.onSurface.withValues(alpha: 0.63),
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
    Color inactive = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.24);
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

// recent device model moved to ble_recent_repository.dart
