import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/food_model.dart';
import '../models/search_cache_entry.dart';

/// Local datasource for fast food search with caching
/// Implements SQLite with indexes for optimal performance
class FoodLocalDatasource {
  static final FoodLocalDatasource _instance =
      FoodLocalDatasource._internal();
  static Database? _database;

  // In-memory LRU cache for ultra-fast repeat queries
  final Map<String, SearchCacheEntry> _memoryCache = {};
  static const int _maxMemoryCacheSize = 50;

  factory FoodLocalDatasource() => _instance;

  FoodLocalDatasource._internal();

  /// Get or initialize database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database with schema and indexes
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'metadash_food_search.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create tables with indexes for search performance
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE foods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT,
        serving_size REAL NOT NULL,
        serving_unit TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        source TEXT NOT NULL,
        name_normalized TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        is_favorite INTEGER DEFAULT 0,
        source_id TEXT,
        barcode TEXT,
        verified INTEGER,
        confidence REAL,
        food_name_raw TEXT,
        food_name TEXT,
        brand_name TEXT,
        brand_owner TEXT,
        restaurant_name TEXT,
        category TEXT,
        subcategory TEXT,
        language_code TEXT,
        serving_qty REAL,
        serving_unit_raw TEXT,
        serving_weight_grams REAL,
        serving_volume_ml REAL,
        serving_options_json TEXT,
        nutrition_basis TEXT,
        raw_json TEXT,
        last_updated INTEGER,
        data_type TEXT,
        popularity INTEGER,
        is_generic INTEGER,
        is_branded INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_searches (
        cache_key TEXT PRIMARY KEY,
        results_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        total_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE recent_searches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for fast lookups
    await db.execute(
      'CREATE INDEX idx_foods_name_normalized ON foods(name_normalized)',
    );
    await db.execute('CREATE INDEX idx_foods_updated_at ON foods(updated_at)');
    await db.execute('CREATE INDEX idx_foods_is_favorite ON foods(is_favorite)');
    await db
        .execute('CREATE INDEX idx_cached_searches_updated_at ON cached_searches(updated_at)');
    await db.execute(
      'CREATE INDEX idx_recent_searches_updated_at ON recent_searches(updated_at)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE foods ADD COLUMN source_id TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN barcode TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN verified INTEGER');
      await db.execute('ALTER TABLE foods ADD COLUMN confidence REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN food_name_raw TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN food_name TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN brand_name TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN brand_owner TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN restaurant_name TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN subcategory TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN language_code TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN serving_qty REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN serving_unit_raw TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN serving_weight_grams REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN serving_volume_ml REAL');
      await db.execute('ALTER TABLE foods ADD COLUMN serving_options_json TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN nutrition_basis TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN raw_json TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN last_updated INTEGER');
      await db.execute('ALTER TABLE foods ADD COLUMN data_type TEXT');
      await db.execute('ALTER TABLE foods ADD COLUMN popularity INTEGER');
      await db.execute('ALTER TABLE foods ADD COLUMN is_generic INTEGER');
      await db.execute('ALTER TABLE foods ADD COLUMN is_branded INTEGER');
    }
  }

  // ==================== FOOD CRUD ====================

  /// Save or update food in local database
  Future<void> saveFoodlocal(FoodModel food) async {
    final db = await database;
    await db.insert(
      'foods',
      food.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save multiple foods (bulk insert)
  Future<void> saveFoodsBatch(List<FoodModel> foods) async {
    final db = await database;
    final batch = db.batch();

    for (final food in foods) {
      batch.insert(
        'foods',
        food.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get food by ID from local database
  Future<FoodModel?> getFoodById(String id) async {
    final db = await database;
    final results = await db.query(
      'foods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return FoodModel.fromJson(results.first);
  }

  /// Search foods locally by name (fast prefix/contains matching)
  Future<List<FoodModel>> searchFoodsLocal(
    String query, {
    int limit = 50,
  }) async {
    if (query.trim().length < 2) return [];

    final db = await database;
    final normalized = FoodModel.normalizeName(query);
    final words = normalized.split(' ');

    // Build WHERE clause for multi-word AND search
    final whereConditions = words
        .where((w) => w.isNotEmpty)
        .map((w) => "name_normalized LIKE '%$w%'")
        .join(' AND ');

    if (whereConditions.isEmpty) return [];

    final results = await db.query(
      'foods',
      where: whereConditions,
      orderBy: '''
        CASE 
          WHEN name_normalized LIKE '$normalized%' THEN 1
          WHEN name_normalized LIKE '%$normalized%' THEN 2
          ELSE 3
        END,
        is_favorite DESC,
        updated_at DESC
      ''',
      limit: limit,
    );

    return results.map((row) => FoodModel.fromJson(row)).toList();
  }

  /// Get favorite foods
  Future<List<FoodModel>> getFavorites({int limit = 20}) async {
    final db = await database;
    final results = await db.query(
      'foods',
      where: 'is_favorite = 1',
      orderBy: 'updated_at DESC',
      limit: limit,
    );

    return results.map((row) => FoodModel.fromJson(row)).toList();
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String foodId) async {
    final db = await database;
    final food = await getFoodById(foodId);
    if (food == null) return;

    await db.update(
      'foods',
      {'is_favorite': food.isFavorite ? 0 : 1},
      where: 'id = ?',
      whereArgs: [foodId],
    );
  }

  /// Clean up old cached foods (> 30 days)
  Future<void> cleanOldFoods() async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;

    await db.delete(
      'foods',
      where: 'updated_at < ? AND is_favorite = 0',
      whereArgs: [cutoff],
    );
  }

  // ==================== SEARCH CACHE ====================

  /// Get cached search results
  Future<SearchCacheEntry?> getCachedSearch(String cacheKey) async {
    // Check memory cache first (fastest)
    if (_memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (cached.isValid) return cached;
      _memoryCache.remove(cacheKey); // Expired
    }

    // Check SQLite cache
    final db = await database;
    final results = await db.query(
      'cached_searches',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final entry = SearchCacheEntry.fromJson(results.first);
    if (!entry.isValid) {
      // Remove expired cache
      await deleteCachedSearch(cacheKey);
      return null;
    }

    // Add to memory cache
    _addToMemoryCache(cacheKey, entry);
    return entry;
  }

  /// Save search results to cache
  Future<void> cacheSearchResults(SearchCacheEntry entry) async {
    final db = await database;
    await db.insert(
      'cached_searches',
      entry.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Also cache in memory
    _addToMemoryCache(entry.cacheKey, entry);
  }

  /// Delete cached search
  Future<void> deleteCachedSearch(String cacheKey) async {
    final db = await database;
    await db.delete(
      'cached_searches',
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
    );
    _memoryCache.remove(cacheKey);
  }

  /// Clean up old cached searches (> 24 hours)
  Future<void> cleanOldCaches() async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

    await db.delete(
      'cached_searches',
      where: 'updated_at < ?',
      whereArgs: [cutoff],
    );

    // Clear memory cache
    _memoryCache.clear();
  }

  /// Add to LRU memory cache
  void _addToMemoryCache(String key, SearchCacheEntry entry) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // Remove oldest entry
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    _memoryCache[key] = entry;
  }

  // ==================== RECENT SEARCHES ====================

  /// Save recent search query
  Future<void> saveRecentSearch(String query) async {
    if (query.trim().length < 2) return;

    final db = await database;
    await db.insert(
      'recent_searches',
      {
        'query': query.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Keep only last 50 recent searches
    await _trimRecentSearches(50);
  }

  /// Get recent search queries
  Future<List<String>> getRecentSearches({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'recent_searches',
      columns: ['query'],
      orderBy: 'updated_at DESC',
      limit: limit,
      distinct: true,
    );

    return results.map((row) => row['query'] as String).toList();
  }

  /// Clear recent searches
  Future<void> clearRecentSearches() async {
    final db = await database;
    await db.delete('recent_searches');
  }

  /// Trim to keep only N recent searches
  Future<void> _trimRecentSearches(int keepCount) async {
    final db = await database;
    await db.delete(
      'recent_searches',
      where: 'id NOT IN (SELECT id FROM recent_searches ORDER BY updated_at DESC LIMIT ?)',
      whereArgs: [keepCount],
    );
  }

  // ==================== UTILITIES ====================

  /// Get database statistics
  Future<Map<String, int>> getStats() async {
    final db = await database;

    final foodCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM foods'),
    );
    final cacheCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM cached_searches'),
    );
    final recentCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM recent_searches'),
    );
    final favoriteCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM foods WHERE is_favorite = 1'),
    );

    return {
      'foods': foodCount ?? 0,
      'cached_searches': cacheCount ?? 0,
      'recent_searches': recentCount ?? 0,
      'favorites': favoriteCount ?? 0,
      'memory_cache': _memoryCache.length,
    };
  }

  /// Clear all data (for debugging/testing)
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('foods');
    await db.delete('cached_searches');
    await db.delete('recent_searches');
    _memoryCache.clear();
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
