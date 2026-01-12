import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/home/widgets/home_cards.dart';

/// Home Sections - Contains all home page content sections
class HomeSections extends StatelessWidget {
  const HomeSections({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          
          // Spoon Connected Card
          const SpoonConnectedCard(),
          const SizedBox(height: 24),
          
          // Temperature Display
          const TemperatureCard(),
          const SizedBox(height: 24),
          
          // Eating Analysis
          const EatingAnalysisCard(),
          const SizedBox(height: 24),
          
          // Health Insights Header
          Text(
            'Health Insights',
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Daily Tip
          const DailyTipCard(),
          const SizedBox(height: 16),
          
          // Motivation
          const MotivationCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
