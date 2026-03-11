import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    return Row(
      children: [
        Expanded(child: _SocialButton(
          customIcon: SvgPicture.asset(
            'assets/images/google_logo.svg',
            width: 22,
            height: 22,
          ),
          icon: Icons.g_mobiledata, // Fallback, not used when customIcon is present
          label: 'Google',
          iconColor: const Color(0xFFEA4335),
          onPressed: onGooglePressed,
        )),
        const SizedBox(width: 12),
        Expanded(child: _SocialButton(
          icon: Icons.facebook,
          label: 'Facebook',
          iconColor: const Color(0xFF1877F2),
          onPressed: onFacebookPressed,
        )),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    this.customIcon,
    required this.label,
    required this.iconColor,
    required this.onPressed,
  });

  final IconData icon;
  final Widget? customIcon;
  final String label;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              width: 1.0,
            ),
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIcon ?? Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Manrope',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
