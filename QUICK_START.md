# Quick Start: Testing the Fix

## One Command to Verify

```bash
cd /Users/emmanuelramirez/Flutter/metadash
flutter test test/food_deduplication_test.dart -v
```

**Expected output:**
```
✓ Coca Cola variants normalize to same brand (coca-cola)
✓ USDA and null brand do not become coca-cola
✓ Coca Cola Coke Brand and Coca cola Goût Original share same family signature
✓ Language variants all collapse to same core (cola)
✓ Deduplication collapses all Coke variants into single canonical
✓ Jaro-Winkler similarity works correctly
✓ Token overlap similarity works correctly
✓ Diet and Zero remain separate families

8 test groups passed, 0 failed
```

---

## Verify In The App

```bash
flutter run
```

Then in the app:
1. Open food search
2. Search: `coke`
3. Verify results show only **5 items** (not 11):
   - ✓ Coca Cola Coke Brand
   - ✓ Diet Coke  
   - ✓ Coke Zero
   - ✓ Cherry Flavored Coke
   - ✓ Coke With Lime Flavor

NOT showing separately:
- ❌ Original Taste
- ❌ Coca cola Goût Original
- ❌ Original Taste Coke

---

## Enable Debug Output

To see detailed transformation steps:

**Option 1: Via Xcode Console**
```
Search for: 🔍 [UNIVERSAL DEDUP]
```

Console will show:
```
🔍 [UNIVERSAL DEDUP] Query: "coke" (debug=true)
   📥 Raw input: 11 items
   📊 Grouped into 5 families (before second pass)
   ✅ Family "coca-cola|cola|regular|none":
      • 3 candidates → selected "Coca Cola Coke Brand"
      • Collapsed: Original Taste, Coca cola Goût Original
```

**Option 2: Modify Code**
In `lib/services/food_search_ranker.dart`, find:
```dart
final result = UniversalFoodDeduper.deduplicateByFamily(
  items: items,
  query: query,
  debug: false,  // ← Change to true
);
```

---

## Key Signatures to Look For

### Perfect Match (All Three Should Be SAME)
```
"Coca Cola Coke Brand"           → coca-cola|cola|regular|none ✓
"Coca cola Goût Original"        → coca-cola|cola|regular|none ✓
"Original Taste Coke"            → coca-cola|cola|regular|none ✓
```

### Different (Should Stay Separate)
```
"Diet Coke"                      → coca-cola|cola|diet|none (different!)
"Coke Zero"                      → coca-cola|cola|zero|none (different!)
"Cherry Flavored Coke"           → coca-cola|cola|regular|cherry (different!)
```

---

## Troubleshooting

### Problem: Still seeing duplicates for "coke"

**Solution 1:** Force hot restart (not hot reload)
```bash
# In Flutter terminal while app is running:
R
```

**Solution 2:** Rebuild app
```bash
flutter clean
flutter run
```

**Solution 3:** Check code integration
- Verify `FoodSearchRanker` calls `UniversalFoodDeduper.deduplicateByFamily()`
- Check if code was properly saved

### Problem: Tests failing

**Solution 1:** Ensure all files compiled
```bash
flutter pub get
```

**Solution 2:** Check specific test
```bash
flutter test test/food_deduplication_test.dart::Coca Cola variants normalize
```

**Solution 3:** Run with verbose output
```bash
flutter test test/food_deduplication_test.dart -v --verbose
```

---

## Files That Changed

✅ **lib/services/universal_food_deduper.dart** - Main implementation
✅ **test/food_deduplication_test.dart** - Unit tests

📖 **Documentation (for reference):**
- FINAL_SUMMARY.md
- DEDUPLICATION_COMPLETE.md
- SIGNATURE_EXAMPLES.md
- SIGNATURE_REFERENCE.md
- IMPLEMENTATION_DETAILS.md
- TESTING_CHECKLIST.md
- DELIVERABLES.md

---

## What to Look For

### In Console Output
```
🔍 [UNIVERSAL DEDUP] Query: "coke"
   📥 Raw input: 11 items
   📊 Grouped into 5 families         ← Should say "5 families" not "9"
   ✅ Family "coca-cola|cola|regular|none":
      • 3 candidates → selected...   ← Should say "3 candidates"
      • Collapsed: Original Taste, Coca cola Goût Original  ← These should be listed
```

### In Search Results
```
[1] Coca Cola Coke Brand (canonical)
[2] Diet Coke (separate)
[3] Coke Zero (separate)
[4] Cherry Flavored Coke (separate)
[5] Coke With Lime Flavor (separate)

TOTAL: 5 items (was 11)
```

---

## Success Indicators

✓ Unit tests pass (no failures)
✓ Search "coke" shows 5 items (not 11)
✓ Language variants not visible separately
✓ Console shows "Grouped into 5 families"
✓ Debug output shows all three variants with same signature
✓ Diet Coke and Coke Zero are separate entries

---

## One More Thing

To see even MORE detail, enable debug in the test itself:

Edit `test/food_deduplication_test.dart`, find the test:
```dart
test('Coca Cola Coke Brand and Coca cola Goût Original share same family signature', () {
  final sig1 = UniversalFoodDeduper.buildFamilyKey(
    name: 'Coca Cola Coke Brand',
    brand: 'Coca-Cola',
    query: 'coke',
  );
  
  final sig2 = UniversalFoodDeduper.buildFamilyKey(
    name: 'Coca cola Goût Original',
    brand: 'coke',
    query: 'coke',
  );
  
  print('Sig1: $sig1');  // ← These will print in test output
  print('Sig2: $sig2');
```

Run:
```bash
flutter test test/food_deduplication_test.dart -v
```

You'll see:
```
Sig1: coca-cola|cola|regular|none
Sig2: coca-cola|cola|regular|none
✓ Both match!
```

---

## Summary

**3 ways to verify:**

1. **Run tests:** `flutter test test/food_deduplication_test.dart`
2. **Run app:** `flutter run` then search "coke"
3. **Check debug:** Enable debug mode and watch console

All should confirm: **3 language variants now merge to 1 canonical result** ✓

