import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/insights/domain/services/unified_data_service.dart';
import 'package:smartspoon/core/theme/app_theme.dart';

class HeaterControlPage extends StatefulWidget {
  const HeaterControlPage({super.key});

  @override
  State<HeaterControlPage> createState() => _HeaterControlPageState();
}

class _HeaterControlPageState extends State<HeaterControlPage> with SingleTickerProviderStateMixin {
  // Local UI State
  bool _isHeaterOn = false;
  double _activationTemp = 15.0;
  double _maxTemp = 40.0;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleHeater(bool value) {
    setState(() {
      _isHeaterOn = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final foodTemp = Provider.of<UnifiedDataService>(context).foodTempC;

    // Premium Background Gradient
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Heater Control',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: isDarkMode ? Colors.white : AppTheme.navy,
        ),
        titleTextStyle: TextStyle(
          color: isDarkMode ? Colors.white : AppTheme.navy,
          fontSize: 20,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    const Color(0xFF121212),
                    const Color(0xFF1E1E2C),
                  ]
                : [
                    const Color(0xFFF5F7FA),
                    const Color(0xFFE4E8F0),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // --- Premium Gauge Section ---
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse Effect for Gauge
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.turquoise.withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // The Gauge
                    CustomPaint(
                      size: const Size(260, 260),
                      painter: _PremiumGaugePainter(
                        progress: (foodTemp / 100).clamp(0.0, 1.0),
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    
                    // Center Info
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.thermostat,
                          size: 32,
                          color: AppTheme.gold,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${foodTemp.toStringAsFixed(1)}°C',
                          style: GoogleFonts.outfit(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : AppTheme.navy,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'Food Temp',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white54 : Colors.grey[600],
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 50),
                
                // --- Premium Control Card ---
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDarkMode
                          ? [
                              const Color(0xFF2C2C35),
                              const Color(0xFF25252E),
                            ]
                          : [
                              Colors.white,
                              const Color(0xFFF8FAFC),
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header / Toggle Row
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isHeaterOn
                                    ? AppTheme.turquoise.withValues(alpha: 0.15)
                                    : (isDarkMode ? Colors.white10 : Colors.grey[100]),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.local_fire_department_rounded,
                                color: _isHeaterOn
                                    ? AppTheme.turquoise
                                    : (isDarkMode ? Colors.white38 : Colors.grey),
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
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? Colors.white : AppTheme.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isHeaterOn ? 'Active & Hosting' : 'Inactive',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: _isHeaterOn
                                          ? AppTheme.turquoise
                                          : (isDarkMode ? Colors.white38 : Colors.grey),
                                      fontWeight: FontWeight.w500,
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
                                activeTrackColor: AppTheme.turquoise,
                                inactiveThumbColor: isDarkMode ? Colors.grey[400] : Colors.white,
                                inactiveTrackColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Animated Settings
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 400),
                        firstCurve: Curves.easeOutCubic,
                        secondCurve: Curves.easeInCubic,
                        crossFadeState: _isHeaterOn 
                            ? CrossFadeState.showSecond 
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox(width: double.infinity), // Keeps width consistent
                        secondChild: Column(
                          children: [
                            Divider(
                              height: 1,
                              color: isDarkMode ? Colors.white10 : Colors.grey[200],
                            ),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  _buildPremiumSlider(
                                    title: 'Activation Threshold',
                                    value: _activationTemp,
                                    min: 0,
                                    max: 30,
                                    color: AppTheme.turquoise,
                                    isDarkMode: isDarkMode,
                                    onChanged: (v) => setState(() => _activationTemp = v),
                                  ),
                                  const SizedBox(height: 32),
                                  _buildPremiumSlider(
                                    title: 'Maximum Limit',
                                    value: _maxTemp,
                                    min: 20,
                                    max: 60,
                                    color: AppTheme.gold,
                                    isDarkMode: isDarkMode,
                                    onChanged: (v) => setState(() => _maxTemp = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required Color color,
    required bool isDarkMode,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : AppTheme.navy.withValues(alpha: 0.8),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Text(
                '${value.toInt()}°C', // Simplified to int for cleaner look
                style: GoogleFonts.robotoMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            thumbColor: Colors.white,
            trackHeight: 6.0,
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
          ),
        ),
      ],
    );
  }
}

// --- Custom Painters & Shapes ---

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
      Paint()..color = Colors.black.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // White Center
    canvas.drawCircle(
      center,
      thumbRadius,
      Paint()..color = Colors.white,
    );

    // Colored Ring
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

class _PremiumGaugePainter extends CustomPainter {
  final double progress;
  final bool isDarkMode;

  _PremiumGaugePainter({required this.progress, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    
    // 1. Draw Ticks (Background)
    final tickPaint = Paint()
      ..color = isDarkMode ? Colors.white12 : Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
      
    final activeTickPaint = Paint()
      ..color = AppTheme.turquoise.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const tickCount = 40;
    for (int i = 0; i < tickCount; i++) {
        // Start from -225 deg (bottom leftish) to +45 deg (bottom rightish)
        // Actually typical gauge is -225 to -315... let's do a 270 degree arc starting from 135 to 405
        // Standard gauge: 135 degrees (bottom left) to 405 degrees (bottom right)
        
        final double angle = (135 + (270 * i / (tickCount - 1))) * (math.pi / 180);
        final bool isActive = (i / (tickCount - 1)) <= progress;
        
        final double tickLen = i % 5 == 0 ? 12.0 : 8.0;
        final Offset start = center + Offset(math.cos(angle), math.sin(angle)) * radius;
        final Offset end = center + Offset(math.cos(angle), math.sin(angle)) * (radius - tickLen);
        
        canvas.drawLine(start, end, isActive ? activeTickPaint : tickPaint);
    }

    // 2. Draw Arc Background
    final arcRect = Rect.fromCircle(center: center, radius: radius - 25);
    final bgArcPaint = Paint()
      ..color = isDarkMode ? Colors.white10 : Colors.grey.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final startAngle = 135 * (math.pi / 180);
    final sweepAngle = 270 * (math.pi / 180);

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, bgArcPaint);

    // 3. Draw Active Gradient Arc
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: const [
        Color(0xFF26C6DA), // Turquoise
        Color(0xFF00ACC1), // Darker Turquoise
        Color(0xFFFFCA28), // Gold/Amber (getting hot)
        Color(0xFFFF7043), // Orange (Hot)
      ],
      stops: const [0.0, 0.4, 0.7, 1.0],
      transform: GradientRotation(math.pi / 2), // Rotate gradient to match arc roughly
      tileMode: TileMode.clamp
    );

    // We can't apply GradientRotation easily to line up perfectly with a 270deg arc starting at 135.
    // Instead, using a Shader directly is better. 
    // Simplified: Just use a solid color or simple linear gradient for now to be safe,
    // or use createShader.
    
    final activeArcPaint = Paint()
      ..shader = gradient.createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    // Mask the gradient only to the progress
    canvas.drawArc(arcRect, startAngle, sweepAngle * progress, false, activeArcPaint);
    
    // 4. Knob at the end of the arc
    // Angle at current progress
    final currentAngle = startAngle + (sweepAngle * progress);
    final knobCenter = center + Offset(math.cos(currentAngle), math.sin(currentAngle)) * (radius - 25);
    
    // Glow behind knob
    canvas.drawCircle(
      knobCenter, 
      10, 
      Paint()..color = AppTheme.turquoise.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
    );
    
    // Knob body
    canvas.drawCircle(knobCenter, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PremiumGaugePainter oldDelegate) =>
      progress != oldDelegate.progress || isDarkMode != oldDelegate.isDarkMode;
}
