import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/home/widgets/home_cards.dart';

class HomeSections extends StatelessWidget {
  const HomeSections({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth * 0.05;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: padding),
              const SpoonConnectedCard(),
              SizedBox(height: padding * 1.5),
              const TemperatureDisplay(),
              SizedBox(height: padding * 1.5),
              const EatingAnalysisCard(),
              SizedBox(height: padding * 1.5),
              Text(
                'Health Insights',
                style: GoogleFonts.lato(
                  fontSize: constraints.maxWidth * 0.055,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: padding),
              const DailyTipCard(),
              SizedBox(height: padding),
              const MotivationCard(),
              SizedBox(height: padding * 1.5),
              const MyDevices(),
            ],
          ),
        );
      },
    );
  }
}
