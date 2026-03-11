import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartspoon/core/core.dart';
import 'package:smartspoon/features/auth/index.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/notifications/index.dart';
import 'package:smartspoon/features/splash/presentation/screens/splash_screen.dart';
import 'package:smartspoon/firebase_options.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase. The firebase_core plugin handles duplicate-init by
  // returning the existing app. On iOS the native SDK may configure [DEFAULT]
  // from GoogleService-Info.plist before Dart runs; calling initializeApp()
  // again is safe — the plugin detects the existing app and skips re-config.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background handler immediately after initialization for terminated state handling
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Configure system UI overlay style for better appearance
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure Google Fonts
  GoogleFonts.config.allowRuntimeFetching = true;

  // Set up global error handlers matching mobile-design constraints
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    return true; // Handled
  };

  _configureCacheManager();

  // Utilize the new setup service to avoid UI blocking (ANR prevention)
  AppSetupService.initializeBackgroundServices();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
        ChangeNotifierProvider(create: (_) => UserProvider()),

        // 1. Create BLE Services first (Singleton instances)
        ChangeNotifierProvider(create: (_) => BleService()..initialize()),
        ChangeNotifierProvider(create: (_) => McuBleService()),
        
        // Tremor Detection Service (Depends on McuBleService)
        ChangeNotifierProxyProvider<McuBleService, TremorDetectionService>(
          create: (context) => TremorDetectionService(Provider.of<McuBleService>(context, listen: false)),
          update: (_, mcuService, previous) => previous ?? TremorDetectionService(mcuService),
        ),

        // 2. Create UnifiedDataService with McuBleService dependency
        ChangeNotifierProxyProvider2<McuBleService, TremorDetectionService, UnifiedDataService>(
          create: (context) => UnifiedDataService(
            mcuService: Provider.of<McuBleService>(context, listen: false),
            tremorService: Provider.of<TremorDetectionService>(context, listen: false),
          ),
          update: (_, mcuService, tremorService, previous) {
             return previous ?? UnifiedDataService(mcuService: mcuService, tremorService: tremorService);
          },
        ),

        // 3. Create Repository using UnifiedDataService
        ProxyProvider<UnifiedDataService, LiveInsightsRepository>(
          create: (context) => LiveInsightsRepository(Provider.of<UnifiedDataService>(context, listen: false)),
          update: (_, dataService, previous) => previous ?? LiveInsightsRepository(dataService),
          dispose: (_, repo) => repo.dispose(),
        ),

        // 4. Create InsightsController using Repository
        // Proxy update hook automatically injects the controller into the service, removing the hacky builder injection.
        ChangeNotifierProxyProvider2<LiveInsightsRepository, UnifiedDataService, InsightsController>(
          create: (context) => InsightsController(Provider.of<LiveInsightsRepository>(context, listen: false))..init(),
          update: (_, repository, dataService, previous) {
             final controller = previous ?? InsightsController(repository);
             if (dataService.insightsController == null) {
                // safely establish the link
                dataService.insightsController = controller;
                controller.setUnifiedDataService(dataService);
             }
             return controller;
          },
        ),

        // 5. Notification Provider
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()..initialize(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Configure cache manager for optimal performance
void _configureCacheManager() {
  CachedNetworkImage.logLevel = CacheManagerLogLevel.warning;
}

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
          navigatorKey: navigatorKey,
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
