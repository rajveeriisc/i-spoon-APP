import 'package:flutter/material.dart';
import 'package:smartspoon/core/theme/app_theme.dart';

/// Clean white card with soft shadow — signature of Wellness Light theme
/// Inspired by Oura Ring, Withings, Apple Health card layouts
class PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double borderRadius;
  final List<Color>? gradientColors;
  final double? width;
  final double? height;

  const PremiumGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius = 16,
    this.gradientColors,
    this.width,
    this.height,
  });

  BoxDecoration _decoration(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = isDarkMode ? AppTheme.darkSurfaceCard : AppTheme.surface;
    final borderColor = isDarkMode ? AppTheme.darkBorder : AppTheme.border;
    final shadowColor = isDarkMode ? Colors.black.withOpacity(0.3) : const Color(0x124F46E5);

    if (gradientColors != null) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: gradientColors!,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    }
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        if (!isDarkMode)
          const BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: _decoration(context),
      child: child,
    );

    if (onTap != null) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: _decoration(context).copyWith(color: null), // shadow-only outer
        child: Material(
          color: gradientColors != null 
              ? Colors.transparent 
              : (Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurfaceCard : AppTheme.surface),
          borderRadius: BorderRadius.circular(borderRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            splashColor: AppTheme.emerald.withValues(alpha: 0.06),
            highlightColor: AppTheme.emerald.withValues(alpha: 0.04),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: _decoration(context),
          child: child,
        ),
          ),
        ),
      );
    }

    return inner;
  }
}

/// Gradient text (indigo→sky or emerald→sky)
class PremiumGradientText extends StatelessWidget {
  final String text;
  final List<Color> gradient;
  final TextStyle? style;

  const PremiumGradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: gradient,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

/// Icon in a tinted soft-color circle — used for list items, feature cards
class PremiumIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const PremiumIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}
