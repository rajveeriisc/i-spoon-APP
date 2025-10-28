import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ConnectedCarousel extends StatelessWidget {
  const ConnectedCarousel({
    super.key,
    required this.devices,
    required this.onDisconnect,
  });
  final List<BluetoothDevice> devices;
  final void Function(BluetoothDevice) onDisconnect;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) return const SizedBox.shrink();
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
            children: devices
                .map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _ConnectedCard(
                      name: d.platformName.isNotEmpty
                          ? d.platformName
                          : 'Unknown Device',
                      id: d.remoteId.toString(),
                      onDisconnect: () => onDisconnect(d),
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
