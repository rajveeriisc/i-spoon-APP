import 'package:flutter/material.dart';
import 'package:smartspoon/pages/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/state/user_provider.dart';
import 'package:smartspoon/features/core/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = kIsWeb;
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (kIsWeb &&
        (options.appId.isEmpty || options.appId.contains('PLACEHOLDER'))) {
      // Skip Firebase init on web if config is not properly set up to prevent launch crash.
      debugPrint(
        'Skipping Firebase initialization on web due to placeholder/empty appId.',
      );
    } else {
      await Firebase.initializeApp(options: options);
    }
  } catch (e) {
    // Do not block app launch — log and continue so the app can open in the browser.
    debugPrint('Firebase initialization failed: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = AppTheme.light();
    final ThemeData darkTheme = AppTheme.dark();

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'i-Spoon',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          scrollBehavior: AppScrollBehavior(),
          home: const SplashScreen(),
        );
      },
    );
  }
}

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
