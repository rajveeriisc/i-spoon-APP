import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Policy')),
      body: const Center(
        child: Text('Terms and Policy content goes here'),
      ),
    );
  }
}
