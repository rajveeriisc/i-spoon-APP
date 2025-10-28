import 'package:flutter/material.dart';

class AuthFormHeader extends StatelessWidget {
  const AuthFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;
    final headline = textTheme.headlineSmall ?? const TextStyle(fontSize: 24);
    final body = textTheme.bodyMedium ?? const TextStyle(fontSize: 14);

    return Column(
      children: [
        Text(
          title,
          style: headline.copyWith(
            fontSize: width > 360 ? 32 : 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: body.copyWith(
            fontSize: width > 360 ? 16 : 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
