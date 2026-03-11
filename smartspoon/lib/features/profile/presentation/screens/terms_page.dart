import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

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
                          icon: Icons.handshake_outlined,
                          title: '1. Acceptance of Terms',
                          content:
                              'By accessing and using the SmartSpoon application, you accept and agree to be bound by the terms and provision of this agreement. In addition, when using these particular services, you shall be subject to any posted guidelines or rules applicable to such services.',
                        ),
                        _buildSection(
                          icon: Icons.description_outlined,
                          title: '2. Description of Service',
                          content:
                              'SmartSpoon provides users with tools to track eating habits and control supported smart devices. You are responsible for obtaining access to the Service and that access may involve third party fees (such as Internet service provider or airtime charges).',
                        ),
                        _buildSection(
                          icon: Icons.manage_accounts_outlined,
                          title: '3. User Account',
                          content:
                              'To access certain features of the App, you may be required to create an account. You are responsible for maintaining the confidentiality of your account and password and for restricting access to your computer or device, and you agree to accept responsibility for all activities that occur under your account or password.',
                        ),
                        _buildSection(
                          icon: Icons.block_outlined,
                          title: '4. Prohibited Conduct',
                          content:
                              'You agree not to use the Service to:\n\n• Upload or transmit any content that is unlawful, harmful, threatening, abusive, or otherwise objectionable.\n• Harm minors in any way.\n• Impersonate any person or entity.',
                        ),
                        _buildSection(
                          icon: Icons.cancel_outlined,
                          title: '5. Termination',
                          content:
                              'We may terminate or suspend access to our Service immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.',
                        ),
                        _buildSection(
                          icon: Icons.update_rounded,
                          title: '6. Changes to Terms',
                          content:
                              'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material we will try to provide at least 30 days notice prior to any new terms taking effect.',
                        ),

                        const SizedBox(height: 8),

                        // I Agree button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [AppTheme.emerald, const Color(0xFF4338CA)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.emerald.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.pop(context),
                                child: Center(
                                  child: Text(
                                    'I Agree',
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
              'Terms of Service',
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

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Builder(
      builder: (context) {
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
                      color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF475569),
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
