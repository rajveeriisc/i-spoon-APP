import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartspoon/features/devices/domain/services/ble_service.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'dart:typed_data';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _bleService = BleService();
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndScan();
  }

  Future<void> _checkPermissionsAndScan() async {
    // Small delay to ensure UI is ready
    await Future.delayed(const Duration(milliseconds: 500));
    _startScan();
  }

  Future<void> _startScan() async {
    if (_bleService.isScanning) {
      return;
    }
    try {
      await _bleService.startScan();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Scanning failed: $e', isError: true);
      }
    }
  }

  Future<void> _handleConnect(DiscoveredDevice device) async {
    if (_connectingDeviceId != null) {
      return;
    }

    setState(() => _connectingDeviceId = device.id);

    try {
      await _bleService.connectToDevice(device);
      
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Connected to ${device.name}', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Connection failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _connectingDeviceId = null);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.lato(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red : AppTheme.turquoise,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    // Ideally we stop scanning when leaving connection screen to save battery
    _bleService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: ListenableBuilder(
        listenable: _bleService,
        builder: (context, _) {
          final scannedDevices = _bleService.discoveredDevices;
          final connectedIds = _bleService.connectedDeviceIds;
          final savedDevices = _bleService.previousDevices;
          final isScanning = _bleService.isScanning;
          final isBluetoothOn = _bleService.isBluetoothOn;

          // If Bluetooth is off, show warning immediately
          if (!isBluetoothOn && _bleService.adapterState != BleStatus.unknown) {
             return _buildBluetoothOffState(context);
          }

          // Filter scanned devices to exclude those already connected
          final availableDevices = scannedDevices.where((d) => !connectedIds.contains(d.id)).toList();

          return RefreshIndicator(
            onRefresh: () async {
              await _bleService.stopScan();
              await _startScan();
            },
            color: AppTheme.turquoise,
            backgroundColor: isDarkMode ? AppTheme.navy : Colors.white,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context),
                
                SliverToBoxAdapter(
                  child: _buildScanningHeader(context, isScanning),
                ),

                // 1. Connected Devices Section
                if (connectedIds.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Connected Devices'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final deviceId = connectedIds[index];
                          final device = _bleService.getDeviceById(deviceId);
                          return _buildConnectedDeviceCard(context, device, deviceId, isDarkMode);
                        },
                        childCount: connectedIds.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // 2. Previously Connected Devices Section
                if (savedDevices.isNotEmpty) ...[
                  _buildSectionHeader(context, 'Previously Connected'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final savedDevice = savedDevices[index];
                          // Don't show if it's already in the "Connected" list
                          if (connectedIds.contains(savedDevice.id)) return const SizedBox.shrink();
                          
                          return _buildSavedDeviceCard(context, savedDevice, isDarkMode);
                        },
                        childCount: savedDevices.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // 3. Available Devices Section
                _buildSectionHeader(context, 'Available Devices'),
                if (availableDevices.isEmpty && !isScanning) 
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40, bottom: 40),
                      child: Center(
                        child: Text(
                          'No new devices found.\nPull to refresh.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final device = availableDevices[index];
                          return _buildDeviceCard(
                            context, 
                            device, 
                            isDarkMode,
                          );
                        },
                        childCount: availableDevices.length,
                      ),
                    ),
                  ),
                  
                // Bottom padding for scroll
                const SliverToBoxAdapter(
                   child: SizedBox(height: 40),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Text(
        'Add Device',
        style: GoogleFonts.lato(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh_rounded, 
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () {
            _bleService.stopScan().then((_) => _startScan());
          },
          tooltip: 'Rescan',
        ),
      ],
    );
  }

  Widget _buildBluetoothOffState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'Bluetooth is Off',
            style: GoogleFonts.lato(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please enable Bluetooth to\nscan for devices.',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: null, // reactive_ble doesn't support enabling BT programmatically easily
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
            // In a real app we'd use app_settings package to open system settings
          ),
        ],
      ),
    );
  }

  Widget _buildScanningHeader(BuildContext context, bool isScanning) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            width: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar Rings
                if (isScanning) ...[
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 1),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: false))
                  .scale(duration: 2.seconds, begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5))
                  .fadeOut(duration: 2.seconds),
                  
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.1), width: 1),
                    ),
                  ).animate(delay: 1.seconds, onPlay: (c) => c.repeat(reverse: false))
                  .scale(duration: 2.seconds, begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5))
                  .fadeOut(duration: 2.seconds),
                ],

                // Center Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isScanning)
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                    ],
                  ),
                  child: Icon(
                    isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                    color: primaryColor,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isScanning ? 'Scanning for nearby devices...' : 'Scan paused',
            style: GoogleFonts.lato(
              color: Colors.grey[600],
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, DiscoveredDevice device, bool isDarkMode) {
    final isConnecting = _connectingDeviceId == device.id;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cardColor = isDarkMode ? const Color(0xFF233044) : Colors.white; // Custom navy for card
    final borderColor = isDarkMode ? Colors.transparent : AppTheme.sky.withValues(alpha: 0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleConnect(device),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Signal Indicator
                _buildRssiIndicator(device.rssi, context),
                const SizedBox(width: 16),
                
                // Device Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name.isNotEmpty ? device.name : 'Unknown Device',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.id,
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action / Status
                if (isConnecting)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Connect',
                      style: GoogleFonts.lato(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          title,
          style: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedDeviceCard(
      BuildContext context, DiscoveredDevice? device, String deviceId, bool isDarkMode) {
    // Green for connected
    final cardColor = isDarkMode ? const Color(0xFF233044) : Colors.white;
    final borderColor = isDarkMode ? Colors.green.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.5);

    final name = device?.name ?? 'Unknown Device';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
             // Maybe go to details or disconnect?
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bluetooth_connected, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connected',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await _bleService.disconnectDevice(deviceId);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Disconnect'),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildSavedDeviceCard(
      BuildContext context, SavedBleDevice device, bool isDarkMode) {
    final isConnecting = _connectingDeviceId == device.id;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final cardColor = isDarkMode ? const Color(0xFF233044) : Colors.white;
    final borderColor = isDarkMode ? Colors.transparent : Colors.grey.withValues(alpha: 0.2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
             // Create a temporary DiscoveredDevice to connect
             final tempDevice = DiscoveredDevice(
               id: device.id, 
               name: device.name, 
               serviceData: {}, 
               manufacturerData: Uint8List(0), 
               rssi: 0, 
               serviceUuids: [],
             );
             _handleConnect(tempDevice);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.grey[400], size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last seen: ${device.formattedLastConnected}',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnecting)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.grey,
                    onPressed: () {
                      _bleService.removeSavedDevice(device.id);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildRssiIndicator(int rssi, BuildContext context) {
    // RSSI range typically -100 (weak) to -40 (strong)
    // 4 bars
    int bars = 0;
    if (rssi > -60) {
      bars = 4;
    } else if (rssi > -70) {
      bars = 3;
    } else if (rssi > -80) {
      bars = 2;
    } else if (rssi > -90) {
      bars = 1;
    }
    
    final color = Theme.of(context).colorScheme.secondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 4,
          height: 6.0 + (index * 4), // 6, 10, 14, 18
          decoration: BoxDecoration(
            color: index < bars ? color : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
