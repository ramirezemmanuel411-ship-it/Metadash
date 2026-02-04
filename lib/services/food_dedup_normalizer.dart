/// Advanced deduplication and normalization for food search results
/// Handles accents, diacritics, brand aliases, and smart title selection
class FoodDedupNormalizer {
  /// Product family classifications for grouping variants
  static const String FAMILY_REGULAR = 'REGULAR';
  static const String FAMILY_DIET = 'DIET';
  static const String FAMILY_ZERO = 'ZERO';
  static const String FAMILY_CHERRY = 'CHERRY';
  static const String FAMILY_LIME = 'LIME';
  static const String FAMILY_VANILLA = 'VANILLA';
  static const String FAMILY_LEMON = 'LEMON';
  static const String FAMILY_ORANGE = 'ORANGE';

  /// Language variants that map to REGULAR (original taste)
  static const Set<String> _regularVariants = {
    'original',
    'original taste',
    'gout original',
    'goût original',
    'sabor original',
    'gusto original',
    'classic',
    'classique',
    'clasico',
    'clásico',
  };

  /// Extended brand synonyms mapping (e.g., "coke" ↔ "coca-cola")
  static const Map<String, List<String>> _brandSynonyms = {
    'coca-cola': ['coca cola', 'coke', 'coca', 'coca-cola brand', 'cocacola', 'coke zero', 'coke zero sugar', 'coca-cola zero', 'cola zero'],
    'pepsi': ['pepsi cola', 'pepsico', 'pepsi company'],
    'sprite': ['sprite lemon lime', 'sprite citrus'],
    'fanta': ['fanta orange', 'fanta strawberry', 'fanta grape'],
    'nestle': ['nestle company', 'nestle waters'],
  };

  /// Key "generic" words that shouldn't be the only part of a title
  static const Set<String> _genericWords = {
    'cherry',
    'lime',
    'lemon',
    'orange',
    'original',
    'diet',
    'zero',
    'sugar',
    'regular',
    'classic',
    'vanilla',
    'chocolate',
    'strawberry',
    'cola',
    'drink',
    'soda',
    'beverage',
  };

  /// Remove accents and diacritics: "ZÉRO" → "ZERO", "café" → "cafe"
  /// Uses simple character mapping (no external Unicode library needed)
  static String _removeAccents(String text) {
    if (text.isEmpty) return text;

    const accents = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ý': 'y', 'ỳ': 'y', 'ÿ': 'y',
      'ñ': 'n',
      'ç': 'c',
      'œ': 'oe',
      'æ': 'ae',
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A', 'Å': 'A',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
      'Ý': 'Y',
      'Ñ': 'N',
      'Ç': 'C',
      'Œ': 'OE',
      'Æ': 'AE',
    };

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(accents[char] ?? char);
    }

    return buffer.toString();
  }

  /// Ultra-aggressive text normalization for canonical key matching
  /// Removes accents, punctuation, symbols, packaging noise, collapses spaces
  /// Examples:
  ///   "Coca-Cola ZÉRO®" → "coca cola zero"
  ///   "C.cola™ - Diet" → "c cola diet"
  ///   "diet coke 500ml" → "diet coke"
  ///   "Sprite® Lemon Lime" → "sprite lemon lime"
  static String normalizeForMatching(String text) {
    if (text.isEmpty) return '';

    // Step 1: Remove packaging noise (500ml, PET, 1.25L, etc.)
    String normalized = _removePackagingNoise(text);

    // Step 2: Remove accents (ZÉRO → ZERO)
    normalized = _removeAccents(normalized);

    // Step 3: Convert to lowercase
    normalized = normalized.toLowerCase();

    // Step 4: Replace punctuation with spaces (MUST happen before single-letter removal)
    // "C.COLA" → "c cola" so it can be matched by the abbreviation pattern
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // Step 5: Collapse multiple spaces (before pattern matching)
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Step 6: Remove single-letter brand abbreviations (e.g., "c cola" → "cola")
    // Now "c.cola" has become "c cola" and can be matched
    normalized = normalized.replaceAllMapped(
      RegExp(r'\b[a-z]\s+(cola|coke|sprite|fanta|pepsi)\b'),
      (match) => match.group(1)!,
    );
    
    // Step 7: Normalize "cola zero" to "coke zero" for consistency
    normalized = normalized.replaceAll('cola zero', 'coke zero');

    // Step 8: Final trim
    normalized = normalized.trim();

    return normalized;
  }

  /// Remove packaging noise like "500ml", "1.25L", "PET", "12 oz", etc.
  static String _removePackagingNoise(String text) {
    // Remove common packaging markers
    final packagingPatterns = [
      RegExp(r'\b(PET|BOTTLE|GLASS|CAN|JAR|PKG|PACK)\b', caseSensitive: false),
      RegExp(r'\d+\.?\d*\s*(L|ML|OZ|FL OZ|FL|G|KG)\b', caseSensitive: false),
      RegExp(r'\d+\s*(PACK|COUNT|CT)\b', caseSensitive: false),
    ];

    String result = text;
    for (final pattern in packagingPatterns) {
      result = result.replaceAll(pattern, '');
    }

    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Normalize brand for alias matching
  /// Examples:
  ///   "Coca Cola" → "coca-cola" (via alias mapping)
  ///   "Coke" → "coca-cola"
  ///   "Coca-Cola, Diet Coke, Company" → "coca-cola" (takes first, maps)
  static String normalizeBrand(String brand) {
    if (brand.isEmpty) return '';

    // Step 1: Clean comma-separated brand lists (take first meaningful part)
    String cleaned = _cleanCommaSeparatedBrand(brand);

    // Step 2: Apply basic normalization
    String normalized = normalizeForMatching(cleaned);

    // Step 3: Check brand aliases
    for (final entry in _brandSynonyms.entries) {
      final canonical = entry.key;
      final aliases = entry.value;

      // If normalized brand matches any alias, return canonical form
      for (final alias in aliases) {
        if (normalized == normalizeForMatching(alias)) {
          return canonical;
        }
      }

      // Also check if it matches the canonical form directly
      if (normalized == normalizeForMatching(canonical)) {
        return canonical;
      }
    }

    return normalized;
  }

  /// Clean comma-separated brand strings, take first meaningful part
  /// "Coca-Cola, Diet Coke, Company" → "Coca-Cola"
  /// "McDonald's, Restaurants" → "McDonald's"
  static String _cleanCommaSeparatedBrand(String brand) {
    if (!brand.contains(',')) return brand;

    final parts = brand.split(',').map((s) => s.trim()).toList();
    final noisePatterns = ['restaurant', 'supermarket', 'generic', 'store', 'brand', 'food service', 'company', 'inc', 'sandwiches'];

    // Find first non-noise part
    for (final part in parts) {
      final lower = part.toLowerCase();
      final isNoise = noisePatterns.any((noise) => lower.contains(noise));
      if (!isNoise && part.isNotEmpty) {
        return part;
      }
    }

    // Fallback: return first part
    return parts.first;
  }

  /// Generate a comprehensive canonical key for deduplication
  /// Includes: normalized name + brand + basis + calories (rounded)
  /// Examples:
  ///   Diet Coke | Coca Cola | per100ml | 0 cal
  ///   Coke Zero | Coca-Cola ZÉRO® | per100ml | 0 cal
  /// → Both should have the same key: "diet coke|coca-cola|per100ml|0"
  static String generateCanonicalKey({
    required String name,
    required String? brand,
    required String nutritionBasisType,
    required double servingSize,
    required String servingUnit,
    required int calories,
    required bool isBeverage,
  }) {
    // Normalize name and brand
    final normalizedName = normalizeForMatching(name);
    final normalizedBrand = normalizeBrand(brand ?? '');

    // Fix serving unit for beverages (g → ml)
    String displayUnit = servingUnit;
    if (isBeverage && (servingUnit.toLowerCase() == 'g' || servingUnit.toLowerCase() == 'gram')) {
      displayUnit = 'ml';
    }

    // Round calories to nearest int (0.5 cal difference is noise)
    final roundedCalories = calories.toString();

    // Basis key: e.g., "per100ml_100_ml"
    final basisKey =
        '${nutritionBasisType}_${servingSize.toStringAsFixed(1)}_$displayUnit';

    // Complete key: "diet coke|coca-cola|per100ml_100_ml|0"
    return '$normalizedName|$normalizedBrand|$basisKey|$roundedCalories';
  }

  /// Determine the best displayTitle from multiple candidates
  /// Priority: fullName > brandedName > descriptionName > name > shortName
  /// If title is too short or generic (single word like "Cherry"), upgrade it
  static String selectBestTitle({
    required String? fullName,
    required String? brandedName,
    required String? descriptionName,
    required String name,
    required String? shortName,
  }) {
    // Build priority list of candidates
    final candidates = [
      fullName,
      brandedName,
      descriptionName,
      name,
      shortName,
    ].where((c) => c != null && c.isNotEmpty).cast<String>().toList();

    if (candidates.isEmpty) return name;

    // Find first candidate that's not "too short" or "too generic"
    for (final candidate in candidates) {
      if (_isSuitableTitle(candidate)) {
        return candidate;
      }
    }

    // Fallback: use first non-empty candidate
    return candidates.first;
  }

  /// Check if a title is suitable (not too short/generic)
  /// Too short: < 6 chars
  /// Too generic: single word AND word is in ["cherry", "lime", "diet", etc.]
  static bool _isSuitableTitle(String title) {
    if (title.length >= 6) {
      return true; // Long enough, use it
    }

    // Check if it's a single generic word
    final trimmed = title.trim();
    final words = trimmed.split(RegExp(r'\s+'));

    if (words.length == 1) {
      final wordLower = words[0].toLowerCase();
      if (_genericWords.contains(wordLower)) {
        return false; // Single generic word, skip
      }
    }

    return true; // Not generic, use it
  }

  /// Deduplicate results while preserving rank order
  /// Keeps only the FIRST (highest-ranked) occurrence of each canonical key
  /// Returns deduplicated list in same order as input
  static List<T> deduplicateResults<T>({
    required List<T> items,
    required String Function(T) getCanonicalKey,
    bool debug = false,
  }) {
    final seen = <String>{};
    final deduplicated = <T>[];

    for (final item in items) {
      final key = getCanonicalKey(item);
      if (!seen.contains(key)) {
        seen.add(key);
        deduplicated.add(item);
      } else if (debug) {
        print('  ⚠️  Duplicate detected (skipped): $key');
      }
    }

    return deduplicated;
  }

  /// Determine product family from name
  /// Priority order: DIET > ZERO > flavor variants > REGULAR
  /// 
  /// Examples:
  ///   "Diet Coke" → DIET
  ///   "Coke Zero" → ZERO
  ///   "Cherry Coke" → CHERRY
  ///   "Coca Cola Original Taste" → REGULAR
  ///   "Goût Original" → REGULAR (language variant)
  static String detectProductFamily(String name) {
    final normalized = normalizeForMatching(name);

    // Check for diet variants
    if (normalized.contains('diet') || normalized.contains('light')) {
      return FAMILY_DIET;
    }

    // Check for zero sugar variants
    if (normalized.contains('zero')) {
      return FAMILY_ZERO;
    }

    // Check for flavor variants (order matters - check specific flavors first)
    if (normalized.contains('cherry')) {
      return FAMILY_CHERRY;
    }
    if (normalized.contains('lime')) {
      return FAMILY_LIME;
    }
    if (normalized.contains('vanilla')) {
      return FAMILY_VANILLA;
    }
    if (normalized.contains('lemon')) {
      return FAMILY_LEMON;
    }
    if (normalized.contains('orange')) {
      return FAMILY_ORANGE;
    }

    // Check if it's a "regular/original" variant
    if (_regularVariants.contains(normalized)) {
      return FAMILY_REGULAR;
    }

    // Default: treat as REGULAR if no specific family detected
    return FAMILY_REGULAR;
  }

  /// Generate product family key for family-level deduplication
  /// Format: "normalizedBrand|productFamily"
  /// 
  /// Examples:
  ///   "Original Taste" + "Coca-Cola" → "coca-cola|REGULAR"
  ///   "Goût Original" + "coke" → "coca-cola|REGULAR" (same key!)
  ///   "Diet Coke" + "Coca-Cola" → "coca-cola|DIET"
  static String generateProductFamilyKey({
    required String name,
    required String? brand,
  }) {
    final normalizedBrand = normalizeBrand(brand ?? '');
    final family = detectProductFamily(name);
    return '$normalizedBrand|$family';
  }

  /// Deduplicate at product family level
  /// Groups items by family key, selects best representative from each group
  /// 
  /// Selection criteria (priority order):
  /// 1. Branded items > generic items (has recognizable brand)
  /// 2. Longer, more descriptive titles
  /// 3. Calories closest to expected baseline (for REGULAR family)
  /// 
  /// Returns one item per family, preserving relative rank order
  static List<T> deduplicateByProductFamily<T>({
    required List<T> items,
    required String Function(T) getName,
    required String? Function(T) getBrand,
    required int Function(T) getCalories,
    bool debug = false,
  }) {
    if (items.isEmpty) return items;

    // Group items by family key
    final familyGroups = <String, List<T>>{};
    
    for (final item in items) {
      final familyKey = generateProductFamilyKey(
        name: getName(item),
        brand: getBrand(item),
      );
      familyGroups.putIfAbsent(familyKey, () => []).add(item);
    }

    if (debug) {
      print('\n🔍 Product Family Deduplication:');
      print('  Total items: ${items.length}');
      print('  Unique families: ${familyGroups.length}');
    }

    // Select best representative from each family
    final representatives = <T>[];
    
    for (final entry in familyGroups.entries) {
      final familyKey = entry.key;
      final candidates = entry.value;

      if (candidates.length == 1) {
        representatives.add(candidates.first);
        continue;
      }

      // Multiple candidates - select best one
      final best = _selectBestFamilyRepresentative(
        candidates: candidates,
        getName: getName,
        getBrand: getBrand,
        getCalories: getCalories,
        familyKey: familyKey,
      );

      representatives.add(best);

      if (debug) {
        print('  Family: $familyKey');
        print('    Candidates: ${candidates.length}');
        print('    Selected: ${getName(best)}');
        if (candidates.length > 1) {
          print('    Collapsed: ${candidates.where((c) => c != best).map((c) => getName(c)).join(", ")}');
        }
      }
    }

    // Preserve original ranking order among representatives
    final originalOrder = <T, int>{};
    for (int i = 0; i < items.length; i++) {
      originalOrder[items[i]] = i;
    }

    representatives.sort((a, b) {
      final indexA = originalOrder[a] ?? items.length;
      final indexB = originalOrder[b] ?? items.length;
      return indexA.compareTo(indexB);
    });

    return representatives;
  }

  /// Select the best representative from a family group
  static T _selectBestFamilyRepresentative<T>({
    required List<T> candidates,
    required String Function(T) getName,
    required String? Function(T) getBrand,
    required int Function(T) getCalories,
    required String familyKey,
  }) {
    // Score each candidate
    final scored = candidates.map((item) {
      int score = 0;

      final name = getName(item);
      final brand = getBrand(item);
      final calories = getCalories(item);

      // 1. Branded items get +100 points
      final normalizedBrand = normalizeBrand(brand ?? '');
      final hasBrand = normalizedBrand.isNotEmpty && 
                      normalizedBrand != 'generic' && 
                      normalizedBrand != 'unknown';
      if (hasBrand) {
        score += 100;
      }

      // 2. Longer titles get +1 point per character (capped at +50)
      final titleLength = name.length;
      score += (titleLength).clamp(0, 50);

      // 3. For REGULAR family, prefer calories near 42 kcal/100ml (typical Coke)
      if (familyKey.contains('|REGULAR')) {
        final caloriesDiff = (calories - 42).abs();
        final caloriesPenalty = caloriesDiff * 2; // -2 points per calorie difference
        score -= caloriesPenalty;
      }

      // 4. Avoid generic words as standalone titles
      final normalized = normalizeForMatching(name);
      if (_regularVariants.contains(normalized)) {
        score -= 20; // Penalty for generic "Original Taste" etc
      }

      return (item: item, score: score);
    }).toList();

    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.first.item;
  }
}
