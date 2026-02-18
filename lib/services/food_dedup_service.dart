import 'dart:convert';
import '../data/models/food_model.dart';
import 'food_display_normalizer.dart';

/// Deterministic deduplication key for food items
String createDedupeKey(FoodModel food) {
  // Highest priority: barcode
  if (food.barcode?.isNotEmpty == true) {
    return 'barcode:${food.barcode!}';
  }

  // Second priority: source_id
  if (food.sourceId?.isNotEmpty == true) {
    return '${food.source.toLowerCase()}:${food.sourceId!}';
  }

  // Fallback: normalized composite key
  final norm = FoodDisplayNormalizer.normalize(food);
  final cal = extractCalories(food) ?? 0;
  final serving = food.servingQty?.toStringAsFixed(0) ?? 'unknown';
  final unit = food.servingUnitRaw ?? 'unknown';

  return 'name:${norm.displayTitle}|brand:${norm.displayBrandLine}|serving:$serving$unit|cal:${cal.toStringAsFixed(0)}|type:${food.dataType ?? 'unknown'}';
}

/// Check if two items are similar enough to be considered duplicates
bool areSimilarItems(FoodModel a, FoodModel b) {
  final normA = FoodDisplayNormalizer.normalize(a);
  final normB = FoodDisplayNormalizer.normalize(b);

  // Title and brand must match closely
  if (normA.displayTitle.toLowerCase() != normB.displayTitle.toLowerCase()) {
    return false;
  }

  if (normA.displayBrandLine.toLowerCase() != normB.displayBrandLine.toLowerCase()) {
    return false;
  }

  // Calories must be within 2 kcal
  final calA = extractCalories(a) ?? 0;
  final calB = extractCalories(b) ?? 0;
  if ((calA - calB).abs() > 2) {
    return false;
  }

  // Serving unit must match
  if ((a.servingUnitRaw ?? '').toLowerCase() != (b.servingUnitRaw ?? '').toLowerCase()) {
    return false;
  }

  // Serving quantity must be within 10%
  final qtyA = a.servingQty ?? 0;
  final qtyB = b.servingQty ?? 0;
  if (qtyA > 0 && qtyB > 0) {
    final diff = ((qtyA - qtyB) / qtyA).abs();
    if (diff > 0.1) {
      return false;
    }
  }

  return true;
}

/// Score an item for selection as "best" representative
/// Higher score = better representative
double scoreItem(FoodModel food) {
  double score = 0;

  // Barcode: highest priority (100)
  if (food.barcode?.isNotEmpty == true) score += 100;

  // Has calories (50)
  if (extractCalories(food) != null && extractCalories(food)! > 0) score += 50;

  // Has brand_owner or brand_name (30)
  if (food.brandOwner?.isNotEmpty == true || food.brandName?.isNotEmpty == true) score += 30;

  // Is branded data type (20)
  if (food.dataType?.toLowerCase().contains('branded') == true) score += 20;

  // Has complete macros (15)
  if (food.protein > 0 && food.carbs > 0 && food.fat > 0) score += 15;

  // Has serving info (10)
  if ((food.servingQty ?? 0) > 0 || (food.servingVolumeMl ?? 0) > 0 || (food.servingWeightGrams ?? 0) > 0) {
    score += 10;
  }

  // Newer item (prefer recent updates) (5)
  if (food.lastUpdated != null) {
    final daysSinceUpdate = DateTime.now().difference(food.lastUpdated!).inDays;
    if (daysSinceUpdate < 30) score += 5;
  }

  return score;
}

/// Deduplicate food results while preserving meaningful diversity
List<FoodModel> deduplicateFoods(List<FoodModel> items) {
  if (items.isEmpty) return items;

  // Group by dedup key
  final byKey = <String, List<FoodModel>>{};
  for (final item in items) {
    final key = createDedupeKey(item);
    byKey.putIfAbsent(key, () => []).add(item);
  }

  // For each group, select best representative
  final result = <FoodModel>[];
  for (final group in byKey.values) {
    if (group.isEmpty) continue;

    // If only one item, use it
    if (group.length == 1) {
      result.add(group[0]);
      continue;
    }

    // Multiple items with same key: pick best
    group.sort((a, b) => scoreItem(b).compareTo(scoreItem(a)));
    result.add(group[0]);
  }

  // Now apply similarity-based dedup (only if result didn't shrink too much)
  final reductionRatio = result.length / items.length;
  if (reductionRatio > 0.4) {
    // Safe to apply similarity check
    result.removeWhere((item) {
      // Check if this item is similar to any item that came before it
      for (final other in result) {
        if (identical(item, other)) continue;
        if (result.indexOf(item) > result.indexOf(other) && areSimilarItems(item, other)) {
          return true; // Remove this item as duplicate
        }
      }
      return false;
    });
  }

  return result;
}

/// Extract calories from food model (with fallback to raw_json)
/// Duplicated here for convenience (also in FoodDisplayNormalizer)
double? extractCalories(FoodModel food) {
  return _extractCaloriesImpl(food);
}

double? _extractCaloriesImpl(FoodModel food) {
  if (food.calories > 0) {
    return food.calories.toDouble();
  }

  // Try raw_json extraction
  if (food.rawJson != null) {
    try {
      final json = food.rawJson is String ? jsonDecode(food.rawJson as String) : food.rawJson;

      // USDA format
      if (json['nutrients'] is List) {
        for (var nutrient in json['nutrients']) {
          if (nutrient['nutrientId'] == 1008 || nutrient['nutrientId'] == '1008') {
            final value = nutrient['value'];
            if (value != null) {
              return double.tryParse(value.toString());
            }
          }
        }
      }

      // OFF format
      if (json['energy_kcal'] != null) {
        return double.tryParse(json['energy_kcal'].toString());
      }
      if (json['energy'] != null) {
        return double.tryParse(json['energy'].toString());
      }
      if (json['calories'] != null) {
        return double.tryParse(json['calories'].toString());
      }
    } catch (_) {}
  }

  return null;
}
