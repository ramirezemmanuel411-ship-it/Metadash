# Product Family Deduplication - Example

## Problem
Searching "Coke" returns many near-identical regular Coke entries in different languages and formats.

## Before Family-Level Deduplication
```
Search: "Coke"
Results: 12 items

[0] Lime (LIME family)
[1] Coke Zero (ZERO family)
[2] Cherry (CHERRY family)
[3] Coca Cola Coke Brand (REGULAR family)
[4] Diet Coke (DIET family)
[5] C.cola Zero (ZERO family) ← duplicate of [1]
[6] Coca Cola Original Taste (REGULAR family) ← duplicate of [3]
[7] Coca-Cola goût original (REGULAR family) ← duplicate of [3]
[8] Original Taste (REGULAR family) ← duplicate of [3]
[9] Sabor Original (REGULAR family) ← duplicate of [3]
```

## After Family-Level Deduplication
```
Search: "Coke"
Results: 5 items

[0] Coke With Lime Flavor (LIME family)
[1] Coke Zero (ZERO family)
[2] Cherry Flavored Coke Mini Cans (CHERRY family)
[3] Coca Cola Coke Brand (REGULAR family) ← best representative
[4] Diet Coke (DIET family)
```

## How It Works

### Step 1: Product Family Detection
```dart
detectProductFamily("Diet Coke") → DIET
detectProductFamily("Coke Zero") → ZERO
detectProductFamily("Cherry Coke") → CHERRY
detectProductFamily("Original Taste") → REGULAR
detectProductFamily("Goût Original") → REGULAR (language variant)
detectProductFamily("Sabor Original") → REGULAR (language variant)
```

### Step 2: Generate Family Keys
All "original" variants get the same family key:
```dart
"Original Taste" + "Coca-Cola" → "coca-cola|REGULAR"
"Goût Original" + "coke" → "coca-cola|REGULAR" (same!)
"Sabor Original" + "Coca-Cola,Coke" → "coca-cola|REGULAR" (same!)
"Coca Cola Original Taste" + "Coke" → "coca-cola|REGULAR" (same!)
```

### Step 3: Select Best Representative
From each family group, select the best item:

**REGULAR Family Candidates:**
- "Coca Cola Coke Brand" (44 cal, branded, 22 chars) → Score: 100 + 22 + 0 = 122
- "Coca Cola Original Taste" (39 cal, branded, 26 chars) → Score: 100 + 26 - 6 - 20 = 100
- "Goût Original" (30 cal, branded, 13 chars) → Score: 100 + 13 - 24 - 20 = 69
- "Original Taste" (44 cal, branded, 14 chars) → Score: 100 + 14 - 20 = 94
- "Sabor Original" (42 cal, branded, 14 chars) → Score: 100 + 14 - 20 = 94

**Winner:** "Coca Cola Coke Brand" (highest score: 122)

### Scoring Criteria
1. **Branded items:** +100 points (has recognizable brand)
2. **Title length:** +1 point per character (capped at +50)
3. **Calories near baseline (42 kcal/100ml for regular Coke):** -2 points per calorie difference
4. **Generic titles penalty:** -20 points for "Original Taste", "Goût Original", etc.

## Configuration

### Language Variants Recognized as REGULAR
```dart
static const Set<String> _regularVariants = {
  'original',
  'original taste',
  'gout original',      // French
  'goût original',      // French with accent
  'sabor original',     // Spanish
  'gusto original',     // Italian
  'classic',
  'classique',          // French
  'clasico',            // Spanish
  'clásico',            // Spanish with accent
};
```

### Product Families Supported
- `REGULAR` - Original/classic variants
- `DIET` - Diet variants
- `ZERO` - Zero sugar variants
- `CHERRY` - Cherry flavored
- `LIME` - Lime flavored
- `VANILLA` - Vanilla flavored
- `LEMON` - Lemon flavored
- `ORANGE` - Orange flavored

## Usage in Code

The family deduplication is automatically applied in `FoodSearchRanker.rank()`:

```dart
final ranked = scored.map((s) => s.item).toList();

// Two-stage deduplication:
// 1. Exact duplicates (same canonical key)
final deduplicated = _deduplicateResults(ranked);

// 2. Product family level (collapse language variants)
final familyDeduplicated = FoodDedupNormalizer.deduplicateByProductFamily(
  items: deduplicated,
  getName: (item) => item.name,
  getBrand: (item) => item.brand,
  getCalories: (item) => item.calories,
  debug: false, // Set to true to see family grouping debug info
);

return familyDeduplicated;
```

## Debug Mode

Enable debug mode to see family grouping details:

```dart
deduplicateByProductFamily(
  items: deduplicated,
  getName: (item) => item.name,
  getBrand: (item) => item.brand,
  getCalories: (item) => item.calories,
  debug: true, // 👈 Enable debug output
);
```

Output:
```
🔍 Product Family Deduplication:
  Total items: 12
  Unique families: 5
  
  Family: coca-cola|REGULAR
    Candidates: 5
    Selected: Coca Cola Coke Brand
    Collapsed: Coca Cola Original Taste, Coca-Cola goût original, Original Taste, Sabor Original
  
  Family: coca-cola|DIET
    Candidates: 1
    Selected: Diet Coke
  
  Family: coca-cola|ZERO
    Candidates: 2
    Selected: Coke Zero
    Collapsed: C.cola Zero
```

## Result

**Before:** 12 results with 7 near-duplicates  
**After:** 5 results, one per distinct product family  

Users now see a clean, deduplicated list with one representative from each product variant!
