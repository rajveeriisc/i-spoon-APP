import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartspoon/core/core.dart';
import 'package:smartspoon/core/providers/theme_provider.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/features/auth/index.dart';
import 'package:smartspoon/features/onboarding/index.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/notifications/domain/services/notification_service.dart';
import 'package:smartspoon/features/notifications/providers/notification_provider.dart';
import 'package:smartspoon/firebase_options.dart';
import 'package:smartspoon/core/services/scheduled_sync_service.dart';
import 'package:smartspoon/features/devices/domain/services/mcu_ble_service.dart';
import 'package:smartspoon/features/devices/domain/services/ble_service.dart';
import 'package:smartspoon/features/devices/domain/services/tremor_detection_service.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required before runApp)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background handler immediately after initialization for terminated state handling
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Configure system UI overlay style for better appearance
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations (optional - remove if you want landscape support)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure Google Fonts
  GoogleFonts.config.allowRuntimeFetching = true;

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

  // Configure cache manager for better performance
  _configureCacheManager();

  // Initialize services in background to prevent ANR
  _initializeServicesInBackground();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
        ChangeNotifierProvider(create: (_) => UserProvider()),

        // 1. Create BLE Services first (Singleton instances)
        ChangeNotifierProvider(create: (_) => BleService()..initialize()),
        ChangeNotifierProvider(create: (_) => McuBleService()),
        
        // Tremor Detection Service (Depends on McuBleService)
        ChangeNotifierProvider(
          create: (context) => 
              TremorDetectionService(context.read<McuBleService>()),
        ),

        // 2. Create UnifiedDataService with McuBleService dependency
        ChangeNotifierProvider(
          create: (context) => UnifiedDataService(
            mcuService: context.read<McuBleService>(),
            tremorService: context.read<TremorDetectionService>(),
          ),
        ),

        // 3. Create Repository using UnifiedDataService (Create ONCE, don't listen to updates)
        Provider<LiveInsightsRepository>(
          create: (context) =>
              LiveInsightsRepository(context.read<UnifiedDataService>()),
          dispose: (_, repo) => repo.dispose(),
        ),

        // 4. Create InsightsController using Repository (Create ONCE)
        ChangeNotifierProvider<InsightsController>(
          create: (context) =>
              InsightsController(context.read<LiveInsightsRepository>())
                ..init(),
        ),

        // 5. Notification Provider
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()..initialize(),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Inject Controller into DataService after creation (breaks circular dep)
          final controller = context.read<InsightsController>();
          final dataService = context.read<UnifiedDataService>();

          if (dataService.insightsController == null) {
            dataService.insightsController = controller;
            // NOTE: Do NOT add controller.addListener(dataService.notifyUpdate) —
            // it creates an infinite loop: InsightsController notifies → 
            // UnifiedDataService.notifyUpdate → notifyListeners → 
            // RealLiveTelemetrySource → 4 streams → InsightsController → ∞ loop
          }

          return const MyApp();
        },
      ),
    ),
  );
}

/// Configure cache manager for optimal performance
void _configureCacheManager() {
  // Configure cached network image settings
  CachedNetworkImage.logLevel = CacheManagerLogLevel.warning;

  // You can customize the cache manager here if needed
  // Example: set custom cache duration, max cache size, etc.
}

// ThemeProvider class removed - imported from core implementation

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'i-Spoon',
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeProvider.themeMode,
          scrollBehavior: AppScrollBehavior(),
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

/// Initialize services in background to prevent blocking main thread and ANR
void _initializeServicesInBackground() {
  Future.microtask(() async {
    try {
      // Initialize Notification Service
      await NotificationService().initialize();
      debugPrint(' NotificationService initialized in background');
    } catch (e) {
      debugPrint(' NotificationService initialization failed: $e');
    }

    try {
      // Initialize Scheduled Sync (Daily at 11 PM)
      await ScheduledSyncService.initializeScheduledSync();
      debugPrint('ScheduledSyncService initialized in background');
    } catch (e) {
      debugPrint('ScheduledSyncService initialization failed: $e');
    }
  });
}
