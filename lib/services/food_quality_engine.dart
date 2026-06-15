import '../data/models/food_model.dart';

// ── Verification Ladder ───────────────────────────────────────────────────────

/// MetaDash Quality Ladder — 5 levels from community to curated.
///
/// Every food entry is classified before being displayed in search results.
/// Higher levels appear first and receive visual trust badges.
enum FoodVerificationLevel {
  /// ⚠ Nutrition values appear inconsistent — deprioritized in search
  needsReview,

  /// No badge — community or unclassified entry
  community,

  /// ✓ Verified Source — data from USDA, manufacturer barcode, or official partner
  verifiedSource,

  /// ✓ Consensus Verified — multiple independent sources agree within tolerance
  consensusVerified,

  /// ✓ MetaDash Verified — curated, high-confidence, nutritionally clean entry
  metadashVerified,

  // Gold (reserved — do not use yet)
  // metadashGold,
}

extension FoodVerificationLevelX on FoodVerificationLevel {
  /// Human-readable label shown in the badge
  String get label => switch (this) {
        FoodVerificationLevel.metadashVerified => 'MetaDash Verified',
        FoodVerificationLevel.consensusVerified => 'Consensus Verified',
        FoodVerificationLevel.verifiedSource => 'Verified Source',
        FoodVerificationLevel.community => 'Community Entry',
        FoodVerificationLevel.needsReview => 'Needs Review',
      };

  /// Whether a trust badge should be rendered for this level
  bool get showsBadge => index >= FoodVerificationLevel.verifiedSource.index;
}

// ── Quality Result ────────────────────────────────────────────────────────────

/// Output of running a food through the quality pipeline.
class FoodQualityResult {
  final FoodVerificationLevel level;
  final double qualityScore;
  final bool nutritionValid;
  final List<String> nutritionFlags;
  final double? canonicalWeightGrams;

  const FoodQualityResult({
    required this.level,
    required this.qualityScore,
    required this.nutritionValid,
    this.nutritionFlags = const [],
    this.canonicalWeightGrams,
  });
}

// ── Quality Engine ────────────────────────────────────────────────────────────

/// MetaDash Database Quality Engine V1
///
/// Runs every food through a 5-stage pipeline before search display:
///
///   Stage 1 · Source Classification   → FoodVerificationLevel
///   Stage 2 · Serving Standardization → canonicalWeightGrams
///   Stage 3 · Nutrition Validation    → detect impossible values
///   Stage 4 · Verification Scoring    → final qualityScore
///   Stage 5 · (External) Duplicate suppression — handled in SearchRepository
///
/// Usage:
///   final result = FoodQualityEngine.evaluate(food, query: 'chicken');
///   final ranked = FoodQualityEngine.sortByQuality(foods, query: 'chicken');
class FoodQualityEngine {
  // ── Public API ──────────────────────────────────────────────────────────────

  /// Sort a list of foods by quality score (highest first).
  /// Pure in-memory sort — no async work, safe to call on any thread.
  static List<FoodModel> sortByQuality(
    List<FoodModel> foods, {
    String query = '',
  }) {
    if (foods.isEmpty) return foods;
    final scored = foods
        .map((food) => (food, evaluate(food, query: query).qualityScore))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((t) => t.$1).toList();
  }

  /// Evaluate a single food through the full quality pipeline.
  static FoodQualityResult evaluate(FoodModel food, {String query = ''}) {
    // Stage 1: Source classification
    var level = classifyVerification(food);

    // Stage 2: Canonical serving weight
    final canonicalWeight = computeCanonicalWeight(food);

    // Stage 3: Nutrition validation
    final validation = validateNutrition(food);

    // Downgrade to needsReview if serious flags detected
    if (validation.flags.any(_isSeriousFlag)) {
      level = FoodVerificationLevel.needsReview;
    }

    // Stage 4: Scoring
    final score = _computeScore(food, level, validation, query);

    return FoodQualityResult(
      level: level,
      qualityScore: score,
      nutritionValid: validation.flags.isEmpty,
      nutritionFlags: validation.flags,
      canonicalWeightGrams: canonicalWeight,
    );
  }

  // ── Stage 1: Source Classification ─────────────────────────────────────────

  /// Classify the verification level from source metadata and data type.
  ///
  /// Ranking logic:
  ///   USDA Foundation / SR Legacy → MetaDash Verified (gold-standard nutrition)
  ///   USDA Branded / FatSecret branded / OFF with barcode → Verified Source
  ///   FatSecret generic / OFF without barcode → Community
  ///   Manual / local user entries → Community
  static FoodVerificationLevel classifyVerification(FoodModel food) {
    final src = food.source.toLowerCase();
    final dt = (food.dataType ?? '').toLowerCase();

    // USDA ─────────────────────────────────────────────────────────────────────
    if (src.contains('usda')) {
      // Foundation and SR Legacy are the nutritional gold standard
      if (dt.contains('foundation') || dt.contains('sr_legacy')) {
        return FoodVerificationLevel.metadashVerified;
      }
      // Branded USDA foods — manufacturer-validated
      if (dt.contains('branded')) {
        return FoodVerificationLevel.verifiedSource;
      }
      // All other USDA data (survey, sub_sample) — still verified
      return FoodVerificationLevel.verifiedSource;
    }

    // FatSecret ────────────────────────────────────────────────────────────────
    if (src.contains('fatsecret')) {
      // Has a UPC/barcode → manufacturer data
      if (food.barcode?.isNotEmpty == true) {
        return FoodVerificationLevel.verifiedSource;
      }
      // Branded with known brand owner → verified
      if (food.isBranded == true &&
          (food.brandOwner?.isNotEmpty == true ||
              food.brandName?.isNotEmpty == true)) {
        return FoodVerificationLevel.verifiedSource;
      }
      // Generic FatSecret without strong attribution
      if (food.isGeneric == true) {
        return FoodVerificationLevel.community;
      }
      // Default FatSecret — trusted partner, show as verified source
      return FoodVerificationLevel.verifiedSource;
    }

    // Open Food Facts ─────────────────────────────────────────────────────────
    if (src.contains('open_food_facts') || src.contains('off')) {
      // Barcode-backed entries are community-verified
      if (food.barcode?.isNotEmpty == true) {
        return FoodVerificationLevel.verifiedSource;
      }
      return FoodVerificationLevel.community;
    }

    // User-created / manual entries
    if (src.contains('local') ||
        src.contains('manual') ||
        src.contains('user')) {
      return FoodVerificationLevel.community;
    }

    return FoodVerificationLevel.community;
  }

  // ── Stage 2: Serving Standardization ───────────────────────────────────────

  /// Compute canonical weight in grams for consistent nutrition scaling.
  ///
  /// All supported unit conversions route through grams.
  /// Returns null if the serving unit is unknown.
  static double? computeCanonicalWeight(FoodModel food) {
    // Prefer explicit gram weight provided by the data source
    if ((food.servingWeightGrams ?? 0) > 0) {
      return food.servingWeightGrams;
    }

    // Volume fallback (assume water density 1g/ml for most foods)
    if ((food.servingVolumeMl ?? 0) > 0) {
      return food.servingVolumeMl;
    }

    // Convert from serving unit
    final qty = food.servingSize;
    if (qty <= 0) return null;

    final unit = food.servingUnit.toLowerCase().trim();
    return switch (unit) {
      'g' || 'gram' || 'grams' => qty,
      'oz' || 'ounce' || 'ounces' => qty * 28.3495,
      'lb' || 'lbs' || 'pound' || 'pounds' => qty * 453.592,
      'ml' || 'milliliter' || 'milliliters' || 'millilitre' => qty,
      'cup' || 'cups' => qty * 236.588,
      'tbsp' || 'tablespoon' || 'tablespoons' => qty * 14.7868,
      'tsp' || 'teaspoon' || 'teaspoons' => qty * 4.92892,
      'fl oz' || 'fluid oz' || 'floz' => qty * 29.5735,
      _ => null,
    };
  }

  // ── Stage 3: Nutrition Validation ──────────────────────────────────────────

  /// Validate nutrition values — detect entries with impossible values.
  ///
  /// Tolerance rules:
  ///   • Macro-calorie consistency: allow ±25% deviation from P×4 + C×4 + F×9
  ///   • Protein density: > 45g per 100 kcal is physiologically impossible
  ///   • Fat density: > 13g per 100 kcal exceeds pure fat
  ///   • Calorie density: > 950 kcal per 100g exceeds pure fat
  ///   • Serving size: > 10,000g is unrealistic
  static ({bool isValid, List<String> flags}) validateNutrition(
      FoodModel food) {
    final flags = <String>[];

    // Missing calories
    if (food.calories <= 0) {
      flags.add('missing_calories');
    }

    if (food.calories > 0) {
      final totalMacroWeight = food.protein + food.carbs + food.fat;

      // Macro-calorie consistency
      if (totalMacroWeight > 0) {
        final expectedCal =
            (food.protein * 4) + (food.carbs * 4) + (food.fat * 9);
        final deviation =
            (food.calories - expectedCal).abs() / food.calories;
        if (deviation > 0.25) {
          flags.add('macro_calorie_mismatch');
        }
      }

      // Impossible protein density
      if (food.protein > 0) {
        final proteinPer100Cal = (food.protein / food.calories) * 100;
        if (proteinPer100Cal > 45) {
          flags.add('impossible_protein_density');
        }
      }

      // Impossible fat density
      if (food.fat > 0) {
        final fatPer100Cal = (food.fat / food.calories) * 100;
        if (fatPer100Cal > 13) {
          flags.add('impossible_fat_density');
        }
      }
    }

    // Unrealistic serving size
    if (food.servingSize > 10000) {
      flags.add('unrealistic_serving_size');
    }

    // Unrealistic calorie density (> 950 kcal per 100g ≈ pure fat)
    final cw = computeCanonicalWeight(food);
    if (cw != null && cw > 0 && food.calories > 0) {
      final calPer100g = (food.calories / cw) * 100;
      if (calPer100g > 950) {
        flags.add('unrealistic_calorie_density');
      }
    }

    return (isValid: flags.isEmpty, flags: flags);
  }

  // ── Stage 4: Scoring ────────────────────────────────────────────────────────

  static double _computeScore(
    FoodModel food,
    FoodVerificationLevel level,
    ({bool isValid, List<String> flags}) validation,
    String query,
  ) {
    double score = 0.0;

    // Verification tier — primary ranking signal
    score += switch (level) {
      FoodVerificationLevel.metadashVerified => 300.0,
      FoodVerificationLevel.consensusVerified => 200.0,
      FoodVerificationLevel.verifiedSource => 100.0,
      FoodVerificationLevel.community => 20.0,
      FoodVerificationLevel.needsReview => -50.0,
    };

    // Brand-only stub penalty: when name == brand the entry has no food
    // descriptor (e.g. cached "Kirkland Signature" stubs). Push them down.
    if (food.brand != null &&
        food.name.trim().toLowerCase() == food.brand!.trim().toLowerCase()) {
      score -= 150.0;
    }

    // Serving basis signal: per-serving entries are far more useful for
    // meal logging than per-100g USDA Foundation/SR Legacy entries.
    final basis = food.nutritionBasis ?? '';
    if (basis == 'per_100g' || basis == 'per_100ml') {
      score -= 20.0;
    } else if (food.servingSize > 0 && food.servingSize != 100.0) {
      score += 25.0;
    }

    // Query relevance — name and brand match
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final n = food.name.toLowerCase();
      final b = (food.brand ?? '').toLowerCase();
      final fullText = '$n $b';
      if (n == q) {
        score += 80.0; // Exact name match
      } else if (n.startsWith(q)) {
        score += 60.0; // Name starts with query
      } else if (n.contains(q)) {
        score += 40.0; // Query appears in name
      }
      if (b.isNotEmpty && b.contains(q)) score += 30.0;

      // Irrelevance penalty: no single query word (>2 chars) appears anywhere
      // in name or brand — this entry almost certainly doesn’t match the intent.
      final qWords = q.split(RegExp(r'\s+'));
      if (!qWords.any((w) => w.length > 2 && fullText.contains(w))) {
        score -= 80.0;
      }
    }

    // Strong trust signals
    if (food.barcode?.isNotEmpty == true) score += 50.0;
    if ((food.servingWeightGrams ?? 0) > 0) score += 20.0;

    // Complete macros (not just calories)
    if (food.protein > 0 && food.carbs >= 0 && food.fat > 0) score += 15.0;

    // Branded over generic
    if (food.isBranded == true) score += 10.0;

    // Nutrition clean
    if (validation.flags.isEmpty) score += 25.0;

    // Usage popularity (capped at 30 points)
    if ((food.popularity ?? 0) > 0) {
      score += (food.popularity! * 0.1).clamp(0.0, 30.0);
    }

    // Provider confidence score (capped at 10 points)
    if ((food.confidence ?? 0) > 0) {
      score += (food.confidence! * 0.05).clamp(0.0, 10.0);
    }

    return score;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Only serious flags (not just missing_calories) trigger a downgrade
  static bool _isSeriousFlag(String flag) => flag != 'missing_calories';
}
