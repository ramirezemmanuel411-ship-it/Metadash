import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import '../models/user_profile.dart';
import '../models/daily_log.dart';
import '../models/reentry_mode_state.dart';
import '../models/data_inputs_settings.dart';
import '../models/user_food_item.dart';
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
      version: 10, // Incremented version to add user_food_library table
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
        macroTargets TEXT,
        manualMacroEntry INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create UserFoodLibrary table for custom foods
    await db.execute('''
      CREATE TABLE user_food_library (
        id TEXT PRIMARY KEY,
        userId INTEGER NOT NULL,
        name TEXT NOT NULL,
        brand TEXT,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        servingSize REAL,
        servingUnit TEXT,
        lastUsed TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_user_food_library_userId_name ON user_food_library(userId, name)');

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
        workoutDurationMinutes INTEGER,
        waterIntake REAL NOT NULL,
        workoutActivities TEXT NOT NULL,
        protein INTEGER NOT NULL,
        carbs INTEGER NOT NULL,
        fat INTEGER NOT NULL,
        sleepMinutes INTEGER,
        restingHeartRate INTEGER,
        averageHeartRate INTEGER,
        distanceMeters REAL,
        vo2Max REAL,
        weight REAL,
        tdeeAdjustment REAL,
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
        serving TEXT,
        confidence REAL,
        assumptions TEXT,
        rawInput TEXT,
        FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
      )
    ''');

    // Create index for faster timeline queries
    await db.execute('CREATE INDEX idx_food_entries_user_timestamp ON food_entries(userId, timestamp DESC)');

    // Create Reentry Mode table
    await db.execute('''
      CREATE TABLE reentry_mode (
        userId INTEGER PRIMARY KEY,
        isActive INTEGER NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT,
        preReentryWeight REAL,
        returnWeight REAL,
        intakeDelta TEXT,
        activityDelta TEXT,
        fatEstimateLowLb REAL,
        fatEstimateHighLb REAL,
        refineUntil TEXT,
        lastRefineWeightDate TEXT,
        lastKnownWeight REAL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
      )
    ''');

    // Create Data Inputs Settings table
    await db.execute('''
      CREATE TABLE data_inputs_settings (
        userId INTEGER PRIMARY KEY,
        stepCalorieMethod TEXT NOT NULL,
        stepGoal INTEGER NOT NULL,
        includeStepsInExpenditure INTEGER NOT NULL,
        useTrackedWorkoutCalories INTEGER NOT NULL,
        workoutAccuracy TEXT NOT NULL,
        includeStrengthInExpenditure INTEGER NOT NULL,
        foodPrimarySource TEXT NOT NULL,
        showVerifiedItemsFirst INTEGER NOT NULL,
        preferBarcodeMatches INTEGER NOT NULL,
        macroCalcMode TEXT NOT NULL,
        showFiber INTEGER NOT NULL,
        showSugar INTEGER NOT NULL,
        appleHealthConnected INTEGER NOT NULL DEFAULT 0,
        googleFitConnected INTEGER NOT NULL DEFAULT 0,
        garminConnected INTEGER NOT NULL DEFAULT 0,
        fitbitConnected INTEGER NOT NULL DEFAULT 0,
        stravaConnected INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
      )
    ''');
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
          serving TEXT,
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

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE food_entries ADD COLUMN serving TEXT');
      } catch (_) {
        // Column may already exist
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reentry_mode (
            userId INTEGER PRIMARY KEY,
            isActive INTEGER NOT NULL,
            startDate TEXT NOT NULL,
            endDate TEXT,
            preReentryWeight REAL,
            returnWeight REAL,
            intakeDelta TEXT,
            activityDelta TEXT,
            fatEstimateLowLb REAL,
            fatEstimateHighLb REAL,
            refineUntil TEXT,
            lastRefineWeightDate TEXT,
            lastKnownWeight REAL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {
        // Table may already exist
      }
    }

    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS data_inputs_settings (
            userId INTEGER PRIMARY KEY,
            stepCalorieMethod TEXT NOT NULL,
            stepGoal INTEGER NOT NULL,
            includeStepsInExpenditure INTEGER NOT NULL,
            useTrackedWorkoutCalories INTEGER NOT NULL,
            workoutAccuracy TEXT NOT NULL,
            includeStrengthInExpenditure INTEGER NOT NULL,
            foodPrimarySource TEXT NOT NULL,
            showVerifiedItemsFirst INTEGER NOT NULL,
            preferBarcodeMatches INTEGER NOT NULL,
            macroCalcMode TEXT NOT NULL,
            showFiber INTEGER NOT NULL,
            showSugar INTEGER NOT NULL,
            appleHealthConnected INTEGER NOT NULL DEFAULT 0,
            googleFitConnected INTEGER NOT NULL DEFAULT 0,
            garminConnected INTEGER NOT NULL DEFAULT 0,
            fitbitConnected INTEGER NOT NULL DEFAULT 0,
            stravaConnected INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {
        // Table may already exist
      }
    }

    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE data_inputs_settings ADD COLUMN appleHealthConnected INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE data_inputs_settings ADD COLUMN googleFitConnected INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE data_inputs_settings ADD COLUMN garminConnected INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE data_inputs_settings ADD COLUMN fitbitConnected INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE data_inputs_settings ADD COLUMN stravaConnected INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
    }

    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN workoutDurationMinutes INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN sleepMinutes INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN restingHeartRate INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN averageHeartRate INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN distanceMeters REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE daily_logs ADD COLUMN vo2Max REAL');
      } catch (_) {}
    }

    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE user_profiles ADD COLUMN manualMacroEntry INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
    }

    if (oldVersion < 10) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_food_library (
            id TEXT PRIMARY KEY,
            userId INTEGER NOT NULL,
            name TEXT NOT NULL,
            brand TEXT,
            calories REAL NOT NULL,
            protein REAL NOT NULL,
            carbs REAL NOT NULL,
            fat REAL NOT NULL,
            servingSize REAL,
            servingUnit TEXT,
            lastUsed TEXT,
            createdAt TEXT NOT NULL,
            FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_user_food_library_userId_name ON user_food_library(userId, name)');
      } catch (_) {}
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

  /// Clear health data for a specific date so it can be re-synced
  Future<void> clearHealthDataForDate(int userId, DateTime date) async {
    final db = await database;
    final dateOnly = DateTime(date.year, date.month, date.day);
    await db.update(
      'daily_logs',
      {
        'stepsCount': 0,
        'runningSteps': 0,
        'workoutCalories': 0,
        'workoutType': '',
        'workoutDurationMinutes': 0,
        'sleepMinutes': 0,
        'restingHeartRate': 0,
        'averageHeartRate': 0,
        'distanceMeters': 0,
        'vo2Max': 0,
      },
      where: 'userId = ? AND date = ?',
      whereArgs: [userId, dateOnly.toIso8601String().split('T')[0]],
    );
  }

  /// Clear all health data (steps, calories, workouts) for a user
  /// Allows complete re-sync from health source with corrected logic
  Future<void> clearAllHealthDataForUser(int userId) async {
    final db = await database;
    await db.update(
      'daily_logs',
      {
        'stepsCount': 0,
        'runningSteps': 0,
        'workoutCalories': 0,
        'workoutType': '',
        'workoutDurationMinutes': 0,
        'sleepMinutes': 0,
        'restingHeartRate': 0,
        'averageHeartRate': 0,
        'distanceMeters': 0,
        'vo2Max': 0,
      },
      where: 'userId = ?',
      whereArgs: [userId],
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
      final dateOnly = DateTime(date.year, date.month, date.day);

      // Fetch health metrics for this date
      final healthMetrics = await healthService.fetchHealthDataForDate(dateOnly);
      if (healthMetrics == null) {
        // Silent fail - health data not always available
        return null;
      }

      // Get existing daily log or create new one
      var dailyLog = await getDailyLogByUserAndDate(userId, dateOnly);

      if (dailyLog != null) {
        // Update existing log with health data
        dailyLog = dailyLog.copyWith(
          stepsCount: healthMetrics.totalSteps,
          runningSteps: healthMetrics.runningSteps,
          workoutCalories: healthMetrics.workoutCalories,
          workoutType: healthMetrics.workoutType,
          workoutDurationMinutes: healthMetrics.workoutDurationMinutes,
          sleepMinutes: healthMetrics.sleepMinutes,
          restingHeartRate: healthMetrics.restingHeartRate,
          averageHeartRate: healthMetrics.averageHeartRate,
          distanceMeters: healthMetrics.distanceMeters,
          vo2Max: healthMetrics.vo2Max,
        );
        await updateDailyLog(dailyLog);
      } else {
        // Create new daily log with health data
        dailyLog = DailyLog(
          userId: userId,
          date: dateOnly,
          caloriesConsumed: 0, // User must enter this manually
          stepsCount: healthMetrics.totalSteps,
          runningSteps: healthMetrics.runningSteps,
          workoutCalories: healthMetrics.workoutCalories,
          workoutType: healthMetrics.workoutType,
          workoutDurationMinutes: healthMetrics.workoutDurationMinutes,
          sleepMinutes: healthMetrics.sleepMinutes,
          restingHeartRate: healthMetrics.restingHeartRate,
          averageHeartRate: healthMetrics.averageHeartRate,
          distanceMeters: healthMetrics.distanceMeters,
          vo2Max: healthMetrics.vo2Max,
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

    try {
      final healthService = HealthService();
      final dateOnlyStart = DateTime(startDate.year, startDate.month, startDate.day);
      final dateOnlyEnd = DateTime(endDate.year, endDate.month, endDate.day);
      final metricsByDay = await healthService.fetchDailyMetricsRange(
        dateOnlyStart,
        dateOnlyEnd,
      );

      for (final entry in metricsByDay.entries) {
        final day = entry.key;
        final metrics = entry.value;
        var dailyLog = await getDailyLogByUserAndDate(userId, day);

        if (dailyLog != null) {
          dailyLog = dailyLog.copyWith(
            stepsCount: metrics.totalSteps,
            runningSteps: metrics.runningSteps,
            workoutCalories: metrics.workoutCalories,
            workoutType: metrics.workoutType,
            workoutDurationMinutes: metrics.workoutDurationMinutes,
            sleepMinutes: metrics.sleepMinutes,
            restingHeartRate: metrics.restingHeartRate,
            averageHeartRate: metrics.averageHeartRate,
            distanceMeters: metrics.distanceMeters,
            vo2Max: metrics.vo2Max,
          );
          await updateDailyLog(dailyLog);
        } else {
          dailyLog = DailyLog(
            userId: userId,
            date: day,
            caloriesConsumed: 0,
            stepsCount: metrics.totalSteps,
            runningSteps: metrics.runningSteps,
            workoutCalories: metrics.workoutCalories,
            workoutType: metrics.workoutType,
            workoutDurationMinutes: metrics.workoutDurationMinutes,
            sleepMinutes: metrics.sleepMinutes,
            restingHeartRate: metrics.restingHeartRate,
            averageHeartRate: metrics.averageHeartRate,
            distanceMeters: metrics.distanceMeters,
            vo2Max: metrics.vo2Max,
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

        syncedLogs.add(dailyLog);
      }
    } catch (_) {
      return syncedLogs;
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

  // User Food Library Methods (Custom Foods)
  Future<void> saveUserFood(UserFoodItem food) async {
    final db = await database;
    await db.insert(
      'user_food_library',
      food.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UserFoodItem>> searchUserFoodLibrary(int userId, String query) async {
    final db = await database;
    final results = await db.query(
      'user_food_library',
      where: 'userId = ? AND name LIKE ?',
      whereArgs: [userId, '%$query%'],
      orderBy: 'lastUsed DESC, name ASC',
    );
    return results.map((m) => UserFoodItem.fromMap(m)).toList();
  }

  Future<void> updateFoodLastUsed(String id) async {
    final db = await database;
    await db.update(
      'user_food_library',
      {'lastUsed': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Data Inputs Settings Methods
  Future<void> createOrUpdateDataInputsSettings(DataInputsSettings settings) async {
    final db = await database;
    await db.insert(
      'data_inputs_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DataInputsSettings?> getDataInputsSettings(int userId) async {
    final db = await database;
    final maps = await db.query(
      'data_inputs_settings',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    if (maps.isEmpty) return null;
    return DataInputsSettings.fromMap(maps.first);
  }

  Future<void> deleteDataInputsSettings(int userId) async {
    final db = await database;
    await db.delete(
      'data_inputs_settings',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  // Reentry Mode Methods
  Future<void> createOrUpdateReentryMode(ReentryModeState state) async {
    final db = await database;
    await db.insert(
      'reentry_mode',
      state.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReentryModeState?> getReentryModeState(int userId) async {
    final db = await database;
    final maps = await db.query(
      'reentry_mode',
      where: 'userId = ?',
      whereArgs: [userId.toString()],
    );

    if (maps.isEmpty) return null;
    return ReentryModeState.fromMap(maps.first);
  }

  Future<void> deleteReentryMode(int userId) async {
    final db = await database;
    await db.delete(
      'reentry_mode',
      where: 'userId = ?',
      whereArgs: [userId.toString()],
    );
  }

  /// Check if a date is within any active reentry window (for excluding from goal evaluation)
  Future<bool> isDateInReentryWindow(int userId, DateTime date) async {
    final reentryState = await getReentryModeState(userId);
    if (reentryState == null || !reentryState.isActive) {
      return false;
    }
    return reentryState.isInReentryWindow(date);
  }

  /// Get all daily logs EXCLUDING reentry window dates
  Future<List<DailyLog>> getDailyLogsExcludingReentry(
    int userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final reentryState = await getReentryModeState(userId);

    String whereClause = 'userId = ?';
    List<dynamic> whereArgs = [userId];

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String().split('T').first);
    }

    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String().split('T').first);
    }

    final maps = await db.query(
      'daily_logs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );

    // Filter out dates within reentry window
    if (reentryState != null && reentryState.isActive) {
      final activeState = reentryState;
      final range = activeState.excludedRange;
      return maps
          .map((map) => DailyLog.fromMap(map))
          .where((log) => !range.contains(log.date))
          .toList();
    }

    return maps.map((map) => DailyLog.fromMap(map)).toList();
  }
}
