import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../datasources/food_local_datasource.dart';
import '../datasources/food_remote_datasource.dart';
import '../datasources/fatsecret_remote_datasource.dart';
import '../models/food_model.dart';
import '../models/search_cache_entry.dart';
import '../models/food_search_result_raw.dart';
import '../../services/raw_search_debug_store.dart';
import '../../services/canonical_food_service.dart'; // Canonical food parsing
import '../../services/food_dedup_service.dart'; // Deduplication service

/// Repository coordinating local-first search strategy
/// Returns results in stages: local → cached → remote (USDA/OFF) → FatSecret
class SearchRepository {
  final FoodLocalDatasource _localDatasource;
  final FoodRemoteDatasource _remoteDatasource;
  // ignore: unused_field
  final FatSecretRemoteDatasource? _fatSecretDatasource;

  // Track active cancel tokens to cancel in-flight requests
  CancelToken? _activeCancelToken;

  SearchRepository({
    FoodLocalDatasource? localDatasource,
    FoodRemoteDatasource? remoteDatasource,
    FatSecretRemoteDatasource? fatSecretDatasource,
  }) : _localDatasource = localDatasource ?? FoodLocalDatasource(),
       _remoteDatasource = remoteDatasource ?? FoodRemoteDatasource(),
       _fatSecretDatasource = fatSecretDatasource;

  /// Factory constructor that automatically initializes FatSecret when available
  /// This makes FatSecret the primary database for all searches
  factory SearchRepository.withFatSecret({
    String? backendUrl,
  }) {
    FatSecretRemoteDatasource? fatSecretDatasource;
    
    try {
      // Try to initialize FatSecret if credentials are available
      fatSecretDatasource = FatSecretRemoteDatasource(
        backendUrl: backendUrl ?? 'https://metadash-production.up.railway.app',
      );
    } catch (e) {
      print('FatSecret initialization failed: $e - will use fallback databases');
    }

    return SearchRepository(
      fatSecretDatasource: fatSecretDatasource,
    );
  }

  /// Search foods with FatSecret-first strategy (returns Stream for progressive updates)
  /// 1. Immediate: Return local/cached results
  /// 2. Then: Fetch fresh results from FatSecret (PRIMARY)
  /// 3. Finally: Fallback to USDA and OpenFoodFacts if needed
  Stream<SearchResult> searchFoods(
    String query, {
    Map<String, dynamic>? filters,
    bool forceRefresh = false,
  }) async* {
    if (query.trim().length < 2) {
      yield SearchResult.empty();
      return;
    }

    // Cancel any previous request
    _cancelPreviousRequest();

    try {
      // ===== STAGE 1: Local Search (fastest, always runs) =====
      final localResults = await _localDatasource.searchFoodsLocal(
        query,
        limit: 50,
      );

      if (localResults.isNotEmpty) {
        _debugLogRawResults('LOCAL', query);
        // Apply deduplication first
        final deduped = deduplicateFoods(localResults);
        
        // Apply canonical parsing to clean and group results
        final canonicalLocal = CanonicalFoodService.processSearchResults(
          results: deduped,
          query: query,
          maxResults: 12,
        );
        _debugLogResults('LOCAL', query, canonicalLocal);

        yield SearchResult(
          results: canonicalLocal,
          source: SearchSource.local,
          isComplete: false,
        );
      }

      // ===== STAGE 2: Check Cache =====
      if (!forceRefresh) {
        final cacheKey = SearchCacheEntry.createKey(query, filters: filters);
        final cached = await _localDatasource.getCachedSearch(cacheKey);

        if (cached != null && cached.isValid) {
          // Merge cached with local (prefer local for duplicates)
          final mergedResults = _mergeResults(localResults, cached.results);

          // Apply deduplication
          final deduped = deduplicateFoods(mergedResults);

          // Apply canonical parsing to clean and group merged results
          final canonicalMerged = CanonicalFoodService.processSearchResults(
            results: deduped,
            query: query,
            maxResults: 12,
          );
          _debugLogRawResults('CACHE', query);
          _debugLogResults('CACHE', query, canonicalMerged);

          yield SearchResult(
            results: canonicalMerged,
            source: SearchSource.cache,
            isComplete: false, // Will still fetch fresh data
          );

          // Prefetch details for top results in background
          _prefetchTopResults(canonicalMerged.take(10).toList());
        }
      }

      // ===== STAGE 3: Fetch Fresh from APIs =====
      // PRIMARY: Try FatSecret first
      List<FoodModel> remoteResults = [];
      
      if (_fatSecretDatasource != null) {
        try {
          _debugLogRawResults('FATSECRET', query);
          final rawFatSecretData = await _fatSecretDatasource.searchFoods(query);
          final fatSecretResults = FatSecretRemoteDatasource.parseFoodsFromSearch(rawFatSecretData);
          remoteResults.addAll(fatSecretResults);
          _debugLogResults('FATSECRET', query, fatSecretResults);
        } catch (e) {
          print('FatSecret search error: $e - Falling back to USDA/OpenFoodFacts');
        }
      }

      // FALLBACK: If FatSecret empty or failed, try USDA + OpenFoodFacts
      if (remoteResults.isEmpty) {
        try {
          _activeCancelToken = _remoteDatasource.createCancelToken();
          final fallbackResults = await _remoteDatasource.searchBoth(
            query,
            pageSize: 25,
            cancelToken: _activeCancelToken,
          );
          _debugLogRawResults('USDA/OFF_FALLBACK', query);
          remoteResults.addAll(fallbackResults);
          _debugLogResults('USDA/OFF_FALLBACK', query, fallbackResults);
        } catch (e) {
          print('USDA/OpenFoodFacts fallback error: $e');
        }
      } else {
        // If FatSecret succeeded, still fetch fallback data in background for better coverage
        try {
          _activeCancelToken = _remoteDatasource.createCancelToken();
          final fallbackResults = await _remoteDatasource.searchBoth(
            query,
            pageSize: 15, // Less from fallback since we have FatSecret
            cancelToken: _activeCancelToken,
          );
          if (fallbackResults.isNotEmpty) {
            _debugLogRawResults('USDA/OFF_SUPPLEMENT', query);
            remoteResults.addAll(fallbackResults);
            _debugLogResults('USDA/OFF_SUPPLEMENT', query, fallbackResults);
          }
        } catch (e) {
          print('USDA/OpenFoodFacts supplement error (non-critical): $e');
        }
      }

      if (remoteResults.isNotEmpty) {
        // Save to local database for future searches
        await _localDatasource.saveFoodsBatch(remoteResults);

        // Cache search results
        final cacheEntry = SearchCacheEntry(
          cacheKey: SearchCacheEntry.createKey(query, filters: filters),
          results: remoteResults,
          timestamp: DateTime.now(),
          totalCount: remoteResults.length,
        );
        await _localDatasource.cacheSearchResults(cacheEntry);

        // Save as recent search
        await _localDatasource.saveRecentSearch(query);

        // Merge all results (local + cached + remote, deduplicated)
        final allResults = _mergeResults(localResults, remoteResults);

        // Apply deduplication
        final deduped = deduplicateFoods(allResults);

        // Apply canonical parsing to clean and group all results
        final canonicalAll = CanonicalFoodService.processSearchResults(
          results: deduped,
          query: query,
          maxResults: 12,
        );
        _debugLogResults('FINAL', query, canonicalAll);

        yield SearchResult(
          results: canonicalAll,
          source: SearchSource.remote,
          isComplete: true,
        );

        // Prefetch details for top 10 results
        _prefetchTopResults(canonicalAll.take(10).toList());
      } else {
        // No remote results, apply deduplication to local only
        final deduped = deduplicateFoods(localResults);
        
        final canonicalLocal = CanonicalFoodService.processSearchResults(
          results: deduped,
          query: query,
          maxResults: 12,
        );

        yield SearchResult(
          results: canonicalLocal,
          source: SearchSource.local,
          isComplete: true,
        );
      }
    } catch (e) {
      print('Search error: $e');
      // On error, return what we have locally
      final localResults = await _localDatasource.searchFoodsLocal(query);
      yield SearchResult(
        results: localResults,
        source: SearchSource.local,
        isComplete: true,
        error: e.toString(),
      );
    } finally {
      _activeCancelToken = null;
    }
  }

  /// Get recent search queries
  Future<List<String>> getRecentSearches({int limit = 10}) async {
    return _localDatasource.getRecentSearches(limit: limit);
  }

  /// Get favorite foods
  Future<List<FoodModel>> getFavorites({int limit = 20}) async {
    return _localDatasource.getFavorites(limit: limit);
  }

  /// Get food details by ID (from local first, then remote if needed)
  Future<FoodModel?> getFoodDetails(String foodId) async {
    // Check local first
    final local = await _localDatasource.getFoodById(foodId);
    if (local != null && local.isFresh) {
      return local;
    }

    // If not in local or stale, this would fetch from remote
    // For now, return what we have
    return local;
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String foodId) async {
    await _localDatasource.toggleFavorite(foodId);
  }

  /// Clear recent searches
  Future<void> clearRecentSearches() async {
    await _localDatasource.clearRecentSearches();
  }

  /// Get database statistics (for debugging/settings screen)
  Future<Map<String, int>> getStats() async {
    return _localDatasource.getStats();
  }

  /// Clean up old data (call periodically, e.g., on app start)
  Future<void> cleanupOldData() async {
    await _localDatasource.cleanOldFoods();
    await _localDatasource.cleanOldCaches();
  }

  /// Cancel any active search request
  void _cancelPreviousRequest() {
    if (_activeCancelToken != null && !_activeCancelToken!.isCancelled) {
      _activeCancelToken!.cancel('New search started');
    }
  }

  /// Prefetch details for top results (run in background)
  Future<void> _prefetchTopResults(List<FoodModel> foods) async {
    // Save to local database to make detail views instant
    if (foods.isNotEmpty) {
      await _localDatasource.saveFoodsBatch(foods);
    }
  }

  /// Merge results from multiple sources, removing duplicates
  /// Prefer local results when there are duplicates
  List<FoodModel> _mergeResults(
    List<FoodModel> priority,
    List<FoodModel> additional,
  ) {
    final seen = <String>{};
    final merged = <FoodModel>[];

    // Add priority results first
    for (final food in priority) {
      final key = _getDedupeKey(food);
      if (!seen.contains(key)) {
        seen.add(key);
        merged.add(food);
      }
    }

    // Add additional results (skip duplicates)
    for (final food in additional) {
      final key = _getDedupeKey(food);
      if (!seen.contains(key)) {
        seen.add(key);
        merged.add(food);
      }
    }

    // Limit to 50 results for UI performance
    return merged.take(50).toList();
  }

  /// Get deduplication key for a food item
  String _getDedupeKey(FoodModel food) {
    return '${food.name}_${food.brand ?? ''}'.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
  }

  /// Dispose resources
  void dispose() {
    _cancelPreviousRequest();
  }

  /// Debug logging for ranked results
  void _debugLogResults(String stage, String query, List<FoodModel> results) {
    print('\n========== FOOD SEARCH DEBUG [$stage] ==========');
    print('Query: "$query"');
    print('Total results: ${results.length}');
    print('\nTop 10 results:');

    for (var i = 0; i < results.length && i < 10; i++) {
      final food = results[i];
      print('\n[$i] ${food.id}');
      print('  Raw name: ${food.name}');
      print('  Display title: ${food.displayTitle}');
      print('  Raw brand: ${food.brand ?? "(none)"}');
      print('  Display brand: ${food.displayBrand}');
      print('  Display subtitle: ${food.displaySubtitle}');
      print('  Serving: ${food.servingSize} ${food.servingUnit}');
      print('  Serving line: ${food.servingLine}');
      print('  Calories: ${food.calories} cal');
      print('  Calories display: ${food.calories} cal • ${food.servingLine}');
      print('  Is beverage: ${food.isBeverage}');
      print('  Nutrition basis: ${food.nutritionBasisType}');
      print('  Missing serving: ${food.isMissingServing}');
      print('  Canonical key: ${food.canonicalKey}');
      print('  Source: ${food.source}');
    }

    print('\n✓ Final sort: rankScore descending');
    print('✓ Deduplication: applied via canonicalKey');
    print('================================================\n');
  }

  void _debugLogRawResults(String stage, String query) {
    if (!kDebugMode) return;

    final rawResults = RawSearchDebugStore.latestQuery == query
        ? RawSearchDebugStore.latestResults
        : const <FoodSearchResultRaw>[];

    print('\n🔎 [FOOD RAW $stage] Query: "$query"');
    print('   Results returned: ${rawResults.length}');

    final preview = rawResults.take(5).toList();
    for (final raw in preview) {
      print('   - id: ${raw.id}');
      print('     source: ${raw.source}');
      print('     foodNameRaw: ${raw.foodNameRaw ?? ''}');
      print('     brandName: ${raw.brandName ?? ''}');
      print('     calories: ${raw.calories ?? ''}');
      print('     nutritionBasis: ${raw.nutritionBasis ?? ''}');
      print('     servingUnit: ${raw.servingUnit ?? ''}');
    }
  }
}

/// Search result with metadata
class SearchResult {
  final List<FoodModel> results;
  final SearchSource source;
  final bool isComplete; // True when all sources checked
  final String? error;

  const SearchResult({
    required this.results,
    required this.source,
    required this.isComplete,
    this.error,
  });

  factory SearchResult.empty() {
    return const SearchResult(
      results: [],
      source: SearchSource.local,
      isComplete: true,
    );
  }

  bool get hasResults => results.isNotEmpty;
  bool get hasError => error != null;
}

/// Source of search results
enum SearchSource {
  local, // From local database
  cache, // From cached search
  remote, // Fresh from API
}
