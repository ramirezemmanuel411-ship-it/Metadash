import '../data/models/food_model.dart';

/// Universal food deduplication system
/// Works across all brands and product categories (beverages, dairy, snacks, etc.)
class UniversalFoodDeduper {
  /// Normalize text: lowercase, remove diacritics, punctuation, collapse spaces
  static String normalize(String text) {
    if (text.isEmpty) return '';
    
    String result = _removeDiacritics(text);
    result = result.toLowerCase();
    result = result.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    return result.trim();
  }

  /// Remove diacritics and accents
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

  /// Extract variant attributes from normalized text
  static ProductVariants extractVariants(String normalizedText) {
    return ProductVariants(
      dietType: _extractDietType(normalizedText),
      flavor: _extractFlavor(normalizedText),
      caffeine: _extractCaffeine(normalizedText),
      format: _extractFormat(normalizedText),
      fatLevel: _extractFatLevel(normalizedText),
      prep: _extractPrep(normalizedText),
    );
  }

  static String _extractDietType(String text) {
    if (text.contains('diet')) return 'diet';
    // Handle all variations of "zero" including accented versions
    if (text.contains('zero sugar') || text.contains('zero cal')) return 'zero';
    if (text.contains('zero') || text.contains('zéro') || text.contains('0 sugar')) return 'zero';
    if (text.contains('sugar free') || text.contains('sugarfree')) return 'sugar-free';
    if (text.contains('light') || text.contains('lite')) return 'light';
    if (text.contains('low calorie')) return 'low-cal';
    return 'regular';
  }

  static String _extractFlavor(String text) {
    const flavors = [
      'cherry', 'vanilla', 'lime', 'lemon', 'orange', 'strawberry', 
      'raspberry', 'blueberry', 'mango', 'peach', 'grape', 'apple',
      'pineapple', 'coconut', 'banana', 'chocolate', 'caramel',
      'mint', 'cinnamon', 'ginger', 'coffee', 'mocha', 'hazelnut',
      'almond', 'peanut butter', 'honey', 'maple', 'berry', 'citrus',
    ];
    
    for (final flavor in flavors) {
      if (text.contains(flavor)) return flavor;
    }
    return 'none';
  }

  static String _extractCaffeine(String text) {
    if (text.contains('caffeine free') || text.contains('decaf')) {
      return 'caffeine-free';
    }
    if (text.contains('caffeinated')) return 'caffeinated';
    return '';
  }

  static String _extractFormat(String text) {
    if (text.contains('mini can') || text.contains('sleek can')) return 'mini-can';
    if (text.contains('can')) return 'can';
    if (text.contains('bottle')) return 'bottle';
    if (text.contains('fountain')) return 'fountain';
    if (text.contains('powder')) return 'powder';
    if (text.contains('bar')) return 'bar';
    if (text.contains('chips') || text.contains('crisps')) return 'chips';
    if (text.contains('snack pack')) return 'snack-pack';
    return '';
  }

  static String _extractFatLevel(String text) {
    if (text.contains('nonfat') || text.contains('non fat') || text.contains('fat free')) {
      return 'nonfat';
    }
    if (text.contains('skim')) return 'skim';
    if (text.contains('1%') || text.contains('1 percent')) return '1%';
    if (text.contains('2%') || text.contains('2 percent')) return '2%';
    if (text.contains('whole milk')) return 'whole';
    if (text.contains('lowfat') || text.contains('low fat')) return 'lowfat';
    return '';
  }

  static String _extractPrep(String text) {
    if (text.contains('raw')) return 'raw';
    if (text.contains('cooked')) return 'cooked';
    if (text.contains('frozen')) return 'frozen';
    if (text.contains('ready to eat')) return 'ready-to-eat';
    if (text.contains('canned')) return 'canned';
    if (text.contains('dried')) return 'dried';
    return '';
  }

  /// Infer core name: remove brand, stop tokens, and packaging
  static String inferCoreName(String normalizedText, ProductVariants variants, {String? brandNorm, String? queryNorm}) {
    String core = normalizedText;
    
    // Step 1: Remove brand tokens first
    const brandTokens = ['coca', 'coke', 'cola', 'coca-cola', 'coca cola'];
    for (final token in brandTokens) {
      core = core.replaceAll(token, ' ');
    }
    
    // Step 2: Remove stop tokens (marketing, language variants)
    const stopTokens = [
      // Marketing variants
      'brand', 'flavored', 'flavour', 'flavor', 'mini', 'cans', 'can', 'bottle',
      'original', 'classic', 'traditional', 'authentic',
      'original taste', 'goût original', 'gout original', 'sabor original',
      'classique', 'traditionnel', 'clasico', 'clásico', 'tradicional',
      'gusto original', 'gusto', 'taste', 'product', 'made with',
      'new', 'improved', 'premium', 'special',
    ];
    
    for (final token in stopTokens) {
      core = core.replaceAll(token, ' ');
    }
    
    // Step 3: Remove diet/flavor/caffeine tokens
    if (variants.dietType.isNotEmpty && variants.dietType != 'regular') {
      core = core.replaceAll(variants.dietType, ' ');
    }
    if (variants.flavor.isNotEmpty && variants.flavor != 'none') {
      core = core.replaceAll(variants.flavor, ' ');
    }
    if (variants.caffeine.isNotEmpty) {
      core = core.replaceAll(variants.caffeine, ' ');
    }
    
    // Step 4: Remove packaging and units
    core = core.replaceAll(RegExp(r'\d+\.?\d*\s*(ml|l|oz|g|kg|lb|pack|count|ct|pc)\b'), ' ');
    core = core.replaceAll(RegExp(r'\b(pet|glass|plastic|aluminum)\b'), ' ');
    core = core.replaceAll(RegExp(r'\d+\s*(mg|mcg|cal|kcal)\b'), ' ');
    
    // Step 5: Clean up
    core = core.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Step 6: If empty, infer from brand or query
    if (core.isEmpty) {
      if (brandNorm == 'coca-cola') return 'cola';
      if (queryNorm != null && queryNorm.contains('coke')) return 'coke';
      if (queryNorm != null && queryNorm.contains('cola')) return 'cola';
      if (normalizedText.contains('coca') || normalizedText.contains('coke')) return 'cola';
      return 'product';
    }
    
    return core;
  }

  /// Build core key: remove variant tokens, marketing words, sizes, packaging (DEPRECATED)
  static String buildCoreKey(String normalizedText, ProductVariants variants) {
    String core = normalizedText;
    
    // Remove variant tokens already extracted
    final variantTokens = [
      variants.dietType,
      variants.flavor,
      variants.caffeine,
      variants.format,
      variants.fatLevel,
      variants.prep,
      'diet', 'zero', 'sugar free', 'light', 'lite', 'caffeine free',
      'mini can', 'can', 'bottle', 'fountain', 'powder', 'bar',
      'nonfat', 'skim', 'lowfat', 'whole milk',
      'raw', 'cooked', 'frozen', 'ready to eat',
    ];
    
    for (final token in variantTokens) {
      if (token.isNotEmpty) {
        core = core.replaceAll(token, ' ');
      }
    }
    
    // Remove marketing/language variants - EXPANDED LIST
    const marketingWords = [
      // English
      'original', 'classic', 'traditional', 'authentic', 'real',
      'original taste', 'classic taste', 
      'taste', 'flavor', 'flavored', 'flavour', 'flavoured',
      // French
      'gout original', 'goût original', 'gout', 'goût', 
      'classique', 'traditionnel',
      // Spanish
      'sabor original', 'sabor', 'gusto original', 'gusto',
      'clasico', 'clásico', 'tradicional',
      // Italian
      'gusto', 'classico', 'tradizionale',
      // Portuguese
      'sabor', 'classico', 'tradicional',
      // Generic marketing
      'brand', 'product', 'made with', 'contains',
      'new', 'improved', 'premium', 'deluxe', 'special',
      'quality', 'best', 'great', 'perfect',
    ];
    
    for (final word in marketingWords) {
      core = core.replaceAll(word, ' ');
    }
    
    // Remove sizes and packaging
    core = core.replaceAll(RegExp(r'\d+\.?\d*\s*(ml|l|oz|g|kg|lb|pack|count|ct|pc)\b'), ' ');
    core = core.replaceAll(RegExp(r'\b(pet|glass|plastic|aluminum)\b'), ' ');
    
    // Normalize common product name variations
    // "coca cola" and "coke" should map to same core
    core = core.replaceAll('coca cola', 'cola');
    core = core.replaceAll('coca', 'cola');
    
    // Collapse spaces and trim
    core = core.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // If core is empty after all removals, infer from common brands
    if (core.isEmpty || core == 'product') {
      if (normalizedText.contains('coca') || normalizedText.contains('coke')) {
        return 'cola';
      } else if (normalizedText.contains('pepsi')) {
        return 'pepsi';
      } else if (normalizedText.contains('sprite')) {
        return 'sprite';
      } else if (normalizedText.contains('fanta')) {
        return 'fanta';
      } else {
        return 'product';
      }
    }
    
    return core;
  }

  /// Normalize brand name with smart inference
  static String normalizeBrand(String? brandRaw, String? nameNorm) {
    // If brand is empty/null, try to infer from name
    if (brandRaw == null || brandRaw.isEmpty) {
      if (nameNorm == null) return 'generic';
      if (nameNorm.contains('coca') || nameNorm.contains('coke')) return 'coca-cola';
      if (nameNorm.contains('pepsi')) return 'pepsi';
      if (nameNorm.contains('sprite')) return 'sprite';
      if (nameNorm.contains('fanta')) return 'fanta';
      return 'generic';
    }
    
    // Don't allow "USDA" or similar source names to become brand
    if (brandRaw.toLowerCase() == 'usda' || brandRaw.toLowerCase() == '?') {
      return 'generic';
    }
    
    final normalized = normalize(brandRaw);
    
    // Brand aliases: map variations to canonical forms
    const brandAliases = {
      'coke': 'coca-cola',
      'coca cola': 'coca-cola',
      'coca-cola': 'coca-cola',
      'coca': 'coca-cola',
      'the coca-cola company': 'coca-cola',
      'coca cola company': 'coca-cola',
      'pepsi cola': 'pepsi',
      'pepsi': 'pepsi',
      'mountain dew': 'mountain-dew',
      'dr pepper': 'dr-pepper',
      'frito lay': 'frito-lay',
      'kraft': 'kraft',
      'danone': 'danone',
      'dannon': 'danone',
      'general mills': 'general-mills',
    };
    
    // Check each alias
    for (final entry in brandAliases.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // Handle comma-separated brands: take first non-noise
    if (normalized.contains(',')) {
      final parts = normalized.split(',').map((s) => s.trim()).toList();
      for (final part in parts) {
        if (part.isNotEmpty && !_isNoiseBrand(part)) {
          // Check aliases for this part
          for (final entry in brandAliases.entries) {
            if (part.contains(entry.key)) {
              return entry.value;
            }
          }
          return part.replaceAll(' ', '-');
        }
      }
    }
    
    return normalized.replaceAll(' ', '-');
  }

  /// Build brand key with aliases (DEPRECATED - use normalizeBrand instead)
  static String buildBrandKey(String? brand) {
    return normalizeBrand(brand, null);
  }

  static bool _isNoiseBrand(String brand) {
    const noise = ['restaurant', 'supermarket', 'generic', 'store', 'company', 'inc', 'ltd'];
    return noise.any((n) => brand.contains(n));
  }

  /// Build complete family key
  static String buildFamilyKey({
    required String name,
    required String? brand,
    String query = '',
    bool debug = false,
  }) {
    final nameNorm = normalize(name);
    final queryNorm = normalize(query);
    final variants = extractVariants(nameNorm);
    final brandNorm = normalizeBrand(brand, nameNorm);
    final coreNorm = inferCoreName(nameNorm, variants, brandNorm: brandNorm, queryNorm: queryNorm);
    
    // Build composite key
    final parts = [
      brandNorm,
      coreNorm,
      variants.dietType,
      variants.flavor,
    ];
    
    final familyKey = parts.where((p) => p.isNotEmpty).join('|');
    
    if (debug) {
      print('   [KEY] "$name"');
      print('      nameNorm="$nameNorm" brandNorm="$brandNorm" coreNorm="$coreNorm"');
      print('      diet="${variants.dietType}" flavor="${variants.flavor}"');
      print('      → $familyKey');
    }
    
    return familyKey;
  }

  /// Deduplicate by family and select best representative
  static DeduplicationResult deduplicateByFamily({
    required List<FoodModel> items,
    String query = '',
    bool debug = false,
  }) {
    if (items.isEmpty) {
      return DeduplicationResult(groupedResults: [], familyVariantsMap: {});
    }
    
    print('\n🔍 [UNIVERSAL DEDUP] Query: "$query" (debug=$debug)');
    print('   📥 Raw input: ${items.length} items');
    
    // Group items by family key
    final familyGroups = <String, List<FoodModel>>{};
    final itemSignatures = <String, String>{}; // map item.id -> family signature
    final itemDetails = <String, Map<String, String>>{}; // map item.id -> details for printing
    
    for (final item in items) {
      final nameNorm = normalize(item.name);
      final brandNorm = normalizeBrand(item.brand, nameNorm);
      final variants = extractVariants(nameNorm);
      final coreNorm = inferCoreName(nameNorm, variants, brandNorm: brandNorm, queryNorm: normalize(query));
      
      final familyKey = buildFamilyKey(
        name: item.name,
        brand: item.brand,
        query: query,
        debug: false,
      );
      
      familyGroups.putIfAbsent(familyKey, () => []).add(item);
      itemSignatures[item.id] = familyKey;
      itemDetails[item.id] = {
        'nameNorm': nameNorm,
        'brandNorm': brandNorm,
        'coreName': coreNorm,
        'dietType': variants.dietType,
        'flavor': variants.flavor,
      };
    }
    
    print('   📊 Grouped into ${familyGroups.length} families (before second pass)');
    
    // Select best representative from each family
    final representatives = <FoodModel>[];
    final variantsMap = <String, List<FoodModel>>{};
    
    int collapsedCount = 0;
    for (final entry in familyGroups.entries) {
      final familyKey = entry.key;
      final candidates = entry.value;
      
      final best = _selectBestRepresentative(
        candidates: candidates,
        query: query,
        debug: debug,
      );
      
      representatives.add(best);
      variantsMap[familyKey] = candidates;
      
      if (candidates.length > 1) {
        collapsedCount += (candidates.length - 1);
        print('   ✅ Family "$familyKey":');
        print('      • ${candidates.length} candidates → selected "${best.displayTitle}"');
        final collapsed = candidates.where((c) => c.id != best.id).map((c) => c.displayTitle).join(', ');
        print('      • Collapsed: $collapsed');
      }
    }
    
    print('   📤 Output: ${representatives.length} items (collapsed $collapsedCount duplicates)');
    
    // STEP 2: Safety-dedup pass - merge near-duplicates
    print('\n   🔄 [SECOND PASS] Near-duplicate merging...');
    final mergedGroups = _secondPassDedup(representatives, query);
    
    print('   ✅ After second pass: ${mergedGroups.length} items');
    
    // Filter and add query relevance score
    print('\n   🎯 [FILTERING] Applying relevance penalties...');
    final filtered = _applyQueryRelevance(mergedGroups, query);
    
    // Print detailed debug info
    if (debug) {
      print('\n   📋 Detailed family signatures:');
      for (int i = 0; i < filtered.length && i < 15; i++) {
        final item = filtered[i];
        final details = itemDetails[item.id] ?? {};
        final sig = itemSignatures[item.id] ?? 'unknown';
        print('   [${i+1}] ${item.displayTitle}');
        print('        nameNorm="${details['nameNorm']}" brandNorm="${details['brandNorm']}"');
        print('        coreName="${details['coreName']}" diet="${details['dietType']}" flavor="${details['flavor']}"');
        print('        source=${item.source} sig=$sig');
      }
    }
    
    // Preserve original ranking order
    final originalOrder = {for (var i = 0; i < items.length; i++) items[i].id: i};
    filtered.sort((a, b) {
      final idxA = originalOrder[a.id] ?? items.length;
      final idxB = originalOrder[b.id] ?? items.length;
      return idxA.compareTo(idxB);
    });
    
    return DeduplicationResult(
      groupedResults: filtered,
      familyVariantsMap: variantsMap,
    );
  }

  /// Jaro-Winkler string similarity (0-1)
  static double jaroWinklerSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    // Jaro distance
    final len1 = s1.length;
    final len2 = s2.length;
    final matchWindow = (({len1, len2}.reduce((a, b) => a > b ? a : b) / 2).ceil() - 1).clamp(1, double.infinity).toInt();
    
    final matched1 = List<bool>.filled(len1, false);
    final matched2 = List<bool>.filled(len2, false);
    int matches = 0;
    
    for (int i = 0; i < len1; i++) {
      final start = (i - matchWindow).clamp(0, len2 - 1);
      final end = (i + matchWindow).clamp(0, len2 - 1);
      
      for (int j = start; j <= end; j++) {
        if (matched2[j] || s1[i] != s2[j]) continue;
        matched1[i] = true;
        matched2[j] = true;
        matches++;
        break;
      }
    }
    
    if (matches == 0) return 0.0;
    
    int transpositions = 0;
    int k = 0;
    for (int i = 0; i < len1; i++) {
      if (!matched1[i]) continue;
      while (!matched2[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }
    
    final jaro = (matches / len1 + matches / len2 + (matches - transpositions / 2) / matches) / 3;
    
    // Winkler modification
    int prefix = 0;
    for (int i = 0; i < ({len1, len2}.reduce((a, b) => a < b ? a : b)); i++) {
      if (s1[i] == s2[i]) {
        prefix++;
      } else {
        break;
      }
    }
    prefix = prefix.clamp(0, 4);
    
    return jaro + prefix * 0.1 * (1 - jaro);
  }

  /// Token overlap similarity (0-1)
  static double tokenOverlapSimilarity(String s1, String s2) {
    final tokens1 = s1.split(RegExp(r'\s+')).toSet();
    final tokens2 = s2.split(RegExp(r'\s+')).toSet();
    
    if (tokens1.isEmpty || tokens2.isEmpty) return 0.0;
    
    final intersection = tokens1.intersection(tokens2).length;
    final union = tokens1.union(tokens2).length;
    
    return union == 0 ? 0.0 : intersection / union;
  }

  /// Second pass: merge near-duplicates
  static List<FoodModel> _secondPassDedup(List<FoodModel> items, String query) {
    if (items.length < 2) return items;
    
    final merged = <List<FoodModel>>[];
    final processed = <String>{};
    
    for (final item in items) {
      if (processed.contains(item.id)) continue;
      
      final group = [item];
      processed.add(item.id);
      
      final nameNorm1 = normalize(item.name);
      final variants1 = extractVariants(nameNorm1);
      final brandNorm1 = normalizeBrand(item.brand, nameNorm1);
      
      // Look for similar items to merge
      for (final other in items) {
        if (processed.contains(other.id) || item.id == other.id) continue;
        
        final nameNorm2 = normalize(other.name);
        final variants2 = extractVariants(nameNorm2);
        final brandNorm2 = normalizeBrand(other.brand, nameNorm2);
        
        // Merge criteria:
        // 1. Same diet type and flavor
        // 2. Similar brand or one is generic
        // 3. Similar names (Jaro-Winkler > 0.85 or token overlap > 0.70)
        if (variants1.dietType == variants2.dietType &&
            variants1.flavor == variants2.flavor &&
            (brandNorm1 == brandNorm2 || brandNorm1 == 'generic' || brandNorm2 == 'generic') &&
            (jaroWinklerSimilarity(nameNorm1, nameNorm2) > 0.85 ||
             tokenOverlapSimilarity(nameNorm1, nameNorm2) > 0.70)) {
          group.add(other);
          processed.add(other.id);
          print('      [MERGED] "${item.displayTitle}" + "${other.displayTitle}"');
        }
      }
      
      merged.add(group);
    }
    
    // Select best from each merged group
    return merged.map((group) => _selectBestRepresentative(
      candidates: group,
      query: query,
      debug: false,
    )).toList();
  }

  /// Apply query relevance scoring and filtering
  static List<FoodModel> _applyQueryRelevance(List<FoodModel> items, String query) {
    if (query.isEmpty) return items;
    
    final queryTokens = normalize(query).split(RegExp(r'\s+')).toSet();
    
    // Sort by relevance (query matching first)
    items.sort((a, b) {
      final aNameNorm = normalize(a.name);
      final bNameNorm = normalize(b.name);
      final aTokens = aNameNorm.split(RegExp(r'\s+')).toSet();
      final bTokens = bNameNorm.split(RegExp(r'\s+')).toSet();
      
      final aOverlap = aTokens.intersection(queryTokens).length;
      final bOverlap = bTokens.intersection(queryTokens).length;
      
      return bOverlap.compareTo(aOverlap); // Descending
    });
    
    return items;
  }

  /// Select best representative using tie-breakers
  static FoodModel _selectBestRepresentative({
    required List<FoodModel> candidates,
    required String query,
    bool debug = false,
  }) {
    if (candidates.length == 1) return candidates.first;
    
    final scored = candidates.map((item) {
      int score = 0;
      
      // 1. Verified branded > unverified (brand is not generic/empty)
      final hasGoodBrand = item.brand != null && 
                          item.brand!.isNotEmpty && 
                          !item.brand!.toLowerCase().contains('generic');
      if (hasGoodBrand) score += 1000;
      
      // 2. Exact brand match to query
      if (query.isNotEmpty && item.brand != null) {
        final queryNorm = normalize(query);
        final brandNorm = normalize(item.brand!);
        if (brandNorm.contains(queryNorm) || queryNorm.contains(brandNorm)) {
          score += 500;
        }
      }
      
      // 3. More complete nutrition fields
      int nutritionFields = 0;
      if (item.calories > 0) nutritionFields++;
      if (item.protein > 0) nutritionFields++;
      if (item.fat > 0) nutritionFields++;
      if (item.carbs > 0) nutritionFields++;
      if (item.servingUnit.isNotEmpty) nutritionFields++;
      score += nutritionFields * 50;
      
      // 4. Text quality score
      final textQuality = _calculateTextQuality(item.name);
      score += textQuality;
      
      // 5. Preferred source order (configurable)
      const sourceScores = {
        'usda': 100,
        'open_food_facts': 80,
        'nutritionix': 60,
      };
      score += sourceScores[item.source] ?? 0;
      
      // 6. Longer descriptive titles (cap at +30)
      score += (item.name.length ~/ 2).clamp(0, 30);
      
      return (item: item, score: score);
    }).toList();
    
    // Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));
    
    return scored.first.item;
  }

  /// Calculate text quality score
  static int _calculateTextQuality(String text) {
    int score = 100;
    
    // Penalize ALL CAPS
    final upperCount = text.replaceAll(RegExp(r'[^A-Z]'), '').length;
    final totalLetters = text.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
    if (totalLetters > 0) {
      final capsRatio = upperCount / totalLetters;
      if (capsRatio > 0.8) {
        score -= 30; // Mostly caps
      } else if (capsRatio > 0.5) score -= 15; // Half caps
    }
    
    // Penalize weird tokens
    if (text.contains(RegExp(r'[®™©]'))) score -= 5;
    if (text.contains(RegExp(r'\d{3,}'))) score -= 10; // Long numbers
    if (text.contains(RegExp(r"[^\w\s\-']"))) score -= 5; // Strange punctuation
    
    // Reward proper capitalization
    if (text.isNotEmpty && text[0] == text[0].toUpperCase()) score += 10;
    
    return score.clamp(0, 100);
  }
}

/// Product variant attributes
class ProductVariants {
  final String dietType;      // regular, diet, zero, sugar-free, light
  final String flavor;         // cherry, vanilla, lime, lemon, etc.
  final String caffeine;       // caffeine-free, caffeinated, or empty
  final String format;         // can, bottle, mini-can, powder, bar, chips, or empty
  final String fatLevel;       // nonfat, skim, 1%, 2%, whole, or empty
  final String prep;           // raw, cooked, frozen, ready-to-eat, or empty
  
  ProductVariants({
    required this.dietType,
    required this.flavor,
    required this.caffeine,
    required this.format,
    required this.fatLevel,
    required this.prep,
  });
}

/// Deduplication result with variants map
class DeduplicationResult {
  final List<FoodModel> groupedResults;
  final Map<String, List<FoodModel>> familyVariantsMap;
  
  DeduplicationResult({
    required this.groupedResults,
    required this.familyVariantsMap,
  });
}
