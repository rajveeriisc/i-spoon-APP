import 'package:flutter/material.dart';
import 'package:smartspoon/features/profile/widgets/faq_section_card.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: FaqSectionCard(),
      ),
    );
  }
}
