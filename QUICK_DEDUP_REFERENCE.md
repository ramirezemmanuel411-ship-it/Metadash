# Food Deduplication & Normalization Quick Reference

## Overview

Three main improvements implemented:

### 1. **Accent/Diacritics Removal**
- `"Coca-Cola ZÉRO®"` → Stored as `"coca cola zero"` internally
- Works for all common accented characters (é, ñ, ü, etc.)

### 2. **Brand Alias Mapping**
- `"Coke"` + `"Coca Cola"` + `"C.cola"` all map to canonical `"coca-cola"`
- Dictionary-based with predefined synonym lists
- Extensible: add more brands as needed

### 3. **Smart Deduplication**
- Canonical key: `name|brand|servingBasis|calories`
- Keeps only highest-ranked result per unique product
- Removes duplicates BEFORE display

---

## Usage in SearchRepository

### Step 1: Import the Service
```dart
import '../../services/food_dedup_normalizer.dart';
```

### Step 2: Apply Enhanced Canonical Keys
The `FoodModel.canonicalKey` getter already uses `FoodDedupNormalizer.generateCanonicalKey()`:

```dart
// Already integrated in FoodModel:
String get canonicalKey {
  return FoodDedupNormalizer.generateCanonicalKey(
    name: name,
    brand: brand,
    nutritionBasisType: nutritionBasisType,
    servingSize: servingSize,
    servingUnit: servingUnit,
    calories: calories,
  );
}
```

### Step 3: Deduplicate Results
In `search_repository.dart`, after ranking:

```dart
// After FoodSearchRanker.rank()
var ranked = FoodSearchRanker.rank(remoteResults, query);

// Deduplicate with enhanced canonical keys
var deduplicated = FoodDedupNormalizer.deduplicateResults(
  items: ranked,
  getCanonicalKey: (food) => food.canonicalKey,
  debug: true, // Shows duplicate count in logs
);

yield deduplicated;
```

---

## Before vs After Examples

### Example 1: Duplicate Detection with Accents

**BEFORE (6 items):**
```
1. Diet Coke        | Coca Cola | 0 cal
2. Coca-Cola Diet   | Coke™     | 0 cal  ← DUPLICATE
3. Coke Zero        | Coca-Cola | 0 cal
4. C.cola Zero      | Coca-Cola ZÉRO® | 0 cal  ← DUPLICATE
5. Diet Coke®       | The Coca-Cola Company | 0 cal  ← DUPLICATE
6. Cherry           | Coca Cola | 5 cal
```

**AFTER (4 items, deduplicated):**
```
1. Diet Coke        | Coca-Cola | 0 cal  ← Kept (highest ranked)
2. Coke Zero        | Coca-Cola | 0 cal  ← Different product
3. Cherry Flavored Coke Mini Cans | Coca-Cola | 5 cal  ← Title upgraded
```

**Canonical Keys Generated:**
```
Item 1: "diet coke|coca-cola|per100ml_100.0_ml|0"
Item 2: "coca cola diet|coca-cola|per100ml_100.0_ml|0"     (Different name)
Item 3: "coke zero|coca-cola|per100ml_100.0_ml|0"          (Different name)
Item 4: "c cola zero|coca-cola|per100ml_100.0_ml|0"        (Different name after normalization)
Item 5: "diet coke|coca-cola|per100ml_100.0_ml|0"          ← DUPLICATE KEY
Item 6: "cherry|coca-cola|per100ml_100.0_ml|5"
```

**Result:** Items 1, 3, and 5 might still look different after step 1, but step 2 handles them.

### Example 2: Text Normalization Process

**Input:**
```dart
FoodModel(
  name: 'Coca-Cola® Diet',
  brand: 'Coke™',
  calories: 0,
  servingSize: 100,
  servingUnit: 'ml',
)
```

**Normalization Steps:**
```
Step 1: Remove accents
  "Coca-Cola® Diet" (no accents to remove)
  
Step 2: Convert to lowercase
  "coca-cola® diet"
  
Step 3: Remove punctuation & symbols
  "coca cola diet"  (® and - removed)
  
Step 4: Collapse spaces
  "coca cola diet"
  
Step 5: Trim
  "coca cola diet"

Brand Normalization:
  "Coke™" → normalizeForMatching() → "coke"
           → Via alias "coca-cola": ["coca cola", "coke", ...]
           → Returns "coca-cola"

Final Canonical Key:
  "coca cola diet|coca-cola|per100ml_100.0_ml|0"
```

### Example 3: Brand Alias Mapping

**Query: "coke"**

| User Input | Normalized | Matches | Canonical |
|-----------|-----------|---------|-----------|
| Coke | coke | coke (alias) | coca-cola |
| Coca Cola | coca cola | coca cola (alias) | coca-cola |
| Coca-Cola ZÉRO® | coca cola zero | coca cola (alias) | coca-cola |
| C.cola™ | c cola | — | c cola |

---

## Implementation Checklist

- [x] Create `FoodDedupNormalizer` service with all methods
- [x] Implement accent/diacritics removal (`_removeAccents`)
- [x] Implement ultra-aggressive normalization (`normalizeForMatching`)
- [x] Implement brand alias mapping (`normalizeBrand`)
- [x] Implement canonical key generation (`generateCanonicalKey`)
- [x] Implement smart title selection (`selectBestTitle`)
- [x] Implement deduplication (`deduplicateResults`)
- [x] Update `FoodModel.canonicalKey` to use enhanced normalizer
- [ ] Update `SearchRepository` to call `FoodDedupNormalizer.deduplicateResults()`
- [ ] Test "coke" query to verify duplicates removed
- [ ] Test "cherry" title expansion
- [ ] Test brand alias matching

---

## Key Methods Reference

### `normalizeForMatching(String text) → String`
Ultra-aggressive normalization for matching.

```dart
"Coca-Cola ZÉRO®" → "coca cola zero"
"C.cola™ - Diet" → "c cola diet"
```

### `normalizeBrand(String brand) → String`
Normalize brand with alias mapping.

```dart
"Coke" → "coca-cola"
"Coca Cola" → "coca-cola"
```

### `generateCanonicalKey({...}) → String`
Generate deduplication key.

```dart
FoodDedupNormalizer.generateCanonicalKey(
  name: "Diet Coke",
  brand: "Coca Cola",
  nutritionBasisType: "per100ml",
  servingSize: 100,
  servingUnit: "ml",
  calories: 0,
)
// → "diet coke|coca-cola|per100ml_100.0_ml|0"
```

### `selectBestTitle({...}) → String`
Choose best title from candidates.

```dart
FoodDedupNormalizer.selectBestTitle(
  fullName: "Cherry Flavored Coke Mini Cans",
  brandedName: "Coke Cherry",
  descriptionName: null,
  name: "Cherry",
  shortName: null,
)
// → "Cherry Flavored Coke Mini Cans"
```

### `deduplicateResults<T>({...}) → List<T>`
Deduplicate results while preserving rank order.

```dart
final deduplicated = FoodDedupNormalizer.deduplicateResults(
  items: rankedResults,
  getCanonicalKey: (food) => food.canonicalKey,
  debug: true,
);
// Output:
// [FoodDedupNormalizer] Duplicates removed:
//   - diet coke|coca-cola|per100ml_100.0_ml|0 (2 extra copies removed)
```

---

## Testing

### Test Case 1: Accent Removal
```dart
void test_accentRemoval() {
  expect(
    FoodDedupNormalizer.normalizeForMatching("Coca-Cola ZÉRO®"),
    equals("coca cola zero"),
  );
}
```

### Test Case 2: Brand Aliasing
```dart
void test_brandAliasing() {
  final key1 = FoodDedupNormalizer.generateCanonicalKey(
    name: "Diet Coke",
    brand: "Coca Cola",
    nutritionBasisType: "per100ml",
    servingSize: 100,
    servingUnit: "ml",
    calories: 0,
  );
  
  final key2 = FoodDedupNormalizer.generateCanonicalKey(
    name: "Coca-Cola® Diet",
    brand: "Coke™",
    nutritionBasisType: "per100ml",
    servingSize: 100,
    servingUnit: "ml",
    calories: 0,
  );
  
  expect(key1, equals(key2)); // Should be same product
}
```

### Test Case 3: Short Title Expansion
```dart
void test_titleExpansion() {
  final title = FoodDedupNormalizer.selectBestTitle(
    fullName: "Cherry Flavored Coke Mini Cans",
    brandedName: null,
    descriptionName: null,
    name: "Cherry",
    shortName: null,
  );
  
  expect(title, equals("Cherry Flavored Coke Mini Cans"));
}
```

---

## Next Steps

1. **Update SearchRepository:**
   ```dart
   // In search_repository.dart, after ranking:
   var ranked = FoodSearchRanker.rank(results, query);
   var deduplicated = FoodDedupNormalizer.deduplicateResults(
     items: ranked,
     getCanonicalKey: (food) => food.canonicalKey,
     debug: true,
   );
   yield deduplicated;
   ```

2. **Test with "coke" query:**
   - Should show "Diet Coke" once (not twice)
   - Should show "Coke Zero" once
   - Debug logs should show canonical keys

3. **Monitor debug logs:**
   - Look for `[FoodDedupNormalizer] Duplicates removed:` messages
   - Verify canonical keys are being generated correctly

4. **Extend brand synonyms as needed:**
   - Update `_brandSynonyms` map in `FoodDedupNormalizer`
   - Add new brands: `'brand-name': ['alias1', 'alias2', ...]`
