import 'package:flutter/material.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';

/// Auth screen layout — clean wellness light design
/// White background with soft indigo gradient header band
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final padding = EdgeInsets.symmetric(
      horizontal: size.width * 0.06,
      vertical: size.height * 0.02,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.bg,
      body: Stack(
        children: [
          // Theme-aware background gradient
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [AppTheme.darkBg, AppTheme.darkSurface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [AppTheme.bg, Color(0xFFEEF2FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            ),
          ),
          // Very subtle dot pattern
          const GeometricBackground(),
          // Emerald glow top-right
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.emerald.withValues(alpha: isDark ? 0.12 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Emerald glow bottom-left
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.emerald.withValues(alpha: isDark ? 0.10 : 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Scrollable content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(padding: padding, child: child),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
