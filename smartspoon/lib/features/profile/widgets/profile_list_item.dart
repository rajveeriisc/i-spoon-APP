import 'package:flutter/material.dart';

class ProfileListItem extends StatelessWidget {
  const ProfileListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.isToggle = false,
    this.toggleValue,
    this.onToggle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool isToggle;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final row = Row(
      children: [
        Icon(icon, size: 28, color: onSurface.withValues(alpha: 0.7)),
        const SizedBox(width: 15),
        Expanded(
          child: Text(title, style: TextStyle(fontSize: 16, color: onSurface)),
        ),
        if (isToggle)
          Switch(
            value: toggleValue ?? (value == 'On' || value == 'Light'),
            onChanged: onToggle,
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: onTap != null && !isToggle
          ? InkWell(onTap: onTap, child: row)
          : row,
    );
  }
}
