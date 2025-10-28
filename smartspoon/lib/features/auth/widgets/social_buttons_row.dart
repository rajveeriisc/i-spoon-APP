import 'package:flutter/material.dart';

class SocialButtonsRow extends StatelessWidget {
  const SocialButtonsRow({
    super.key,
    required this.onGooglePressed,
    required this.onFacebookPressed,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onFacebookPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface;
    final width = MediaQuery.of(context).size.width;
    final fbSize = width > 360 ? 28.0 : 24.0;
    final googleSize = width > 360 ? 36.0 : 30.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.facebook, color: iconColor, size: fbSize),
          tooltip: 'Login with Facebook',
          onPressed: onFacebookPressed,
        ),
        const SizedBox(width: 32),
        IconButton(
          icon: Icon(Icons.g_mobiledata, color: iconColor, size: googleSize),
          tooltip: 'Login with Google',
          onPressed: onGooglePressed,
        ),
      ],
    );
  }
}
