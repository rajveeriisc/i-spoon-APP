import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/devices/index.dart';

/// Device Details Screen - Shows detailed information about a connected BLE device
class DeviceDetailsScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceDetailsScreen({super.key, required this.device});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  List<BluetoothService> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _discoverServices();
  }

  Future<void> _discoverServices() async {
    try {
      _services = await widget.device.discoverServices();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error discovering services: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _forgetDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget Device'),
        content: const Text(
          'Are you sure you want to forget this device? '
          'It will be disconnected and removed from saved devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Forget'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final bleService = BleService();
        await bleService.forgetDevice(widget.device.remoteId.toString());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device forgotten successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device.platformName.isNotEmpty
              ? widget.device.platformName
              : 'Device Details',
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'MCU Debug',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => McuDebugScreen(device: widget.device),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Forget Device',
            onPressed: _forgetDevice,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
          ? const Center(child: Text('No services found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Text(
                      'Service: ${_formatUuid(service.uuid.toString())}',
                      style: GoogleFonts.lato(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      service.uuid.toString(),
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    children: service.characteristics
                        .map(
                          (c) => ListTile(
                            title: Text(
                              'Characteristic: ${_formatUuid(c.uuid.toString())}',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('UUID: ${c.uuid.toString()}'),
                                Text('Properties: ${_getProperties(c)}'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
    );
  }

  String _getProperties(BluetoothCharacteristic characteristic) {
    List<String> properties = [];
    if (characteristic.properties.read) properties.add('Read');
    if (characteristic.properties.write) properties.add('Write');
    if (characteristic.properties.notify) properties.add('Notify');
    if (characteristic.properties.writeWithoutResponse) {
      properties.add('WriteNoResp');
    }
    if (characteristic.properties.indicate) properties.add('Indicate');
    return properties.isEmpty ? 'None' : properties.join(', ');
  }

  /// Safely format UUID string - handles both short and long UUIDs
  String _formatUuid(String uuid) {
    // Remove any extra formatting
    final cleaned = uuid.replaceAll('-', '').replaceAll(':', '');
    
    // If it's a short UUID (4 characters or less), return as is
    if (cleaned.length <= 4) {
      return '0x$cleaned';
    }
    
    // For longer UUIDs, show first 8 characters
    if (cleaned.length >= 8) {
      return cleaned.substring(0, 8).toUpperCase();
    }
    
    // For anything in between, just return what we have
    return cleaned.toUpperCase();
  }
}
