import '../data/models/food_model.dart';

/// Normalized display information for a food item
class DisplayNormalization {
  final String displayTitle;
  final String displayBrandLine;
  final String displaySourceTag;
  final String displayServingText;
  final String displayCaloriesText;

  const DisplayNormalization({
    required this.displayTitle,
    required this.displayBrandLine,
    required this.displaySourceTag,
    required this.displayServingText,
    required this.displayCaloriesText,
  });

  /// Subtitle formatted as: "Brand • Calories • Serving"
  String get subtitle {
    final parts = <String>[];
    if (displayBrandLine.isNotEmpty) parts.add(displayBrandLine);
    if (displayCaloriesText.isNotEmpty) parts.add(displayCaloriesText);
    if (displayServingText.isNotEmpty) parts.add(displayServingText);
    return parts.join(' • ');
  }

  @override
  String toString() =>
      'DisplayNormalization(title: "$displayTitle", brand: "$displayBrandLine", source: "$displaySourceTag", cal: "$displayCaloriesText", serving: "$displayServingText")';
}

/// Pure normalization service for food display
class FoodDisplayNormalizer {
  /// Normalize a food model for display
  static DisplayNormalization normalize(FoodModel food) {
    final title = _normalizeTitle(food);
    final brand = _normalizeBrand(food);
    final tag = _normalizeSourceTag(food);
    final calories = _normalizeCalories(food);
    final serving = _normalizeServing(food);

    return DisplayNormalization(
      displayTitle: title,
      displayBrandLine: brand,
      displaySourceTag: tag,
      displayCaloriesText: calories,
      displayServingText: serving,
    );
  }

  /// Extract clean product title from food model
  static String _normalizeTitle(FoodModel food) {
    // Prefer foodName, fallback to name
    var title = (food.foodName?.isNotEmpty == true ? food.foodName : food.name) ?? '';

    if (title.isEmpty) return 'Unknown Product';

    // Remove USDA-style commas (keep first meaningful phrase)
    title = _cleanCommaText(title);

    // Remove repeated brand name if present
    final brand = _normalizeBrand(food);
    if (brand.isNotEmpty && brand != 'Generic') {
      title = _removeLeadingBrand(title, brand);
    }

    // Title case with smart acronym handling
    title = _titleCaseSmartly(title);

    // Remove trailing punctuation and extra spaces
    title = title.trim().replaceAll(RegExp(r'[,;.\s]+$'), '').trim();

    // Collapse multiple spaces
    title = title.replaceAll(RegExp(r'\s+'), ' ');

    return title.isEmpty ? 'Unknown Product' : title;
  }

  /// Extract brand/restaurant/owner name
  static String _normalizeBrand(FoodModel food) {
    // Priority: restaurant > brand_owner > brand_name
    if (food.restaurantName?.isNotEmpty == true) {
      return _cleanBrandText(food.restaurantName!);
    }
    if (food.brandOwner?.isNotEmpty == true) {
      return _cleanBrandText(food.brandOwner!);
    }
    if (food.brandName?.isNotEmpty == true) {
      return _cleanBrandText(food.brandName!);
    }
    return 'Generic';
  }

  /// Extract source tag (USDA, OFF, DB, etc.)
  static String _normalizeSourceTag(FoodModel food) {
    final source = food.source.toLowerCase();
    if (source.contains('usda')) return 'USDA';
    if (source.contains('open_food') || source.contains('off')) return 'OFF';
    if (source.contains('local') || source.contains('cache')) return 'Cache';
    if (source.contains('branded')) return 'Branded';
    return 'DB';
  }

  /// Extract calories text
  static String _normalizeCalories(FoodModel food) {
    final calories = extractCalories(food);
    if (calories != null && calories > 0) {
      return '${calories.toStringAsFixed(0)} kcal';
    }
    return '—';
  }

  /// Extract serving text
  static String _normalizeServing(FoodModel food) {
    final serving = extractServing(food);
    if (serving == null) return '';
    return serving;
  }

  /// Clean comma-separated text (USDA format)
  static String _cleanCommaText(String text) {
    // Pattern: "COKE WITH LIME FLAVOR, LIME" => "Coke With Lime Flavor"
    // Take everything before the last comma if it's a repeat/descriptor
    final parts = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (parts.isEmpty) return text;

    // If only one part, use it
    if (parts.length == 1) return parts[0];

    // If last part is very short or repeated, drop it
    final last = parts.last.toLowerCase();
    final first = parts[0].toLowerCase();

    if (last.length < 4 && (first.contains(last) || last == 'flavored' || last == 'cola')) {
      return parts.sublist(0, parts.length - 1).join(' ');
    }

    // Otherwise join meaningful parts
    return parts.join(' ');
  }

  /// Clean brand text (remove corporate suffixes)
  static String _cleanBrandText(String text) {
    if (text.isEmpty) return text;

    // Remove common corporate suffixes
    var cleaned = text
        .replaceAll(RegExp(r',?\s*(Inc|LLC|Ltd|Corp|Corporation|USA|US)\.?\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r',?\s*Company\s*$', caseSensitive: false), '')
        .trim();

    return cleaned.isEmpty ? text : cleaned;
  }

  /// Remove leading brand from title if present
  static String _removeLeadingBrand(String title, String brand) {
    // Check if title starts with brand name
    final brandPattern = RegExp('^${RegExp.escape(brand)}\\s+', caseSensitive: false);
    return title.replaceFirst(brandPattern, '').trim();
  }

  /// Smart title case that preserves acronyms
  static String _titleCaseSmartly(String text) {
    if (text.isEmpty) return text;

    // List of acronyms to preserve
    const acronyms = {'USDA', 'BBQ', 'USA', 'UK', 'ml', 'g', 'oz', 'lb', 'FDA'};

    return text.split(' ').map((word) {
      if (acronyms.contains(word)) return word;
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

/// Extract calories from food model (with fallback to raw_json)
double? extractCalories(FoodModel food) {
  // Direct field
  if (food.calories > 0) {
    return food.calories.toDouble();
  }

  // Try raw_json extraction
  if (food.rawJson != null) {
    try {
      final json = food.rawJson!;

      // USDA format: nutrients array with nutrientId 1008 (Energy)
      if (json['nutrients'] is List) {
        for (var nutrient in json['nutrients']) {
          if (nutrient['nutrientId'] == 1008 || nutrient['nutrientId'] == '1008') {
            final value = nutrient['value'];
            if (value != null) {
              return double.tryParse(value.toString()) ?? null;
            }
          }
        }
      }

      // OFF format: typical "energy_kcal" or "energy" field
      if (json['energy_kcal'] != null) {
        return double.tryParse(json['energy_kcal'].toString());
      }
      if (json['energy'] != null) {
        return double.tryParse(json['energy'].toString());
      }
      if (json['calories'] != null) {
        return double.tryParse(json['calories'].toString());
      }
    } catch (_) {
      // Ignore parse errors
    }
  }

  return null;
}

/// Extract serving information
String? extractServing(FoodModel food) {
  // Try quantity + unit first
  if ((food.servingQty ?? 0) > 0 && (food.servingUnitRaw?.isNotEmpty == true)) {
    final qty = food.servingQty!.toStringAsFixed(food.servingQty! % 1 == 0 ? 0 : 1);
    final unit = _normalizeUnit(food.servingUnitRaw!);
    return '$qty $unit';
  }

  // Try volume or weight
  if ((food.servingVolumeMl ?? 0) > 0) {
    final vol = food.servingVolumeMl!.toStringAsFixed(0);
    return '$vol ml';
  }
  if ((food.servingWeightGrams ?? 0) > 0) {
    final wt = food.servingWeightGrams!.toStringAsFixed(0);
    return '$wt g';
  }

  // Try household serving text (USDA format)
  if (food.rawJson != null) {
    try {
      final json = food.rawJson!;
      final household = json['householdServingFullText'];
      if (household != null && household.toString().isNotEmpty) {
        return household.toString();
      }
    } catch (_) {}
  }

  return null;
}

/// Normalize unit strings
String _normalizeUnit(String unit) {
  final lower = unit.toLowerCase();
  if (lower == 'mlt' || lower == 'ml' || lower == 'mL') return 'ml';
  if (lower == 'g' || lower == 'gm') return 'g';
  if (lower == 'oz') return 'oz';
  if (lower == 'lb') return 'lb';
  if (lower == 'cup' || lower == 'cups') return 'cup';
  if (lower == 'tbsp') return 'tbsp';
  if (lower == 'tsp') return 'tsp';
  // Return as-is with first letter lowercase
  return lower;
}
