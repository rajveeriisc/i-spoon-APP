import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/auth/providers/user_provider.dart';
import 'package:smartspoon/features/profile/presentation/widgets/profile_redesign_widgets.dart';
import 'package:smartspoon/features/auth/domain/services/auth_service.dart';

class DailyBitesScreen extends StatefulWidget {
  const DailyBitesScreen({super.key});

  @override
  State<DailyBitesScreen> createState() => _DailyBitesScreenState();
}

class _DailyBitesScreenState extends State<DailyBitesScreen> {
  // Local state for sliders
  double _breakfastBites = 15;
  double _lunchBites = 20;
  double _dinnerBites = 15;
  double _snackBites = 5;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Initialize from provider values
    final daily = userProvider.dailyGoal?.toDouble() ?? 50.0;
    // Split equally for now as detailed goals aren't supported in backend yet
    final split = daily / 4;
    _breakfastBites = split;
    _lunchBites = split;
    _dinnerBites = split;
    _snackBites = split;
  }

  bool _isSaving = false;

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final total = _breakfastBites + _lunchBites + _dinnerBites + _snackBites;
      
      final updates = {
        'daily_goal': total.toInt(),
        // Detailed goals not yet supported in UserProvider/Backend
      };

      // Call API
      final res = await AuthService.updateProfile(data: updates);
      
      if (mounted) {
        // Update UserProvider with response
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final userData = res['user'];
        if (userData != null) {
          userProvider.setFromMap(userData as Map<String, dynamic>);
        }
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Daily bite goal updated to ${total.toInt()}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save goals: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _breakfastBites + _lunchBites + _dinnerBites + _snackBites;

    return Scaffold(
      backgroundColor: kProfileBackground,
      appBar: AppBar(
        title: Text(
          'Daily Bites Goal',
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: GoogleFonts.outfit(
                color: kProfilePrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             // Total Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kProfilePrimary, kProfileGradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: kProfilePrimary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Total Daily Goal',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${total.toInt()}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'bites / day',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Meal Breakdown',
                style: kTitleStyle,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildMealSlider('Breakfast', _breakfastBites, (val) => setState(() => _breakfastBites = val), Icons.wb_sunny_outlined),
            _buildMealSlider('Lunch', _lunchBites, (val) => setState(() => _lunchBites = val), Icons.restaurant_outlined),
            _buildMealSlider('Dinner', _dinnerBites, (val) => setState(() => _dinnerBites = val), Icons.nights_stay_outlined),
            _buildMealSlider('Snacks', _snackBites, (val) => setState(() => _snackBites = val), Icons.cookie_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSlider(String label, double value, ValueChanged<double> onChanged, IconData icon) {
    return ProfileCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kProfilePrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: kProfilePrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: kBodyStyle.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${value.toInt()} bites',
                style: kSubtitleStyle.copyWith(color: kProfilePrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: kProfilePrimary,
              inactiveTrackColor: kProfilePrimary.withValues(alpha: 0.1),
              thumbColor: kProfilePrimary,
              overlayColor: kProfilePrimary.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 50,
              divisions: 50,
              label: value.round().toString(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
