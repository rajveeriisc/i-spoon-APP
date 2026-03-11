import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/profile/index.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/auth/index.dart';
import 'package:smartspoon/features/home/widgets/home_cards.dart'
    as home_widgets;
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';
import 'package:smartspoon/core/widgets/premium_header.dart';
import 'package:smartspoon/core/services/permission_service.dart';

// HomePage widget serves as the main entry point for the app's home screen
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Tracks the currently selected bottom navigation item
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Request permissions once on first ever launch (no-op on all subsequent opens)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionService.requestIfNeeded(context);
    });
  }

  // Updates the selected index when a bottom navigation item is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Determines which content to display based on the selected index
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const HomeContent();
      case 1:
        // InsightsController now provided globally in main.dart
        return const InsightsDashboard();
      case 2:
        return const ProfilePage();
      default:
        return const HomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allow body to extend behind the bottom nav
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Premium theme-aware gradient background
          Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkBackgroundGradient
                  : AppTheme.backgroundGradient,
            ),
          ),
          // 2. Subtle geometric background pattern
          const GeometricBackground(),
          // 3. Turquoise glow top-right
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.emerald.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 4. Main Content Area
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Custom Header
                const PremiumHeader(
                  title: 'Good Morning,',
                  subtitle: 'Welcome back',
                ),

                // Body Content
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildGlassBottomNav(context),
    );
  }



  Widget _buildGlassBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter:
              dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Needs imports
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.grid_view_rounded, 'Home'),
              _buildNavItem(1, Icons.insights_rounded, 'Insights'),
              _buildNavItem(2, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(isSelected ? 10 : 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.emerald.withValues(alpha: 0.2)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? AppTheme.emerald
                  : Colors.white.withValues(alpha: 0.5),
              size: 24,
            ),
          ),
          if (isSelected)
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.emerald,
              ),
            ),
        ],
      ),
    );
  }
}

// HomeContent widget displays the main content of the home page
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reduced top padding because custom header handles spacing
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // Bottom padding for floating nav
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const home_widgets.SpoonConnectedCard(),
              const SizedBox(height: 20),
              
              // Temperature Card handles its own side-by-side layout internally now
              const home_widgets.TemperatureCard(),
              const SizedBox(height: 20),
              
              const home_widgets.EatingAnalysisCard(),
              const SizedBox(height: 24),
              
              Text(
                'Health Insights',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              const home_widgets.DailyTipCard(),
              const SizedBox(height: 16),
              const home_widgets.MotivationCard(),
              const SizedBox(height: 20),
              // We removed MyDevices list to clean up the dashboard.
              // Users can access devices via the Connected Card or Settings.
            ],
          ),
        );
      },
    );
  }
}
