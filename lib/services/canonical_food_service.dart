import '../data/models/food_model.dart';
import '../data/models/food_search_result_raw.dart';
import 'canonical_food_parser.dart';
import 'canonical_food_ranker.dart';
import 'package:logger/logger.dart' as logger;

final log = logger.Logger();

/// Service integrating canonical food parsing into search results
///
/// Transforms raw database results → clean canonical groups → ranked display
class CanonicalFoodService {
  /// Process search results through canonical parsing pipeline
  ///
  /// Steps:
  /// 1. Extract FoodSearchResultRaw from each FoodModel
  /// 2. Parse into canonical groups (groups duplicates)
  /// 3. Select best representative per group
  /// 4. Rank groups by query relevance
  /// 5. Convert representatives back to FoodModel
  static List<FoodModel> processSearchResults({
    required List<FoodModel> results,
    required String query,
    int? maxResults,
  }) {
    if (results.isEmpty) return results;

    log.i(
      '🔍 [Canonical] Processing ${results.length} results for query: $query',
    );

    // Extract raw results from FoodModel
    final rawResults = <FoodSearchResultRaw>[];
    for (final food in results) {
      final raw = _extractRaw(food);
      if (raw != null) {
        rawResults.add(raw);
      }
    }

    if (rawResults.isEmpty) {
      log.i('⚠️ [Canonical] No raw results extracted');
      return results;
    }

    log.i('🔍 [Canonical] Extracted ${rawResults.length} raw results');

    // Group and select representatives
    final groups = CanonicalFoodParser.groupAndSelectRepresentatives(
      rawResults,
    );

    if (groups.isEmpty) {
      log.i('⚠️ [Canonical] No groups formed');
      return results;
    }

    log.i('🔍 [Canonical] Formed ${groups.length} groups');

    // Rank groups by query relevance
    final rankedGroups = CanonicalFoodRanker.rankGroups(
      groups.values.toList(),
      query,
    );

    log.i('🔍 [Canonical] Ranked ${rankedGroups.length} groups');

    // Convert back to FoodModel (representatives only)
    final canonicalResults = <FoodModel>[];
    for (final group in rankedGroups) {
      if (group.representative != null &&
          group.representativeCanonical != null) {
        // Find original FoodModel for this representative
        final originalFood = results.firstWhere(
          (f) => f.id == group.representative!.id,
          orElse: () => results.first,
        );

        // Preserve the original food name whenever it's a real food descriptor.
        // The canonical displayName is brand-centric — designed for USDA-style
        // opaque strings — and would replace a clean name like "Chicken Breast"
        // with the brand "Tony Downs Foods Co".
        //
        // Only use canonical.displayName when the name is empty, unknown, or
        // clearly a corporate record (contains Inc / LLC / Corp / Ltd).
        final nameLower = originalFood.name.trim().toLowerCase();
        final isCorporateName =
            nameLower.isEmpty ||
            nameLower == 'unknown' ||
            RegExp(r'\b(inc|llc|corp|ltd)\b').hasMatch(nameLower) ||
            nameLower.endsWith(' co') ||
            nameLower.endsWith(' co.');
        final canonical = group.representativeCanonical!;
        final displayFood = originalFood.copyWith(
          name: isCorporateName ? canonical.displayName : originalFood.name,
        );

        canonicalResults.add(displayFood);
      }
    }

    log.i(
      '🔍 [Canonical] Created ${canonicalResults.length} canonical results',
    );

    // Limit results if requested
    if (maxResults != null && canonicalResults.length > maxResults) {
      final limited = canonicalResults.take(maxResults).toList();
      log.i('🔍 [Canonical] Limited to $maxResults results');
      return limited;
    }

    return canonicalResults;
  }

  /// Extract FoodSearchResultRaw from FoodModel
  static FoodSearchResultRaw? _extractRaw(FoodModel food) {
    // Reconstruct FoodSearchResultRaw from FoodModel fields
    return FoodSearchResultRaw(
      id: food.id,
      source: food.source,
      sourceId: food.sourceId,
      barcode: food.barcode,
      verified: food.verified,
      providerScore: food.confidence,
      foodNameRaw: food.foodNameRaw ?? food.name,
      foodName: food.foodName ?? food.name,
      brandName: food.brandName,
      brandOwner: food.brandOwner,
      restaurantName: food.restaurantName,
      category: food.category,
      subcategory: food.subcategory,
      languageCode: food.languageCode,
      servingQty: food.servingQty,
      servingUnit: food.servingUnitRaw,
      servingWeightGrams: food.servingWeightGrams,
      servingVolumeMl: food.servingVolumeMl,
      servingOptions: food.servingOptions,
      calories: food.calories.toDouble(),
      proteinG: food.protein,
      carbsG: food.carbs,
      fatG: food.fat,
      nutritionBasis: food.nutritionBasis,
      rawJson: food.rawJson ?? {},
      lastUpdated: food.lastUpdated,
      dataType: food.dataType,
      popularity: food.popularity,
      isGeneric: food.isGeneric,
      isBranded: food.isBranded,
    );
  }
}
