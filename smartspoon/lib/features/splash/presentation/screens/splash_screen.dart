import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/home/presentation/screens/home_page.dart';
import 'package:smartspoon/features/auth/index.dart';

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

    // Bootstrap auth state: if a token exists, fetch profile and navigate to Home
    // Otherwise, go to Login. Keep a short delay so splash is visible.
    _bootstrapAuth();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapAuth() async {
    debugPrint('🚀 Splash: Starting auth bootstrap...');
    // Show splash at least ~1.2s
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 1200));
    
    bool toHome = false;
    Map<String, dynamic>? me;
    
    try {
      debugPrint('🚀 Splash: Check token...');
      final token = await AuthService.getToken();
      
      if (token != null) {
        debugPrint('🚀 Splash: Token found, fetching profile...');
        // Add timeout to prevent hanging indefinitely
        final res = await AuthService.getMe().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ Splash: Auth timeout!');
            throw TimeoutException('Auth check timed out');
          },
        );
        
        me = res;
        toHome = res['user'] != null;
        debugPrint('🚀 Splash: Profile loaded: $toHome');
      } else {
        debugPrint('🚀 Splash: No token found');
      }
    } catch (e) {
      debugPrint('❌ Splash: Auth error: $e');
      toHome = false;
    }
    
    await minDelay;
    
    if (!mounted) return;
    
    debugPrint('🚀 Splash: Navigating to ${toHome ? 'Home' : 'Login'}');
    
    if (toHome) {
      try {
        final userMap = me!['user'] as Map<String, dynamic>;
        // Use listen: false to avoid unnecessary rebuilds during navigation
        Provider.of<UserProvider>(context, listen: false).setFromMap(userMap);
      } catch (e) {
        debugPrint('❌ Splash: UserProvider mismatch: $e');
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
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
