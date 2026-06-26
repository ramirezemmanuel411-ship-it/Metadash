import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:metadash/core/logging/app_logger.dart';

import '../../services/canonical_food_service.dart'; // Canonical food parsing
import '../../services/food_dedup_service.dart'; // Deduplication service
import '../../services/food_quality_engine.dart'; // Quality pipeline & ranking
import '../../services/raw_search_debug_store.dart';
import '../datasources/fatsecret_remote_datasource.dart';
import '../datasources/food_local_datasource.dart';
import '../datasources/food_remote_datasource.dart';
import '../models/food_model.dart';
import '../models/food_search_result_raw.dart';
import '../models/search_cache_entry.dart';

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
  factory SearchRepository.withFatSecret({String? backendUrl}) {
    FatSecretRemoteDatasource? fatSecretDatasource;

    try {
      // Try to initialize FatSecret if credentials are available
      fatSecretDatasource = FatSecretRemoteDatasource(
        backendUrl:
            backendUrl ??
            'https://fatsecret-proxy-production-d58c.up.railway.app',
      );
      AppLogger.d('✅ FatSecret datasource initialized successfully');
    } catch (e) {
      AppLogger.d(
        '❌ FatSecret initialization failed: $e - will use fallback databases',
      );
    }

    return SearchRepository(fatSecretDatasource: fatSecretDatasource);
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
      // ===== STAGE 1: Fetch Fresh from APIs (FatSecret primary) =====
      final List<FoodModel> remoteResults = [];

      AppLogger.d(
        '🔍 FatSecret datasource available: ${_fatSecretDatasource != null}',
      );

      if (_fatSecretDatasource != null) {
        try {
          AppLogger.d('🔍 Attempting FatSecret search for: $query');
          _debugLogRawResults('FATSECRET', query);
          final rawFatSecretData = await _fatSecretDatasource.searchFoods(
            query,
          );
          final fatSecretResults =
              FatSecretRemoteDatasource.parseFoodsFromSearch(rawFatSecretData);
          AppLogger.d(
            '✅ FatSecret returned ${fatSecretResults.length} results',
          );
          remoteResults.addAll(fatSecretResults);
          _debugLogResults('FATSECRET', query, fatSecretResults);
        } catch (e) {
          AppLogger.d(
            '❌ FatSecret search error: $e - Falling back to USDA/OpenFoodFacts',
          );
        }
      } else {
        AppLogger.d('⚠️ FatSecret datasource is null - will use fallback');
      }

      // FALLBACK: If FatSecret empty or failed, try USDA + OpenFoodFacts
      if (remoteResults.isEmpty) {
        try {
          _activeCancelToken = _remoteDatasource.createCancelToken();
          final fallbackResults = await _remoteDatasource.searchBoth(
            query,
            cancelToken: _activeCancelToken,
          );
          _debugLogRawResults('USDA/OFF_FALLBACK', query);
          remoteResults.addAll(fallbackResults);
          _debugLogResults('USDA/OFF_FALLBACK', query, fallbackResults);
        } catch (e) {
          AppLogger.d('USDA/OpenFoodFacts fallback error: $e');
        }
      } else {
        // Only supplement with USDA/OFF when FatSecret returned few results.
        // With ≥ 10 FatSecret (per-serving) entries the per-100g USDA entries
        // would just pollute results and confuse users with duplicate foods
        // that require manual gram math to use.
        final fatSecretCount = remoteResults.length;
        if (fatSecretCount < 10) {
          try {
            _activeCancelToken = _remoteDatasource.createCancelToken();
            final fallbackResults = await _remoteDatasource.searchBoth(
              query,
              pageSize: 15,
              cancelToken: _activeCancelToken,
            );
            if (fallbackResults.isNotEmpty) {
              _debugLogRawResults('USDA/OFF_SUPPLEMENT', query);
              remoteResults.addAll(fallbackResults);
              _debugLogResults('USDA/OFF_SUPPLEMENT', query, fallbackResults);
            }
          } catch (e) {
            AppLogger.d(
              'USDA/OpenFoodFacts supplement error (non-critical): $e',
            );
          }
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

        // Apply deduplication to remote results
        final deduped = deduplicateFoods(remoteResults);

        // Apply canonical parsing to clean and group all results
        final canonicalAll = CanonicalFoodService.processSearchResults(
          results: deduped,
          query: query,
          maxResults: 50,
        );

        // Quality pipeline: re-rank by verification level + nutrition validation
        final qualityRanked = FoodQualityEngine.sortByQuality(
          canonicalAll,
          query: query,
        );

        // Final guard: drop any entry whose food name is still a bare corporate
        // record (ends with Inc / LLC / Corp / Ltd). These are manufacturer
        // master records that slipped through from any source or stale cache.
        final finalResults = _dropCorporateNameEntries(qualityRanked);
        _debugLogResults('FINAL', query, finalResults);

        yield SearchResult(
          results: finalResults,
          source: SearchSource.remote,
          isComplete: true,
        );

        // Prefetch details for top 10 results
        unawaited(_prefetchTopResults(qualityRanked.take(10).toList()));
      } else {
        // No remote results, fallback to cache/local for anything available
        List<FoodModel> localResults = [];

        if (!forceRefresh) {
          final cacheKey = SearchCacheEntry.createKey(query, filters: filters);
          final cached = await _localDatasource.getCachedSearch(cacheKey);
          if (cached != null && cached.isValid) {
            localResults.addAll(cached.results);
            _debugLogRawResults('CACHE', query);
          }
        }

        final localSearchResults = await _localDatasource.searchFoodsLocal(
          query,
        );
        if (localSearchResults.isNotEmpty) {
          localResults = _mergeResults(localResults, localSearchResults);
          _debugLogRawResults('LOCAL', query);
        }

        if (localResults.isNotEmpty) {
          final deduped = deduplicateFoods(localResults);
          final canonicalLocal = CanonicalFoodService.processSearchResults(
            results: deduped,
            query: query,
            maxResults: 50,
          );
          final qualityLocal = FoodQualityEngine.sortByQuality(
            canonicalLocal,
            query: query,
          );
          final finalLocal = _dropCorporateNameEntries(qualityLocal);

          yield SearchResult(
            results: finalLocal,
            source: SearchSource.local,
            isComplete: true,
          );
        } else {
          yield SearchResult.empty();
        }
      }
    } catch (e) {
      AppLogger.d('Search error: $e');
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
  /// Drop entries whose food name is a bare corporate/manufacturer record
  /// with no real food descriptor attached.
  /// Matches names ending in: Inc, Inc., LLC, Corp, Corp., Ltd, Ltd.
  static final _corpEndRegex = RegExp(
    r'\b(inc\.?|llc\.?|corp\.?|ltd\.?)$',
    caseSensitive: false,
  );

  static List<FoodModel> _dropCorporateNameEntries(List<FoodModel> foods) {
    return foods.where((food) {
      final n = food.name.trim();
      if (n.isEmpty || n.toLowerCase() == 'unknown') return false;
      if (_corpEndRegex.hasMatch(n)) return false;
      return true;
    }).toList();
  }

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
    AppLogger.d('\n========== FOOD SEARCH DEBUG [$stage] ==========');
    AppLogger.d('Query: "$query"');
    AppLogger.d('Total results: ${results.length}');
    AppLogger.d('\nTop 10 results:');

    for (var i = 0; i < results.length && i < 10; i++) {
      final food = results[i];
      AppLogger.d('\n[$i] ${food.id}');
      AppLogger.d('  Raw name: ${food.name}');
      AppLogger.d('  Display title: ${food.displayTitle}');
      AppLogger.d('  Raw brand: ${food.brand ?? "(none)"}');
      AppLogger.d('  Display brand: ${food.displayBrand}');
      AppLogger.d('  Display subtitle: ${food.displaySubtitle}');
      AppLogger.d('  Serving: ${food.servingSize} ${food.servingUnit}');
      AppLogger.d('  Serving line: ${food.servingLine}');
      AppLogger.d('  Calories: ${food.calories} cal');
      AppLogger.d(
        '  Calories display: ${food.calories} cal • ${food.servingLine}',
      );
      AppLogger.d('  Is beverage: ${food.isBeverage}');
      AppLogger.d('  Nutrition basis: ${food.nutritionBasisType}');
      AppLogger.d('  Missing serving: ${food.isMissingServing}');
      AppLogger.d('  Canonical key: ${food.canonicalKey}');
      AppLogger.d('  Source: ${food.source}');
    }

    AppLogger.d('\n✓ Final sort: rankScore descending');
    AppLogger.d('✓ Deduplication: applied via canonicalKey');
    AppLogger.d('================================================\n');
  }

  void _debugLogRawResults(String stage, String query) {
    if (!kDebugMode) return;

    final rawResults = RawSearchDebugStore.latestQuery == query
        ? RawSearchDebugStore.latestResults
        : const <FoodSearchResultRaw>[];

    AppLogger.d('\n🔎 [FOOD RAW $stage] Query: "$query"');
    AppLogger.d('   Results returned: ${rawResults.length}');

    final preview = rawResults.take(5).toList();
    for (final raw in preview) {
      AppLogger.d('   - id: ${raw.id}');
      AppLogger.d('     source: ${raw.source}');
      AppLogger.d('     foodNameRaw: ${raw.foodNameRaw ?? ''}');
      AppLogger.d('     brandName: ${raw.brandName ?? ''}');
      AppLogger.d('     calories: ${raw.calories ?? ''}');
      AppLogger.d('     nutritionBasis: ${raw.nutritionBasis ?? ''}');
      AppLogger.d('     servingUnit: ${raw.servingUnit ?? ''}');
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
