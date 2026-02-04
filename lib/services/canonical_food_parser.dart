import 'package:flutter/foundation.dart';
import '../data/models/food_search_result_raw.dart';
import '../models/canonical_food.dart';

/// Parses raw food database strings into canonical display format
///
/// Normalization rules:
/// 1. Brand resolution: restaurant_name → brand_owner → brand_name → inferred
/// 2. Strip duplicate brand tokens from food_name_raw
/// 3. Remove generic words: "product", "original product", "food"
/// 4. Detect variants: Diet, Zero, Cherry, Vanilla, Lime, Caffeine Free
/// 5. Display format: {Brand} or {Brand} ({Variant})
class CanonicalFoodParser {
  // Fixed variant whitelist (case-insensitive)
  static final _variantWhitelist = {
    'diet',
    'zero',
    'cherry',
    'vanilla',
    'lime',
    'caffeine free',
    'caffeine-free',
  };

  // Generic words to remove from food names
  static final _genericWords = {
    'product',
    'original product',
    'food',
    'original',
  };

  /// Parse raw result into canonical food display
  static CanonicalFoodDisplay parseCanonicalFood(FoodSearchResultRaw raw) {
    // 1. Resolve brand using priority order
    final brand = _resolveBrand(raw);

    // 2. Detect variant from food name
    final variant = _detectVariant(raw);

    // 3. Generate canonical key for grouping: {brand + variant}
    final canonicalKey = variant != null ? '$brand|$variant' : brand;

    // 4. Generate display name: {Brand} or {Brand} ({Variant})
    final displayName = CanonicalFoodDisplay.generateDisplayName(
      brand,
      variant,
    );

    // 5. Generate normalized nutrition display
    final nutritionDisplay = _generateNutritionDisplay(raw);

    return CanonicalFoodDisplay(
      brand: brand,
      variant: variant,
      canonicalKey: canonicalKey,
      displayName: displayName,
      nutritionDisplay: nutritionDisplay,
      rawResultId: raw.id,
    );
  }

  /// Resolve brand using priority order: restaurant_name → brand_owner → brand_name → inferred
  static String _resolveBrand(FoodSearchResultRaw raw) {
    // Priority 1: restaurant_name
    if (raw.restaurantName != null && raw.restaurantName!.isNotEmpty) {
      return _cleanBrandName(raw.restaurantName!);
    }

    // Priority 2: brand_owner
    if (raw.brandOwner != null && raw.brandOwner!.isNotEmpty) {
      return _cleanBrandName(raw.brandOwner!);
    }

    // Priority 3: brand_name
    if (raw.brandName != null && raw.brandName!.isNotEmpty) {
      return _cleanBrandName(raw.brandName!);
    }

    // Priority 4: infer from food_name_raw
    return _inferBrandFromFoodName(raw.foodNameRaw ?? 'Unknown');
  }

  /// Clean brand name: remove duplicate tokens and generic words
  static String _cleanBrandName(String brand) {
    // Remove common suffixes
    var cleaned = brand
        .replaceAll(
          RegExp(
            r'\s+(Inc\.?|LLC|Co\.?|Corporation|Ltd\.?)$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // Remove generic words
    for (final word in _genericWords) {
      cleaned = cleaned
          .replaceAll(RegExp(word, caseSensitive: false), '')
          .trim();
    }

    // Title case
    return _toTitleCase(cleaned);
  }

  /// Infer brand from food name by extracting first meaningful word
  static String _inferBrandFromFoodName(String foodName) {
    final words = foodName.split(RegExp(r'[\s,]+'));
    for (final word in words) {
      final cleaned = word.trim().replaceAll(RegExp(r'[^\w]'), '');
      if (cleaned.isNotEmpty &&
          !_genericWords.contains(cleaned.toLowerCase())) {
        return _toTitleCase(cleaned);
      }
    }
    return 'Unknown';
  }

  /// Detect variant from fixed whitelist
  static String? _detectVariant(FoodSearchResultRaw raw) {
    final foodName = (raw.foodNameRaw ?? '').toLowerCase();

    // Check for each variant in whitelist
    for (final variant in _variantWhitelist) {
      if (foodName.contains(variant)) {
        // Return title-cased variant
        return _toTitleCase(variant);
      }
    }

    return null;
  }

  /// Generate normalized nutrition display (shown once)
  /// Prefer per-serving calories. If only per-100g/ml, show "X kcal · 100 ml"
  static String _generateNutritionDisplay(FoodSearchResultRaw raw) {
    if (raw.calories == null) return 'No nutrition info';

    final calories = raw.calories!.round();
    final basis = raw.nutritionBasis ?? '';

    // Prefer per-serving display
    if (basis != 'per_100g' && basis != 'per_100ml') {
      if (raw.servingQty != null && raw.servingUnit != null) {
        final qty = raw.servingQty!;
        final unit = raw.servingUnit!;
        return '$calories kcal · ${qty.toStringAsFixed(0)} $unit';
      }
      return '$calories kcal';
    }

    // Per-100g/ml display
    if (basis == 'per_100ml') {
      return '$calories kcal · 100 ml';
    }
    if (basis == 'per_100g') {
      return '$calories kcal · 100 g';
    }

    return '$calories kcal';
  }

  /// Convert string to title case
  static String _toTitleCase(String text) {
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Group results by canonical key and select representative
  ///
  /// Selection criteria (in order):
  /// a) has per-serving calories
  /// b) branded > generic
  /// c) higher provider score
  /// d) newer modifiedDate
  static Map<String, CanonicalFoodGroup> groupAndSelectRepresentatives(
    List<FoodSearchResultRaw> rawResults,
  ) {
    final groups = <String, CanonicalFoodGroup>{};

    // Parse all results and group by canonical key
    for (final raw in rawResults) {
      final canonical = parseCanonicalFood(raw);

      if (!groups.containsKey(canonical.canonicalKey)) {
        groups[canonical.canonicalKey] = CanonicalFoodGroup(
          canonicalKey: canonical.canonicalKey,
          brand: canonical.brand,
          variant: canonical.variant,
          allResults: [],
        );
      }

      groups[canonical.canonicalKey]!.allResults.add((raw, canonical));
    }

    // Select representative for each group
    for (final group in groups.values) {
      group.selectRepresentative();
    }

    return groups;
  }

  /// Score a result for representative selection
  static double _scoreForSelection(FoodSearchResultRaw raw) {
    double score = 0.0;

    final basis = raw.nutritionBasis ?? '';

    // a) Has per-serving calories (+100)
    if (raw.calories != null && basis != 'per_100g' && basis != 'per_100ml') {
      score += 100.0;
    }

    // b) Branded > generic (+50)
    if (raw.isBranded == true) {
      score += 50.0;
    }

    // c) Higher provider score (+0.1x)
    if (raw.providerScore != null) {
      score += raw.providerScore! * 0.1;
    }

    // d) Newer modified date (+10 per year freshness)
    if (raw.lastUpdated != null) {
      final now = DateTime.now();
      final age = now.difference(raw.lastUpdated!);
      final yearsOld = age.inDays / 365;
      score += (10 - yearsOld).clamp(0, 10);
    }

    return score;
  }
}

/// Group of raw results with same canonical identity
class CanonicalFoodGroup {
  final String canonicalKey;
  final String brand;
  final String? variant;
  final List<(FoodSearchResultRaw, CanonicalFoodDisplay)> allResults;

  FoodSearchResultRaw? representative;
  CanonicalFoodDisplay? representativeCanonical;
  String? selectionReason;

  CanonicalFoodGroup({
    required this.canonicalKey,
    required this.brand,
    required this.variant,
    required this.allResults,
  });

  /// Select the best representative from the group
  void selectRepresentative() {
    if (allResults.isEmpty) return;

    // Score all results
    final scored = allResults.map((tuple) {
      final raw = tuple.$1;
      final score = CanonicalFoodParser._scoreForSelection(raw);
      return (raw, tuple.$2, score);
    }).toList();

    // Sort by score descending
    scored.sort((a, b) => b.$3.compareTo(a.$3));

    // Select best
    final best = scored.first;
    representative = best.$1;
    representativeCanonical = best.$2.copyWith(
      selectionReason: _buildSelectionReason(best.$1, best.$3),
    );
    selectionReason = representativeCanonical!.selectionReason;

    // Debug log
    if (kDebugMode) {
      debugPrint(
        '[$canonicalKey] → ${representative!.id} (${selectionReason ?? "score: ${best.$3}"})',
      );
    }
  }

  /// Build human-readable reason for selection
  String _buildSelectionReason(FoodSearchResultRaw raw, double score) {
    final reasons = <String>[];

    final basis = raw.nutritionBasis ?? '';
    if (raw.calories != null && basis != 'per_100g' && basis != 'per_100ml') {
      reasons.add('per-serving');
    }

    if (raw.isBranded == true) {
      reasons.add('branded');
    }

    if (raw.providerScore != null && raw.providerScore! > 50) {
      reasons.add('high score');
    }

    if (reasons.isEmpty) {
      return 'score: ${score.toStringAsFixed(1)}';
    }

    return reasons.join(', ');
  }
}

/// Extension to copy CanonicalFoodDisplay with updates
extension CanonicalFoodDisplayCopy on CanonicalFoodDisplay {
  CanonicalFoodDisplay copyWith({
    String? brand,
    String? variant,
    String? canonicalKey,
    String? displayName,
    String? nutritionDisplay,
    String? rawResultId,
    String? selectionReason,
  }) {
    return CanonicalFoodDisplay(
      brand: brand ?? this.brand,
      variant: variant ?? this.variant,
      canonicalKey: canonicalKey ?? this.canonicalKey,
      displayName: displayName ?? this.displayName,
      nutritionDisplay: nutritionDisplay ?? this.nutritionDisplay,
      rawResultId: rawResultId ?? this.rawResultId,
      selectionReason: selectionReason ?? this.selectionReason,
    );
  }
}
