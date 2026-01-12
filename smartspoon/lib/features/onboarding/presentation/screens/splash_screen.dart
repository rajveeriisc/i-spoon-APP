import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:smartspoon/features/home/index.dart';
import 'package:smartspoon/features/auth/index.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smartspoon/firebase_options.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:flutter/foundation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutBack,
      ),
    );

    _animationController.forward();

    // Initialize app services then check auth
    _initApp();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    // Minimum splash duration
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 1500));
    
    try {
      // 1. Initialize Firebase
      final options = DefaultFirebaseOptions.currentPlatform;
      if (kIsWeb && (options.appId.isEmpty || options.appId.contains('PLACEHOLDER'))) {
        debugPrint('Skipping Firebase init on web (placeholder)');
      } else {
        await Firebase.initializeApp(options: options);
        debugPrint('✅ Firebase initialized');
      }

      // 2. Initialize BLE
      final bleService = BleService();
      await bleService.initialize();
      // Auto-connect in background
      bleService.autoConnectToLastDevice().then((_) {}).catchError((_) {});
      debugPrint('✅ BLE Service initialized');

    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      // Continue anyway, auth check might handle it or fail gracefully
    }

    // 3. Check Auth
    await _checkAuth(minDelay);
  }

  Future<void> _checkAuth(Future<void> minDelay) async {
    bool toHome = false;
    Map<String, dynamic>? me;
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        try {
          final res = await AuthService.getMe();
          me = res;
          toHome = res['user'] != null;
        } catch (_) {
          // Backend might be down or removed. Fallback to Firebase user.
          final fbService = FirebaseAuthService();
          final user = fbService.currentUser;
          if (user != null) {
             me = {
              'user': {
                'id': 0, // Placeholder ID
                'email': user.email,
                'name': user.displayName,
                'avatar_url': user.photoURL,
              }
            };
            toHome = true;
          }
        }
      }
    } catch (_) {
      toHome = false;
    }

    await minDelay;
    if (!mounted) return;

    if (toHome) {
      try {
        final userMap = me!['user'] as Map<String, dynamic>;
        Provider.of<UserProvider>(context, listen: false).setFromMap(userMap);
      } catch (_) {}
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF533CE5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.ramen_dining,
                      color: Colors.white,
                      size: 80,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'i-Spoon',
                  style: GoogleFonts.lato(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
