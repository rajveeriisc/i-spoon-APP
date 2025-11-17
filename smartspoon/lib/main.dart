import 'package:flutter/material.dart';
import 'package:smartspoon/pages/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/state/user_provider.dart';
import 'package:smartspoon/features/core/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:smartspoon/features/ble/application/ble_controller.dart';
import 'package:smartspoon/features/ble/infrastructure/flutter_blue_plus_repository.dart';
import 'package:smartspoon/features/insights/application/insights_controller.dart';
import 'package:smartspoon/features/insights/infrastructure/mock_insights_repository.dart';
import 'package:smartspoon/services/unified_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = kIsWeb;

  // Set up global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    debugPrint('Stack trace: $stack');
    return true; // Handled
  };

  // Initialize Firebase with proper error handling
  String? firebaseError;
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (kIsWeb &&
        (options.appId.isEmpty || options.appId.contains('PLACEHOLDER'))) {
      firebaseError = 'Firebase not configured for web platform';
      debugPrint(
        'Skipping Firebase initialization on web due to placeholder/empty appId.',
      );
    } else {
      await Firebase.initializeApp(options: options);
      debugPrint('Firebase initialized successfully');
    }
  } catch (e) {
    firebaseError = 'Firebase initialization failed: ${e.toString()}';
    debugPrint(firebaseError);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(
          create: (_) => BleController(FlutterBluePlusRepository())..init(),
        ),
        // Insights Controller - provides meal/tremor/bite data
        ChangeNotifierProvider(
          create: (_) => InsightsController(MockInsightsRepository())..init(),
        ),
        // Unified Data Service - bridges BLE and Insights data
        ChangeNotifierProxyProvider2<BleController, InsightsController,
            UnifiedDataService>(
          create: (context) => UnifiedDataService(
            bleController: context.read<BleController>(),
            insightsController: context.read<InsightsController>(),
          ),
          update: (context, ble, insights, previous) =>
              previous ??
              UnifiedDataService(
                bleController: ble,
                insightsController: insights,
              ),
        ),
        // Provide firebase error state
        Provider<String?>.value(value: firebaseError),
      ],
      child: const MyApp(),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  static const String _themeKey = 'theme_mode';

  ThemeMode get themeMode => _themeMode;

  /// Load saved theme preference from SharedPreferences
  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme != null) {
        _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load theme preference: $e');
    }
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();

    // Save preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themeKey,
        _themeMode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
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
