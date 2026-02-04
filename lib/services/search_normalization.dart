import '../data/models/food_model.dart';

/// Text normalization for food search deduplication and display
class SearchNormalization {
  /// Normalize text: lowercase, trim, collapse spaces, remove punctuation
  /// "Coca-Cola" → "coca cola", "Coca  Cola" → "coca cola"
  static String normalizeText(String text) {
    if (text.isEmpty) return '';
    
    return text
        .toLowerCase()
        .trim()
        // Replace dashes/underscores with spaces
        .replaceAll(RegExp(r'[-_]+'), ' ')
        // Remove special punctuation but keep letters/numbers/spaces
        .replaceAll(RegExp(r'[^\w\s]'), '')
        // Collapse multiple spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Extract canonical brand from various sources
  static String canonicalBrand(FoodModel item) {
    // Priority: brandName → brandOwner → restaurantName
    String? brand = item.brandName?.isNotEmpty == true ? item.brandName : null;
    brand ??= item.brandOwner?.isNotEmpty == true ? item.brandOwner : null;
    brand ??= item.restaurantName?.isNotEmpty == true ? item.restaurantName : null;

    if (brand?.isNotEmpty == true) {
      return _titleCase(_removeNoiseTokens(normalizeText(brand!)));
    }

    return '';
  }

  /// Extract canonical product name from various sources
  static String canonicalProductName(FoodModel item) {
    String productName = item.foodName?.isNotEmpty == true
        ? item.foodName!
        : (item.foodNameRaw?.isNotEmpty == true ? item.foodNameRaw! : '');

    if (productName.isEmpty) {
      return '';
    }

    var normalized = normalizeText(productName);
    final brand = canonicalBrand(item);

    // Remove leading brand tokens if they duplicate the brand
    if (brand.isNotEmpty) {
      final brandTokens = brand.toLowerCase().split(' ');
      final productTokens = normalized.split(' ');

      // Skip brand tokens at the start
      int skipCount = 0;
      for (int i = 0; i < productTokens.length && i < brandTokens.length; i++) {
        if (productTokens[i] == brandTokens[i]) {
          skipCount++;
        } else {
          break;
        }
      }

      if (skipCount > 0 && skipCount < productTokens.length) {
        normalized = productTokens.skip(skipCount).join(' ');
      }
    }

    // Check if product name became too short or is a fragment
    if (_isFragment(normalized) && item.foodNameRaw?.isNotEmpty == true) {
      // Try to rebuild from raw name with context
      final raw = item.foodNameRaw!.toUpperCase();
      if (raw.contains('COKE') && (raw.contains('LIME') || raw.contains('CHERRY'))) {
        final variant = _extractVariant(raw);
        if (variant.isNotEmpty) {
          normalized = 'Coke $variant';
        }
      }
    }

    // Strip trailing measurement words
    normalized = _stripMeasurementWords(normalized);

    // Remove duplicate consecutive words
    normalized = _removeDuplicateTokens(normalized);

    return _titleCase(normalized);
  }

  /// Format title for display
  static String displayTitle(FoodModel item) {
    final brand = canonicalBrand(item);
    final productName = canonicalProductName(item);

    if (brand.isEmpty) {
      return productName;
    }

    // If product already contains brand, just show product
    if (productName.toLowerCase().contains(brand.toLowerCase())) {
      return productName;
    }

    // Show "Brand Product" format
    if (productName.isNotEmpty && productName != brand) {
      return '$brand $productName';
    }

    return brand;
  }

  /// Format subtitle: "Brand • Kcal kcal • Serving"
  static String displaySubtitle(FoodModel item) {
    final brand = canonicalBrand(item);
    final sourceLabel = brand.isEmpty ? _getSourceLabel(item.source) : brand;

    // Get calories
    final kcal = item.calories > 0 ? item.calories.toStringAsFixed(0) : null;

    // Get serving text
    final servingText = _getServingText(item);

    // Build subtitle
    final parts = <String>[sourceLabel];

    if (kcal != null) {
      parts.add('$kcal kcal');
    }

    if (servingText.isNotEmpty) {
      parts.add(servingText);
    }

    return parts.join(' • ');
  }

  /// Get leading letter for avatar
  static String getLeadingLetter(FoodModel item) {
    final title = displayTitle(item);
    if (title.isEmpty) return '?';
    return title[0].toUpperCase();
  }

  // ============ PRIVATE HELPERS ============

  static String _titleCase(String text) {
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  static String _removeNoiseTokens(String text) {
    const noiseTokens = [
      'inc',
      'ltd',
      'llc',
      'corp',
      'corporation',
      'usa',
      'us',
      'operations',
      'company',
      'the',
      'brands',
      'beverage',
    ];

    var result = text;
    for (final token in noiseTokens) {
      result = result.replaceAll(RegExp(r'\b' + token + r'\b'), ' ');
    }

    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isFragment(String text) {
    final words = text.split(' ');
    if (words.length != 1) return false;

    const fragments = ['lime', 'cherry', 'diet', 'zero', 'vanilla', 'coke'];
    return fragments.contains(text.toLowerCase());
  }

  static String _extractVariant(String raw) {
    const variants = ['LIME', 'CHERRY', 'VANILLA', 'DIET', 'ZERO'];
    for (final variant in variants) {
      if (raw.contains(variant)) {
        return variant.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      }
    }
    return '';
  }

  static String _stripMeasurementWords(String text) {
    const measurements = [
      'ml',
      'mlt',
      'g',
      'grm',
      'oz',
      'fl oz',
      'cup',
      'tbsp',
      'tsp',
      'slice',
      'piece',
      'can',
      'bottle'
    ];

    var result = text;
    for (final unit in measurements) {
      result = result.replaceAll(RegExp(r'\b' + unit + r'\b'), '');
    }

    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _removeDuplicateTokens(String text) {
    final tokens = text.split(' ');
    final seen = <String>{};
    final result = <String>[];

    for (final token in tokens) {
      final lower = token.toLowerCase();
      if (!seen.contains(lower)) {
        result.add(token);
        seen.add(lower);
      }
    }

    return result.join(' ');
  }

  static String _getSourceLabel(String source) {
    const sourceMap = {
      'usda': 'USDA',
      'off': 'OFF',
      'open_food_facts': 'OFF',
      'local': 'Local',
    };

    return sourceMap[source.toLowerCase()] ?? source.toUpperCase();
  }

  static String _getServingText(FoodModel item) {
    // Prefer ml
    if (item.servingVolumeMl != null && item.servingVolumeMl! > 0) {
      return '${item.servingVolumeMl!.toStringAsFixed(0)} ml';
    }

    // Then grams
    if (item.servingWeightGrams != null && item.servingWeightGrams! > 0) {
      return '${item.servingWeightGrams!.toStringAsFixed(0)} g';
    }

    // Then qty + unit
    if (item.servingQty != null && item.servingQty! > 0) {
      final unit = item.servingUnitRaw ?? item.servingUnit ?? '';
      if (unit.isNotEmpty) {
        final qtyStr = item.servingQty! == item.servingQty!.toInt()
            ? item.servingQty!.toInt().toString()
            : item.servingQty!.toStringAsFixed(1);
        return '$qtyStr $unit';
      }
    }

    return '';
  }
}

/// Create deduplication key for results
String createDedupeKey(FoodModel item) {
  final brand = SearchNormalization.canonicalBrand(item);
  final product = SearchNormalization.canonicalProductName(item);
  final category = item.category ?? '';

  return '${brand.toLowerCase()}|${product.toLowerCase()}|${category.toLowerCase()}';
}

/// Get barcode key if available
String? getBarcodeKey(FoodModel item) {
  return item.barcode?.isNotEmpty == true ? item.barcode : null;
}
