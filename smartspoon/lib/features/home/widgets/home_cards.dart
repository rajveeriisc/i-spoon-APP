import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smartspoon/features/insights/index.dart';
import 'package:smartspoon/features/devices/index.dart';
import 'package:smartspoon/features/devices/presentation/screens/ble_settings_screen.dart';
import 'package:smartspoon/features/insights/presentation/screens/heater_control_page.dart';
import 'package:smartspoon/features/insights/domain/services/unified_data_service.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart'; // Import custom premium widgets
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart'; // For animations

/// BLE Device Card - Shows connected device with battery and status
class SpoonConnectedCard extends StatefulWidget {
  const SpoonConnectedCard({super.key});

  @override
  State<SpoonConnectedCard> createState() => _SpoonConnectedCardState();
}

class _SpoonConnectedCardState extends State<SpoonConnectedCard> {
  late BleService _bleService;

  @override
  void initState() {
    super.initState();
    _bleService = Provider.of<BleService>(context, listen: false);
  }

  void _navigateToAddDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDeviceScreen()),
    );
  }

  void _navigateToDeviceDetails() {
    final connectedIds = _bleService.connectedDeviceIds;
    if (connectedIds.isEmpty) return;

    final id = connectedIds.first;
    final device = _bleService.getDeviceById(id);
    final deviceName = device?.name ?? 'I-Spoon Device';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BleSettingsScreen(
          deviceId: id,
          deviceName: deviceName.isEmpty ? 'I-Spoon Device' : deviceName,
        ),
      ),
    );
  }

  Future<void> _handleReconnect() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Attempting to reconnect...')));
    await _bleService.autoConnectToLastDevice();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _bleService,
      builder: (context, _) {
        final connectedIds = _bleService.connectedDeviceIds;
        final savedDevices = _bleService.previousDevices;
        final dataService = Provider.of<UnifiedDataService>(context);
        final batteryLevel = dataService.batteryLevel;

        final isConnected = connectedIds.isNotEmpty;
        final hasLastDevice = savedDevices.isNotEmpty;

        if (!isConnected && !hasLastDevice) {
          return _buildNoDeviceCard();
        }

        String deviceName = 'Unknown Device';
        String lastConnectedText = '';

        if (isConnected) {
          final id = connectedIds.first;
          final device = _bleService.getDeviceById(id);
          deviceName = device?.name ?? 'I-Spoon Device';
          if (deviceName.isEmpty) deviceName = 'I-Spoon Device';
        } else if (hasLastDevice) {
          final last = savedDevices.first;
          deviceName = last.name;
          lastConnectedText = last.formattedLastConnected;
        }

        return _buildStatusCard(
          isConnected: isConnected,
          deviceName: deviceName,
          lastConnectedText: lastConnectedText,
          batteryLevel: batteryLevel,
        ).animate().fadeIn().slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildNoDeviceCard() {
    return PremiumGlassCard(
      onTap: _navigateToAddDevice,
      child: Row(
        children: [
          PremiumIconBox(
            icon: Icons.bluetooth_searching,
            color: const Color(0xFF475569),
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Device',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to pair your I-Spoon',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.add_circle, color: AppTheme.emerald, size: 28),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildStatusCard({
    required bool isConnected,
    required String deviceName,
    required String lastConnectedText,
    required int batteryLevel,
  }) {
    return PremiumGlassCard(
      onTap: isConnected ? _navigateToDeviceDetails : _navigateToAddDevice,
      child: Column(
        children: [
          Row(
            children: [
              PremiumIconBox(
                icon: isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: isConnected ? AppTheme.emerald : Colors.redAccent,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? AppTheme.emerald
                                : Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isConnected
                                        ? AppTheme.emerald
                                        : Colors.redAccent)
                                    .withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConnected ? 'Connected' : 'Disconnected',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: isConnected
                                ? AppTheme.emerald
                                : Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isConnected)
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: AppTheme.border,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isConnected) ...[
                Row(
                  children: [
                    Icon(
                      _getBatteryIcon(batteryLevel),
                      size: 20,
                      color: _getBatteryColor(batteryLevel),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      batteryLevel > 0
                          ? '$batteryLevel% Battery'
                          : 'Battery N/A',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Last: $lastConnectedText',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
              if (!isConnected)
                GestureDetector(
                  onTap: _handleReconnect,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.emerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Reconnect',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppTheme.emerald,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getBatteryIcon(int level) {
    if (level == 0) return Icons.battery_unknown;
    if (level > 90) return Icons.battery_full;
    if (level > 70) return Icons.battery_6_bar;
    if (level > 50) return Icons.battery_5_bar;
    if (level > 30) return Icons.battery_3_bar;
    if (level > 10) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _getBatteryColor(int level) {
    if (level == 0) return Colors.grey;
    if (level > 30) return AppTheme.emerald;
    if (level > 10) return Colors.orange;
    return Colors.red;
  }
}

/// Temperature Display Card
class TemperatureCard extends StatelessWidget {
  const TemperatureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UnifiedDataService>(
      builder: (context, dataService, _) {
        return Row(
          children: [
            Expanded(
              child: PremiumGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(
                          Icons.thermostat,
                          color: Color(0xFFFFA726),
                          size: 24,
                        ),
                        Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFA726),
                              shape: BoxShape.circle,
                            )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Food Temp',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(dataService.foodTempC).toStringAsFixed(1)}°',
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PremiumGlassCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HeaterControlPage(),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: dataService.isHeaterOn
                              ? const Color(0xFFEF5350)
                              : Colors.grey,
                          size: 24,
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: dataService.isHeaterOn
                                ? const Color(0xFFEF5350)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            boxShadow: dataService.isHeaterOn
                                ? [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Heater',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dataService.isHeaterOn ? 'ON' : 'OFF',
                      style: GoogleFonts.manrope(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: dataService.isHeaterOn
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
      },
    );
  }
}

/// Eating Analysis Card
class EatingAnalysisCard extends StatelessWidget {
  const EatingAnalysisCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<UnifiedDataService, InsightsController>(
      builder: (context, dataService, insights, _) {
        // Get the tremor index (0-3 scale). Prefer live data if session is active.
        double tremorIdx = dataService.isSessionActive 
            ? dataService.tremorIndex 
            : (insights.summary?.tremorIndex ?? 0).toDouble();
            
        tremorIdx = tremorIdx.clamp(0.0, 3.0);

        bool hasData = dataService.totalBites > 0;
        
        // Tremor stability = inverse of tremor index (0 = perfectly stable 100%, 3 = very tremory 0%)
        final stabilityPct = (100 - (tremorIdx / 3.0 * 100)).clamp(0, 100).toInt();

        final String stabilityText = hasData ? '$stabilityPct%' : '--%';
        final Color stabilityColor = !hasData 
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
            : stabilityPct >= 70
                ? const Color(0xFF26A69A)
                : stabilityPct >= 40
                    ? AppTheme.amber
                    : AppTheme.rose;
                    
        final String speedText = hasData ? '${dataService.avgBiteTime.toStringAsFixed(0)}s' : '--s';
        final Color speedColor = !hasData 
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
            : AppTheme.emerald;

        return PremiumGlassCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MealsAnalysisPage(),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Eating Analysis',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _AnalysisItem(
                    label: 'Total Bites',
                    value: dataService.totalBites.toString(),
                    color: !hasData 
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) 
                        : const Color(0xFF7E57C2),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  _AnalysisItem(
                    label: 'Avg Speed',
                    value: speedText,
                    color: speedColor,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  _AnalysisItem(
                    label: 'Stability',
                    value: stabilityText,
                    color: stabilityColor,
                  ),
                ],
              ),
              // ── Per-Meal Breakdown ───────────────────────────────
              if (hasData) ...[
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MealBiteChip(
                      icon: Icons.wb_twilight,
                      label: 'Breakfast',
                      bites: dataService.breakfastTotalBites,
                      isActive: dataService.currentMealType == 'Breakfast',
                    ),
                    _MealBiteChip(
                      icon: Icons.wb_sunny,
                      label: 'Lunch',
                      bites: dataService.lunchTotalBites,
                      isActive: dataService.currentMealType == 'Lunch',
                    ),
                    _MealBiteChip(
                      icon: Icons.nights_stay_outlined,
                      label: 'Dinner',
                      bites: dataService.dinnerTotalBites,
                      isActive: dataService.currentMealType == 'Dinner',
                    ),
                    _MealBiteChip(
                      icon: Icons.local_dining,
                      label: 'Snack',
                      bites: dataService.snackTotalBites,
                      isActive: dataService.currentMealType == 'Snack',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
      },
    );
  }
}


class _AnalysisItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalysisItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Per-meal bite chip for the Eating Analysis card
class _MealBiteChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int bites;
  final bool isActive;

  const _MealBiteChip({
    required this.icon,
    required this.label,
    required this.bites,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.emerald.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: isActive
                ? Border.all(color: AppTheme.emerald, width: 1.5)
                : null,
          ),
          child: Icon(icon, size: 16, color: isActive ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 6),
        Text(
          '$bites',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: bites > 0 ? const Color(0xFF7E57C2) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Daily Tip Card
class DailyTipCard extends StatelessWidget {
  const DailyTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF43A047).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: Color(0xFF66BB6A),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tip',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF66BB6A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mindful eating can help you recognize true hunger and fullness cues more effectively.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0);
  }
}

/// Motivation Card
class MotivationCard extends StatelessWidget {
  const MotivationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.favorite_border,
              color: Color(0xFFF06292),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivation',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF06292),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"Slow down, savor life, and nourish your body with intention."',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1, end: 0);
  }
}

/// Today's Meals Table
class TodayMealsTable extends StatefulWidget {
  const TodayMealsTable({super.key});

  @override
  State<TodayMealsTable> createState() => _TodayMealsTableState();
}

class _TodayMealsTableState extends State<TodayMealsTable> {
  late Future<List<MealSummary>> _mealsFuture;

  @override
  void initState() {
    super.initState();
    _fetchMeals();
  }

  void _fetchMeals() {
    final controller = context.read<InsightsController>();
    final today = DateTime.now();
    _mealsFuture = controller.getMealsForDate(DateTime(today.year, today.month, today.day));
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  IconData _getMealIcon(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast': return Icons.wb_twilight;
      case 'lunch': return Icons.wb_sunny;
      case 'dinner': return Icons.nights_stay_outlined;
      default: return Icons.local_dining;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Meals',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        PremiumGlassCard(
          child: FutureBuilder<List<MealSummary>>(
            future: _mealsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ));
              }
              
              final meals = snapshot.data ?? [];
              
              if (meals.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No meals recorded today yet.',
                      style: GoogleFonts.manrope(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                );
              }

              // Reverse to show most recent at top
              final displayMeals = meals.reversed.toList();

              return ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayMeals.length,
                separatorBuilder: (context, index) => Divider(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  height: 24,
                ),
                itemBuilder: (context, index) {
                  final meal = displayMeals[index];
                  final type = meal.mealType ?? 'Meal';
                  final duration = meal.durationMinutes?.round() ?? 0;
                  
                  return Consumer<UnifiedDataService>(
                    builder: (context, unifiedData, child) {
                      int displayBites = meal.totalBites;
                      bool isLive = false;
                      
                      if (unifiedData.isSessionActive && unifiedData.currentMealType == type) {
                         displayBites = unifiedData.totalBites;
                         isLive = true;
                      }

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.emerald.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getMealIcon(type),
                              color: AppTheme.emerald,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      type,
                                      style: GoogleFonts.manrope(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    if (isLive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          'LIVE',
                                          style: GoogleFonts.manrope(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_formatTime(meal.lastMealStart)} - ${_formatTime(meal.lastMealEnd)} ($duration min)',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$displayBites',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF7E57C2),
                                ),
                              ),
                              Text(
                                'bites',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }
}
