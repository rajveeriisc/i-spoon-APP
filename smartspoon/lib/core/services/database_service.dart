import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/meal.dart';
import '../models/bite.dart';

/// Local SQLite database — v7 optimized schema.
///
/// Tables:
///   meals             — one row per eating session
///   bites             — one row per detected bite (with tremor + temp readings)
///   daily_summaries   — pre-aggregated per-day cache (replaces daily_analytics,
///                       daily_bite_breakdown, daily_tremor_breakdown)
///   devices           — cached BLE device info
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
      version: 8, // v8: guaranteed daily_summaries on all devices
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  // ==========================================================================
  // SCHEMA CREATION (fresh install)
  // ==========================================================================

  Future<void> _createDb(Database db, int version) async {
    if (kDebugMode) debugPrint('[DB] Creating v7 schema...');

    // -- meals --
    await db.execute('''
      CREATE TABLE meals (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid            TEXT    UNIQUE NOT NULL,
        server_id       INTEGER,
        user_id         TEXT    NOT NULL,
        device_id       TEXT,
        started_at      TEXT    NOT NULL,
        ended_at        TEXT,
        meal_type       TEXT,
        total_bites     INTEGER DEFAULT 0,
        avg_pace_bpm    REAL,
        tremor_index    INTEGER DEFAULT 0,
        duration_minutes REAL,
        avg_food_temp_c REAL,
        is_synced       INTEGER DEFAULT 0,
        dirty           INTEGER DEFAULT 0,
        created_at      TEXT    DEFAULT (datetime('now')),
        updated_at      TEXT    DEFAULT (datetime('now'))
      )
    ''');
    await db.execute('CREATE INDEX idx_meals_started ON meals(started_at DESC)');

    // -- bites --
    await db.execute('''
      CREATE TABLE bites (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_uuid       TEXT    NOT NULL REFERENCES meals(uuid) ON DELETE CASCADE,
        timestamp       TEXT    NOT NULL,
        sequence_number INTEGER,
        tremor_magnitude REAL,
        tremor_frequency REAL,
        food_temp_c     REAL,
        is_valid        INTEGER DEFAULT 1,
        is_synced       INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_bites_meal  ON bites(meal_uuid)');
    await db.execute('CREATE INDEX idx_bites_time  ON bites(timestamp DESC)');

    // -- daily_summaries (replaces daily_analytics + daily_bite_breakdown + daily_tremor_breakdown) --
    await db.execute('''
      CREATE TABLE daily_summaries (
        user_id              TEXT,
        date                 TEXT,
        total_bites          INTEGER DEFAULT 0,
        total_eating_min     REAL    DEFAULT 0,
        breakfast_bites      INTEGER DEFAULT 0,
        lunch_bites          INTEGER DEFAULT 0,
        dinner_bites         INTEGER DEFAULT 0,
        snack_bites          INTEGER DEFAULT 0,
        avg_tremor_magnitude REAL    DEFAULT 0,
        avg_tremor_frequency REAL    DEFAULT 0,
        tremor_low_count     INTEGER DEFAULT 0,
        tremor_moderate_count INTEGER DEFAULT 0,
        tremor_high_count    INTEGER DEFAULT 0,
        avg_food_temp_c      REAL    DEFAULT 0,
        updated_at           TEXT    DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, date)
      )
    ''');
    await db.execute('CREATE INDEX idx_daily_date ON daily_summaries(date DESC)');

    // -- devices (cached BLE device registry) --
    await db.execute('''
      CREATE TABLE devices (
        id              TEXT PRIMARY KEY,
        user_id         TEXT,
        mac_address_hash TEXT,
        firmware_version TEXT,
        heater_active   INTEGER DEFAULT 0,
        heater_activation_temp REAL DEFAULT 15.0,
        heater_max_temp REAL DEFAULT 40.0,
        last_sync_at    TEXT,
        created_at      TEXT DEFAULT (datetime('now')),
        updated_at      TEXT DEFAULT (datetime('now'))
      )
    ''');

    if (kDebugMode) debugPrint('[DB] v7 schema created successfully.');
  }

  // ==========================================================================
  // MIGRATIONS (existing installs)
  // ==========================================================================

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (kDebugMode) debugPrint('[DB] Upgrading $oldVersion → $newVersion');

    // v2: daily_bite_breakdown + daily_tremor_breakdown
    if (oldVersion < 2) {
      await _safeExec(db, '''
        CREATE TABLE IF NOT EXISTS daily_bite_breakdown (
          user_id TEXT, date TEXT,
          breakfast INTEGER DEFAULT 0, lunch INTEGER DEFAULT 0,
          dinner INTEGER DEFAULT 0, snacks INTEGER DEFAULT 0,
          total_bites INTEGER DEFAULT 0, avg_pace_bpm REAL,
          total_duration_min REAL, avg_meal_duration_min REAL,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT DEFAULT (datetime('now')),
          updated_at TEXT DEFAULT (datetime('now')),
          PRIMARY KEY (user_id, date)
        )
      ''', 'v2 daily_bite_breakdown');

      await _safeExec(db, '''
        CREATE TABLE IF NOT EXISTS daily_tremor_breakdown (
          user_id TEXT, date TEXT,
          avg_magnitude REAL, avg_frequency_hz REAL,
          dominant_level TEXT, level_value INTEGER,
          total_tremor_events INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT DEFAULT (datetime('now')),
          updated_at TEXT DEFAULT (datetime('now')),
          PRIMARY KEY (user_id, date)
        )
      ''', 'v2 daily_tremor_breakdown');
    }

    // v5: remove weight_grams from bites
    if (oldVersion < 5) {
      final cols = await db.rawQuery('PRAGMA table_info(bites)');
      if (cols.any((c) => c['name'] == 'weight_grams')) {
        await _rebuildBitesTable(db);
      }
    }

    // v6: remove peak_magnitude from daily_tremor_breakdown
    // (no-op if table is replaced in v7 below)

    // v7: merge daily_analytics + daily_bite_breakdown + daily_tremor_breakdown
    //     into single daily_summaries; add food_temp_c to bites
    if (oldVersion < 7) {
      // 1. Create new unified daily_summaries
      await _safeExec(db, '''
        CREATE TABLE IF NOT EXISTS daily_summaries (
          user_id              TEXT,
          date                 TEXT,
          total_bites          INTEGER DEFAULT 0,
          total_eating_min     REAL    DEFAULT 0,
          breakfast_bites      INTEGER DEFAULT 0,
          lunch_bites          INTEGER DEFAULT 0,
          dinner_bites         INTEGER DEFAULT 0,
          snack_bites          INTEGER DEFAULT 0,
          avg_tremor_magnitude REAL    DEFAULT 0,
          avg_tremor_frequency REAL    DEFAULT 0,
          tremor_low_count     INTEGER DEFAULT 0,
          tremor_moderate_count INTEGER DEFAULT 0,
          tremor_high_count    INTEGER DEFAULT 0,
          avg_food_temp_c      REAL    DEFAULT 0,
          updated_at           TEXT    DEFAULT (datetime('now')),
          PRIMARY KEY (user_id, date)
        )
      ''', 'v7 create daily_summaries');

      await _safeExec(db,
        'CREATE INDEX IF NOT EXISTS idx_daily_date ON daily_summaries(date DESC)',
        'v7 index daily_summaries');

      // 2. Migrate from daily_bite_breakdown (bites & duration data)
      await _safeExec(db, '''
        INSERT OR IGNORE INTO daily_summaries
          (user_id, date, total_bites, total_eating_min,
           breakfast_bites, lunch_bites, dinner_bites, snack_bites)
        SELECT
          user_id, date, total_bites,
          COALESCE(total_duration_min, 0),
          COALESCE(breakfast, 0), COALESCE(lunch, 0),
          COALESCE(dinner, 0),   COALESCE(snacks, 0)
        FROM daily_bite_breakdown
      ''', 'v7 migrate daily_bite_breakdown');

      // 3. Migrate tremor data from daily_tremor_breakdown
      await _safeExec(db, '''
        UPDATE daily_summaries
        SET
          avg_tremor_magnitude = (
            SELECT COALESCE(dtb.avg_magnitude, 0)
            FROM daily_tremor_breakdown dtb
            WHERE dtb.user_id = daily_summaries.user_id
              AND dtb.date    = daily_summaries.date
          ),
          avg_tremor_frequency = (
            SELECT COALESCE(dtb.avg_frequency_hz, 0)
            FROM daily_tremor_breakdown dtb
            WHERE dtb.user_id = daily_summaries.user_id
              AND dtb.date    = daily_summaries.date
          )
        WHERE EXISTS (
          SELECT 1 FROM daily_tremor_breakdown dtb
          WHERE dtb.user_id = daily_summaries.user_id
            AND dtb.date    = daily_summaries.date
        )
      ''', 'v7 migrate tremor into daily_summaries');

      // 4. Add food_temp_c to bites (SQLite ALTER TABLE ADD COLUMN is safe)
      final biteCols = await db.rawQuery('PRAGMA table_info(bites)');
      if (!biteCols.any((c) => c['name'] == 'food_temp_c')) {
        await _safeExec(db,
          'ALTER TABLE bites ADD COLUMN food_temp_c REAL',
          'v7 add food_temp_c to bites');
      }

      // 5. Add heater columns to devices if missing
      final devCols = await db.rawQuery('PRAGMA table_info(devices)');
      if (!devCols.any((c) => c['name'] == 'heater_active')) {
        await _safeExec(db, 'ALTER TABLE devices ADD COLUMN heater_active INTEGER DEFAULT 0', 'v7 heater_active');
        await _safeExec(db, 'ALTER TABLE devices ADD COLUMN heater_activation_temp REAL DEFAULT 15.0', 'v7 heater_activation_temp');
        await _safeExec(db, 'ALTER TABLE devices ADD COLUMN heater_max_temp REAL DEFAULT 40.0', 'v7 heater_max_temp');
      }

      // 6. Drop old redundant tables
      await _safeExec(db, 'DROP TABLE IF EXISTS daily_bite_breakdown',   'v7 drop daily_bite_breakdown');
      await _safeExec(db, 'DROP TABLE IF EXISTS daily_tremor_breakdown', 'v7 drop daily_tremor_breakdown');
      await _safeExec(db, 'DROP TABLE IF EXISTS daily_analytics',        'v7 drop daily_analytics');
      await _safeExec(db, 'DROP TABLE IF EXISTS temperature_logs',       'v7 drop temperature_logs');
    }

    // v8: idempotent safety pass — ensures daily_summaries always exists.
    //     Handles devices where v7 migration silently failed via _safeExec.
    if (oldVersion < 8) {
      await _safeExec(db, '''
        CREATE TABLE IF NOT EXISTS daily_summaries (
          user_id               TEXT,
          date                  TEXT,
          total_bites           INTEGER DEFAULT 0,
          total_eating_min      REAL    DEFAULT 0,
          breakfast_bites       INTEGER DEFAULT 0,
          lunch_bites           INTEGER DEFAULT 0,
          dinner_bites          INTEGER DEFAULT 0,
          snack_bites           INTEGER DEFAULT 0,
          avg_tremor_magnitude  REAL    DEFAULT 0,
          avg_tremor_frequency  REAL    DEFAULT 0,
          tremor_low_count      INTEGER DEFAULT 0,
          tremor_moderate_count INTEGER DEFAULT 0,
          tremor_high_count     INTEGER DEFAULT 0,
          avg_food_temp_c       REAL    DEFAULT 0,
          updated_at            TEXT    DEFAULT (datetime(\'now\')),
          PRIMARY KEY (user_id, date)
        )
      ''', 'v8 ensure daily_summaries');

      await _safeExec(db,
        'CREATE INDEX IF NOT EXISTS idx_daily_date ON daily_summaries(date DESC)',
        'v8 index daily_summaries');

      // Also ensure food_temp_c exists on bites (idempotent)
      final biteCols = await db.rawQuery('PRAGMA table_info(bites)');
      if (!biteCols.any((c) => c['name'] == 'food_temp_c')) {
        await _safeExec(db,
          'ALTER TABLE bites ADD COLUMN food_temp_c REAL',
          'v8 add food_temp_c to bites');
      }
    }

    if (kDebugMode) debugPrint('[DB] Upgrade complete.');
  }

  // Safe wrapper for migrations — logs errors but doesn't crash
  Future<void> _safeExec(Database db, String sql, String label) async {
    try {
      await db.execute(sql);
    } catch (e) {
      if (kDebugMode) debugPrint('[DB] Migration warning ($label): $e');
    }
  }

  // Rebuilds bites table to remove weight_grams (used by v5 migration)
  Future<void> _rebuildBitesTable(Database db) async {
    await _safeExec(db, 'ALTER TABLE bites RENAME TO bites_old', 'rebuild bites rename');
    await _safeExec(db, '''
      CREATE TABLE bites (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        meal_uuid       TEXT    NOT NULL,
        timestamp       TEXT    NOT NULL,
        sequence_number INTEGER,
        tremor_magnitude REAL,
        tremor_frequency REAL,
        food_temp_c     REAL,
        is_valid        INTEGER DEFAULT 1,
        is_synced       INTEGER DEFAULT 0,
        FOREIGN KEY (meal_uuid) REFERENCES meals(uuid) ON DELETE CASCADE
      )
    ''', 'rebuild bites create');
    await _safeExec(db, '''
      INSERT INTO bites (id, meal_uuid, timestamp, tremor_magnitude, tremor_frequency,
        is_valid, sequence_number, is_synced)
      SELECT id, meal_uuid, timestamp, tremor_magnitude, tremor_frequency,
        is_valid, sequence_number, is_synced
      FROM bites_old
    ''', 'rebuild bites copy');
    await _safeExec(db, 'DROP TABLE bites_old', 'rebuild bites drop old');
    await _safeExec(db, 'CREATE INDEX IF NOT EXISTS idx_bites_meal ON bites(meal_uuid)', 'rebuild bites index');
  }

  // ==========================================================================
  // MEAL OPERATIONS
  // ==========================================================================

  Future<int> insertMeal(Meal meal) async {
    final db = await database;
    return db.insert('meals', meal.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateMeal(Meal meal) async {
    final db = await database;
    return db.update('meals', meal.toMap(), where: 'uuid = ?', whereArgs: [meal.uuid]);
  }

  Future<Meal?> getMeal(String uuid) async {
    final db = await database;
    final rows = await db.query('meals', where: 'uuid = ?', whereArgs: [uuid]);
    return rows.isNotEmpty ? Meal.fromMap(rows.first) : null;
  }

  Future<List<Meal>> getMeals({int limit = 20, int offset = 0}) async {
    final db = await database;
    final rows = await db.query('meals', orderBy: 'started_at DESC', limit: limit, offset: offset);
    return rows.map(Meal.fromMap).toList();
  }

  /// Query meals for a specific date range using SQL (no in-memory scanning).
  /// [start] is inclusive (start of day), [end] is exclusive (start of next day).
  /// Filters by [userId] to prevent cross-user data leakage.
  Future<List<Meal>> getMealsForDateRange(DateTime start, DateTime end,
      {String? userId}) async {
    final db = await database;
    final startStr = start.toIso8601String().substring(0, 10); // YYYY-MM-DD
    final endStr   = end.toIso8601String().substring(0, 10);

    if (userId != null && userId.isNotEmpty) {
      final rows = await db.rawQuery('''
        SELECT * FROM meals
        WHERE user_id = ?
          AND substr(started_at, 1, 10) >= ?
          AND substr(started_at, 1, 10) < ?
        ORDER BY started_at DESC
      ''', [userId, startStr, endStr]);
      return rows.map(Meal.fromMap).toList();
    }

    // Fallback: no userId filter (offline / pre-login edge case)
    final rows = await db.rawQuery('''
      SELECT * FROM meals
      WHERE substr(started_at, 1, 10) >= ? AND substr(started_at, 1, 10) < ?
      ORDER BY started_at DESC
    ''', [startStr, endStr]);
    return rows.map(Meal.fromMap).toList();
  }

  Future<List<Meal>> getUnsyncedMeals() async {
    final db = await database;
    final rows = await db.query('meals', where: 'is_synced = 0');
    return rows.map(Meal.fromMap).toList();
  }

  Future<void> markMealSynced(String uuid, int serverId) async {
    final db = await database;
    await db.update('meals',
      {'is_synced': 1, 'server_id': serverId, 'dirty': 0},
      where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ==========================================================================
  // BITE OPERATIONS
  // ==========================================================================

  Future<int> insertBite(Bite bite) async {
    final db = await database;
    return db.insert('bites', bite.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertBites(List<Bite> bites) async {
    final db = await database;
    final batch = db.batch();
    for (final bite in bites) {
      batch.insert('bites', bite.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Direct count from the `bites` table for a given meal UUID.
  /// Used for real-time UI updates during an active session where no `meals` row exists yet.
  Future<int> countBitesForMeal(String mealUuid) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM bites WHERE meal_uuid = ? AND is_valid = 1',
      [mealUuid],
    );
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  /// Returns live stats for an in-progress meal: bite count + tremor averages.
  /// Computed from the bites table — survives app kill, always accurate.
  /// This is the single source of truth during an active session.
  Future<Map<String, dynamic>> getMealStats(String mealUuid) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*)                                                                     AS total_bites,
        AVG(CASE WHEN tremor_magnitude IS NOT NULL THEN tremor_magnitude END)        AS avg_tremor_magnitude,
        AVG(CASE WHEN tremor_frequency IS NOT NULL THEN tremor_frequency END)        AS avg_tremor_frequency,
        SUM(CASE WHEN tremor_magnitude IS NOT NULL AND tremor_magnitude < 0.6  THEN 1 ELSE 0 END) AS tremor_low,
        SUM(CASE WHEN tremor_magnitude IS NOT NULL AND tremor_magnitude >= 0.6 AND tremor_magnitude < 1.4 THEN 1 ELSE 0 END) AS tremor_moderate,
        SUM(CASE WHEN tremor_magnitude IS NOT NULL AND tremor_magnitude >= 1.4 THEN 1 ELSE 0 END) AS tremor_high,
        AVG(CASE WHEN food_temp_c IS NOT NULL AND food_temp_c > 0 THEN food_temp_c END) AS avg_food_temp
      FROM bites
      WHERE meal_uuid = ? AND is_valid = 1
    ''', [mealUuid]);
    final r = result.first;
    return {
      'total_bites':          (r['total_bites']          as num?)?.toInt()    ?? 0,
      'avg_tremor_magnitude': (r['avg_tremor_magnitude'] as num?)?.toDouble() ?? 0.0,
      'avg_tremor_frequency': (r['avg_tremor_frequency'] as num?)?.toDouble() ?? 0.0,
      'tremor_low':           (r['tremor_low']           as num?)?.toInt()    ?? 0,
      'tremor_moderate':      (r['tremor_moderate']      as num?)?.toInt()    ?? 0,
      'tremor_high':          (r['tremor_high']          as num?)?.toInt()    ?? 0,
      'avg_food_temp':        (r['avg_food_temp']        as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Bite>> getBitesForMeal(String mealUuid) async {
    final db = await database;
    final rows = await db.query('bites',
      where: 'meal_uuid = ?', whereArgs: [mealUuid], orderBy: 'timestamp ASC');
    return rows.map(Bite.fromMap).toList();
  }

  Future<List<Bite>> getUnsyncedBites({int limit = 50}) async {
    final db = await database;
    final rows = await db.query('bites', where: 'is_synced = 0', limit: limit);
    return rows.map(Bite.fromMap).toList();
  }

  /// All unsynced bites for a specific meal — no limit, used by sync service.
  Future<List<Bite>> getUnsyncedBitesForMeal(String mealUuid) async {
    final db = await database;
    final rows = await db.query('bites',
        where: 'meal_uuid = ? AND is_synced = 0', whereArgs: [mealUuid]);
    return rows.map(Bite.fromMap).toList();
  }

  Future<void> markBitesSynced(List<int> ids) async {
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('bites', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  // ==========================================================================
  // DAILY SUMMARIES — rebuild after each meal completes
  // ==========================================================================

  /// Rebuilds (upserts) the daily_summaries row for the given [userId] and [date].
  /// Called by the sync service / meal recording flow when a session ends.
  Future<void> rebuildDailySummary(String userId, DateTime date) async {
    final db      = await database;
    final dateStr = date.toIso8601String().substring(0, 10); // YYYY-MM-DD

    final rows = await db.rawQuery('''
      SELECT
        COUNT(b.id)                                                                  AS total_bites,
        (SELECT COALESCE(SUM(m2.duration_minutes), 0)
         FROM meals m2 WHERE m2.user_id = m.user_id
           AND substr(m2.started_at, 1, 10) = ?)                                     AS total_eating_min,
        SUM(CASE WHEN m.meal_type = 'Breakfast' AND b.id IS NOT NULL THEN 1 ELSE 0 END) AS breakfast_bites,
        SUM(CASE WHEN m.meal_type = 'Lunch'     AND b.id IS NOT NULL THEN 1 ELSE 0 END) AS lunch_bites,
        SUM(CASE WHEN m.meal_type = 'Dinner'    AND b.id IS NOT NULL THEN 1 ELSE 0 END) AS dinner_bites,
        SUM(CASE WHEN m.meal_type = 'Snack'     AND b.id IS NOT NULL THEN 1 ELSE 0 END) AS snack_bites,
        AVG(b.tremor_magnitude)                                                      AS avg_tremor_magnitude,
        AVG(b.tremor_frequency)                                                      AS avg_tremor_frequency,
        SUM(CASE WHEN b.tremor_magnitude < 0.6  THEN 1 ELSE 0 END)                  AS tremor_low_count,
        SUM(CASE WHEN b.tremor_magnitude >= 0.6 AND b.tremor_magnitude < 1.4 THEN 1 ELSE 0 END) AS tremor_moderate_count,
        SUM(CASE WHEN b.tremor_magnitude >= 1.4 THEN 1 ELSE 0 END)                  AS tremor_high_count,
        AVG(b.food_temp_c)                                                           AS avg_food_temp_c
      FROM meals m
      LEFT JOIN bites b ON b.meal_uuid = m.uuid AND b.is_valid = 1
      WHERE m.user_id = ? AND substr(m.started_at, 1, 10) = ?
    ''', [dateStr, userId, dateStr]);

    if (rows.isEmpty) return;
    final r = rows.first;

    await db.insert('daily_summaries', {
      'user_id':               userId,
      'date':                  dateStr,
      'total_bites':           r['total_bites'] ?? 0,
      'total_eating_min':      r['total_eating_min'] ?? 0,
      'breakfast_bites':       r['breakfast_bites'] ?? 0,
      'lunch_bites':           r['lunch_bites'] ?? 0,
      'dinner_bites':          r['dinner_bites'] ?? 0,
      'snack_bites':           r['snack_bites'] ?? 0,
      'avg_tremor_magnitude':  r['avg_tremor_magnitude'] ?? 0,
      'avg_tremor_frequency':  r['avg_tremor_frequency'] ?? 0,
      'tremor_low_count':      r['tremor_low_count'] ?? 0,
      'tremor_moderate_count': r['tremor_moderate_count'] ?? 0,
      'tremor_high_count':     r['tremor_high_count'] ?? 0,
      'avg_food_temp_c':       r['avg_food_temp_c'] ?? 0,
      'updated_at':            DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Fetch daily summaries dynamically directly from the meals table to guarantee 
  /// 100% data consistency (single source of truth).
  Future<List<Map<String, dynamic>>> getDailySummaries({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final db = await database;
      final startStr = start.toIso8601String().substring(0, 10);
      end = end.add(const Duration(days: 1)); // Include current day up to midnight
      final endStr = end.toIso8601String().substring(0, 10);

      // Count bites directly from the bites table (not meals.total_bites which may be 0
      // for old records saved before the auth fix). This is the single source of truth.
      // duration_minutes must be aggregated per distinct meal BEFORE joining bites,
      // otherwise the LEFT JOIN fan-out multiplies each meal's duration by its bite count.
      // We do this with a correlated subquery that sums duration per date independently.
      final rows = await db.rawQuery('''
        SELECT
          substr(m.started_at, 1, 10)                                                      AS date,
          COUNT(b.id)                                                                       AS total_bites,
          (SELECT COALESCE(SUM(m2.duration_minutes), 0)
           FROM meals m2
           WHERE m2.user_id = m.user_id
             AND substr(m2.started_at, 1, 10) = substr(m.started_at, 1, 10))              AS total_eating_min,
          SUM(CASE WHEN m.meal_type = 'Breakfast' AND b.id IS NOT NULL THEN 1 ELSE 0 END)  AS breakfast_bites,
          SUM(CASE WHEN m.meal_type = 'Lunch'     AND b.id IS NOT NULL THEN 1 ELSE 0 END)  AS lunch_bites,
          SUM(CASE WHEN m.meal_type = 'Dinner'    AND b.id IS NOT NULL THEN 1 ELSE 0 END)  AS dinner_bites,
          SUM(CASE WHEN m.meal_type = 'Snack'     AND b.id IS NOT NULL THEN 1 ELSE 0 END)  AS snack_bites,
          AVG(b.tremor_magnitude)                                                           AS avg_tremor_magnitude,
          AVG(b.tremor_frequency)                                                           AS avg_tremor_frequency,
          SUM(CASE WHEN b.tremor_magnitude < 0.6  THEN 1 ELSE 0 END)                       AS tremor_low_count,
          SUM(CASE WHEN b.tremor_magnitude >= 0.6 AND b.tremor_magnitude < 1.4 THEN 1 ELSE 0 END) AS tremor_moderate_count,
          SUM(CASE WHEN b.tremor_magnitude >= 1.4 THEN 1 ELSE 0 END)                       AS tremor_high_count,
          AVG(b.food_temp_c)                                                                AS avg_food_temp_c
        FROM meals m
        LEFT JOIN bites b ON b.meal_uuid = m.uuid AND b.is_valid = 1
        WHERE m.user_id = ? AND substr(m.started_at, 1, 10) >= ? AND substr(m.started_at, 1, 10) < ?
        GROUP BY substr(m.started_at, 1, 10)
        ORDER BY date ASC
      ''', [userId, startStr, endStr]);

      return rows;
    } catch (e) {
      debugPrint('[DB] getDailySummaries error: $e');
      return [];
    }
  }

  // ==========================================================================
  // TREMOR STATS — computed live from bites (used by Tremor History page)
  // Kept as on-demand query so no extra table is needed.
  // ==========================================================================

  Future<List<Map<String, dynamic>>> getDailyTremorStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        substr(m.started_at, 1, 10)                                                 AS date,
        AVG(b.tremor_frequency)                                                     AS avg_frequency,
        AVG(b.tremor_magnitude)                                                     AS avg_magnitude,
        COUNT(b.id)                                                                 AS sample_count,
        SUM(CASE WHEN b.tremor_magnitude <  0.6 THEN 1 ELSE 0 END)                 AS low_count,
        SUM(CASE WHEN b.tremor_magnitude >= 0.6 AND b.tremor_magnitude < 1.4 THEN 1 ELSE 0 END) AS moderate_count,
        SUM(CASE WHEN b.tremor_magnitude >= 1.4 THEN 1 ELSE 0 END)                 AS high_count
      FROM meals  m
      JOIN bites  b ON b.meal_uuid = m.uuid
      WHERE m.started_at >= ? AND m.started_at <= ?
        AND b.tremor_frequency > 0
      GROUP BY substr(m.started_at, 1, 10)
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  // Per meal-type tremor breakdown (Tremor History detail view)
  Future<List<Map<String, dynamic>>> getMealTypeTremorStats({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        substr(m.started_at, 1, 10)                                                 AS date,
        m.meal_type,
        AVG(b.tremor_frequency)                                                     AS avg_frequency,
        AVG(b.tremor_magnitude)                                                     AS avg_magnitude,
        SUM(CASE WHEN b.tremor_magnitude <  0.6 THEN 1 ELSE 0 END)                 AS low_count,
        SUM(CASE WHEN b.tremor_magnitude >= 0.6 AND b.tremor_magnitude < 1.4 THEN 1 ELSE 0 END) AS moderate_count,
        SUM(CASE WHEN b.tremor_magnitude >= 1.4 THEN 1 ELSE 0 END)                 AS high_count
      FROM meals  m
      JOIN bites  b ON b.meal_uuid = m.uuid
      WHERE m.started_at >= ? AND m.started_at <= ?
        AND b.tremor_frequency > 0
      GROUP BY substr(m.started_at, 1, 10), m.meal_type
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  // ==========================================================================
  // UTILITY
  // ==========================================================================

  /// Rebuild daily_summaries for ALL historical dates that have meal data.
  Future<void> rebuildAllDailySummaries(String userId) async {
    final db = await database;

    final dates = await db.rawQuery('''
      SELECT DISTINCT substr(started_at, 1, 10) AS date
      FROM meals
      WHERE user_id = ?
      ORDER BY date ASC
    ''', [userId]);

    if (dates.isEmpty) return;

    debugPrint('[DB] Rebuilding daily_summaries for ${dates.length} days...');
    for (final row in dates) {
      final dateStr = row['date'] as String; // "YYYY-MM-DD"
      final parts = dateStr.split('-');
      final localDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      await rebuildDailySummary(userId, localDate);
    }
    debugPrint('[DB] Rebuild complete.');
  }

  /// Backfill daily_summaries only for meal dates that are missing a summary row.
  /// Called on app init — safe to call every startup (no-op if already up to date).
  Future<void> backfillMissingSummaries(String userId) async {
    final db = await database;

    // Find meal dates that have NO corresponding daily_summaries row
    final missingDates = await db.rawQuery('''
      SELECT DISTINCT substr(m.started_at, 1, 10) AS date
      FROM meals m
      WHERE m.user_id = ?
        AND NOT EXISTS (
          SELECT 1 FROM daily_summaries ds
          WHERE ds.user_id = m.user_id
            AND ds.date = substr(m.started_at, 1, 10)
        )
      ORDER BY date ASC
    ''', [userId]);

    if (missingDates.isEmpty) return;

    debugPrint('[DB] Backfilling ${missingDates.length} missing daily_summary rows...');
    for (final row in missingDates) {
      final dateStr = row['date'] as String; // "YYYY-MM-DD"
      final parts = dateStr.split('-');
      // Parse as LOCAL midnight — DateTime.parse("YYYY-MM-DD") creates UTC midnight
      // which shifts the date in non-UTC timezones (e.g. IST = UTC+5:30).
      final localDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      await rebuildDailySummary(userId, localDate);
    }
    debugPrint('[DB] Backfill complete.');
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('bites');
    await db.delete('meals');
    await db.delete('daily_summaries');
  }
}
