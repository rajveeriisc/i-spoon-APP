import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';
import 'package:smartspoon/features/profile/presentation/widgets/profile_redesign_widgets.dart'; // For ProfileCard

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkBackgroundGradient
                  : AppTheme.backgroundGradient,
            ),
          ),
          const GeometricBackground(),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'FAQ',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 40), // Balance
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
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
                ),
              ],
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ProfileCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            iconColor: AppTheme.emerald,
            collapsedIconColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            title: Text(
              question,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold, 
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            children: [
              Text(
                answer,
                style: GoogleFonts.manrope(
                  color: const Color(0xFF475569),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
