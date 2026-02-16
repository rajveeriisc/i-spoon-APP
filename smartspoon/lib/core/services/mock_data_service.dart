import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../core/models/meal.dart';
import '../../core/models/bite.dart';
import '../../core/services/database_service.dart';
import 'package:flutter/foundation.dart';

class MockDataService {
  final DatabaseService _db = DatabaseService();
  final Random _rnd = Random();
  final Uuid _uuid = const Uuid();

  Future<void> seedDatabase({int days = 90, bool forceReseed = false}) async {
    // Check if data exists first to avoid double seeding
    final existing = await _db.getMeals(limit: 1);
    if (existing.isNotEmpty && !forceReseed) {
      if (kDebugMode) print('Database already contains data. Skipping seed. (Use forceReseed=true to override)');
      return;
    }
    
    // Clear existing data if force reseeding
    if (forceReseed && existing.isNotEmpty) {
      if (kDebugMode) print('Force reseeding: Clearing existing data...');
      // Note: You may want to add a clearAll() method to DatabaseService
    }

    if (kDebugMode) print('Seeding database with $days days of mock data...');
    final now = DateTime.now();
    final List<Meal> meals = [];
    final List<Bite> bites = [];

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      
      // Simulate 3 meals per day
      _generateMeal(date, 'Breakfast', 8, meals, bites);
      _generateMeal(date, 'Lunch', 13, meals, bites);
      _generateMeal(date, 'Dinner', 20, meals, bites);
      
      // Random snack
      if (_rnd.nextBool()) {
        _generateMeal(date, 'Snacks', 16, meals, bites);
      }
    }

    // Insert Meals
    for (var meal in meals) {
      await _db.insertMeal(meal);
    }
    
    // Insert Bites (Batch)
    // Batch insert might be too large for SQLite in one go, split it
    int batchSize = 100;
    for (int i = 0; i < bites.length; i += batchSize) {
      final end = (i + batchSize < bites.length) ? i + batchSize : bites.length;
      await _db.insertBites(bites.sublist(i, end));
    }

    if (kDebugMode) print('Seeding complete: ${meals.length} meals, ${bites.length} bites.');
  }

  void _generateMeal(DateTime date, String type, int hour, List<Meal> meals, List<Bite> bites) {
    // Randomize time slightly
    final start = DateTime(date.year, date.month, date.day, hour, _rnd.nextInt(60));
    final durationMin = 10 + _rnd.nextDouble() * 20; // 10-30 mins
    final end = start.add(Duration(minutes: durationMin.toInt()));
    
    final mealUuid = _uuid.v4();
    final biteCount = 15 + _rnd.nextInt(25); // 15-40 bites
    
    // Tremor: varied per day to show trends
    // Make tremor worse on some days
    final baseTremor = 20 + _rnd.nextInt(30); 
    final tremorIndex = baseTremor + (date.day % 7 == 0 ? 20 : 0); // Spikes once a week

    // Avg Temp: 30-50C
    final avgTemp = 35.0 + _rnd.nextDouble() * 15.0;

    final meal = Meal(
      uuid: mealUuid,
      userId: 'current_user',
      startedAt: start,
      endedAt: end,
      mealType: type,
      totalBites: biteCount,
      durationMinutes: durationMin,
      avgPaceBpm: biteCount / durationMin,
      tremorIndex: tremorIndex,
      avgFoodTemp: avgTemp,
      isSynced: _rnd.nextBool(), // Random sync status
    );

    meals.add(meal);

    // Generate Bites
    for (int k = 0; k < biteCount; k++) {
      // time distribution
      final biteTime = start.add(Duration(seconds: (durationMin * 60 * (k / biteCount)).toInt()));
      
      bites.add(Bite(
        mealUuid: mealUuid,
        timestamp: biteTime,
        tremorMagnitude: (tremorIndex / 20.0) + (_rnd.nextDouble() * 0.5), // Correlation
        tremorFrequency: 4.0 + _rnd.nextDouble() * 3.0,
        sequenceNumber: k,
        isSynced: meal.isSynced,
      ));
    }
  }
}
