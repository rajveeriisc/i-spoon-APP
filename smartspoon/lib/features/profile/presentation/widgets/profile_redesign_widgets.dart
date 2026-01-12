import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Constants & Theme ---
const Color kProfilePrimary = Color(0xFF00A896);
const Color kProfileGradientEnd = Color(0xFF028174);
const Color kProfileBackground = Color(0xFFF5F7FA); // Light mode background
const Color kProfileCardBg = Colors.white;
const double kPadding = 16.0;
const double kBorderRadius = 16.0;

// Typography Helper
TextStyle get kTitleStyle => GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87);
TextStyle get kSubtitleStyle => GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600);
TextStyle get kBodyStyle => GoogleFonts.outfit(fontSize: 15, color: Colors.black87);

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
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kProfilePrimary, kProfileGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 60, // Adjust based on SafeArea needs in parent
            child: Column(
              children: [
                // Avatar with 4px white border
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Edit',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- 2. ProfileCard (Container) ---
class ProfileCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;

  const ProfileCard({super.key, required this.child, this.padding, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(kPadding),
      decoration: BoxDecoration(
        color: kProfileCardBg,
        borderRadius: BorderRadius.circular(kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), // 2dp-ish subtle shadow
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
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
      child: ProfileCard(
        width: 140, // Fixed width
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: kProfilePrimary, size: 24),
                Icon(
                  isUp ? Icons.arrow_upward : Icons.arrow_downward, 
                  size: 14, 
                  color: isUp ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
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
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: kProfilePrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: kProfilePrimary,
            borderRadius: BorderRadius.circular(4),
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

  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
    this.showBorder = true,
  });

  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showBorder ? Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 24, // Icon Container Width
              alignment: Alignment.centerLeft,
              child: Icon(icon, size: 20, color: isDestructive ? Colors.red : Colors.grey.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : Colors.black87,
                ),
              ),
            ),
            if (trailing != null) trailing! 
            else Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
