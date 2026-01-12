import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FAQ',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          FaqItem(
            question: 'How do I connect my spoon?',
            answer:
                'Turn on Bluetooth on your phone and the spoon. Go to the Home tab and tap "Add Device". Select your spoon from the list to pair.',
          ),
          FaqItem(
            question: 'How do I change the temperature units?',
            answer:
                'Currently, the app supports Celsius. We plan to add Fahrenheit support in a future update.',
          ),
          FaqItem(
            question: 'Can I track multiple users?',
            answer:
                'Yes! You can log out and create a new account for another user on the same device.',
          ),
          FaqItem(
            question: 'What if the heater doesn\'t turn on?',
            answer:
                'Ensure the spoon has sufficient battery charge. If the battery is below 15%, the heater may be disabled to preserve power.',
          ),
          FaqItem(
            question: 'How is "Speed" calculated?',
            answer:
                'Speed is measured in "bites per minute". We analyze the motion data from your spoon to detect every time you take a bite.',
          ),
        ],
      ),
    );
  }
}

class FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const FaqItem({super.key, required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: GoogleFonts.outfit(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
