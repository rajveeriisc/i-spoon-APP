import 'package:flutter/material.dart';
import 'package:smartspoon/services/auth_service.dart';

class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    required this.radius,
    this.avatarUrl,
    this.displayName,
    this.fallbackAsset = 'assets/images/ispoon_onboarding.png',
  });

  final double radius;
  final String? avatarUrl;
  final String? displayName;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    String? url = avatarUrl;
    if (url != null && url.startsWith('/')) {
      url = AuthService.baseUrl + url;
    }

    // If we have a URL, show it
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    }

    // Otherwise, try to show first initial from displayName
    final String initial = _extractInitial(displayName);
    if (initial.isNotEmpty) {
      final theme = Theme.of(context);
      final bg = theme.colorScheme.primary.withValues(alpha: 0.15);
      final fg = theme.colorScheme.primary;
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Text(
          initial,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.9,
          ),
        ),
      );
    }

    // Fallback asset
    return CircleAvatar(
      radius: radius,
      backgroundImage: AssetImage(fallbackAsset),
    );
  }

  String _extractInitial(String? name) {
    if (name == null) return '';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    // Take first letter of first word
    final first = trimmed.split(RegExp(r'\s+')).first;
    return first.isNotEmpty ? first.characters.first.toUpperCase() : '';
  }
}
