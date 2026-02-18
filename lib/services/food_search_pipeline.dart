// ignore_for_file: avoid_print

import '../data/models/food_model.dart';
import 'food_text_normalizer.dart';

/// Complete food search pipeline: normalization → grouping → scoring → deduplication
/// 
/// Solves:
/// - Duplicate items (language variants, serving size duplicates)
/// - Poor ranking (obscure items before obvious ones)
/// - Excessive noise (translations, database artifacts)
/// - Inconsistent display names
/// 
/// Works for ALL brands and food categories (Coke, Pepsi, Reese's, Pizza Hut, etc.)
class FoodSearchPipeline {
  
  /// Main entry point: Process raw search results into clean, ranked output
  /// 
  /// Returns up to 12 results, ranked by relevance and user-friendliness
  static List<FoodModel> process({
    required List<FoodModel> rawResults,
    required String query,
    int maxResults = 12,
    bool debug = false,
  }) {
    if (rawResults.isEmpty) return [];
    if (query.trim().isEmpty) return rawResults.take(maxResults).toList();

    final normalizedQuery = FoodTextNormalizer.normalize(query);

    // STAGE 1: Normalize and extract metadata
    final enriched = rawResults.map((item) => _enrichItem(item, normalizedQuery)).toList();

    // STAGE 2: Score each item
    final scored = enriched.map((item) {
      final score = _calculateScore(item, normalizedQuery);
      return _ScoredItem(item: item.original, enriched: item, score: score);
    }).toList();

    // STAGE 3: Group by canonical key (exact duplicates)
    final grouped = _groupByCanonicalKey(scored);

    // STAGE 4: Deduplicate by family (language variants, serving duplicates)
    final deduplicated = _deduplicateByFamily(grouped, normalizedQuery);

    // STAGE 5: Final ranking and limit
    deduplicated.sort((a, b) {
      final scoreDiff = b.score - a.score;
      if (scoreDiff != 0) return scoreDiff.sign.toInt();
      return a.enriched.nameLength - b.enriched.nameLength; // Shorter names first
    });

    if (debug) {
      _debugLog(deduplicated, normalizedQuery, maxResults);
    }

    return deduplicated.take(maxResults).map((s) => s.item).toList();
  }

  // ============================================================================
  // STAGE 1: ENRICHMENT
  // ============================================================================

  /// Enrich item with normalized metadata for scoring
  static _EnrichedItem _enrichItem(FoodModel item, String normalizedQuery) {
    final name = FoodTextNormalizer.normalize(item.name);
    final brand = FoodTextNormalizer.normalize(item.brand ?? '');
    final displayTitle = FoodTextNormalizer.normalize(item.displayTitle);

    return _EnrichedItem(
      original: item,
      normalizedName: name,
      normalizedBrand: brand,
      normalizedDisplayTitle: displayTitle,
      nameLength: name.length,
      isGeneric: _isGenericBrand(brand),
      isForeignLanguage: _isForeignLanguageOnly(name, normalizedQuery),
      hasCompleteServing: !item.isMissingServing,
      isUSDA: item.source.toLowerCase().contains('usda'),
      brandFamily: _extractBrandFamily(brand, name),
    );
  }

  static bool _isGenericBrand(String normalizedBrand) {
    return normalizedBrand.isEmpty || 
           normalizedBrand == 'generic' ||
           normalizedBrand == 'usda' ||
           normalizedBrand == 'unknown';
  }

  static bool _isForeignLanguageOnly(String name, String query) {
    // If name contains query words, it's at least partially English
    final queryWords = query.split(' ');
    for (final word in queryWords) {
      if (word.length > 2 && name.contains(word)) {
        return false; // Has English match
      }
    }

    // Check for foreign-language-only patterns
    const foreignIndicators = [
      'gout', 'sabor', 'gusto', 'geschmack', // taste
      'classique', 'clasico', 'classico', // classic
      'original', 'originale', // original (in foreign context)
      'traditionnel', 'tradicional', // traditional
    ];

    int foreignCount = 0;
    for (final indicator in foreignIndicators) {
      if (name.contains(indicator)) foreignCount++;
    }

    return foreignCount >= 2; // Multiple foreign words = foreign-only
  }

  static String _extractBrandFamily(String brand, String name) {
    // Normalize major brand families
    const brandMap = {
      'coca cola': 'cocacola',
      'coca-cola': 'cocacola',
      'coke': 'cocacola',
      'pepsi': 'pepsi',
      'pepsico': 'pepsi',
      'dr pepper': 'drpepper',
      'reeses': 'reeses',
      'reese\'s': 'reeses',
      'pizza hut': 'pizzahut',
      'mcdonalds': 'mcdonalds',
      'mcdonald\'s': 'mcdonalds',
      'starbucks': 'starbucks',
      'yoplait': 'yoplait',
      'dannon': 'dannon',
      'chobani': 'chobani',
      'lays': 'lays',
      'lay\'s': 'lays',
      'doritos': 'doritos',
      'pringles': 'pringles',
      'oreo': 'oreo',
      'nutella': 'nutella',
    };

    final brandLower = brand.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    // Check brand first
    for (final entry in brandMap.entries) {
      if (brandLower.contains(entry.key.replaceAll(RegExp(r'[^\w\s]'), ''))) {
        return entry.value;
      }
    }

    // Check name if brand didn't match
    final nameLower = name.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    for (final entry in brandMap.entries) {
      if (nameLower.contains(entry.key.replaceAll(RegExp(r'[^\w\s]'), ''))) {
        return entry.value;
      }
    }

    return brand.isEmpty ? 'generic' : brand;
  }

  // ============================================================================
  // STAGE 2: SCORING
  // ============================================================================

  static double _calculateScore(_EnrichedItem item, String query) {
    double score = 0.0;

    // === QUERY MATCH (highest priority) ===
    // Exact match (e.g., "Coke" searches for "Coke")
    if (item.normalizedDisplayTitle == query) {
      score += 50;
    }
    // Prefix match (e.g., "Coke" matches "Coke Zero")
    else if (item.normalizedDisplayTitle.startsWith(query)) {
      score += 35;
    }
    // Whole word match (e.g., "Coke" in "Diet Coke")
    else if (_wholeWordMatch(query, item.normalizedDisplayTitle)) {
      score += 25;
    }
    // Substring match (e.g., "Pep" matches "Pepsi")
    else if (item.normalizedDisplayTitle.contains(query)) {
      score += 15;
    }
    // Fuzzy match in name
    else if (item.normalizedName.contains(query)) {
      score += 10;
    }

    // === BRAND RECOGNITION ===
    // Known brand family gets boost
    if (item.brandFamily != 'generic' && item.brandFamily != item.normalizedBrand) {
      score += 15; // Recognized brand (Coke, Pepsi, etc.)
    }
    
    // Brand matches query (e.g., searching "Coke" and brand is "Coca-Cola")
    if (_brandMatchesQuery(query, item.normalizedBrand, item.brandFamily)) {
      score += 20;
    }

    // === QUALITY INDICATORS ===
    // Complete serving information
    if (item.hasCompleteServing) {
      score += 8;
    } else {
      score -= 5;
    }

    // USDA or verified source
    if (item.isUSDA) {
      score += 5;
    }

    // === PENALTIES ===
    // Generic/unknown brand
    if (item.isGeneric) {
      score -= 10;
    }

    // Foreign language only (no English match)
    if (item.isForeignLanguage) {
      score -= 15;
    }

    // Name too long (probably noisy/descriptive)
    if (item.nameLength > 80) {
      score -= 8;
    } else if (item.nameLength > 120) {
      score -= 15;
    }

    // Name too short (probably incomplete)
    if (item.nameLength < 5 && score > 0) {
      score *= 0.7;
    }

    // === PLAUSIBILITY CHECK ===
    if (!_caloriesSeemPlausible(item.original)) {
      score *= 0.5; // Suspicious nutrition = major penalty
    }

    return score;
  }

  static bool _wholeWordMatch(String query, String text) {
    final words = text.split(RegExp(r'\s+'));
    return words.contains(query);
  }

  static bool _brandMatchesQuery(String query, String brand, String brandFamily) {
    if (brand.contains(query)) return true;
    if (brandFamily.contains(query)) return true;
    
    // Brand synonym matching
    if (query.contains('coke') || query.contains('cola')) {
      return brandFamily == 'cocacola';
    }
    if (query.contains('pepsi')) {
      return brandFamily == 'pepsi';
    }
    if (query.contains('reese')) {
      return brandFamily == 'reeses';
    }
    
    return false;
  }

  static bool _caloriesSeemPlausible(FoodModel item) {
    if (item.calories == 0) return true; // Diet products OK
    if (item.servingSize == 0 || item.isMissingServing) return true;

    // Calories per 100g/ml should be 0-900 for most foods
    final caloriesPer100 = (item.calories / item.servingSize) * 100;
    return caloriesPer100 >= 0 && caloriesPer100 <= 900;
  }

  // ============================================================================
  // STAGE 3: CANONICAL KEY GROUPING (EXACT DUPLICATES ONLY)
  // ============================================================================

  /// Group items by simple exact-duplicate key (name + calories + serving)
  /// This is LESS aggressive than FoodModel.canonicalKey to preserve variants
  static List<_ScoredItem> _groupByCanonicalKey(List<_ScoredItem> items) {
    final groups = <String, List<_ScoredItem>>{};

    for (final item in items) {
      // Create a simple key: normalized name + calories + serving
      // This only catches TRUE duplicates, not variants
      final key = _buildSimpleCanonicalKey(item.enriched);
      groups.putIfAbsent(key, () => []).add(item);
    }

    final result = <_ScoredItem>[];
    for (final group in groups.values) {
      // Sort by score, take best
      group.sort((a, b) => b.score.compareTo(a.score));
      result.add(group.first);
    }

    return result;
  }
  
  /// Build simple canonical key for exact duplicate detection
  /// Only collapses items with IDENTICAL name and nutrition
  static String _buildSimpleCanonicalKey(_EnrichedItem item) {
    final namePart = item.normalizedName.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
    final caloriesPart = item.original.calories.toString();
    final servingPart = '${item.original.servingSize}${item.original.servingUnit}';
    return '$namePart|$caloriesPart|$servingPart';
  }

  // ============================================================================
  // STAGE 4: FAMILY DEDUPLICATION
  // ============================================================================

  /// Deduplicate language variants and serving-size duplicates
  static List<_ScoredItem> _deduplicateByFamily(
    List<_ScoredItem> items,
    String query,
  ) {
    final families = <String, List<_ScoredItem>>{};

    for (final item in items) {
      final familyKey = _buildFamilyKey(item.enriched);
      families.putIfAbsent(familyKey, () => []).add(item);
    }

    final result = <_ScoredItem>[];
    for (final family in families.values) {
      if (family.length == 1) {
        result.add(family.first);
        continue;
      }

      // Multiple items in same family - pick best representative
      final best = _selectBestFromFamily(family);
      result.add(best);
    }

    return result;
  }

  /// Build family key: brand|productType|dietVariant|flavor|variant
  /// 
  /// Examples:
  /// - "cocacola|soda|regular|none|none" (Original Coke)
  /// - "cocacola|soda|diet|none|none" (Diet Coke)
  /// - "cocacola|soda|zero|none|none" (Coke Zero)
  /// - "cocacola|soda|regular|cherry|wild" (Cherry Coke)
  /// - "pizzahut|pizza|regular|none|pepperoni" (Pizza Hut Pepperoni Pizza)
  static String _buildFamilyKey(_EnrichedItem item) {
    final brand = item.brandFamily;
    final name = item.normalizedName.toLowerCase();
    final brandTokens = item.normalizedBrand.toLowerCase().split(RegExp(r'\s+'));
    
    // Infer product type
    String productType = 'unknown';
    if (name.contains('soda') || name.contains('cola') || name.contains('pop')) {
      productType = 'soda';
    } else if (name.contains('yogurt') || name.contains('yoghurt')) {
      productType = 'yogurt';
    } else if (name.contains('chips') || name.contains('crisps')) {
      productType = 'chips';
    } else if (name.contains('pizza')) {
      productType = 'pizza';
    } else if (name.contains('burger') || name.contains('sandwich')) {
      productType = 'burger';
    } else if (name.contains('candy') || name.contains('chocolate')) {
      productType = 'candy';
    } else if (name.contains('milk')) {
      productType = 'milk';
    } else if (name.contains('cheese')) {
      productType = 'cheese';
    } else if (name.contains('chicken')) {
      productType = 'chicken';
    }

    // Extract diet variant
    String dietVariant = 'regular';
    if (name.contains('diet')) {
      dietVariant = 'diet';
    } else if (name.contains('zero') || name.contains('zéro')) {
      dietVariant = 'zero';
    } else if (name.contains('light') || name.contains('lite')) {
      dietVariant = 'light';
    } else if (name.contains('sugar free') || name.contains('sugarfree')) {
      dietVariant = 'sugar-free';
    }

    // Extract flavor
    const flavors = [
      'cherry', 'vanilla', 'lime', 'lemon', 'orange', 'strawberry',
      'chocolate', 'caramel', 'mint', 'peanut', 'almond',
    ];
    String flavor = 'none';
    for (final f in flavors) {
      if (name.contains(f)) {
        flavor = f;
        break;
      }
    }

    // Extract variant tokens to avoid collapsing distinct products
    final stopTokens = <String>{
      ...brandTokens,
      'brand', 'company', 'co', 'inc', 'ltd',
      'food', 'foods', 'drink', 'beverage',
      'soda', 'cola', 'pop', 'pizza', 'burger', 'sandwich', 'chips',
      'crisps', 'candy', 'chocolate', 'milk', 'cheese', 'chicken', 'yogurt',
      'diet', 'zero', 'light', 'lite', 'sugar', 'free', 'sugarfree',
      'original', 'classic', 'taste', 'gout', 'sabor', 'gusto',
      'flavor', 'flavour', 'flavored', 'flavoured',
      'and', 'with', 'the', 'of', 'a', 'an',
      ...flavors,
    };

    final variantTokens = name
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .where((token) => token.length > 2)
        .where((token) => !stopTokens.contains(token))
        .toList();

    final variantKey = variantTokens.isEmpty ? 'none' : variantTokens.join(' ');

    return '$brand|$productType|$dietVariant|$flavor|$variantKey';
  }

  /// Select best representative from a family
  static _ScoredItem _selectBestFromFamily(List<_ScoredItem> family) {
    // Sort by multiple criteria
    family.sort((a, b) {
      // 1. Higher score first
      final scoreDiff = b.score - a.score;
      if (scoreDiff.abs() > 5) return scoreDiff.sign.toInt();

      // 2. Non-generic brand first
      if (a.enriched.isGeneric != b.enriched.isGeneric) {
        return a.enriched.isGeneric ? 1 : -1;
      }

      // 3. English (non-foreign) first
      if (a.enriched.isForeignLanguage != b.enriched.isForeignLanguage) {
        return a.enriched.isForeignLanguage ? 1 : -1;
      }

      // 4. Shorter name (cleaner)
      return a.enriched.nameLength - b.enriched.nameLength;
    });

    return family.first;
  }

  // ============================================================================
  // DEBUGGING
  // ============================================================================

  static void _debugLog(List<_ScoredItem> results, String query, int limit) {
    print('\n🔍 [FOOD SEARCH PIPELINE] Query: "$query"');
    print('   📥 Final results: ${results.length} (showing top $limit)');
    print('');

    int count = 0;
    for (final item in results.take(limit)) {
      count++;
      print('   ${count.toString().padLeft(2)}. ${item.item.displayTitle}');
      print('       Score: ${item.score.toStringAsFixed(1)} | '
            'Brand: ${item.enriched.brandFamily} | '
            'Calories: ${item.item.calories}cal/${item.item.servingSize}${item.item.servingUnit}');
      if (item.enriched.isForeignLanguage) {
        print('       ⚠️  Foreign language detected');
      }
      if (!item.enriched.hasCompleteServing) {
        print('       ⚠️  Missing serving info');
      }
      print('');
    }
  }
}

// ============================================================================
// INTERNAL DATA CLASSES
// ============================================================================

class _EnrichedItem {
  final FoodModel original;
  final String normalizedName;
  final String normalizedBrand;
  final String normalizedDisplayTitle;
  final int nameLength;
  final bool isGeneric;
  final bool isForeignLanguage;
  final bool hasCompleteServing;
  final bool isUSDA;
  final String brandFamily;

  _EnrichedItem({
    required this.original,
    required this.normalizedName,
    required this.normalizedBrand,
    required this.normalizedDisplayTitle,
    required this.nameLength,
    required this.isGeneric,
    required this.isForeignLanguage,
    required this.hasCompleteServing,
    required this.isUSDA,
    required this.brandFamily,
  });
}

class _ScoredItem {
  final FoodModel item;
  final _EnrichedItem enriched;
  final double score;

  _ScoredItem({
    required this.item,
    required this.enriched,
    required this.score,
  });
}
