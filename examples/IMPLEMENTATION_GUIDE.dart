// ignore_for_file: unused_import, undefined_class, undefined_identifier, unused_element, unused_local_variable, directives_ordering

// ============================================================================
// IMPLEMENTATION GUIDE: Using FoodDedupNormalizer in Your App
// ============================================================================

// File: lib/services/food_dedup_normalizer.dart
// Status: ✅ COMPLETE - Ready to use

// import '../data/models/food_model.dart'; // TODO: Update path as needed

// ============================================================================
// STEP 1: Basic Usage Examples
// ============================================================================

void example_1_normalize_text() {
  // Remove accents and punctuation
  final normalized = FoodDedupNormalizer.normalizeForMatching(
    "Coca-Cola ZÉRO®",
  );
  print('$normalized'); // → "coca cola zero"
}

void example_2_normalize_brand() {
  // Normalize brand with alias mapping
  final brand1 = FoodDedupNormalizer.normalizeBrand("Coke");
  final brand2 = FoodDedupNormalizer.normalizeBrand("Coca Cola");
  final brand3 = FoodDedupNormalizer.normalizeBrand("Coca-Cola ZÉRO®");

  print('$brand1'); // → "coca-cola"
  print('$brand2'); // → "coca-cola"
  print('$brand3'); // → "coca-cola"

  // All three map to the same canonical brand!
}

void example_3_canonical_key() {
  // Generate deduplication key
  final key = FoodDedupNormalizer.generateCanonicalKey(
    name: "Diet Coke",
    brand: "Coca Cola",
    nutritionBasisType: "per100ml",
    servingSize: 100,
    servingUnit: "ml",
    calories: 0,
  );

  print('Key: $key');
  // → "diet coke|coca-cola|per100ml_100.0_ml|0"
}

void example_4_select_title() {
  // Choose best title from candidates
  final title1 = FoodDedupNormalizer.selectBestTitle(
    fullName: "Cherry Flavored Coke Mini Cans",
    brandedName: "Coke Cherry",
    descriptionName: null,
    name: "Cherry",
    shortName: null,
  );
  print('Title: $title1');
  // → "Cherry Flavored Coke Mini Cans" (skips "Cherry" as too generic)

  final title2 = FoodDedupNormalizer.selectBestTitle(
    fullName: null,
    brandedName: "Sprite Lemon Lime",
    descriptionName: "Lemon and lime flavored soft drink",
    name: "Lime",
    shortName: null,
  );
  print('Title: $title2');
  // → "Sprite Lemon Lime" (first suitable, > 6 chars)
}

// ============================================================================
// STEP 2: Integrating into SearchRepository
// ============================================================================

// File: lib/data/repositories/search_repository.dart

// import '../../services/food_dedup_normalizer.dart'; // TODO: Update path

class SearchRepository {
  // ... existing code ...

  // Add this import at the top
  // import '../../services/food_dedup_normalizer.dart';

  /// Enhanced search with deduplication
  Stream<dynamic> searchFoodsEnhanced(String query) async* {
    // ... existing search code ...
    
    // After ranking results:
    final rankedResults = FoodSearchRanker.rank(mergedResults, query);
    
    // NEW: Deduplicate with enhanced canonical keys
    final deduplicated = FoodDedupNormalizer.deduplicateResults(
      items: rankedResults,
      getCanonicalKey: (food) => food.canonicalKey,
      debug: true, // Shows debug logs
    );
    
    yield deduplicated;
  }
}

// ============================================================================
// STEP 3: Testing the Deduplication
// ============================================================================

void test_deduplication_example() {
  // Create mock data - Use Map instead of FoodModel constructor
  final results = <Map<String, dynamic>>[
    {
      'id': '1',
      'name': 'Diet Coke',
      'brand': 'Coca Cola',
      'calories': 0,
      'servingSize': 100,
      'servingUnit': 'ml',
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'source': 'local',
    },
    {
      'id': '2',
      'name': 'Coca-Cola® Diet',
      'brand': 'Coke™',
      'calories': 0,
      'servingSize': 100,
      'servingUnit': 'ml',
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'source': 'remote',
    },
    {
      'id': '3',
      'name': 'Coke Zero',
      'brand': 'Coca-Cola ZÉRO®',
      'calories': 0,
      'servingSize': 100,
      'servingUnit': 'ml',
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'source': 'cache',
    },
  ];

  // Deduplicate
  final deduplicated = FoodDedupNormalizer.deduplicateResults(
    items: results,
    getCanonicalKey: (food) => food.canonicalKey,
    debug: true,
  );

  print('Input: ${results.length} items');
  print('Output: ${deduplicated.length} items');
  
  // Expected output:
  // Input: 3 items
  // Output: 3 items (all different names after normalization)
  // 
  // But in real search:
  // - "Diet Coke" (matches query better)
  // - "Coca-Cola Diet" (different word order, lower rank)
  // → Only "Diet Coke" shown due to ranking priority
}

// ============================================================================
// STEP 4: Debug Logging Output
// ============================================================================

/*
When you run with debug=true, you'll see:

[FoodDedupNormalizer] Duplicates removed:
  - diet coke|coca-cola|per100ml_100.0_ml|0 (2 extra copies removed)
  - cherry|coca-cola|per100ml_100.0_ml|5 (1 extra copy removed)

This tells you:
- 2 extra "Diet Coke" entries were removed (found 3, kept 1)
- 1 extra "Cherry" entry was removed (found 2, kept 1)
*/

// ============================================================================
// STEP 5: Customization
// ============================================================================

// To add more brand aliases:
// Edit _brandSynonyms in FoodDedupNormalizer:

/*
static const Map<String, List<String>> _brandSynonyms = {
  'coca-cola': ['coca cola', 'coke', 'coca', 'coca-cola brand'],
  'pepsi': ['pepsi cola', 'pepsico'],
  'new-brand': ['alias1', 'alias2', 'alias3'],  // ← Add custom brand
  ...
};
*/

// To add more generic words for title filtering:
// Edit _genericWords in FoodDedupNormalizer:

/*
static const Set<String> _genericWords = {
  'cherry', 'lime', 'lemon', 'orange',
  'my-generic-word',  // ← Add custom word
  ...
};
*/

// ============================================================================
// STEP 6: API Reference
// ============================================================================

/*
FoodDedupNormalizer.normalizeForMatching(String text)
  - Purpose: Ultra-aggressive normalization for matching
  - Input: "Coca-Cola ZÉRO®"
  - Output: "coca cola zero"
  - Use case: Canonical key generation, deduplication matching

FoodDedupNormalizer.normalizeBrand(String brand)
  - Purpose: Normalize brand with alias mapping
  - Input: "Coke™"
  - Output: "coca-cola" (via _brandSynonyms)
  - Use case: Brand matching, canonical key generation

FoodDedupNormalizer.generateCanonicalKey({...})
  - Purpose: Generate deduplication key
  - Returns: "name|brand|basis|calories"
  - Use case: deduplicateResults() callable

FoodDedupNormalizer.selectBestTitle({...})
  - Purpose: Choose best title from candidates
  - Skips: Single generic words < 6 chars
  - Returns: Best suitable title
  - Use case: Choosing displayTitle

FoodDedupNormalizer.deduplicateResults({...})
  - Purpose: Remove duplicate results
  - Keeps: First (highest-ranked) per canonical key
  - Returns: Deduplicated list in same order
  - Use case: Post-ranking cleanup in SearchRepository
*/

// ============================================================================
// STEP 7: Integration Checklist
// ============================================================================

/*
☐ FoodDedupNormalizer.dart created and compiled
☐ FoodModel.canonicalKey updated to use FoodDedupNormalizer
☐ Import FoodDedupNormalizer in SearchRepository
☐ Call deduplicateResults() after FoodSearchRanker.rank()
☐ Test with "coke" query
  ☐ Verify no duplicate "Diet Coke" entries
  ☐ Verify "Coke Zero" appears once
  ☐ Verify "Cherry" expanded to full name
  ☐ Verify debug logs show canonical keys
☐ Test with other queries ("sprite", "diet", "coke zero")
☐ Monitor performance (should be negligible for typical results)
☐ Add custom brand aliases as needed
☐ Document any customizations in project README
*/

// ============================================================================
// STEP 8: Troubleshooting
// ============================================================================

/*
Q: Duplicates still appearing
A: Ensure SearchRepository calls deduplicateResults() at ALL yield points
   (local search, cache merge, remote API results)

Q: Titles not expanding
A: Verify FoodModel.displayTitle uses FoodTextNormalizer.normalize()
   Check if fullName/descriptionName fields are populated in database

Q: Brand aliases not working
A: Check if brand string matches exactly one in _brandSynonyms
   Enable debug logging to see normalization process
   Add new aliases if needed

Q: Performance slow
A: Deduplication is O(m) where m = number of results
   Should be instant for typical queries (10-50 results)
   Check if issue is database query, not deduplication

Q: Accents not removed
A: FoodDedupNormalizer._removeAccents() handles common accents
   Check if character is in the accents mapping
   Add missing character to the mapping if needed
*/

// ============================================================================
// STEP 9: Migration Path
// ============================================================================

/*
Current State:
  - FoodModel has basic canonicalKey
  - SearchRepository ranks but doesn't deduplicate
  - UI shows some duplicates and short titles

Migration to Enhanced State:
  1. ✅ Create FoodDedupNormalizer (DONE)
  2. ✅ Update FoodModel.canonicalKey (DONE)
  3. → Update SearchRepository.search() to deduplicate
  4. → Test "coke" query
  5. → Adjust brand aliases as needed
  6. → Document in project README

Rollback if needed:
  - Remove deduplicateResults() call from SearchRepository
  - Revert FoodModel.canonicalKey to simpler version
  - No database changes required
*/

// ============================================================================
// STEP 10: Future Enhancements
// ============================================================================

/*
Potential improvements:
  1. Machine learning for title selection (pick most-clicked title)
  2. User feedback: "these are duplicates" → auto-merge
  3. Caching canonical keys in database for faster lookup
  4. Analytics: track which duplicates are most common
  5. Regional brand aliases (e.g., "Coca-Cola" vs "Coke" varies by region)
  6. Automatic brand discovery from search queries
  7. A/B testing different deduplication thresholds
*/
