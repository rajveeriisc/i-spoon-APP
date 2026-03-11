import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/devices/domain/services/mcu_ble_service.dart';
import 'package:smartspoon/features/insights/domain/services/unified_data_service.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartspoon/features/devices/domain/models/device_model.dart';
import 'package:smartspoon/features/devices/domain/services/device_api_service.dart';

class HeaterControlPage extends StatefulWidget {
  const HeaterControlPage({super.key});

  @override
  State<HeaterControlPage> createState() => _HeaterControlPageState();
}

class _HeaterControlPageState extends State<HeaterControlPage>
    with TickerProviderStateMixin {
  // Local UI State
  bool _isHeaterOn = false;
  double _maxTemp = 40.0;

  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _settingsController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _settingsAnimation;

  final DeviceApiService _deviceApiService = DeviceApiService();
  String? _userDeviceId;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _settingsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _settingsAnimation = CurvedAnimation(
      parent: _settingsController,
      curve: Curves.easeOutCubic,
    );

    _loadSettings().then((_) => _syncFromBackend());
  }

  Future<void> _loadSettings() async {
    final mcuService = Provider.of<McuBleService>(context, listen: false);
    final dataService = Provider.of<UnifiedDataService>(context, listen: false);
    final deviceId = mcuService.connectedDeviceId;
    if (deviceId == null) return;

    if (mounted) {
      setState(() {
        _isHeaterOn = dataService.isHeaterOn;
        _maxTemp = dataService.maxHeaterTemp;
      });
    }
  }

  Future<void> _syncFromBackend() async {
    final mcuService = Provider.of<McuBleService>(context, listen: false);
    final bleDeviceId = mcuService.connectedDeviceId;
    if (bleDeviceId == null) return;

    try {
      final devices = await _deviceApiService.getUserDevices();
      final matchedDevice = devices.firstWhere(
        (d) => d.macAddress?.toUpperCase() == bleDeviceId.toUpperCase(),
        orElse: () => DeviceModel(id: '', name: '', userDeviceId: null),
      );

      if (matchedDevice.userDeviceId != null) {
        _userDeviceId = matchedDevice.userDeviceId;
        if (mounted) {
          bool stateChanged = false;
          if (matchedDevice.heaterActive != null) {
            _isHeaterOn = matchedDevice.heaterActive!;
            stateChanged = true;
          }
          if (matchedDevice.heaterMaxTemp != null) {
            _maxTemp = matchedDevice.heaterMaxTemp!;
            stateChanged = true;
          }
          if (stateChanged) {
            setState(() {});
            await _saveToStorage();
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing heater settings from backend: $e');
    }
  }

  Future<void> _saveToStorage() async {
    final mcuService = Provider.of<McuBleService>(context, listen: false);
    final deviceId = mcuService.connectedDeviceId;
    if (deviceId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('heater_on_$deviceId', _isHeaterOn);
    await prefs.setDouble('heater_max_$deviceId', _maxTemp);
  }

  Future<void> _saveToBackend() async {
    if (_userDeviceId == null) return;
    try {
      await _deviceApiService.updateSettings(_userDeviceId!, {
        'heaterActive': _isHeaterOn,
        'heaterMaxTemp': _maxTemp,
      });
    } catch (e) {
      debugPrint('Error saving heater settings to backend: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  void _toggleHeater(bool value) {
    setState(() => _isHeaterOn = value);
    if (value) {
      _settingsController.forward();
    } else {
      _settingsController.reverse();
    }
  }

  Future<void> _saveSettings() async {
    final mcu = Provider.of<McuBleService>(context, listen: false);
    final dataService = Provider.of<UnifiedDataService>(context, listen: false);

    if (!mcu.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Not connected to Spoon',
              style: GoogleFonts.manrope(color: Colors.white),
            ),
            backgroundColor: AppTheme.rose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    // Update UnifiedDataService
    await dataService.setHeaterState(_isHeaterOn);
    await dataService.setMaxHeaterTemp(_maxTemp);

    // Communicate directly to BLE spoon if connected
    if (_isHeaterOn) {
      await mcu.setHeaterParameters(_maxTemp.toInt(), _maxTemp.toInt()); // Send same value for target and max
    } else {
      await mcu.setHeaterParameters(0, 0); // Send 0 to turn off
    }

    await _saveToStorage();
    _saveToBackend();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isHeaterOn ? '🔥 Heater settings saved & activated' : '🛑 Heater turned OFF',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          backgroundColor: _isHeaterOn ? AppTheme.emerald : Theme.of(context).colorScheme.surfaceVariant,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<McuBleService, UnifiedDataService>(
      builder: (context, mcuService, dataService, _) {
        final foodTemp = dataService.foodTempC;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkBackgroundGradient
                      : AppTheme.backgroundGradient,
                ),
              ),
              const GeometricBackground(),
              SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(context),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            _buildGaugeSection(foodTemp),
                            const SizedBox(height: 40),
                            _buildStatusRow(foodTemp),
                            const SizedBox(height: 32),
                            _buildControlCard(),
                            const SizedBox(height: 28),
                            _buildSaveButton(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Heater Control',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          // Info button
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 22),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text('About Heater Control', style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  content: Text(
                    'The Smart Heater maintains your food at the optimal temperature. Set the activation threshold and maximum limit to customize your heating profile.',
                    style: GoogleFonts.manrope(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Got it', style: GoogleFonts.manrope(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeSection(double foodTemp) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow behind gauge
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, _) {
            return Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emerald.withValues(alpha: _glowAnimation.value),
                    blurRadius: 60,
                    spreadRadius: 0,
                  ),
                ],
              ),
            );
          },
        ),

        // Pulse ring
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.emerald.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
            );
          },
        ),

        // The gauge
        CustomPaint(
          size: const Size(270, 270),
          painter: _EnhancedGaugePainter(
            progress: (foodTemp / 100).clamp(0.0, 1.0),
            isHeaterOn: _isHeaterOn,
          ),
        ),

        // Center info
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.thermostat_rounded, size: 28, color: AppTheme.gold),
            const SizedBox(height: 6),
            Text(
              '${foodTemp.toStringAsFixed(1)}°C',
              style: GoogleFonts.manrope(
                fontSize: 46,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -1.5,
              ),
            ),
            Text(
              'Food Temperature',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusRow(double foodTemp) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatusChip(
          icon: Icons.thermostat_outlined,
          label: 'Current',
          value: '${foodTemp.toStringAsFixed(1)}°C',
          color: AppTheme.emerald,
        ),
        const SizedBox(width: 12),
        _buildStatusChip(
          icon: Icons.local_fire_department_rounded,
          label: 'Target',
          value: '${_maxTemp.toInt()}°C',
          color: AppTheme.gold,
        ),
      ],
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard() {
    return PremiumGlassCard(
      child: Column(
        children: [
          // Header / Toggle Row
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isHeaterOn
                        ? AppTheme.emerald.withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isHeaterOn
                        ? [BoxShadow(color: AppTheme.emerald.withValues(alpha: 0.2), blurRadius: 12)]
                        : null,
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: _isHeaterOn ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Heater',
                        style: GoogleFonts.manrope(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isHeaterOn ? 'Active & Heating' : 'Inactive',
                          key: ValueKey(_isHeaterOn),
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: _isHeaterOn ? AppTheme.emerald : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: _isHeaterOn,
                    onChanged: _toggleHeater,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppTheme.emerald,
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: Colors.grey[800],
                    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                  ),
                ),
              ],
            ),
          ),

          // Animated Settings
          SizeTransition(
            sizeFactor: _settingsAnimation,
            child: Column(
              children: [
                Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildPremiumSlider(
                        title: 'Target Temperature',
                        subtitle: 'Heater will maintain this temperature',
                        value: _maxTemp,
                        min: 20,
                        max: 60,
                        color: AppTheme.gold,
                        icon: Icons.local_fire_department_outlined,
                        onChanged: (v) => setState(() => _maxTemp = v),
                        onChangeEnd: (v) {
                          if (v > 50) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚠️ Caution: High maximum temperature selected!',
                                    style: GoogleFonts.manrope(color: Colors.white)),
                                backgroundColor: Colors.deepOrange,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          }
                        },
                      ),
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

  Widget _buildPremiumSlider({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required Color color,
    required IconData icon,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${value.toInt()}°C',
                style: GoogleFonts.sourceCodePro(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            thumbColor: Colors.white,
            trackHeight: 5.0,
            overlayColor: color.withValues(alpha: 0.1),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            thumbShape: _PremiumThumbShape(ringColor: color),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: _isHeaterOn
                ? [AppTheme.emerald, const Color(0xFF4338CA)]
                : [Colors.grey[800]!, Colors.grey[900]!],
          ),
          boxShadow: [
            BoxShadow(
              color: (_isHeaterOn ? AppTheme.emerald : Colors.black).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _saveSettings,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isHeaterOn ? Icons.save_rounded : Icons.power_settings_new_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  _isHeaterOn ? 'Save & Activate' : 'Save as Inactive',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Custom Painters & Shapes ───

class _PremiumThumbShape extends SliderComponentShape {
  final double thumbRadius = 10.0;
  final Color ringColor;

  _PremiumThumbShape({required this.ringColor});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // Shadow
    canvas.drawCircle(
      center + const Offset(0, 2),
      thumbRadius + 1,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // White center
    canvas.drawCircle(center, thumbRadius, Paint()..color = Colors.white);

    // Colored ring
    canvas.drawCircle(
      center,
      thumbRadius - 3,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}

class _EnhancedGaugePainter extends CustomPainter {
  final double progress;
  final bool isHeaterOn;

  _EnhancedGaugePainter({required this.progress, required this.isHeaterOn});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // 1. Draw Ticks
    const tickCount = 40;
    for (int i = 0; i < tickCount; i++) {
      final double angle = (135 + (270 * i / (tickCount - 1))) * (math.pi / 180);
      final bool isActive = (i / (tickCount - 1)) <= progress;
      final double tickLen = i % 5 == 0 ? 14.0 : 8.0;
      final double tickWidth = i % 5 == 0 ? 2.5 : 1.5;

      final paint = Paint()
        ..color = isActive
            ? AppTheme.emerald.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.1)
        ..strokeWidth = tickWidth
        ..strokeCap = StrokeCap.round;

      final Offset start = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final Offset end = center + Offset(math.cos(angle), math.sin(angle)) * (radius - tickLen);
      canvas.drawLine(start, end, paint);
    }

    // 2. Background arc
    final arcRect = Rect.fromCircle(center: center, radius: radius - 28);
    final bgArcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final startAngle = 135 * (math.pi / 180);
    final sweepAngle = 270 * (math.pi / 180);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, bgArcPaint);

    // 3. Active gradient arc
    if (progress > 0) {
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: const [
          Color(0xFF26C6DA),
          Color(0xFF00ACC1),
          Color(0xFFFFCA28),
          Color(0xFFFF7043),
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
        transform: const GradientRotation(math.pi / 2),
        tileMode: TileMode.clamp,
      );

      final activeArcPaint = Paint()
        ..shader = gradient.createShader(arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(arcRect, startAngle, sweepAngle * progress, false, activeArcPaint);

      // 4. Knob at end of arc
      final currentAngle = startAngle + (sweepAngle * progress);
      final knobCenter = center + Offset(math.cos(currentAngle), math.sin(currentAngle)) * (radius - 28);

      // Glow
      canvas.drawCircle(
        knobCenter,
        12,
        Paint()
          ..color = AppTheme.emerald.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Knob body
      canvas.drawCircle(knobCenter, 7, Paint()..color = Colors.white);
      canvas.drawCircle(
        knobCenter,
        5,
        Paint()
          ..color = AppTheme.emerald
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EnhancedGaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isHeaterOn != isHeaterOn;
}
