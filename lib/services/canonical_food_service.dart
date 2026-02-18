import '../data/models/food_model.dart';
import '../data/models/food_search_result_raw.dart';
import 'canonical_food_parser.dart';
import 'canonical_food_ranker.dart';

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

    print('🔍 [Canonical] Processing ${results.length} results for query: $query');

    // Extract raw results from FoodModel
    final rawResults = <FoodSearchResultRaw>[];
    for (final food in results) {
      final raw = _extractRaw(food);
      if (raw != null) {
        rawResults.add(raw);
      }
    }

    if (rawResults.isEmpty) {
      print('⚠️ [Canonical] No raw results extracted');
      return results;
    }

    print('🔍 [Canonical] Extracted ${rawResults.length} raw results');

    // Group and select representatives
    final groups = CanonicalFoodParser.groupAndSelectRepresentatives(
      rawResults,
    );

    if (groups.isEmpty) {
      print('⚠️ [Canonical] No groups formed');
      return results;
    }

    print('🔍 [Canonical] Formed ${groups.length} groups');

    // Rank groups by query relevance
    final rankedGroups = CanonicalFoodRanker.rankGroups(
      groups.values.toList(),
      query,
    );

    print('🔍 [Canonical] Ranked ${rankedGroups.length} groups');

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

        // Create display version with canonical name
        final canonical = group.representativeCanonical!;
        final displayFood = originalFood.copyWith(
          // Use canonical display name instead of raw DB string
          name: canonical.displayName,
        );

        canonicalResults.add(displayFood);
      }
    }

    print('🔍 [Canonical] Created ${canonicalResults.length} canonical results');

    // Limit results if requested
    if (maxResults != null && canonicalResults.length > maxResults) {
      final limited = canonicalResults.take(maxResults).toList();
      print('🔍 [Canonical] Limited to $maxResults results');
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
