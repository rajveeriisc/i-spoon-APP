import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/home/presentation/screens/home_page.dart';
import 'package:smartspoon/features/auth/index.dart';
import 'package:smartspoon/core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCirc),
      ),
    );

    _animController.forward();

    _bootstrapAuth();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapAuth() async {
    debugPrint('🚀 Splash: Starting auth bootstrap...');
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 2400));

    bool toHome = false;
    Map<String, dynamic>? userMap;

    // ── Step 1: Wait for Firebase to restore its persisted session ─────────────
    // currentUser is null until Firebase finishes reading from its local cache.
    // authStateChanges().first waits for that restore — still no network needed.
    try {
      final fbService = FirebaseAuthService();
      final fbUser = await fbService.authStateChanges
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (fbUser != null) {
        debugPrint('🚀 Splash: Firebase session found (${fbUser.email})');
        // Seed a minimal user map from the cached Firebase profile
        userMap = {
          'email': fbUser.email,
          'name': fbUser.displayName,
          'avatar_url': fbUser.photoURL,
        };
        toHome = true;

        // ── Step 2: Enrich with backend profile (best-effort, non-blocking) ────
        // If backend is reachable we load the full DB profile (id, preferences…).
        // If it's not reachable we still go home — Firebase session is the source
        // of truth. We must NOT call logout() on failure here.
        try {
          final storedToken = await AuthService.getToken();
          if (storedToken != null) {
            final res = await AuthService.getMe().timeout(const Duration(seconds: 6));
            final backendUser = res['user'] as Map<String, dynamic>?;
            if (backendUser != null) {
              userMap = backendUser;
              debugPrint('🚀 Splash: Backend profile loaded');
            }
          } else {
            // No backend JWT — silently re-exchange the Firebase token for one
            debugPrint('🚀 Splash: No backend JWT, re-exchanging Firebase token...');
            final idToken = await fbUser.getIdToken();
            if (idToken == null) throw Exception('Could not get Firebase ID token');
            await AuthService.verifyFirebaseToken(idToken: idToken)
                .timeout(const Duration(seconds: 8));
            final res = await AuthService.getMe().timeout(const Duration(seconds: 6));
            final backendUser = res['user'] as Map<String, dynamic>?;
            if (backendUser != null) userMap = backendUser;
            debugPrint('🚀 Splash: Token re-exchanged, profile loaded');
          }
        } catch (e) {
          // Backend unreachable / ngrok down / token stale — fine, keep going.
          debugPrint('⚠️ Splash: Backend check skipped (offline?): $e');
        }
      } else {
        debugPrint('🚀 Splash: No Firebase session — going to login');
        toHome = false;
      }
    } catch (e) {
      debugPrint('❌ Splash: Firebase check error: $e');
      toHome = false;
    }

    await minDelay;
    if (!mounted) return;

    debugPrint('🚀 Splash: → ${toHome ? 'Home' : 'Login'}');

    if (toHome) {
      try {
        if (userMap != null) {
          Provider.of<UserProvider>(context, listen: false).setFromMap(userMap!);
        }
      } catch (e) {
        debugPrint('❌ Splash: UserProvider error: $e');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Theme-aware background
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : null,
              gradient: isDark
                  ? null
                  : AppTheme.backgroundGradient,
            ),
          ),
          // Emerald ambient glow
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.emerald.withValues(alpha: isDark ? 0.15 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.emerald.withValues(alpha: isDark ? 0.10 : 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Premium Floating Icon Container
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.black : Theme.of(context).colorScheme.surface,
                          border: Border.all(
                            color: isDark 
                                ? Colors.white.withValues(alpha: 0.1) 
                                : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            // Soft floating shadow
                            BoxShadow(
                              color: AppTheme.emerald.withValues(alpha: 0.12),
                              blurRadius: 40,
                              spreadRadius: 8,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.restaurant,
                            color: AppTheme.emerald,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      // Clean, modern typography
                      Text(
                        'i-Spoon',
                        style: GoogleFonts.outfit(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Ultra-light subtitle
                      Text(
                        'Smart Eating. Better Living.',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Subtle Micro-Loading Indicator at the very bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _animController,
                    curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
                  ),
                ),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.emerald.withValues(alpha: 0.8)),
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
