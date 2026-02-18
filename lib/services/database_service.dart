import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import '../models/user_profile.dart';
import '../models/daily_log.dart';
import 'health_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal() {
    // Initialize sqflite for desktop/web
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static const bool kIsWeb = false;

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'metadash.db');

    // Add a small delay to let UI render first
    await Future.delayed(const Duration(milliseconds: 50));

    return openDatabase(
      path,
      version: 3, // Incremented version to trigger upgrade
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Enable foreign keys
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Create UserProfile table
    await db.execute('''
      CREATE TABLE user_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        weight REAL NOT NULL,
        height REAL NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        dateOfBirth TEXT NOT NULL,
        bmr REAL NOT NULL,
        goalWeight REAL NOT NULL,
        dailyCaloricGoal INTEGER NOT NULL,
        activityLevel TEXT NOT NULL,
        dailyStepsGoal INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        macroTargets TEXT
      )
    ''');

    // Create DailyLog table
    await db.execute('''
      CREATE TABLE daily_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        date TEXT NOT NULL,
        caloriesConsumed INTEGER NOT NULL,
        stepsCount INTEGER NOT NULL,
        runningSteps INTEGER,
        workoutCalories INTEGER,
        workoutType TEXT,
        waterIntake REAL NOT NULL,
        workoutActivities TEXT NOT NULL,
        protein INTEGER NOT NULL,
        carbs INTEGER NOT NULL,
        fat INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE,
        UNIQUE(userId, date)
      )
    ''');

    // Create index for faster queries
    await db.execute('CREATE INDEX idx_daily_logs_user_date ON daily_logs(userId, date)');

    // Create Exercises table
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        userId INTEGER NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        intensity TEXT,
        durationMinutes INTEGER,
        description TEXT,
        caloriesBurned INTEGER,
        timestamp TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
      )
    ''');

    // Create index for faster date queries
    await db.execute('CREATE INDEX idx_exercises_user_date ON exercises(userId, date)');

    // Create Food Entries table for diary timeline
    await db.execute('''
      CREATE TABLE food_entries (
        id TEXT PRIMARY KEY,
        userId INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        name TEXT NOT NULL,
        calories INTEGER NOT NULL,
        proteinG INTEGER NOT NULL,
        carbsG INTEGER NOT NULL,
        fatG INTEGER NOT NULL,
        source TEXT NOT NULL,
        confidence REAL,
        assumptions TEXT,
        rawInput TEXT,
        FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
      )
    ''');

    // Create index for faster timeline queries
    await db.execute('CREATE INDEX idx_food_entries_user_timestamp ON food_entries(userId, timestamp DESC)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add food_entries table for v2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS food_entries (
          id TEXT PRIMARY KEY,
          userId INTEGER NOT NULL,
          timestamp TEXT NOT NULL,
          name TEXT NOT NULL,
          calories INTEGER NOT NULL,
          proteinG INTEGER NOT NULL,
          carbsG INTEGER NOT NULL,
          fatG INTEGER NOT NULL,
          source TEXT NOT NULL,
          confidence REAL,
          assumptions TEXT,
          rawInput TEXT,
          FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_food_entries_user_timestamp ON food_entries(userId, timestamp DESC)');
    }

    // Add macroTargets column if missing
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN macroTargets TEXT');
      } catch (_) {
        // Column may already exist
      }
    }
  }

  // User Profile Methods
  Future<int> createUserProfile(UserProfile profile) async {
    final db = await database;
    return db.insert('user_profiles', profile.toMap());
  }

  Future<UserProfile?> getUserProfileById(int id) async {
    final db = await database;
    final maps = await db.query(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<UserProfile?> getUserProfileByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'user_profiles',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null;
  }

  Future<List<UserProfile>> getAllUserProfiles() async {
    final db = await database;
    final maps = await db.query('user_profiles');
    return maps.map((map) => UserProfile.fromMap(map)).toList();
  }

  Future<int> updateUserProfile(UserProfile profile) async {
    final db = await database;
    return db.update(
      'user_profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<int> deleteUserProfile(int id) async {
    final db = await database;
    return db.delete(
      'user_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Daily Log Methods
  Future<int> createDailyLog(DailyLog log) async {
    final db = await database;
    return db.insert(
      'daily_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DailyLog?> getDailyLogByUserAndDate(int userId, DateTime date) async {
    final db = await database;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final maps = await db.query(
      'daily_logs',
      where: 'userId = ? AND date = ?',
      whereArgs: [userId, dateOnly.toIso8601String()],
    );
    if (maps.isNotEmpty) {
      return DailyLog.fromMap(maps.first);
    }
    return null;
  }

  Future<List<DailyLog>> getDailyLogsByUserAndDateRange(int userId, DateTime startDate, DateTime endDate) async {
    final db = await database;
    final maps = await db.query(
      'daily_logs',
      where: 'userId = ? AND date >= ? AND date <= ?',
      whereArgs: [
        userId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'date DESC',
    );
    return maps.map((map) => DailyLog.fromMap(map)).toList();
  }

  Future<List<DailyLog>> getAllDailyLogsByUser(int userId) async {
    final db = await database;
    final maps = await db.query(
      'daily_logs',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => DailyLog.fromMap(map)).toList();
  }

  Future<int> updateDailyLog(DailyLog log) async {
    final db = await database;
    return db.update(
      'daily_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> deleteDailyLog(int id) async {
    final db = await database;
    return db.delete(
      'daily_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Clear all data (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('daily_logs');
    await db.delete('user_profiles');
    await db.delete('exercises');
  }

  // Exercise Methods
  Future<int> createExercise(Map<String, dynamic> exercise) async {
    final db = await database;
    return db.insert(
      'exercises',
      exercise,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getExercisesByUserAndDate(int userId, DateTime date) async {
    final db = await database;
    final dateOnly = DateTime(date.year, date.month, date.day);
    return db.query(
      'exercises',
      where: 'userId = ? AND date = ?',
      whereArgs: [userId, dateOnly.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getExercisesByUser(int userId) async {
    final db = await database;
    return db.query(
      'exercises',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<int> deleteExercise(String exerciseId) async {
    final db = await database;
    return db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
  }

  // Health Data Sync Method
  /// Syncs health data from device (HealthKit/Google Fit) to a DailyLog
  /// Creates or updates the daily log with device health metrics
  Future<DailyLog?> syncHealthDataToDailyLog(
    int userId,
    DateTime date,
  ) async {
    try {
      final healthService = HealthService();

      // Fetch health metrics for this date
      final healthMetrics = await healthService.fetchHealthDataForDate(date);
      if (healthMetrics == null) {
        // Silent fail - health data not always available
        return null;
      }

      // Get existing daily log or create new one
      var dailyLog = await getDailyLogByUserAndDate(userId, date);

      if (dailyLog != null) {
        // Update existing log with health data
        dailyLog = dailyLog.copyWith(
          stepsCount: healthMetrics.totalSteps,
          runningSteps: healthMetrics.runningSteps,
          workoutCalories: healthMetrics.workoutCalories,
          workoutType: healthMetrics.workoutType,
        );
        await updateDailyLog(dailyLog);
      } else {
        // Create new daily log with health data
        dailyLog = DailyLog(
          userId: userId,
          date: date,
          caloriesConsumed: 0, // User must enter this manually
          stepsCount: healthMetrics.totalSteps,
          runningSteps: healthMetrics.runningSteps,
          workoutCalories: healthMetrics.workoutCalories,
          workoutType: healthMetrics.workoutType,
          waterIntake: 0,
          workoutActivities: [],
          protein: 0,
          carbs: 0,
          fat: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await createDailyLog(dailyLog);
      }

      return dailyLog;
    } catch (e) {
      // Silently fail, don't break main app flow
      return null;
    }
  }

  /// Syncs health data for a date range
  Future<List<DailyLog>> syncHealthDataForDateRange(
    int userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final syncedLogs = <DailyLog>[];

    var currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final log = await syncHealthDataToDailyLog(userId, currentDate);
      if (log != null) {
        syncedLogs.add(log);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return syncedLogs;
  }

  // Food Entry Methods for Diary Timeline
  Future<void> addFoodEntry(dynamic entry) async {
    final db = await database;
    await db.insert(
      'food_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFoodEntriesForDay(int userId, DateTime day) async {
    final db = await database;
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final maps = await db.query(
      'food_entries',
      where: 'userId = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        userId,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      orderBy: 'timestamp DESC',
    );
    
    return maps;
  }

  Future<void> deleteFoodEntry(String id) async {
    final db = await database;
    await db.delete(
      'food_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
