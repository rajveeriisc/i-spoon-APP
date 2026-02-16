import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/core/core.dart';
import 'package:smartspoon/core/providers/theme_provider.dart';
import 'package:smartspoon/features/splash/presentation/screens/splash_screen.dart';

/// Main application widget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'i-Spoon',

          // Theme configuration
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeProvider.themeMode,

          // Custom scroll behavior
          scrollBehavior: AppScrollBehavior(),

          // Home screen
          home: const SplashScreen(),

          // Performance improvements
          builder: (context, child) {
            // Ensure text scale factor doesn't exceed reasonable limits
            final mediaQuery = MediaQuery.of(context);
            final constrainedTextScale = mediaQuery.textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.3,
            );

            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: constrainedTextScale),
              child: child!,
            );
          },
        );
      },
    );
  }
}

/// Custom scroll behavior without scrollbar
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
