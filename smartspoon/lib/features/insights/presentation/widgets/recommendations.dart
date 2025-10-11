import 'package:flutter/material.dart';
import '../../domain/models.dart';

class Recommendations extends StatelessWidget {
  const Recommendations({super.key, required this.trends});
  final TrendData? trends;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: size.width * 0.05),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Personalized Suggestions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('✓ Great progress! Tremor decreased this week.'),
          Text('⚠️ Eating speed: Try smaller bites and pauses.'),
        ],
      ),
    );
  }
}
