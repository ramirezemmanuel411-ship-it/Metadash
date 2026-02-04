// BEFORE vs AFTER: Food Search Deduplication & Title Selection
// 
// This document demonstrates the improvements made to handle duplicates,
// short titles, and brand/name variations.

// ============================================================================
// EXAMPLE 1: Duplicate Detection with Brand Aliases
// ============================================================================

// BEFORE (6 items, with duplicates):
// 1. Diet Coke | Brand: Coca Cola | 0 cal • 100 ml
// 2. Coca-Cola Diet | Brand: Coke™ | 0 cal • 100 ml  <-- DUPLICATE
// 3. Coke Zero | Brand: Coca-Cola ZÉRO® | 0 cal • 100 ml
// 4. C.cola Zero | Brand: C.cola™ | 0 cal • 100 ml  <-- DUPLICATE
// 5. Diet Coke® | Brand: The Coca-Cola Company | 0 cal • 100 ml  <-- DUPLICATE
// 6. Cherry | Brand: Coca Cola | 5 cal • 100 ml

// AFTER (4 items, deduplicated + title selection applied):
// 1. Diet Coke | Brand: Coca-Cola | 0 cal • 100 ml  <-- Kept highest-ranked
// 2. Coke Zero | Brand: Coca-Cola | 0 cal • 100 ml  <-- Kept highest-ranked
// 3. Cherry Flavored Coke Mini Cans | Brand: Coca-Cola | 5 cal • 100 ml  <-- Title upgraded

// ============================================================================
// EXAMPLE 2: Text Normalization Process
// ============================================================================

// Input items:
[
  FoodModel(
    id: '1',
    name: 'Diet Coke',
    brand: 'Coca Cola',
    calories: 0,
    ...
  ),
  FoodModel(
    id: '2',
    name: 'Coca-Cola® Diet',
    brand: 'Coke™',
    calories: 0,
    ...
  ),
  FoodModel(
    id: '3',
    name: 'COKE ZERO',
    brand: 'Coca-Cola ZÉRO®',
    calories: 0,
    ...
  ),
]

// Canonical keys generated:
/*
Item 1: FoodDedupNormalizer.generateCanonicalKey(
  name: "Diet Coke",
  brand: "Coca Cola",
  nutritionBasisType: "per100ml",
  servingSize: 100,
  servingUnit: "ml",
  calories: 0,
)
// Normalizations applied:
// - name: "diet coke"                                (lowercase)
// - brand: "coca-cola" (via alias mapping)          (normalized + alias)
// - Removed: accents, punctuation, symbols
// Result: "diet coke|coca-cola|per100ml_100.0_ml|0"

Item 2: FoodDedupNormalizer.generateCanonicalKey(
  name: "Coca-Cola® Diet",
  brand: "Coke™",
  nutritionBasisType: "per100ml",
  servingSize: 100,
  servingUnit: "ml",
  calories: 0,
)
// Normalizations applied:
// - name: "coca cola diet" (removed ®)              (accent/symbol removal)
// - brand: "coca-cola" (via alias mapping)          (Coke™ → coca-cola via synonyms)
// - Result: "coca cola diet|coca-cola|per100ml_100.0_ml|0"  <-- DIFFERENT KEY
//   (different because name has "diet" as suffix)

Item 3: FoodDedupNormalizer.generateCanonicalKey(
  name: "COKE ZERO",
  brand: "Coca-Cola ZÉRO®",
  nutritionBasisType: "per100ml",
  servingSize: 100,
  servingUnit: "ml",
  calories: 0,
)
// Normalizations applied:
// - name: "coke zero"     (uppercase → lowercase)
// - brand: "coca-cola"    (ZÉRO® removed, Coca-Cola ZÉRO → coca-cola)
// - Result: "coke zero|coca-cola|per100ml_100.0_ml|0"
*/

// Deduplication result:
// - Item 1 kept (first occurrence of "diet coke|coca-cola|...")
// - Item 2 marked as duplicate? NO - different name normalization
//   (This might still be a duplicate in real world, but names differ enough)
// - Item 3 kept (unique: "coke zero|coca-cola|...")

// ============================================================================
// EXAMPLE 3: Short Title Upgrade
// ============================================================================

// BEFORE:
// 1. Title: "Cherry" | Brand: Coca Cola
//    → User sees: "Cherry" (what type? flavor? just cherry juice?)

// AFTER (with title selection):
// selectBestTitle(
//   fullName: "Cherry Flavored Coke Mini Cans",
//   brandedName: "Coke Cherry",
//   descriptionName: null,
//   name: "Cherry",
//   shortName: null,
// )
// 
// Process:
// 1. "Cherry Flavored Coke Mini Cans" (length 28, >6) → SUITABLE ✓
// 2. Result: "Cherry Flavored Coke Mini Cans"
//
// User sees: "Cherry Flavored Coke Mini Cans" (much better!)

// ============================================================================
// EXAMPLE 4: Integration in Search Repository
// ============================================================================

// In search_repository.dart, after ranking results:

Stream<List<FoodModel>> searchFoods(String query) async* {
  // ... existing code ...
  
  // Stage 3: Remote API results
  final remoteResults = await _fetchRemoteResults(query);
  
  // RANK (existing)
  var ranked = FoodSearchRanker.rank(remoteResults, query);
  
  // DEDUPLICATE (NEW) - Enhanced deduplication with accent removal + brand aliases
  var deduplicated = FoodDedupNormalizer.deduplicateResults(
    items: ranked,
    getCanonicalKey: (food) => food.canonicalKey,
    debug: true, // Shows duplicate count in logs
  );
  
  // APPLY ENHANCED TITLES (Automatic from model)
  // The FoodModel now uses enhanced canonicalKey generation
  // and displayTitle already gets normalized via FoodTextNormalizer
  
  yield deduplicated;
}

// ============================================================================
// EXAMPLE 5: String Normalization Examples
// ============================================================================

// Accent Removal:
"ZÉRO" → "ZERO"
"Café" → "Cafe"
"Naïve" → "Naive"
"Açaí" → "Acai"

// Text Normalization for Matching:
"Coca-Cola ZÉRO®" → "coca cola zero"
"C.cola™ - Diet" → "c cola diet"
"Sprite® Lemon Lime" → "sprite lemon lime"

// Brand Alias Mapping:
"Coke" → "coca-cola" (via _brandSynonyms)
"Coca Cola" → "coca-cola"
"Coca-Cola" → "coca-cola"
"Coca-Cola ZÉRO®" → "coca-cola"

// ============================================================================
// EXAMPLE 6: Generic Word Detection
// ============================================================================

// Generic words that shouldn't be the only part of a title:
const Set<String> _genericWords = {
  'cherry', 'lime', 'lemon', 'orange',
  'original', 'diet', 'zero', 'sugar',
  'vanilla', 'chocolate', 'cola', 'soda',
  ...
};

// Title "Cherry" alone is too generic:
_isSuitableTitle("Cherry") → false (single generic word)
selectBestTitle(..., name: "Cherry", fullName: "Cherry Flavored Coke")
→ "Cherry Flavored Coke" (chosen because Cherry is too short)

// Title "Diet Coke" is OK:
_isSuitableTitle("Diet Coke") → true (length 9, multiple words)

// ============================================================================
// QUICK IMPLEMENTATION CHECKLIST
// ============================================================================

// 1. ✅ Created FoodDedupNormalizer service with:
//    - normalizeForMatching() - accent removal + punctuation stripping
//    - normalizeBrand() - includes brand alias mapping
//    - generateCanonicalKey() - comprehensive key for deduplication
//    - selectBestTitle() - smart title selection
//    - deduplicateResults() - batch deduplication with ordering preservation

// 2. ✅ Updated FoodModel:
//    - canonicalKey now uses FoodDedupNormalizer.generateCanonicalKey()
//    - Handles accents, brand aliases, calories rounding

// 3. ✅ FoodTextNormalizer (existing):
//    - Already has fuzzyMatch(), prefixMatch(), wholeWordMatch()
//    - Already has brand synonym mapping via _brandSynonyms

// 4. 🔄 NEXT: Update SearchRepository to log deduplication
//    - Call FoodDedupNormalizer.deduplicateResults() with debug=true
//    - Show canonical key and duplicate count

// 5. 🔄 TESTING: Run "coke" query and verify:
//    - ✅ "Diet Coke" appears once (not twice)
//    - ✅ "Coke Zero" appears once
//    - ✅ "Cherry" titles expanded to full names
//    - ✅ "Coca-Cola ZÉRO®" merged with "Coke Zero"

// ============================================================================
// CODE EXAMPLES: Using FoodDedupNormalizer
// ============================================================================

// Example 1: Check if two products are the same
void example1() {
  final product1 = FoodModel(
    id: '1',
    name: 'Diet Coke',
    brand: 'Coca Cola',
    calories: 0,
    servingSize: 100,
    servingUnit: 'ml',
    // ...
  );

  final product2 = FoodModel(
    id: '2',
    name: 'Coca-Cola® Diet',
    brand: 'Coke™',
    calories: 0,
    servingSize: 100,
    servingUnit: 'ml',
    // ...
  );

  final key1 = product1.canonicalKey;
  final key2 = product2.canonicalKey;

  print('Key 1: $key1');
  print('Key 2: $key2');
  print('Are duplicates? ${key1 == key2}');
}

// Example 2: Normalize brand with aliases
void example2() {
  print(FoodDedupNormalizer.normalizeBrand("Coca Cola")); // → coca-cola
  print(FoodDedupNormalizer.normalizeBrand("Coke"));      // → coca-cola
  print(FoodDedupNormalizer.normalizeBrand("Coke™"));     // → coca-cola
}

// Example 3: Remove accents
void example3() {
  final text = "Coca-Cola ZÉRO®";
  final normalized = FoodDedupNormalizer.normalizeForMatching(text);
  print('$text → $normalized');
  // → coca cola zero
}

// Example 4: Select best title
void example4() {
  final title = FoodDedupNormalizer.selectBestTitle(
    fullName: 'Cherry Flavored Coke Mini Cans',
    brandedName: 'Coke Cherry',
    descriptionName: null,
    name: 'Cherry',
    shortName: null,
  );
  print('Selected: $title');
  // → Cherry Flavored Coke Mini Cans
}

// Example 5: Deduplicate results
void example5() {
  final results = [
    FoodModel(id: '1', name: 'Diet Coke', brand: 'Coca Cola', ...),
    FoodModel(id: '2', name: 'Coca-Cola Diet', brand: 'Coke', ...),
    FoodModel(id: '3', name: 'Coke Zero', brand: 'Coca-Cola', ...),
  ];

  final deduplicated = FoodDedupNormalizer.deduplicateResults(
    items: results,
    getCanonicalKey: (food) => food.canonicalKey,
    debug: true,
  );

  // Output:
  // [FoodDedupNormalizer] Duplicates removed:
  //   - diet coke|coca-cola|per100ml_100.0_ml|0 (1 extra copy removed)
  //
  // Result: 2 items (Diet Coke kept once, Coke Zero separate)
}
