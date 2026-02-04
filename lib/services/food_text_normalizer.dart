/// Single source of truth for food text normalization
/// Ensures consistent display across all food search interfaces
class FoodTextNormalizer {
  /// Brand synonyms for intelligent matching (e.g., "coke" → "coca-cola")
  static const Map<String, List<String>> _brandSynonyms = {
    'coca-cola': ['coca cola', 'coke', 'coca', 'coca-cola brand'],
    'pepsi': ['pepsi cola', 'pepsico'],
    'sprite': ['sprite lemon lime'],
    'fanta': ['fanta orange', 'fanta strawberry'],
  };

  /// Normalize food text: trim, fix casing, remove duplicates, etc.
  static String normalize(String text, {bool debug = false}) {
    if (text.isEmpty) return text;

    // Step 1: Trim whitespace
    String normalized = text.trim();
    if (debug) print('  [normalize] Step 1 (trim): "$normalized"');

    // Step 2: Handle casing - BOTH all-caps AND mostly-lowercase
    // This catches both "COCA COLA" and "diet coke" and "PET 1.25L C.cola"
    final isUppercase = _isMostlyUppercase(normalized);
    final isLowercase = _isMostlyLowercase(normalized);
    
    if (debug) print('  [normalize] isUppercase: $isUppercase, isLowercase: $isLowercase');
    
    if (isUppercase) {
      normalized = _toTitleCasePreservingAcronyms(normalized);
      if (debug) print('  [normalize] Step 2 (uppercase→title): "$normalized"');
    } else if (isLowercase) {
      // Convert mostly-lowercase to Title Case too
      normalized = _toTitleCasePreservingAcronyms(normalized);
      if (debug) print('  [normalize] Step 2 (lowercase→title): "$normalized"');
    }

    // Step 3: Standardize spacing and separators
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' '); // Multiple spaces → single
    normalized = normalized.replaceAll('_', ' '); // Underscores → spaces
    normalized = normalized.replaceAll('-', ' '); // Dashes → spaces (keep hyphens in compounds)
    if (debug) print('  [normalize] Step 3 (spacing): "$normalized"');

    // Step 4: Remove packaging info noise (e.g., "500ml", "PET", "1.25L")
    normalized = _removePackagingNoise(normalized);
    if (debug) print('  [normalize] Step 4 (packaging): "$normalized"');

    // Step 5: Remove duplicate brand terms
    normalized = _removeDuplicateBrandTerms(normalized);
    if (debug) print('  [normalize] Step 5 (dedup): "$normalized"');

    return normalized;
  }

  /// Clean brand string: pick best brand and drop noisy tags
  /// Examples:
  ///   "Coca Cola,Coke" → "Coca Cola"
  ///   "McDonald's,Restaurants" → "McDonald's"
  ///   "Generic,Supermarket" → "" (drop generic markers)
  static String cleanBrandString(String brand) {
    if (brand.isEmpty) return '';

    // Split by comma and take first meaningful term
    final parts = brand.split(',').map((s) => s.trim()).toList();
    
    // Filter out noise and generic markers
    final noisePatterns = ['restaurant', 'supermarket', 'generic', 'store', 'brand', 'food service'];
    final cleaned = parts.where((part) {
      final lower = part.toLowerCase();
      return part.isNotEmpty && 
             !noisePatterns.any((noise) => lower.contains(noise));
    }).toList();

    if (cleaned.isEmpty) return '';

    // Normalize the best brand option
    return normalize(cleaned.first);
  }

  /// Check if text is mostly uppercase (likely needs conversion)
  static bool _isMostlyUppercase(String text) {
    final lettersOnly = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (lettersOnly.isEmpty) return false;

    final uppercaseCount = lettersOnly.split('').where((c) => c == c.toUpperCase()).length;
    return uppercaseCount / lettersOnly.length > 0.75; // 75% uppercase threshold
  }

  /// Check if text is mostly lowercase (database entries often are)
  static bool _isMostlyLowercase(String text) {
    final lettersOnly = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (lettersOnly.isEmpty) return false;

    final lowercaseCount = lettersOnly.split('').where((c) => c == c.toLowerCase()).length;
    return lowercaseCount / lettersOnly.length > 0.75; // 75% lowercase threshold
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

  /// Convert ALL CAPS to Title Case while preserving acronyms
  /// Examples:
  ///   "COCA COLA" → "Coca Cola"
  ///   "USDA APPROVED" → "USDA Approved"
  ///   "CHERRY FLAVORED COKE" → "Cherry Flavored Coke"
  static String _toTitleCasePreservingAcronyms(String text) {
    final words = text.split(' ');
    final result = words.map((word) {
      if (word.isEmpty) return word;

      // If word is 1-3 uppercase letters, treat as acronym
      if (word.length <= 3 && word == word.toUpperCase()) {
        return word; // Keep: USA, FDA, GM
      }

      // Otherwise: first letter uppercase, rest lowercase
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    return result;
  }

  /// Remove duplicate brand terms (e.g., "Coca Cola Coca Cola" → "Coca Cola")
  static String _removeDuplicateBrandTerms(String text) {
    final words = text.split(' ');
    final seen = <String>{};
    final result = <String>[];

    for (final word in words) {
      final wordLower = word.toLowerCase();
      // Skip if we've already seen this word (case-insensitive)
      if (!seen.contains(wordLower)) {
        result.add(word);
        seen.add(wordLower);
      }
    }

    return result.join(' ');
  }

  /// Get canonical brand name for a query (synonym mapping)
  /// Example: "coke" → "coca-cola"
  static String getCanonicalBrand(String query) {
    final queryLower = query.toLowerCase().trim();
    
    for (final entry in _brandSynonyms.entries) {
      final canonical = entry.key;
      final synonyms = entry.value;
      if (synonyms.any((s) => s.contains(queryLower) || queryLower.contains(s))) {
        return canonical;
      }
    }
    
    return queryLower;
  }

  /// Fuzzy match: does normalized query appear in normalized text?
  static bool fuzzyMatch(String query, String text) {
    return normalize(text).toLowerCase().contains(normalize(query).toLowerCase());
  }

  /// Whole word match (better for exact category matching)
  static bool wholeWordMatch(String query, String text) {
    final queryLower = normalize(query).toLowerCase();
    final textLower = normalize(text).toLowerCase();
    final words = textLower.split(RegExp(r'[\s,;:]'));
    return words.any((word) => word == queryLower);
  }

  /// Prefix match (starts with query)
  static bool prefixMatch(String query, String text) {
    return normalize(text).toLowerCase().startsWith(normalize(query).toLowerCase());
  }

  /// Check if brand matches query (using synonyms)
  static bool isBrandMatch(String query, String? brand) {
    if (brand == null || brand.isEmpty) return false;
    
    final canonical = getCanonicalBrand(query);
    final brandLower = brand.toLowerCase();
    
    // Direct match
    if (brandLower.contains(canonical)) return true;
    
    // Check if any synonym matches
    if (_brandSynonyms.containsKey(canonical)) {
      return _brandSynonyms[canonical]!.any((syn) => brandLower.contains(syn));
    }
    
    return false;
  }
}
