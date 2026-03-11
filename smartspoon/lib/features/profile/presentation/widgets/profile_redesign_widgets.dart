import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';

// --- Constants & Theme ---
// We use AppTheme constants directly now, but keep aliases if needed for compatibility
const double kPadding = 20.0;
const double kBorderRadius = 24.0;

// Typography Helper - Mapped to Manrope/Premium
TextStyle get kTitleStyle => GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold);
TextStyle get kSubtitleStyle => GoogleFonts.manrope(fontSize: 13);
TextStyle get kBodyStyle => GoogleFonts.manrope(fontSize: 15);

// --- 1. ProfileHeader ---
class ProfileHeader extends StatelessWidget {
  final String avatarUrl;
  final String name;
  final String email;
  final VoidCallback onEdit;

  const ProfileHeader({
    super.key,
    required this.avatarUrl,
    required this.name,
    required this.email,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        children: [
          Stack(
            children: [
              // Avatar
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.emerald, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.emerald.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(avatarUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Edit Button (Small icon badge)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.emerald,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. ProfileCard (Container) ---
// Replaced with PremiumGlassCard wrapper
class ProfileCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;

  const ProfileCard({super.key, required this.child, this.padding, this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: PremiumGlassCard(
        child: Padding(
          padding: padding ?? const EdgeInsets.all(kPadding),
          child: child,
        ),
      ),
    );
  }
}

// --- 3. StatsCard ---
class StatsCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isUp; // Trend
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.isUp = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PremiumIconBox(icon: icon, color: AppTheme.emerald, size: 20),
              if (isUp) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_upward, size: 14, color: AppTheme.emerald),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 4. ProgressBar ---
class ProfileProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0

  const ProfileProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.border,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.emerald, const Color(0xFF4338CA)],
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.emerald.withValues(alpha: 0.5),
                blurRadius: 6,
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- 5. SettingsRow ---
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing; // Switch or Chevron often
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showBorder;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: showBorder 
                ? Border(bottom: BorderSide(color: AppTheme.border, width: 1)) 
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDestructive 
                      ? AppTheme.rose.withValues(alpha: 0.10) 
                      : AppTheme.emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isDestructive ? AppTheme.rose : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDestructive 
                        ? AppTheme.rose 
                        : (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
              if (trailing != null) 
                trailing! 
              else 
                Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
