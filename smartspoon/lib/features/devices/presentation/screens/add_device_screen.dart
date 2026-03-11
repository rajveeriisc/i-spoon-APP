import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartspoon/features/devices/domain/services/ble_service.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';

// I should check premium_widgets.dart path. It's likely in core/widgets.
// Actually, earlier I used 'package:smartspoon/features/insights/presentation/widgets/summary_cards.dart' which had PremiumGlassCard?
// Wait, I should verify where PremiumGlassCard is defined.
// In MealsAnalysisPage I used 'package:smartspoon/features/insights/presentation/screens/meals_analysis_page.dart' and defined PremiumGlassCard inside it or imported it?
// Let's check where PremiumGlassCard is.
// I think I defined it in `lib/core/widgets/premium_widgets.dart`? 
// I should verify exists. If not, I'll define it locally or find it.
// Actually, I'll view the file list to be sure where I put the premium widgets.
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
    // Explicitly prompt the user for permissions first if needed.
    final granted = await _bleService.checkAndRequestPermissions();
    if (!granted) {
      if (mounted) {
        _showSnackBar('Bluetooth/Location permissions are required to scan', isError: true);
      }
      return; // Do not scan if denied
    }

    // Small delay to ensure UI is ready
    await Future.delayed(const Duration(milliseconds: 500));
    _startScan();
  }

  Future<void> _startScan() async {
    if (_bleService.isScanning) {
      return;
    }
    
    // We already checked and got permissions above, safe to scan
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
        // Timeout means we saved the device and are retrying in background.
        // Navigate back so the user can see the connection status on the home screen.
        final isTimeout = e.toString().contains('timed out');
        Navigator.pop(context);
        _showSnackBar(
          isTimeout
              ? 'Connecting to ${device.name}… check back in a moment'
              : 'Connection failed: $e',
          isError: !isTimeout,
        );
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
          style: GoogleFonts.manrope(color: Colors.white),
        ),
        backgroundColor: isError ? const Color(0xFFEF5350) : AppTheme.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    // Always dark mode for premium screen
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkBackgroundGradient
                  : AppTheme.backgroundGradient,
            ),
          ),
          const GeometricBackground(),
          
          ListenableBuilder(
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
                color: AppTheme.emerald,
                backgroundColor: Theme.of(context).colorScheme.surface,
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
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final deviceId = connectedIds[index];
                              final device = _bleService.getDeviceById(deviceId);
                              return _buildConnectedDeviceCard(context, device, deviceId);
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
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final savedDevice = savedDevices[index];
                              // Don't show if it's already in the "Connected" list
                              if (connectedIds.contains(savedDevice.id)) return const SizedBox.shrink();
                              
                              return _buildSavedDeviceCard(context, savedDevice);
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
                              style: GoogleFonts.manrope(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final device = availableDevices[index];
                              return _buildDeviceCard(
                                context, 
                                device,
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
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Text(
        'Add Device',
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, size: 20, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh_rounded, 
            color: AppTheme.emerald,
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
          Icon(Icons.bluetooth_disabled, size: 80, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          Text(
            'Bluetooth is Off',
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please enable Bluetooth to\nscan for devices.',
            textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningHeader(BuildContext context, bool isScanning) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar Rings
                if (isScanning) ...[
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2), width: 1),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: false))
                  .scale(duration: 2.seconds, begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5))
                  .fadeOut(duration: 2.seconds),
                  
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2), width: 1),
                    ),
                  ).animate(delay: 1.seconds, onPlay: (c) => c.repeat(reverse: false))
                  .scale(duration: 2.seconds, begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5))
                  .fadeOut(duration: 2.seconds),
                ],

                // Center Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (isScanning)
                        BoxShadow(
                          color: AppTheme.emerald.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                    ],
                    border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                    color: AppTheme.emerald,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isScanning ? 'Scanning for nearby devices...' : 'Scan paused',
            style: GoogleFonts.manrope(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.emerald,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, DiscoveredDevice device) {
    final isConnecting = _connectingDeviceId == device.id;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumGlassCard(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
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
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.id,
                          style: GoogleFonts.sourceCodePro( // Monospace for ID
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.emerald, AppTheme.emerald]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald.withValues(alpha: 0.3),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: Text(
                        'Connect',
                        style: GoogleFonts.manrope(
                          color: Colors.white,
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
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms);
  }

  Widget _buildConnectedDeviceCard(
      BuildContext context, DiscoveredDevice? device, String deviceId) {
    
    final name = device?.name ?? 'Unknown Device';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumGlassCard(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
               // Maybe go to details or disconnect?
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.5)),
                    ),
                    child: Icon(Icons.bluetooth_connected, color: AppTheme.emerald, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connected',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                height: 1.4,
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
                      foregroundColor: AppTheme.rose,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildSavedDeviceCard(
      BuildContext context, SavedBleDevice device) {
    final isConnecting = _connectingDeviceId == device.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumGlassCard(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.history, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last seen: ${device.formattedLastConnected}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: Colors.white.withValues(alpha: 0.5)),
                      onPressed: () {
                        _bleService.removeSavedDevice(device.id);
                      },
                    ),
                ],
              ),
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
    
    final color = AppTheme.emerald;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: 6.0 + (index * 4), // 6, 10, 14, 18
          decoration: BoxDecoration(
            color: index < bars ? color : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
            boxShadow: index < bars ? [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)
            ] : null,
          ),
        );
      }),
    );
  }
}

