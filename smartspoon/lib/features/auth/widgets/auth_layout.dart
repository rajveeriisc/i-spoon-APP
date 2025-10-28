import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final padding = EdgeInsets.symmetric(
      horizontal: size.width * 0.08,
      vertical: size.height * 0.02,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _gradientForBrightness(
                      Theme.of(context).brightness,
                    ),
                  ),
                  child: Padding(padding: padding, child: child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  LinearGradient _gradientForBrightness(Brightness brightness) {
    if (brightness == Brightness.light) {
      return const LinearGradient(
        colors: [Color(0xFFBBDEFB), Color(0xFFE1BEE7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
