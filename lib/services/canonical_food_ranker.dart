import 'canonical_food_parser.dart';

/// Minimal but effective ranking for canonical food results
class CanonicalFoodRanker {
  /// Rank groups based on query relevance
  static List<CanonicalFoodGroup> rankGroups(
    List<CanonicalFoodGroup> groups,
    String query,
  ) {
    final queryLower = query.toLowerCase();

    // Score each group
    final scored = groups.map((group) {
      final score = _scoreGroup(group, queryLower);
      return (group, score);
    }).toList();

    // Sort by score descending
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    return scored.map((tuple) => tuple.$1).toList();
  }

  /// Score a group for ranking
  static double _scoreGroup(CanonicalFoodGroup group, String query) {
    if (group.representative == null) return 0.0;

    double score = 0.0;
    final raw = group.representative!;

    // PRIMARY: food NAME matches user query — this is what the user is searching for.
    final foodName = (raw.foodName ?? raw.foodNameRaw ?? '').toLowerCase();
    if (foodName == query) {
      score += 150.0; // Exact food name match
    } else if (foodName.startsWith(query)) {
      score += 100.0; // Name starts with query
    } else if (foodName.contains(query)) {
      score += 60.0; // Query appears anywhere in name
    }

    // SECONDARY: brand contains query (e.g. user typed "kirkland chicken")
    if (group.brand.toLowerCase().contains(query)) {
      score += 30.0;
    }

    // TERTIARY: variant contains query (e.g. "diet" for "diet coke")
    if (group.variant != null && group.variant!.toLowerCase().contains(query)) {
      score += 25.0;
    }

    // Boost: Branded product (real brand attribution)
    if (raw.isBranded == true) {
      score += 15.0;
    }

    // Boost: Per-serving nutrition — far more useful for meal logging
    final basis = raw.nutritionBasis ?? '';
    if (basis != 'per_100g' && basis != 'per_100ml' && raw.calories != null) {
      score += 40.0;
    }

    // Penalize: Per 100g/ml (requires manual math; less user-friendly)
    if (basis == 'per_100g' || basis == 'per_100ml') {
      score -= 30.0;
    }

    // Penalize: Generic entry without brand
    if (raw.isGeneric == true) {
      score -= 10.0;
    }

    // Penalize: Missing calories
    if (raw.calories == null) {
      score -= 20.0;
    }

    // Provider confidence score (minor signal)
    if (raw.providerScore != null) {
      score += raw.providerScore! * 0.1;
    }

    return score;
  }

  /// Filter out low-quality results (optional post-processing)
  static List<CanonicalFoodGroup> filterLowQuality(
    List<CanonicalFoodGroup> groups,
  ) {
    return groups.where((group) {
      if (group.representative == null) return false;

      final raw = group.representative!;

      // Keep if has basic nutrition info
      if (raw.calories != null) return true;

      // Keep if branded with barcode
      if (raw.isBranded == true &&
          raw.barcode != null &&
          raw.barcode!.isNotEmpty) {
        return true;
      }

      // Filter out otherwise
      return false;
    }).toList();
  }
}
