import '../data/models/food_model.dart';
import 'food_text_normalizer.dart';
import 'food_deduplication_service.dart';

/// Intelligent food search ranking with brand boost, synonym mapping, and serving context
class FoodSearchRanker {
  /// Rank and sort food results by relevance
  /// 
  /// Scoring:
  /// - Prefix match on display title: +10
  /// - Whole word match on display title: +6
  /// - Substring match on display title: +3
  /// - Brand matches query (with synonyms): +8
  /// - Has complete serving information: +2
  /// - Penalize items without serving: -3
  /// - Penalize "Generic" brand: -2
  /// 
  /// Tiebreakers (secondary sort):
  /// - Items with serving info come first
  /// - Branded items before generic
  /// - Branded items before items with incomplete serving
  static List<FoodModel> rank(
    List<FoodModel> items,
    String query, {
    Set<int>? recentFoodIds,
  }) {
    if (query.isEmpty) {
      items.sort((a, b) {
        // Without query, prioritize: complete serving, branded, recent
        if (a.isMissingServing != b.isMissingServing) {
          return a.isMissingServing ? 1 : -1;
        }
        if ((a.displayBrand.isEmpty) != (b.displayBrand.isEmpty)) {
          return a.displayBrand.isEmpty ? 1 : -1;
        }
        return 0;
      });
      return _deduplicateResults(items);
    }

    // Score each item
    final scored = items.map((item) {
      final score = _scoreItem(item, query);
      return (item: item, score: score);
    }).toList();

    // Sort by score descending, then by secondary tiebreakers
    scored.sort((a, b) {
      final scoreDiff = b.score - a.score;
      if (scoreDiff != 0) return scoreDiff.toInt();

      // Tiebreaker 1: Complete serving info first
      if (a.item.isMissingServing != b.item.isMissingServing) {
        return a.item.isMissingServing ? 1 : -1;
      }

      // Tiebreaker 2: Branded items first
      final aIsBranded = a.item.displayBrand.isNotEmpty && 
                          a.item.displayBrand.toLowerCase() != 'generic';
      final bIsBranded = b.item.displayBrand.isNotEmpty && 
                          b.item.displayBrand.toLowerCase() != 'generic';
      if (aIsBranded != bIsBranded) {
        return aIsBranded ? -1 : 1;
      }

      // Tiebreaker 3: Alphabetical
      return a.item.displayTitle.compareTo(b.item.displayTitle);
    });

    final ranked = scored.map((s) => s.item).toList();
    
    // Two-stage deduplication:
    // 1. Exact duplicates (same canonical key)
    final deduplicated = _deduplicateResults(ranked);
    
    // 2. Family-based deduplication with improved core name inference
    final result = FoodDeduplicationService.deduplicateByFamily(
      items: deduplicated,
      query: query,
      debug: true,
    );
    
    return result.groupedResults;
  }

  /// Remove duplicate results based on canonical key
  /// Keeps the highest-ranked (first) occurrence of each unique item
  static List<FoodModel> _deduplicateResults(List<FoodModel> items) {
    final seen = <String>{};
    final deduplicated = <FoodModel>[];

    for (final item in items) {
      final key = item.canonicalKey;
      if (!seen.contains(key)) {
        seen.add(key);
        deduplicated.add(item);
      }
    }

    return deduplicated;
  }

  /// Calculate relevance score for a single item
  static double _scoreItem(FoodModel item, String query) {
    double score = 0.0;
    final displayBrand = item.displayBrand.toLowerCase();

    // ===== PRIMARY SCORING =====

    // Title matches (higher priority)
    if (FoodTextNormalizer.prefixMatch(query, item.displayTitle)) {
      score += 10;
    } else if (FoodTextNormalizer.wholeWordMatch(query, item.displayTitle)) {
      score += 6;
    } else if (FoodTextNormalizer.fuzzyMatch(query, item.displayTitle)) {
      score += 3;
    }

    // Brand matches (with synonym mapping)
    if (FoodTextNormalizer.isBrandMatch(query, item.brand)) {
      score += 8; // Strong boost for brand match
    }

    // ===== PENALTY/BONUS SCORING =====

    // Bonus for complete serving information
    if (!item.isMissingServing) {
      score += 2;
    } else {
      score -= 3; // Penalize missing serving
    }

    // Penalize generic/unknown brands when branded alternatives exist
    if (displayBrand.isEmpty || displayBrand == 'generic') {
      score -= 2;
    }

    // Plausibility check: if calories seem way too low or high, penalize
    if (!_caloriesSeemPlausible(item)) {
      score *= 0.7; // 30% reduction for suspicious calorie values
    }

    return score;
  }

  /// Check if calories seem plausible for the serving
  /// Examples:
  ///   - 0 cal for 100ml: OK (e.g., diet soda)
  ///   - 300 cal for 1 serving: OK
  ///   - 5000 cal for 12 fl oz: NOT plausible
  static bool _caloriesSeemPlausible(FoodModel item) {
    if (item.calories == 0) return true; // Diet/zero calorie items OK
    if (item.servingSize == 0 || item.isMissingServing) return true; // Can't judge without serving

    // Rough heuristic: calories per 100g should be 0-900
    final caloriesPer100 = (item.calories / item.servingSize) * 100;
    return caloriesPer100 >= 0 && caloriesPer100 <= 900;
  }
}
