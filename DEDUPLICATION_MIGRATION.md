# Migration to Universal Food Deduplication

## What Changed

### Old System (Coke-specific)
- `FoodDedupNormalizer` - Coke-focused with hardcoded families
- `deduplicateByProductFamily()` - Limited to beverages
- Hardcoded constants: `FAMILY_REGULAR`, `FAMILY_DIET`, `FAMILY_ZERO`, etc.

### New System (Universal)
- `UniversalFoodDeduper` - Works for all food categories
- Dictionary-based variant extraction
- Smart core key building with marketing word removal
- Multi-criteria representative selection

## Migration Steps

### 1. Update Import (Already Done)
```dart
// OLD
import 'food_dedup_normalizer.dart';

// NEW
import 'universal_food_deduper.dart';
```

### 2. Update Ranker Call (Already Done)
```dart
// OLD
final familyDeduplicated = FoodDedupNormalizer.deduplicateByProductFamily(
  items: deduplicated,
  getName: (item) => item.name,
  getBrand: (item) => item.brand,
  getCalories: (item) => item.calories,
  debug: false,
);

// NEW
final familyResult = UniversalFoodDeduper.deduplicateByFamily(
  items: deduplicated,
  query: query,
  debug: false,
);
return familyResult.groupedResults;
```

### 3. Optional: Access Variants Map
If you want to show variants on tap:
```dart
final familyResult = UniversalFoodDeduper.deduplicateByFamily(
  items: deduplicated,
  query: query,
);

// Display grouped results
for (final item in familyResult.groupedResults) {
  final familyKey = UniversalFoodDeduper.buildFamilyKey(
    name: item.name,
    brand: item.brand,
  );
  final variants = familyResult.familyVariantsMap[familyKey] ?? [];
  print('${item.displayTitle} has ${variants.length} variants');
}
```

## Key Improvements

### 1. Universal Coverage
**Before:** Only worked well for Coke and beverages  
**After:** Works for all categories (dairy, snacks, produce, beverages, etc.)

### 2. Better Variant Detection
**Before:** Hardcoded product families (REGULAR, DIET, ZERO, CHERRY, LIME)  
**After:** Dictionary-based extraction of:
- Diet types (diet, zero, light, sugar-free)
- Flavors (30+ flavors: cherry, vanilla, strawberry, etc.)
- Formats (can, bottle, bar, chips, powder)
- Fat levels (nonfat, 1%, 2%, whole)
- Prep methods (raw, cooked, frozen)

### 3. Smarter Representative Selection
**Before:** Simple scoring (brand + title length + calories)  
**After:** Multi-criteria tie-breaking:
1. Verified branded items (+1000 pts)
2. Exact brand match to query (+500 pts)
3. Complete nutrition fields (+50 pts each)
4. Text quality score (+0 to +100)
5. Preferred source (USDA: +100, OFF: +80)
6. Title length bonus (+0 to +30)

### 4. Language Variants Handled
**Before:** Hardcoded list: "original", "goût original", "sabor original"  
**After:** Core key builder removes ALL marketing/language words:
- original, classic, traditional, authentic
- taste, flavor, flavored, flavour
- gout original, sabor original, gusto original
- new, improved, premium, deluxe

### 5. Size/Packaging Removed
**Before:** Not handled  
**After:** Automatically strips:
- Sizes: 500ml, 1.25L, 12oz, 2kg
- Packaging: PET, can, bottle, glass, plastic
- Counts: 6 pack, 12 count

## Testing

### Test with Beverages
```dart
// Search "coke"
// Expected: ~5 results (was 12)
// - Lime variant
// - Zero variant (2 collapsed)
// - Cherry variant
// - Regular variant (5 collapsed)
// - Diet variant
```

### Test with Dairy
```dart
// Search "greek yogurt"
// Expected: ~6 results (was 15)
// - Nonfat plain (4 collapsed)
// - Whole milk plain
// - 2% plain (2 collapsed)
// - Strawberry (2 collapsed)
// - Vanilla (2 collapsed)
// - Blueberry
```

### Test with Snacks
```dart
// Search "lays chips"
// Expected: ~3 results (was 10)
// - Original (3 collapsed)
// - BBQ (2 collapsed)
// - Sour Cream & Onion (2 collapsed)
```

## Debug Mode

Enable to see grouping decisions:
```dart
final result = UniversalFoodDeduper.deduplicateByFamily(
  items: items,
  query: query,
  debug: true, // 👈 Enable
);
```

Output shows:
- Total items vs unique families
- Which items were collapsed
- Which item was selected as representative
- Family keys for each group

## Backward Compatibility

The old `FoodDedupNormalizer` class still exists but is no longer used. You can:

### Option 1: Keep It (Safe)
- Leave `food_dedup_normalizer.dart` in place
- No code breaks
- Can revert if needed

### Option 2: Remove It (Clean)
- Delete `food_dedup_normalizer.dart`
- Update any direct imports
- Cleaner codebase

**Recommendation:** Keep it for now, remove after testing confirms new system works perfectly.

## Extending the System

### Add New Flavors
Edit `_extractFlavor()` in `universal_food_deduper.dart`:
```dart
static String _extractFlavor(String text) {
  const flavors = [
    'cherry', 'vanilla', 'lime', 'lemon',
    // Add more:
    'pomegranate', 'acai', 'dragonfruit',
  ];
  // ...
}
```

### Add New Brand Aliases
Edit `buildBrandKey()`:
```dart
const brandAliases = {
  'coca cola': 'cocacola',
  'coke': 'cocacola',
  // Add more:
  'trader joes': 'traderjoes',
  'whole foods': 'wholefoods',
};
```

### Add New Marketing Words
Edit `buildCoreKey()`:
```dart
const marketingWords = [
  'original', 'classic', 'traditional',
  // Add more:
  'artisan', 'gourmet', 'handcrafted',
];
```

## Performance Notes

- **Time Complexity**: Still O(n log n)
- **Space Complexity**: Still O(n)
- **No Additional Dependencies**: Pure Dart
- **Hot Reload Safe**: Changes apply immediately

## Support

If you encounter issues:
1. Enable debug mode to see grouping
2. Check family keys are being generated correctly
3. Verify variant extraction with test cases
4. Check representative selection scores

See [UNIVERSAL_DEDUPLICATION_EXAMPLES.md](UNIVERSAL_DEDUPLICATION_EXAMPLES.md) for detailed examples.
