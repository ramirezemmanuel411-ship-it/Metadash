import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'food_model.dart';

/// Cached search result entry with TTL
class SearchCacheEntry extends Equatable {
  final String cacheKey; // query + filters hash
  final List<FoodModel> results;
  final DateTime timestamp;
  final int totalCount; // For pagination
  
  const SearchCacheEntry({
    required this.cacheKey,
    required this.results,
    required this.timestamp,
    this.totalCount = 0,
  });

  /// Check if cache is still valid (< 24 hours)
  bool get isValid {
    final age = DateTime.now().difference(timestamp);
    return age.inHours < 24;
  }

  /// Create cache key from query and filters
  static String createKey(String query, {Map<String, dynamic>? filters}) {
    final normalized = query.toLowerCase().trim();
    if (filters == null || filters.isEmpty) {
      return normalized;
    }
    final filterStr = filters.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    return '$normalized#$filterStr';
  }

  /// Convert to JSON for SQLite storage
  Map<String, dynamic> toJson() {
    return {
      'cache_key': cacheKey,
      'results_json': jsonEncode(results.map((r) => r.toJson()).toList()),
      'updated_at': timestamp.millisecondsSinceEpoch,
      'total_count': totalCount,
    };
  }

  /// Create from JSON (SQLite row)
  factory SearchCacheEntry.fromJson(Map<String, dynamic> json) {
    final resultsJson = jsonDecode(json['results_json'] as String) as List;
    final results = resultsJson
        .map((r) => FoodModel.fromJson(r as Map<String, dynamic>))
        .toList();

    return SearchCacheEntry(
      cacheKey: json['cache_key'] as String,
      results: results,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['updated_at'] as int,
      ),
      totalCount: json['total_count'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [cacheKey, results, timestamp, totalCount];
}
