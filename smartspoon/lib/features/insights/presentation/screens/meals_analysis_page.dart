import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartspoon/features/insights/application/insights_controller.dart';
import 'package:smartspoon/features/insights/domain/models.dart';
import 'package:smartspoon/features/insights/domain/services/unified_data_service.dart';
import 'package:smartspoon/core/theme/app_theme.dart';
import 'package:smartspoon/core/widgets/premium_header.dart';
import 'package:smartspoon/core/widgets/premium_widgets.dart';
import 'package:smartspoon/core/widgets/geometric_background.dart';

class MealsAnalysisPage extends StatefulWidget {
  const MealsAnalysisPage({super.key});

  @override
  State<MealsAnalysisPage> createState() => _MealsAnalysisPageState();
}

class _MealsAnalysisPageState extends State<MealsAnalysisPage> {
  final DateTime _today = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

  late DateTime _selectedDate;
  List<DateTime> _dates = [];
  late Future<List<MealSummary>> _mealsFuture;

  // Track last session state so we re-fetch when session ends
  bool _wasSessionActive = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _today;
    _dates = List.generate(7, (i) => _today.subtract(Duration(days: i)));
    _fetchMeals();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch from DB when session ends (active → inactive transition)
    final isActive = context.read<UnifiedDataService>().isSessionActive;
    if (_wasSessionActive && !isActive) {
      _fetchMeals();
    }
    _wasSessionActive = isActive;
  }

  void _fetchMeals() {
    _mealsFuture =
        context.read<InsightsController>().getMealsForDate(_selectedDate);
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _fetchMeals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;

    // Responsive scale factor: 1.0 on ~390px (iPhone 14), scales on larger/smaller
    final scale = (sw / 390).clamp(0.8, 1.3);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background
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
                const PremiumHeader(
                  title: 'Meals Analysis',
                  subtitle: 'Daily meal breakdown',
                ),

                // ── 7-Day Date Scroller ──────────────────────────────────
                SizedBox(
                  height: (68 * scale).clamp(56, 90),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: sw * 0.04,
                      vertical: 8,
                    ),
                    itemCount: _dates.length,
                    itemBuilder: (context, i) {
                      final d = _dates[i];
                      final isSelected = d == _selectedDate;
                      final isToday = d == _today;

                      return GestureDetector(
                        onTap: () => _selectDate(d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.only(right: sw * 0.025),
                          padding: EdgeInsets.symmetric(
                            horizontal: (14 * scale).clamp(10, 20),
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.emerald
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.emerald
                                  : Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isToday ? 'Today' : _weekday(d),
                                style: GoogleFonts.manrope(
                                  fontSize: (10 * scale).clamp(9, 13),
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                ),
                              ),
                              SizedBox(height: 2 * scale),
                              Text(
                                '${d.day}',
                                style: GoogleFonts.manrope(
                                  fontSize: (15 * scale).clamp(13, 20),
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Meal Content ─────────────────────────────────────────
                Expanded(
                  child: Consumer<UnifiedDataService>(
                    builder: (context, dataService, _) {
                      // Detect session end → re-fetch completed meal from DB
                      if (_wasSessionActive && !dataService.isSessionActive) {
                        _wasSessionActive = false;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _fetchMeals());
                        });
                      } else {
                        _wasSessionActive = dataService.isSessionActive;
                      }

                      return FutureBuilder<List<MealSummary>>(
                        future: _mealsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.emerald),
                            );
                          }

                          // Completed meals from DB
                          final dbMeals = snapshot.data ?? [];

                          // Inject live session card at the top when today is selected
                          final isToday = _selectedDate == _today;
                          final List<MealSummary> meals = [...dbMeals];

                          MealSummary? liveSession;
                          final liveBites = dataService.totalBites;
                          if (isToday && liveBites > 0 && (dataService.isSessionActive || liveBites > 0)) {
                            final durationMin = dataService.avgBiteTime > 0 && liveBites > 0
                                ? (liveBites * dataService.avgBiteTime / 60.0)
                                : 0.0;
                            liveSession = MealSummary(
                              totalBites: liveBites,
                              eatingPaceBpm: dataService.eatingSpeedBpm,
                              tremorIndex:
                                  (dataService.tremorIndex * 33).round(),
                              lastMealStart: DateTime.now(),
                              mealType: dataService.currentMealType ?? 'In Progress',
                              durationMinutes: durationMin,
                            );
                          }

                          return SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: (sw * 0.05).clamp(16, 32),
                              vertical: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Live session banner
                                if (liveSession != null) ...[
                                  _LiveSessionCard(
                                    bites: liveSession.totalBites,
                                    bpm: liveSession.eatingPaceBpm,
                                    scale: scale,
                                  ),
                                  SizedBox(height: 12 * scale),
                                ],

                                // Summary cards (DB meals only)
                                _buildSummaryCards(meals, scale, sw),
                                SizedBox(height: 20 * scale),

                                // Section heading
                                Text(
                                  meals.isEmpty
                                      ? 'No completed meals today'
                                      : '${meals.length} completed meal${meals.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.manrope(
                                    fontSize: (17 * scale).clamp(14, 22),
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                SizedBox(height: 12 * scale),

                                // Empty state
                                if (meals.isEmpty && liveSession == null)
                                  PremiumGlassCard(
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Padding(
                                        padding: EdgeInsets.all(36 * scale),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.no_food_outlined,
                                              size:
                                                  (44 * scale).clamp(32, 60),
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.25),
                                            ),
                                            SizedBox(height: 14 * scale),
                                            Text(
                                              'No meals recorded for this day',
                                              style: GoogleFonts.manrope(
                                                fontSize: (14 * scale)
                                                    .clamp(12, 18),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 6 * scale),
                                            Text(
                                              'Try selecting a different day above',
                                              style: GoogleFonts.manrope(
                                                fontSize: (12 * scale)
                                                    .clamp(10, 15),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.35),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ...meals.map((meal) => Padding(
                                        padding: EdgeInsets.only(
                                            bottom: 10 * scale),
                                        child: _MealCard(
                                            meal: meal, scale: scale),
                                      )),

                                SizedBox(height: 20 * scale),
                                _buildInfoCard(scale),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _weekday(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  Widget _buildSummaryCards(
      List<MealSummary> meals, double scale, double sw) {
    // Sum from DB meals
    int totalBites =
        meals.fold(0, (s, m) => s + m.totalBites);
    double avgSpeed = meals.isEmpty
        ? 0.0
        : meals.fold(0.0, (s, m) => s + m.eatingPaceBpm) / meals.length;
    int totalDuration =
        meals.fold(0, (s, m) => s + (m.durationMinutes ?? 0).toInt());

    // If viewing today, overlay live hardware bite data on top
    if (_selectedDate == _today) {
      final dataService = context.read<UnifiedDataService>();
      final liveBites = dataService.totalBites;
      if (liveBites > totalBites) {
        totalBites = liveBites;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            label: 'Total Bites',
            value: '$totalBites',
            icon: Icons.restaurant,
            color: AppTheme.emerald,
            scale: scale,
          ),
        ),
        SizedBox(width: sw * 0.03),
        Expanded(
          child: _SummaryItem(
            label: 'Avg Speed',
            value: avgSpeed.toStringAsFixed(1),
            unit: 'bpm',
            icon: Icons.speed,
            color: const Color(0xFFFFA726),
            scale: scale,
          ),
        ),
        SizedBox(width: sw * 0.03),
        Expanded(
          child: _SummaryItem(
            label: 'Duration',
            value: '$totalDuration',
            unit: 'min',
            icon: Icons.timer,
            color: const Color(0xFF42A5F5),
            scale: scale,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(double scale) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.emerald,
              size: (18 * scale).clamp(14, 24)),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Text(
              'Speed is measured in bites per minute. A steady pace aids better digestion.',
              style: GoogleFonts.manrope(
                fontSize: (12 * scale).clamp(10, 15),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live Session Banner ────────────────────────────────────────────────────────

class _LiveSessionCard extends StatelessWidget {
  final int bites;
  final double bpm;
  final double scale;

  const _LiveSessionCard({
    required this.bites,
    required this.bpm,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Pulsing dot
          Container(
            width: 10 * scale,
            height: 10 * scale,
            decoration: const BoxDecoration(
              color: AppTheme.emerald,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Text(
              'Session in progress',
              style: GoogleFonts.manrope(
                fontSize: (13 * scale).clamp(11, 17),
                fontWeight: FontWeight.w600,
                color: AppTheme.emerald,
              ),
            ),
          ),
          Text(
            '$bites bites',
            style: GoogleFonts.manrope(
              fontSize: (15 * scale).clamp(13, 20),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (bpm > 0) ...[
            SizedBox(width: 8 * scale),
            Text(
              '${bpm.toStringAsFixed(1)} bpm',
              style: GoogleFonts.manrope(
                fontSize: (11 * scale).clamp(9, 14),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;
  final double scale;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: (18 * scale).clamp(14, 26)),
            SizedBox(height: 6 * scale),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.manrope(
                      fontSize: (18 * scale).clamp(13, 26),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (unit != null) ...[
                    SizedBox(width: 2 * scale),
                    Text(
                      unit!,
                      style: GoogleFonts.manrope(
                        fontSize: (9 * scale).clamp(8, 13),
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: (9 * scale).clamp(8, 12),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Meal Card ─────────────────────────────────────────────────────────────────

class _MealCard extends StatelessWidget {
  final MealSummary meal;
  final double scale;

  const _MealCard({required this.meal, required this.scale});

  IconData _icon(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_twilight;
      case 'lunch':
        return Icons.wb_sunny;
      case 'dinner':
        return Icons.nights_stay_outlined;
      default:
        return Icons.local_dining;
    }
  }

  Color _speedColor(double bpm) {
    if (bpm < 4) return Colors.green;
    if (bpm < 8) return Colors.orange;
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final type = meal.mealType ?? 'Meal';
    final start = meal.lastMealStart;
    final timeStr = start != null
        ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
        : '';

    final iconBoxSize = (40 * scale).clamp(32.0, 56.0);

    return PremiumGlassCard(
      child: Row(
        children: [
          // Meal type icon
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Icon(_icon(type), color: AppTheme.emerald,
                size: (20 * scale).clamp(16, 28)),
          ),
          SizedBox(width: 12 * scale),

          // Title + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: (14 * scale).clamp(12, 18),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 3 * scale),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: (11 * scale).clamp(9, 15),
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                    SizedBox(width: 3 * scale),
                    Flexible(
                      child: Text(
                        '${(meal.durationMinutes ?? 0).toInt()} min'
                        '${timeStr.isNotEmpty ? ' · $timeStr' : ''}',
                        style: GoogleFonts.manrope(
                          fontSize: (11 * scale).clamp(9, 14),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(width: 8 * scale),

          // Bites + speed badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${meal.totalBites} bites',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: (13 * scale).clamp(11, 17),
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 4 * scale),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 7 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  color:
                      _speedColor(meal.eatingPaceBpm).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${meal.eatingPaceBpm.toStringAsFixed(1)} bpm',
                  style: GoogleFonts.manrope(
                    fontSize: (9 * scale).clamp(8, 12),
                    fontWeight: FontWeight.bold,
                    color: _speedColor(meal.eatingPaceBpm),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
