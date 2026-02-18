// ignore_for_file: avoid_print

import '../data/models/food_model.dart';

/// Enhanced food deduplication with improved core name inference
/// Specifically handles language variants and "Original Taste" collapsing
class FoodDeduplicationService {
  // ==================== NORMALIZATION ====================
  
  /// Normalize text: lowercase, remove diacritics, punctuation, collapse spaces
  static String normalizeText(String text) {
    if (text.isEmpty) return '';
    
    String result = _removeDiacritics(text);
    result = result.toLowerCase();
    result = result.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    return result.trim();
  }

  static String _removeDiacritics(String text) {
    const accents = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ý': 'y', 'ỳ': 'y', 'ÿ': 'y',
      'ñ': 'n', 'ç': 'c', 'œ': 'oe', 'æ': 'ae',
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A', 'Å': 'A',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
      'Ý': 'Y', 'Ñ': 'N', 'Ç': 'C', 'Œ': 'OE', 'Æ': 'AE',
    };
    
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(accents[text[i]] ?? text[i]);
    }
    return buffer.toString();
  }

  // ==================== BRAND NORMALIZATION ====================

  /// Normalize brand with alias mapping
  static String normalizeBrand(String? rawBrand, String? rawName) {
    if (rawBrand == null || rawBrand.isEmpty) {
      // If no brand but name contains cola/coke, infer brand
      if (rawName != null) {
        final nameNorm = normalizeText(rawName);
        if (nameNorm.contains('coca') || nameNorm.contains('coke')) {
          return 'coca-cola';
        }
        if (nameNorm.contains('pepsi')) return 'pepsi';
        if (nameNorm.contains('sprite')) return 'sprite';
        if (nameNorm.contains('fanta')) return 'fanta';
      }
      return 'generic';
    }

    final normalized = normalizeText(rawBrand);

    // Brand aliases mapping
    const aliases = {
      'coca cola': 'coca-cola',
      'coke': 'coca-cola',
      'coca': 'coca-cola',
      'cocacola': 'coca-cola',
      'pepsi cola': 'pepsi',
      'pepsico': 'pepsi',
      'mountain dew': 'mountaindew',
      'frito lay': 'fritolay',
      'general mills': 'generalmills',
    };

    for (final entry in aliases.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }

    // Handle comma-separated brands - take first meaningful part
    if (normalized.contains(',')) {
      final parts = normalized.split(',').map((s) => s.trim()).toList();
      for (final part in parts) {
        if (part.isNotEmpty && !_isNoisyBrand(part)) {
          return part.replaceAll(' ', '');
        }
      }
    }

    return normalized.replaceAll(' ', '');
  }

  static bool _isNoisyBrand(String brand) {
    const noise = ['restaurant', 'supermarket', 'generic', 'store', 'company', 'inc', 'ltd', 'food service'];
    return noise.any((n) => brand.contains(n));
  }

  // ==================== DIET TYPE EXTRACTION ====================

  static String extractDietType(String nameNorm) {
    if (nameNorm.contains('diet')) return 'diet';
    if (nameNorm.contains('zero') || 
        nameNorm.contains('zéro') || 
        nameNorm.contains('0 sugar') || 
        nameNorm.contains('no sugar')) {
      return 'zero';
    }
    if (nameNorm.contains('sugar free') || nameNorm.contains('sugarfree')) return 'sugar-free';
    if (nameNorm.contains('light') || nameNorm.contains('lite')) return 'light';
    if (nameNorm.contains('low calorie')) return 'low-cal';
    return 'regular';
  }

  // ==================== FLAVOR EXTRACTION ====================

  static String extractFlavor(String nameNorm) {
    const flavors = [
      'cherry', 'vanilla', 'lime', 'lemon', 'orange', 'strawberry',
      'raspberry', 'blueberry', 'mango', 'peach', 'grape', 'apple',
      'pineapple', 'coconut', 'banana', 'chocolate', 'caramel',
      'mint', 'cinnamon', 'ginger', 'coffee', 'mocha', 'hazelnut',
      'almond', 'peanut butter', 'honey', 'maple', 'berry', 'citrus',
    ];

    for (final flavor in flavors) {
      if (nameNorm.contains(flavor)) return flavor;
    }
    return 'none';
  }

  // ==================== CORE NAME INFERENCE (THE KEY!) ====================

  /// Infer the true core product name by removing brand, variants, and marketing fluff
  /// Examples:
  ///   "Original Taste" + "coca-cola" -> "cola"
  ///   "Coca cola Goût Original" + "coca-cola" -> "cola"
  ///   "Sabor Original Coke" + "coca-cola" -> "cola"
  ///   "Diet Coke" + "coca-cola" -> "coke" (diet is variant, not core)
  ///   "Cherry Coke" + "coca-cola" -> "coke" (cherry is flavor, not core)
  static String inferCoreName({
    required String nameNorm,
    required String brandNorm,
    required String queryNorm,
    required String dietType,
    required String flavor,
  }) {
    String core = nameNorm;

    // 1. Remove brand tokens
    const brandKeywords = ['coca', 'cola', 'coke', 'coca cola', 'coca-cola', 'cocacola'];
    for (final keyword in brandKeywords) {
      core = core.replaceAll(keyword, ' ');
    }

    // 2. Remove diet/variant tokens
    const variantTokens = [
      'diet', 'zero', 'zéro', 'sugar free', 'light', 'lite',
      'regular', 'original', 'classic', 'traditional',
      'authentic', 'real', 'new', 'improved',
    ];
    for (final token in variantTokens) {
      core = core.replaceAll(token, ' ');
    }

    // 3. Remove language-specific "Original Taste" variants
    const styleTokens = [
      'gout original', 'goût original', 'gout', 'goût',
      'sabor original', 'sabor',
      'gusto original', 'gusto',
      'original taste', 'taste',
      'flavor', 'flavored', 'flavour', 'flavoured',
      'classique', 'clasico', 'clásico', 'tradicional',
      'autentico', 'autêntico', 'autentique',
    ];
    for (final token in styleTokens) {
      core = core.replaceAll(token, ' ');
    }

    // 4. Remove packaging/size tokens
    core = core.replaceAll(RegExp(r'\d+\.?\d*\s*(ml|l|oz|g|kg|lb|pack|count|ct|pc)\b'), ' ');
    core = core.replaceAll(RegExp(r'\b(mini|can|bottle|glass|plastic|pet|aluminum)\b'), ' ');

    // 5. Remove flavor tokens (if already extracted as separate attribute)
    if (flavor != 'none') {
      core = core.replaceAll(flavor, ' ');
    }

    // 6. Clean up
    core = core.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 7. If core is now empty or just generic words, infer from brand or query
    if (core.isEmpty || 
        core == 'original' || 
        core == 'taste' || 
        core == 'flavor' ||
        core == 'original taste' ||
        core == 'gout original' ||
        core == 'sabor original') {
      
      // Infer core from brand
      if (brandNorm == 'coca-cola') {
        return 'cola';
      }
      if (brandNorm == 'pepsi') {
        return 'pepsi';
      }
      if (brandNorm == 'sprite') {
        return 'sprite';
      }

      // Infer from query
      if (queryNorm.contains('coke')) return 'coke';
      if (queryNorm.contains('cola')) return 'cola';
      if (queryNorm.contains('pepsi')) return 'pepsi';
      if (queryNorm.contains('sprite')) return 'sprite';

      return 'product'; // Generic fallback
    }

    return core;
  }

  // ==================== FAMILY SIGNATURE GENERATION ====================

  static String buildFamilySignature({
    required String name,
    required String? brand,
    required String query,
  }) {
    final nameNorm = normalizeText(name);
    final brandNorm = normalizeBrand(brand, name);
    final queryNorm = normalizeText(query);

    final dietType = extractDietType(nameNorm);
    final flavor = extractFlavor(nameNorm);
    
    final coreName = inferCoreName(
      nameNorm: nameNorm,
      brandNorm: brandNorm,
      queryNorm: queryNorm,
      dietType: dietType,
      flavor: flavor,
    );

    return '$brandNorm|$coreName|$dietType|$flavor';
  }

  // ==================== GROUPING & SELECTION ====================

  static DeduplicationResult deduplicateByFamily({
    required List<FoodModel> items,
    required String query,
    bool debug = false,
  }) {
    if (items.isEmpty) {
      return DeduplicationResult(groupedResults: [], familyVariantsMap: {});
    }

    final queryNorm = normalizeText(query);

    print('\n${'='*60}');
    print('[DEDUP] Query: "$query" (norm: "$queryNorm")');
    print('[DEDUP] Raw items: ${items.length}');

    // Group by family signature
    final familyGroups = <String, List<FoodModel>>{};

    for (final item in items) {
      final sig = buildFamilySignature(
        name: item.name,
        brand: item.brand,
        query: query,
      );
      familyGroups.putIfAbsent(sig, () => []).add(item);

      if (debug) {
        print('[  ] "${item.displayTitle}" → $sig');
      }
    }

    print('[DEDUP] Family groups: ${familyGroups.length}');

    // Select best representative from each family
    final representatives = <FoodModel>[];
    final variantsMap = <String, List<FoodModel>>{};

    int collapsed = 0;
    for (final entry in familyGroups.entries) {
      final sig = entry.key;
      final candidates = entry.value;

      if (candidates.length > 1) {
        collapsed += (candidates.length - 1);
      }

      final best = _selectBestRepresentative(candidates);
      representatives.add(best);
      variantsMap[sig] = candidates;

      if (candidates.length > 1) {
        print('[✓] Family: $sig');
        print('    Candidates: ${candidates.length}');
        print('    Selected: "${best.displayTitle}" (${best.source})');
        print('    Collapsed: ${candidates.where((c) => c.id != best.id).map((c) => '"${c.displayTitle}" (${c.source})').join(", ")}');
      }
    }

    print('[DEDUP] Collapsed: $collapsed duplicates');
    print('[DEDUP] Final output: ${representatives.length} items');

    // Debug: print top 25 results with full info
    print('\n[DEBUG] Top 25 results:');
    for (int i = 0; i < representatives.length && i < 25; i++) {
      final item = representatives[i];
      final sig = buildFamilySignature(
        name: item.name,
        brand: item.brand,
        query: query,
      );
      print('[${(i+1).toString().padLeft(2)}] "${item.displayTitle}" '
          '| brand="${item.brand ?? "?"}" '
          '| ${item.calories} cal '
          '| source=${item.source} '
          '| sig=$sig');
    }
    print('${'='*60}\n');

    // Second pass: ensure uniqueness (safety net)
    _ensureUniqueFamilySignatures(representatives, query);

    // Preserve original ranking order
    final originalOrder = {for (var i = 0; i < items.length; i++) items[i].id: i};
    representatives.sort((a, b) {
      final idxA = originalOrder[a.id] ?? items.length;
      final idxB = originalOrder[b.id] ?? items.length;
      return idxA.compareTo(idxB);
    });

    return DeduplicationResult(
      groupedResults: representatives,
      familyVariantsMap: variantsMap,
    );
  }

  /// Ensure no duplicate family signatures in the results (safety net)
  static void _ensureUniqueFamilySignatures(List<FoodModel> items, String query) {
    final seen = <String>{};
    final duplicates = <String>[];

    for (final item in items) {
      final sig = buildFamilySignature(
        name: item.name,
        brand: item.brand,
        query: query,
      );
      if (seen.contains(sig)) {
        duplicates.add('$sig: "${item.displayTitle}"');
      }
      seen.add(sig);
    }

    if (duplicates.isNotEmpty) {
      print('[⚠️ WARNING] Found duplicate family signatures after dedup:');
      for (final dup in duplicates) {
        print('  - $dup');
      }
    }
  }

  static FoodModel _selectBestRepresentative(List<FoodModel> candidates) {
    if (candidates.length == 1) return candidates.first;

    final scored = candidates.map((item) {
      int score = 0;

      // 1. Branded items (+1000)
      if (item.brand != null && item.brand!.isNotEmpty && 
          !item.brand!.toLowerCase().contains('generic')) {
        score += 1000;
      }

      // 2. Complete nutrition fields (+50 each)
      int fields = 0;
      if (item.calories > 0) fields++;
      if (item.protein > 0) fields++;
      if (item.fat > 0) fields++;
      if (item.carbs > 0) fields++;
      if (item.servingUnit.isNotEmpty) fields++;
      score += fields * 50;

      // 3. Text quality (+0 to +100)
      score += _calculateTextQuality(item.name);

      // 4. Preferred source (+50 to +100)
      if (item.source == 'usda') {
        score += 100;
      } else if (item.source == 'open_food_facts') {
        score += 80;
      } else {
        score += 50;
      }

      // 5. Avoid "USDA" as source for non-USDA queries (-30 if USDA)
      if (item.source == 'usda') score -= 10;

      // 6. Longer descriptive title (+1 per 2 chars, max +30)
      score += (item.name.length ~/ 2).clamp(0, 30);

      return (item: item, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.first.item;
  }

  static int _calculateTextQuality(String text) {
    int score = 100;

    // Penalize ALL CAPS
    final upperCount = text.replaceAll(RegExp(r'[^A-Z]'), '').length;
    final totalLetters = text.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
    if (totalLetters > 0) {
      final ratio = upperCount / totalLetters;
      if (ratio > 0.8) {
        score -= 30;
      } else if (ratio > 0.5) {
        score -= 15;
      }
    }

    // Penalize weird tokens
    if (text.contains(RegExp(r'[®™©]'))) score -= 5;
    if (text.contains(RegExp(r'\d{3,}'))) score -= 10;

    // Reward proper capitalization
    if (text.isNotEmpty && text[0] == text[0].toUpperCase()) score += 10;

    return score.clamp(0, 100);
  }
}

/// Result of deduplication
class DeduplicationResult {
  final List<FoodModel> groupedResults;
  final Map<String, List<FoodModel>> familyVariantsMap;

  DeduplicationResult({
    required this.groupedResults,
    required this.familyVariantsMap,
  });
}
