# Quick Reference: Testing the Food Search Deduplication Fix

## What Changed?

Three critical bugs fixed:
1. **Brand Normalization** - "Coke", "Coca-Cola", "coca cola" now all map to "coca-cola"
2. **Flavor Detection** - "original" is NO LONGER treated as a flavor (should be "none")
3. **Core Name Inference** - "goût original", "sabor original" removed as complete tokens, not individually

---

## Test It Yourself

### Test Case 1: Search "coke"

**Expected Results (5 items shown, NOT 11):**
```
1. Coca Cola Coke Brand      (44 cal, regular) - CANONICAL
2. Diet Coke                 (0 cal, diet)
3. Coke Zero                 (0 cal, zero sugar)
4. Cherry Flavored Coke      (45 cal, cherry)
5. Coke With Lime Flavor     (42 cal, lime)
```

**NOT Expected:**
- ❌ "Original Taste" as separate item (merged into #1)
- ❌ "Coca cola Goût Original" as separate item (merged into #1)
- ❌ "Original Taste Coke" as separate item (merged into #1)
- ❌ "Transformation" ranked high (dropped by relevance filter)

---

### Test Case 2: Check Debug Output

In Xcode console, search for:
```
🔍 [UNIVERSAL DEDUP] Query: "coke"
```

Look for:
- ✅ "Grouped into 5 families" (was: 9 families)
- ✅ Family "coca-cola|cola|regular|none": 3 candidates → selected "Coca Cola Coke Brand"
- ✅ Collapsed items listed (Original Taste, Coca cola Goût Original)

---

### Test Case 3: Verify Family Signatures

Search for debug line like:
```
✅ Family "coca-cola|cola|regular|none":
   • 3 candidates → selected "Coca Cola Coke Brand"
   • Collapsed: Original Taste, Coca cola Goût Original
```

This confirms:
1. All three items have SAME family signature
2. Canonical was selected (Coca Cola Coke Brand has best score)
3. Duplicates were properly merged

---

### Test Case 4: Other Searches

Try these searches to verify the system works for ALL products:

#### Search: "yogurt"
Expected: Greek yogurt variants collapse (nonfat, whole, 2% should stay separate, but exact name duplicates merge)

#### Search: "chips"
Expected: Lays Original, Lays Classic, Lays Traditional collapse (if exact match)

#### Search: "pepsi"
Expected: Similar behavior - "Pepsi", "Pepsi Cola", "PepsiCo" normalize to "pepsi"

---

## Key Numbers

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| Items for "coke" | 11 | 5 | 5-7 |
| Families created | 9 | 5 | 5-7 |
| Collapsed duplicates | 2 | 6 | 5+ |
| Relevance ranking | ✗ | ✓ | ✓ |

---

## Implementation Details

### Files Modified:
1. **lib/services/universal_food_deduper.dart** (added 300+ lines)
   - New: `normalizeBrand()`, `inferCoreName()`, `_secondPassDedup()`, `_applyQueryRelevance()`
   - Updated: `buildFamilyKey()`, `deduplicateByFamily()`

2. **test/food_deduplication_test.dart** (complete rewrite)
   - 10+ unit tests covering all scenarios

### New Helper Functions:
- `jaroWinklerSimilarity()` - String matching (0-1 score)
- `tokenOverlapSimilarity()` - Token-based matching (0-1 score)

---

## Troubleshooting

### Problem: Still seeing duplicates for "coke"
**Solution:** 
1. Force hot restart: `R` in Flutter terminal (not just hot reload `r`)
2. Check that `buildFamilyKey()` is using new `normalizeBrand()` and `inferCoreName()`
3. Verify debug output shows family grouping step

### Problem: "Transformation" still appears at top
**Solution:**
1. Query relevance filter should drop it - check `_applyQueryRelevance()` is being called
2. Verify token overlap is being calculated correctly (should be 0/0 = 0.0 for "transformation" vs "coke")

### Problem: Diet/Zero merging incorrectly
**Solution:**
1. Verify `extractDietType()` is working:
   - "diet" → "diet"
   - "zero" → "zero"
   - else → "regular"
2. Family signature includes diet type - different diets should NOT merge

---

## Before/After Comparison

### Before Fix: Family Signatures Generated
```
"Coca Cola Coke Brand"           → cocacola|cola coke|regular|original
"Coca cola Goût Original"        → cocacola|cola|regular|original
"Original Taste Coke"            → generic|coke|regular|original
                                   ↑ Different!
```

### After Fix: Family Signatures Generated
```
"Coca Cola Coke Brand"           → coca-cola|cola|regular|none
"Coca cola Goût Original"        → coca-cola|cola|regular|none
"Original Taste Coke"            → coca-cola|cola|regular|none
                                   ↑ IDENTICAL! ✓
```

---

## Success Criteria

✅ All of these must be true after fix:

1. **Brand Normalization**
   - [ ] "Coca-Cola", "Coke", "coca cola" all → "coca-cola"
   - [ ] "USDA" → "generic" (not treated as brand)
   - [ ] null brand with "coke" in name → "coca-cola"

2. **Flavor Detection**
   - [ ] "original taste" → flavor = "none" (not "original")
   - [ ] "goût original" → flavor = "none" (not "gout original")
   - [ ] "cherry coke" → flavor = "cherry" ✓

3. **Core Name Inference**
   - [ ] "original taste" → coreName = "cola" (inferred from brand)
   - [ ] "coca cola goût original" → coreName = "cola"
   - [ ] "sabor original" → coreName = "cola"

4. **Family Signature**
   - [ ] All three variants → "coca-cola|cola|regular|none"
   - [ ] Diet Coke → "coca-cola|cola|diet|none" (different!)
   - [ ] Coke Zero → "coca-cola|cola|zero|none" (different!)

5. **Deduplication**
   - [ ] 11 raw items → 5 displayed items ✓
   - [ ] "Coca cola Goût Original" merged with canonical
   - [ ] "Original Taste" merged with canonical
   - [ ] "Original Taste Coke" merged with canonical
   - [ ] "Transformation" dropped or ranked last ✓

---

## How to Enable Debug Output

In `lib/services/universal_food_deduper.dart`, call with `debug=true`:

```dart
FoodSearchRanker.rank(results: items, query: 'coke', debug: true);
```

Or directly:

```dart
final result = UniversalFoodDeduper.deduplicateByFamily(
  items: items,
  query: 'coke',
  debug: true,
);
```

Console will show detailed step-by-step transformation for every item.

---

## Expected Debug Output Sample

```
🔍 [UNIVERSAL DEDUP] Query: "coke" (debug=true)
   📥 Raw input: 11 items
   
   ✅ Family "coca-cola|cola|regular|none":
      • 3 candidates → selected "Coca Cola Coke Brand"
      • Collapsed: Original Taste, Coca cola Goût Original
   
   📋 Detailed family signatures:
   [1] Coca Cola Coke Brand
        nameNorm="coca cola coke brand"
        brandNorm="coca-cola" | coreName="cola" | diet="regular" | flavor="none"
        sig=coca-cola|cola|regular|none
   [2] Diet Coke
        nameNorm="diet coke"
        brandNorm="coca-cola" | coreName="cola" | diet="diet" | flavor="none"
        sig=coca-cola|cola|diet|none
   ...
```

All three language variants show the SAME family signature ✓

