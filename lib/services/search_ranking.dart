import '../data/models/food_model.dart';
import 'search_normalization.dart';

/// Score a search result based on query and data quality
double scoreResult(FoodModel item, String query) {
  double score = 0;

  // Tokenize query
  final queryTokens = query.toLowerCase().split(RegExp(r'\s+'));
  final brandTokens = SearchNormalization.canonicalBrand(item).toLowerCase().split(' ');
  final productTokens = SearchNormalization.canonicalProductName(item).toLowerCase().split(' ');

  // Exact brand match boost
  for (final token in queryTokens) {
    if (brandTokens.contains(token)) {
      score += 100;
    }
  }

  // Exact product match boost
  for (final token in queryTokens) {
    if (productTokens.contains(token)) {
      score += 50;
    }
  }

  // Penalize fragments unless query includes the fragment
  final productName = SearchNormalization.canonicalProductName(item).toLowerCase();
  if (_isFragment(productName)) {
    bool queryHasFragment = queryTokens.contains(productName);
    if (!queryHasFragment) {
      score -= 200; // Strong penalty
    }
  }

  // Boost if barcode exists (trusted data)
  if (item.barcode?.isNotEmpty == true) {
    score += 50;
  }

  // Boost if branded data
  if (item.isBranded == true) {
    score += 30;
  }

  // Boost if complete nutrition
  if (item.calories > 0 && item.protein > 0 && item.carbs > 0 && item.fat > 0) {
    score += 20;
  } else if (item.calories > 0) {
    score += 10;
  }

  // Boost if has serving info
  if ((item.servingVolumeMl ?? 0) > 0 || (item.servingWeightGrams ?? 0) > 0) {
    score += 15;
  }

  // Slight boost for USDA if brand is present
  if (item.source.toLowerCase().contains('usda') && SearchNormalization.canonicalBrand(item).isNotEmpty) {
    score += 5;
  }

  return score;
}

/// Deduplicate food results keeping best representatives
List<FoodModel> dedupeResults(List<FoodModel> items, String query) {
  if (items.isEmpty) return items;

  final byDedupeKey = <String, FoodModel>{};
  final byBarcode = <String, FoodModel>{};

  for (final item in items) {
    final dedupeKey = createDedupeKey(item);
    final barcodeKey = getBarcodeKey(item);

    // Handle barcode duplicates
    if (barcodeKey != null && byBarcode.containsKey(barcodeKey)) {
      final existing = byBarcode[barcodeKey]!;
      if (_isBetterRepresentative(item, existing)) {
        byBarcode[barcodeKey] = item;
      }
      continue;
    }
    if (barcodeKey != null) {
      byBarcode[barcodeKey] = item;
    }

    // Handle dedupe key duplicates
    if (byDedupeKey.containsKey(dedupeKey)) {
      final existing = byDedupeKey[dedupeKey]!;
      if (_isBetterRepresentative(item, existing)) {
        byDedupeKey[dedupeKey] = item;
      }
    } else {
      byDedupeKey[dedupeKey] = item;
    }
  }

  // Merge both maps (prefer barcode duplicates)
  final result = <FoodModel>[];
  final seenDedupeKeys = <String>{};

  // Add barcode items first
  for (final item in byBarcode.values) {
    result.add(item);
    final key = createDedupeKey(item);
    seenDedupeKeys.add(key);
  }

  // Add non-barcode items
  for (final entry in byDedupeKey.entries) {
    if (!seenDedupeKeys.contains(entry.key)) {
      result.add(entry.value);
    }
  }

  // Sort by score, then name length, then calorie presence
  result.sort((a, b) {
    final scoreA = scoreResult(a, query);
    final scoreB = scoreResult(b, query);

    if (scoreA != scoreB) {
      return scoreB.compareTo(scoreA); // Higher score first
    }

    // Shorter cleaner names first
    final titleA = SearchNormalization.displayTitle(a);
    final titleB = SearchNormalization.displayTitle(b);

    if (titleA.length != titleB.length) {
      return titleA.length.compareTo(titleB.length);
    }

    // Calories present first
    if (a.calories > 0 && b.calories <= 0) return -1;
    if (a.calories <= 0 && b.calories > 0) return 1;

    return 0;
  });

  return result;
}

/// Check if item A is a better representative than item B
bool _isBetterRepresentative(FoodModel a, FoodModel b) {
  // Prefer item with barcode
  if ((a.barcode?.isNotEmpty == true) && (b.barcode?.isEmpty != false)) {
    return true;
  }
  if ((a.barcode?.isEmpty != false) && (b.barcode?.isNotEmpty == true)) {
    return false;
  }

  // Prefer branded
  if (a.isBranded == true && b.isBranded != true) {
    return true;
  }
  if (a.isBranded != true && b.isBranded == true) {
    return false;
  }

  // Prefer complete nutrition
  final aHasComplete = a.calories > 0 && a.protein > 0 && a.carbs > 0 && a.fat > 0;
  final bHasComplete = b.calories > 0 && b.protein > 0 && b.carbs > 0 && b.fat > 0;

  if (aHasComplete && !bHasComplete) return true;
  if (!aHasComplete && bHasComplete) return false;

  // Prefer with serving info
  final aHasServing = (a.servingVolumeMl ?? 0) > 0 || (a.servingWeightGrams ?? 0) > 0;
  final bHasServing = (b.servingVolumeMl ?? 0) > 0 || (b.servingWeightGrams ?? 0) > 0;

  if (aHasServing && !bHasServing) return true;
  if (!aHasServing && bHasServing) return false;

  // Prefer higher calorie (more likely to be the main product)
  if (a.calories != b.calories) {
    return a.calories > b.calories;
  }

  // Prefer shorter title (cleaner)
  final aTitle = SearchNormalization.displayTitle(a);
  final bTitle = SearchNormalization.displayTitle(b);

  return aTitle.length < bTitle.length;
}

bool _isFragment(String text) {
  const fragments = ['lime', 'cherry', 'diet', 'zero', 'vanilla', 'coke', 'diet', 'sugar'];
  return fragments.contains(text.toLowerCase());
}

// ============ DEBUG HELPERS ============

/// Print debug info for top results
void debugPrintSearchResults(List<FoodModel> results, String query) {
  if (results.isEmpty) {
    print('📭 No results for query: "$query"');
    return;
  }

  print('\n🔍 SEARCH RESULTS: "$query" (${results.length} items)');
  print('─' * 120);

  for (int i = 0; i < results.take(10).length; i++) {
    final item = results[i];
    final score = scoreResult(item, query);
    final dedupeKey = createDedupeKey(item);
    final title = SearchNormalization.displayTitle(item);
    final subtitle = SearchNormalization.displaySubtitle(item);
    final hasBarcode = item.barcode?.isNotEmpty == true ? '✓' : '✗';
    final isBranded = item.isBranded == true ? 'Y' : 'N';
    final hasKcal = item.calories > 0 ? 'Y' : 'N';

    print('[${(i + 1).toString().padLeft(2)}] Score: ${score.toStringAsFixed(0).padLeft(4)} | '
        'Title: ${title.padRight(25)} | '
        'Subtitle: ${subtitle.padRight(30)} | '
        'Barcode: $hasBarcode | Branded: $isBranded | Kcal: $hasKcal');
    print('     Source: ${item.source.padRight(12)} | '
        'DedupeKey: ${dedupeKey.substring(0, (dedupeKey.length / 2).toInt()).padRight(40)}');
  }

  print('─' * 120);
}
