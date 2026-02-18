import 'package:flutter/foundation.dart';
import '../../data/models/food_model.dart';

/// Presentation layer for food search results
///
/// Handles all UI formatting in one place:
/// - Clean titles (no raw DB strings, no duplicates)
/// - Single serving subtitle
/// - Provider labels (debug only)
/// - Leading avatar letter
class FoodDisplayStrings {
  final String title;
  final String subtitle;
  final String leadingLetter;
  final String? debugProviderLabel; // Only populated in debug builds

  FoodDisplayStrings({
    required this.title,
    required this.subtitle,
    required this.leadingLetter,
    this.debugProviderLabel,
  });

  @override
  String toString() => 'FoodDisplayStrings(title: $title, subtitle: $subtitle)';
}

/// Unit normalization map
const Map<String, String> unitNormalizationMap = {
  'mlt': 'ml',
  'ml': 'ml',
  'MLT': 'ml',
  'ML': 'ml',
  'gram': 'g',
  'grams': 'g',
  'grm': 'g',
  'g': 'g',
  'G': 'g',
  'oz': 'oz',
  'OZ': 'oz',
  'ounce': 'oz',
  'ounces': 'oz',
  'fl oz': 'fl oz',
  'fl. oz': 'fl oz',
  'floz': 'fl oz',
  'cup': 'cup',
  'cups': 'cup',
  'tbsp': 'tbsp',
  'tsp': 'tsp',
  'serving': 'serving',
  'piece': 'piece',
  'slice': 'slice',
};

/// Generic product detection keywords
const Set<String> genericKeywords = {
  'generic',
  'product',
  'food',
  'item',
  'unknown',
  'usda',
  'survey',
  'homemade',
};

/// Noise tokens to remove from brand/food names
const Set<String> noiseTokens = {
  'inc',
  'inc.',
  'ltd',
  'ltd.',
  'llc',
  'co',
  'co.',
  'corp',
  'corp.',
  'corporation',
  'usa',
  'us',
  'operations',
  'company',
  'the',
  'brands',
  'beverage',
};

/// Core formatting utilities
class FoodDisplayFormatter {
  /// Normalize text: lowercase, trim, remove extra spaces
  static String normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[®™©]'), '');
  }

  /// Convert to Title Case
  static String titleCase(String text) {
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Remove noise tokens and clean up the text
  static String stripNoiseTokens(String text) {
    var cleaned = normalizeText(text);

    // Remove noise tokens
    for (final token in noiseTokens) {
      cleaned = cleaned.replaceAll(RegExp(r'\b' + token + r'\b'), ' ');
    }

    // Clean up extra spaces and punctuation
    cleaned = cleaned
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[,;:()]'), '')
        .trim();

    return titleCase(cleaned);
  }

  /// Remove duplicate words (e.g., "Cherry Cherry" → "Cherry")
  static String removeDuplicateWords(String text) {
    final words = text.split(' ');
    final seen = <String>{};
    final result = <String>[];

    for (final word in words) {
      final lower = word.toLowerCase();
      if (!seen.contains(lower)) {
        result.add(word);
        seen.add(lower);
      }
    }

    return result.join(' ');
  }

  /// Normalize serving unit
  static String normalizeUnit(String? unit) {
    if (unit == null || unit.isEmpty) return '';
    final normalized = unitNormalizationMap[unit.toLowerCase()] ?? unit;
    return normalized;
  }

  /// Build title using priority order:
  /// 1. restaurantName (if available)
  /// 2. brandName + variant (if available)
  /// 3. foodName + "(Generic)" if generic
  static String buildTitle(FoodModel item) {
    // Priority 1: Restaurant name
    if (item.restaurantName != null && item.restaurantName!.isNotEmpty) {
      return stripNoiseTokens(item.restaurantName!);
    }

    // Priority 2: Brand + optional variant
    if (item.brandName != null && item.brandName!.isNotEmpty) {
      var brand = stripNoiseTokens(item.brandName!);

      // Try to extract variant from food name
      final variant = _extractVariant(item.foodNameRaw ?? item.name);
      if (variant != null && variant.isNotEmpty) {
        // Avoid duplicate: "Cherry (cherry)" → "Cherry"
        if (!brand.toLowerCase().contains(variant.toLowerCase())) {
          brand = '$brand $variant';
        }
      }

      return removeDuplicateWords(brand);
    }

    // Priority 3: Food name + "(Generic)" if needed
    var title = stripNoiseTokens(item.foodNameRaw ?? item.name);

    if (item.isGeneric == true && !title.toLowerCase().contains('generic')) {
      title = '$title (Generic)';
    }

    return removeDuplicateWords(title);
  }

  /// Extract variant from food name (simple pattern matching)
  static String? _extractVariant(String foodName) {
    final lower = normalizeText(foodName);

    const variantKeywords = [
      'diet',
      'zero',
      'sugar free',
      'sugar-free',
      'caffeine free',
      'caffeine-free',
      'cherry',
      'vanilla',
      'lime',
      'lemon',
      'orange',
      'grape',
      'strawberry',
    ];

    for (final variant in variantKeywords) {
      if (lower.contains(variant)) {
        return titleCase(variant);
      }
    }

    return null;
  }

  /// Build subtitle with SINGLE serving selection
  /// Format: "{kcal} kcal · P xg · C yg · F zg · {serving}"
  static String buildSubtitle(FoodModel item) {
    if (item.calories <= 0) {
      return 'No nutrition info';
    }

    // Always use rounded integer kcal
    final kcal = item.calories;
    final servingStr = _selectBestServing(item);
    final macros = _formatMacros(item);
    final parts = <String>['$kcal kcal'];
    if (macros.isNotEmpty) {
      parts.add(macros);
    }
    if (servingStr.isNotEmpty) {
      parts.add(servingStr);
    }

    return parts.join(' · ');
  }

  static String _formatMacros(FoodModel item) {
    final protein = _formatMacroValue(item.protein);
    final carbs = _formatMacroValue(item.carbs);
    final fat = _formatMacroValue(item.fat);

    return 'P $protein · C $carbs · F $fat';
  }

  static String _formatMacroValue(double value) {
    if (value <= 0) return '0g';
    final formatted = value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '${formatted}g';
  }

  /// Select best serving representation (ONE only)
  /// Priority: ml > g > qty + unit
  static String _selectBestServing(FoodModel item) {
    // 1. Prefer ml if available
    if (item.servingVolumeMl != null && item.servingVolumeMl! > 0) {
      return '${item.servingVolumeMl!.toStringAsFixed(0)} ml';
    }

    // 2. Prefer grams if available
    if (item.servingWeightGrams != null && item.servingWeightGrams! > 0) {
      return '${item.servingWeightGrams!.toStringAsFixed(0)} g';
    }

    // 3. Fall back to qty + unit
    if (item.servingQty != null && item.servingQty! > 0) {
      final unit = normalizeUnit(item.servingUnitRaw);
      if (unit.isNotEmpty) {
        final qty = item.servingQty! == item.servingQty!.toInt()
            ? item.servingQty!.toInt().toString()
            : item.servingQty!.toStringAsFixed(1);
        return '$qty $unit';
      }
    }

    // 4. Last resort: just kcal
    return '${item.calories} kcal';
  }

  /// Get provider label (debug only, return null in release)
  static String? getDebugProviderLabel(FoodModel item) {
    if (!kDebugMode) {
      return null;
    }

    // Map source to friendly name
    const sourceMap = {
      'usda': 'USDA',
      'open_food_facts': 'OFF',
      'local': 'Local',
      'off': 'OFF',
    };

    final source = sourceMap[item.source.toLowerCase()] ?? item.source;
    return source;
  }

  /// Get leading avatar letter
  static String getLeadingLetter(FoodModel item) {
    final title = buildTitle(item);
    if (title.isEmpty) return '?';
    return title[0].toUpperCase();
  }
}

/// Main function to build display strings from FoodModel
FoodDisplayStrings buildFoodDisplayStrings(FoodModel item) {
  return FoodDisplayStrings(
    title: FoodDisplayFormatter.buildTitle(item),
    subtitle: FoodDisplayFormatter.buildSubtitle(item),
    leadingLetter: FoodDisplayFormatter.getLeadingLetter(item),
    debugProviderLabel: FoodDisplayFormatter.getDebugProviderLabel(item),
  );
}

/// Optional: Deduplication function
/// Keeps best result for each unique (brand, name, calories) combination
List<FoodModel> deduplicateFoodResults(List<FoodModel> items) {
  if (items.isEmpty) return items;

  final seen = <String, FoodModel>{};

  for (final item in items) {
    final title = FoodDisplayFormatter.buildTitle(item);
    final kcal = item.calories;

    // Create dedup key: brand + title + kcal range
    final key = '$title-$kcal';

    if (!seen.containsKey(key)) {
      seen[key] = item;
    } else {
      // Keep the better one: prefer branded with barcode and serving info
      final existing = seen[key]!;
      final score = _scoreForDedup(item);
      final existingScore = _scoreForDedup(existing);

      if (score > existingScore) {
        seen[key] = item;
      }
    }
  }

  return seen.values.toList();
}

/// Score item for deduplication (higher = better)
double _scoreForDedup(FoodModel item) {
  double score = 0;

  if (item.isBranded == true) score += 50;
  if (item.barcode != null && item.barcode!.isNotEmpty) score += 25;
  if (item.servingVolumeMl != null && item.servingVolumeMl! > 0) score += 10;
  if (item.servingWeightGrams != null && item.servingWeightGrams! > 0) score += 10;

  return score;
}

/// ============================================================================
/// SIMPLE TESTS / ASSERTIONS (run these to verify formatting)
/// ============================================================================

void runFoodDisplayTests() {
  if (!kDebugMode) return;

  // Test 1: Title formatting
  assert(FoodDisplayFormatter.stripNoiseTokens('The Coca-Cola Company') ==
      'Coca Cola');
  assert(FoodDisplayFormatter.stripNoiseTokens('COKE WITH LIME FLAVOR, LIME') ==
      'Coke With Lime Flavor Lime');

  // Test 2: Duplicate word removal
  assert(FoodDisplayFormatter.removeDuplicateWords('Cherry cherry') == 'Cherry');
  assert(
      FoodDisplayFormatter.removeDuplicateWords('Diet Diet Coke') == 'Diet Coke');

  // Test 3: Unit normalization
  assert(FoodDisplayFormatter.normalizeUnit('MLT') == 'ml');
  assert(FoodDisplayFormatter.normalizeUnit('GRM') == 'g');
  assert(FoodDisplayFormatter.normalizeUnit('fl oz') == 'fl oz');

  // Test 4: Title case
  assert(FoodDisplayFormatter.titleCase('coca cola') == 'Coca Cola');
  assert(FoodDisplayFormatter.titleCase('DIET COKE') == 'Diet Coke');

  debugPrint('✓ FoodDisplayFormatter: All tests passed');
}
