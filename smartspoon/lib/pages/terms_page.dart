import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Policy')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'i-Spoon Terms & Privacy',
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This is a placeholder terms and privacy page. Replace with your actual policy.\n\n'
              'We collect basic profile information and device activity to provide the service. '
              'You can request data deletion by contacting support@i-spoon.app.',
              style: GoogleFonts.lato(fontSize: 14, color: onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
