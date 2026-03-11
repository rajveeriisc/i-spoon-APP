import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : null,
              gradient: isDark
                  ? null
                  : AppTheme.backgroundGradient,
            ),
          ),
          const GeometricBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gold date badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined, color: AppTheme.gold, size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  'Last updated: January 23, 2026',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSection(
                          context,
                          icon: Icons.info_outline_rounded,
                          title: '1. Introduction',
                          content:
                              'Welcome to SmartSpoon. We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you as to how we look after your personal data when you visit our application and tell you about your privacy rights and how the law protects you.',
                        ),
                        _buildSection(
                          context,
                          icon: Icons.data_usage_rounded,
                          title: '2. Data We Collect',
                          content:
                              'We may collect, use, store and transfer different kinds of personal data about you:\n\n• Identity Data: includes first name, last name, username or similar identifier.\n• Contact Data: includes email address and telephone number.\n• Technical Data: includes internet protocol (IP) address, login data, browser type and version.\n• Usage Data: includes information about how you use our website, products and services.',
                        ),
                        _buildSection(
                          context,
                          icon: Icons.manage_search_rounded,
                          title: '3. How We Use Your Data',
                          content:
                              'We will only use your personal data when the law allows us to. Most commonly, we will use your personal data in the following circumstances:\n\n• Where we need to perform the contract we are about to enter into or have entered into with you.\n• Where it is necessary for our legitimate interests.\n• Where we need to comply with a legal or regulatory obligation.',
                        ),
                        _buildSection(
                          context,
                          icon: Icons.security_rounded,
                          title: '4. Data Security',
                          content:
                              'We have put in place appropriate security measures to prevent your personal data from being accidentally lost, used or accessed in an unauthorized way, altered or disclosed. In addition, we limit access to your personal data to those employees, agents, contractors and other third parties who have a business need to know.',
                        ),
                        _buildSection(
                          context,
                          icon: Icons.contact_support_outlined,
                          title: '5. Contact Us',
                          content:
                              'If you have any questions about this privacy policy or our privacy practices, please contact us at support@smartspoon.com.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Privacy Policy',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceCard : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
          boxShadow: isDark ? const [] : const [
            BoxShadow(color: Color(0x0A4F46E5), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppTheme.emerald, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emerald,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                content,
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  color: isDark ? Colors.white.withValues(alpha: 0.8) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.65,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
