import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last updated: January 23, 2026',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '1. Acceptance of Terms',
              'By accessing and using the SmartSpoon application, you accept and agree to be bound by the terms and provision of this agreement. In addition, when using these particular services, you shall be subject to any posted guidelines or rules applicable to such services.',
            ),
            _buildSection(
              context,
              '2. Description of Service',
              'SmartSpoon provides users with tools to track eating habits and control supported smart devices. You are responsible for obtaining access to the Service and that access may involve third party fees (such as Internet service provider or airtime charges).',
            ),
            _buildSection(
              context,
              '3. User Account',
              'To access certain features of the App, you may be required to create an account. You are responsible for maintaining the confidentiality of your account and password and for restricting access to your computer or device, and you agree to accept responsibility for all activities that occur under your account or password.',
            ),
            _buildSection(
              context,
              '4. Prohibited Conduct',
              'You agree not to use the Service to:\n\n• Upload, post, email, transmit or otherwise make available any content that is unlawful, harmful, threatening, abusive, harassing, tortious, defamatory, vulgar, obscene, libelous, invasive of another\'s privacy, hateful, or racially, ethnically or otherwise objectionable.\n• Harm minors in any way.\n• Impersonate any person or entity.',
            ),
            _buildSection(
              context,
              '5. Termination',
              'We may terminate or suspend access to our Service immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.',
            ),
             _buildSection(
              context,
              '6. Changes to Terms',
              'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material we will try to provide at least 30 days notice prior to any new terms taking effect.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
