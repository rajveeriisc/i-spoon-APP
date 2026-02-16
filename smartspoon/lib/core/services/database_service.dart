import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/meal.dart';
import '../models/bite.dart';
// import '../models/temperature_log.dart'; // Removed: unused

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smartspoon.db');

    return await openDatabase(
      path,
      version: 5, // Bumped to remove weight_grams from bites table
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    if (kDebugMode) {
      print('Creating local database tables...');
    }

    // Meals Table
    await db.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE,
        server_id INTEGER,
        user_id TEXT,
        device_id TEXT,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        meal_type TEXT,
        total_bites INTEGER DEFAULT 0,
        avg_pace_bpm REAL,
        tremor_index INTEGER,
        duration_minutes REAL,
        avg_food_temp_c REAL,
        max_food_temp_c REAL,
        min_food_temp_c REAL,
        is_synced INTEGER DEFAULT 0,
        dirty INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // Devices Table
    await db.execute('''
      CREATE TABLE devices (
        id TEXT PRIMARY KEY, 
        user_id TEXT,
        mac_address_hash TEXT,
        firmware_version TEXT,
        last_sync_at TEXT,
        health_metrics TEXT,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // Daily Analytics Table
    await db.execute('''
      CREATE TABLE daily_analytics (
        user_id TEXT,
        date TEXT,
        total_bites INTEGER DEFAULT 0,
        avg_tremor_magnitude REAL,
        max_tremor_magnitude REAL,
        avg_tremor_frequency REAL,
        meal_breakdown TEXT,
        tremor_distribution TEXT,
        total_eating_duration_min REAL,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, date)
      )
    ''');

    // Bites Table
    await db.execute('''
      CREATE TABLE bites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_uuid TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        tremor_magnitude REAL,
        tremor_frequency REAL,
        is_valid INTEGER DEFAULT 1,
        sequence_number INTEGER,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (meal_uuid) REFERENCES meals (uuid) ON DELETE CASCADE
      )
    ''');
    
    // Index for faster queries
    await db.execute('CREATE INDEX idx_bites_meal_uuid ON bites(meal_uuid)');

    // Daily Bite Breakdown Table
    await db.execute('''
      CREATE TABLE daily_bite_breakdown (
        user_id TEXT,
        date TEXT,
        breakfast INTEGER DEFAULT 0,
        lunch INTEGER DEFAULT 0,
        dinner INTEGER DEFAULT 0,
        snacks INTEGER DEFAULT 0,
        total_bites INTEGER DEFAULT 0,
        avg_pace_bpm REAL,
        total_duration_min REAL,
        avg_meal_duration_min REAL,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, date)
      )
    ''');
    
    await db.execute('CREATE INDEX idx_daily_bite_breakdown_date ON daily_bite_breakdown(date DESC)');

    // Daily Tremor Breakdown Table
    await db.execute('''
      CREATE TABLE daily_tremor_breakdown (
        user_id TEXT,
        date TEXT,
        avg_magnitude REAL,
        peak_magnitude REAL,
        min_magnitude REAL,
        avg_frequency_hz REAL,
        dominant_level TEXT,
        level_value INTEGER,
        total_tremor_events INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, date)
      )
    ''');
    
    await db.execute('CREATE INDEX idx_daily_tremor_breakdown_date ON daily_tremor_breakdown(date DESC)');

    // Temperature Logs Table REMOVED per user request (storing stats in meals instead)
    
    if (kDebugMode) {
      print('Database tables created successfully');
    }
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) {
      print('Upgrading database from version $oldVersion to $newVersion');
    }
    
    // For version 2, 3, or 4: Drop all tables and recreate to ensure clean state
    if (newVersion >= 2) {
      await db.execute('DROP TABLE IF EXISTS daily_tremor_breakdown');
      await db.execute('DROP TABLE IF EXISTS daily_bite_breakdown');
      await db.execute('DROP TABLE IF EXISTS bites');
      await db.execute('DROP TABLE IF EXISTS meals');
      await db.execute('DROP TABLE IF EXISTS devices');
      await db.execute('DROP TABLE IF EXISTS daily_analytics');
      
      // Recreate all tables
      await _createDb(db, newVersion);
      
      if (kDebugMode) {
        print('Database reset complete. Tables recreated with version $newVersion schema.');
      }
    }
  }
  
  // ========================================================================
  // MEAL OPERATIONS
  // ========================================================================

  Future<int> insertMeal(Meal meal) async {
    final db = await database;
    return await db.insert(
      'meals',
      meal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateMeal(Meal meal) async {
    final db = await database;
    return await db.update(
      'meals',
      meal.toMap(),
      where: 'uuid = ?',
      whereArgs: [meal.uuid],
    );
  }

  Future<Meal?> getMeal(String uuid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meals',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    if (maps.isNotEmpty) {
      return Meal.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Meal>> getMeals({int limit = 20, int offset = 0}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meals',
      orderBy: 'started_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((e) => Meal.fromMap(e)).toList();
  }
  
  Future<List<Meal>> getUnsyncedMeals() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meals',
      where: 'is_synced = 0',
    );
    return maps.map((e) => Meal.fromMap(e)).toList();
  }

  Future<int> markMealSynced(String uuid, int serverId) async {
    final db = await database;
    return await db.update(
      'meals',
      {'is_synced': 1, 'server_id': serverId, 'dirty': 0},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ========================================================================
  // BITE OPERATIONS
  // ========================================================================

  Future<int> insertBite(Bite bite) async {
    final db = await database;
    return await db.insert(
      'bites',
      bite.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<void> insertBites(List<Bite> bites) async {
    final db = await database;
    final batch = db.batch();
    for (var bite in bites) {
      batch.insert(
        'bites',
        bite.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Bite>> getBitesForMeal(String mealUuid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bites',
      where: 'meal_uuid = ?',
      whereArgs: [mealUuid],
      orderBy: 'timestamp ASC',
    );
    return maps.map((e) => Bite.fromMap(e)).toList();
  }
  
  Future<List<Bite>> getUnsyncedBites({int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'bites',
      where: 'is_synced = 0',
      limit: limit,
    );
    return maps.map((e) => Bite.fromMap(e)).toList();
  }
  
  Future<void> markBitesSynced(List<int> ids) async {
    final db = await database;
    final batch = db.batch();
    for (var id in ids) {
      batch.update(
        'bites',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ========================================================================
  // ANALYTICS OPERATIONS
  // ========================================================================

  Future<List<Map<String, dynamic>>> getDailyTremorStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    
    // Aggregate bite-level tremor data by day with level counts
    // Classify tremor levels: Low (<0.6), Moderate (0.6-1.4), High (>1.4)
    return await db.rawQuery('''
      SELECT 
        substr(m.started_at, 1, 10) as date,
        AVG(b.tremor_frequency) as avg_frequency,
        AVG(b.tremor_magnitude) as avg_magnitude,
        MAX(b.tremor_magnitude) as peak_magnitude,
        COUNT(b.id) as sample_count,
        SUM(CASE WHEN b.tremor_magnitude < 0.6 THEN 1 ELSE 0 END) as low_count,
        SUM(CASE WHEN b.tremor_magnitude >= 0.6 AND b.tremor_magnitude < 1.4 THEN 1 ELSE 0 END) as moderate_count,
        SUM(CASE WHEN b.tremor_magnitude >= 1.4 THEN 1 ELSE 0 END) as high_count
      FROM meals m
      JOIN bites b ON b.meal_uuid = m.uuid
      WHERE m.started_at >= ? AND m.started_at <= ?
        AND b.tremor_frequency > 0
      GROUP BY substr(m.started_at, 1, 10)
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getMealTypeTremorStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    
    return await db.rawQuery('''
      SELECT 
        substr(m.started_at, 1, 10) as date,
        m.meal_type as meal_type,
        AVG(b.tremor_frequency) as avg_frequency,
        AVG(b.tremor_magnitude) as avg_magnitude,
        MAX(b.tremor_magnitude) as peak_magnitude,
        COUNT(b.id) as sample_count,
        SUM(CASE WHEN b.tremor_magnitude < 0.6 THEN 1 ELSE 0 END) as low_count,
        SUM(CASE WHEN b.tremor_magnitude >= 0.6 AND b.tremor_magnitude < 1.4 THEN 1 ELSE 0 END) as moderate_count,
        SUM(CASE WHEN b.tremor_magnitude >= 1.4 THEN 1 ELSE 0 END) as high_count
      FROM meals m
      JOIN bites b ON b.meal_uuid = m.uuid
      WHERE m.started_at >= ? AND m.started_at <= ?
        AND b.tremor_frequency > 0
      GROUP BY substr(m.started_at, 1, 10), m.meal_type
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  // ========================================================================
  // TEMPERATURE OPERATIONS - DEPRECATED (Avg stored in Meal)
  // ========================================================================

  // Methods removed to reflect schema change
  
  // Helper to clear database (for testing/debugging)
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('temperature_logs');
    await db.delete('bites');
    await db.delete('meals');
  }
}
