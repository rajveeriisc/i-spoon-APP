import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../infrastructure/ble_recent_repository.dart';

class RecentSection extends StatelessWidget {
  const RecentSection({
    super.key,
    required this.devices,
    required this.onConnect,
  });
  final List<RecentDevice> devices;
  final void Function(RecentDevice) onConnect;

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
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Previously Connected',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...devices.map(
          (d) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                d.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: () => onConnect(d),
                child: const Text('Connect'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
