import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/auth/presentation/screens/login_screen.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingContent> _contents = [
    OnboardingContent(
      image: 'assets/images/onboarding_1.jpg',
      title: 'Smart Dining Analytics',
      description:
          'Experience the future of eating with AI-powered insights. Track every bite and improve your stability.',
    ),
    OnboardingContent(
      image: 'assets/images/onboarding_2.jpg',
      title: 'Health & Tremor Control',
      description:
          'Monitor your health metrics in real-time. Our advanced algorithms help you maintain control and confidence.',
    ),
    OnboardingContent(
      image: 'assets/images/onboarding_3.png',
      title: 'Temperature Control',
      description:
          'Ensure every meal is perfectly warm. Our built-in sensors alert you proactively to unsafe temperatures.',
    ),
    OnboardingContent(
      image: 'assets/images/onboarding_4.png',
      title: 'Progress Insights',
      description:
          'Visualize your daily wellness journey effortlessly. Watch your eating habits transform beautifully over time.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _contents.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    } else {
      _onGetStarted();
    }
  }

  void _onGetStarted() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine bottom padding safe area
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkBackgroundGradient
                  : AppTheme.backgroundGradient,
            ),
          ),
          const GeometricBackground(),

          SafeArea(
            bottom: false, // We handle bottom manually for the sticky controls
            child: Column(
              children: [
                // Scrollable Page Content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _contents.length,
                    itemBuilder: (context, index) {
                      return OnboardingPage(content: _contents[index]);
                    },
                  ),
                ),

                // Sticky Bottom Controls Area
                Container(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset > 0 ? bottomInset : 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                        width: 1,
                      )
                    )
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _contents.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentPage == index ? 32 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppTheme.emerald
                                  : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: _currentPage == index
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.emerald.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Primary Button (Next / Get Started)
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.emerald.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.emerald,
                              AppTheme.emerald.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _currentPage == _contents.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      // Skip Button spacing handling
                      if (_currentPage < _contents.length - 1) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _onGetStarted,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12 + 48), // Match height of skip button exactly to prevent layout jumping
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingContent {
  final String image;
  final String title;
  final String description;

  OnboardingContent({
    required this.image,
    required this.title,
    required this.description,
  });
}

class OnboardingPage extends StatelessWidget {
  final OnboardingContent content;

  const OnboardingPage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Beautiful constrained image container
          Expanded(
            flex: 5,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340), // Stop huge stretching on tablets
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Image.asset(
                    content.image,
                    fit: BoxFit.contain, // Contain keeps correct proportions
                    width: double.infinity,
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  content.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
