import 'package:flutter/material.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.name,
    required this.id,
    required this.rssi,
    required this.connected,
    required this.onTap,
  });

  final String name;
  final String id;
  final int rssi;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
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
                    .withValues(alpha: 0.14),
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.63),
        ),
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
    Color inactive = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24);
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
