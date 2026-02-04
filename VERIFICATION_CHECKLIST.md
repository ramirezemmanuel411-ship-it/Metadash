# FoodDisplayFormatter - Verification & Testing Checklist

## Pre-Integration Checklist

- [ ] `lib/presentation/formatters/food_display_formatter.dart` file exists and compiles
- [ ] `FoodDisplayStrings` class defined with 4 fields: title, subtitle, leadingLetter, debugProviderLabel
- [ ] `buildFoodDisplayStrings(FoodModel)` function exists
- [ ] All formatter methods are static in `FoodDisplayFormatter` class
- [ ] Constants defined: `unitNormalizationMap`, `genericKeywords`, `noiseTokens`, `variantKeywords`
- [ ] Test assertions included in file

---

## Integration Checklist (Before Running App)

- [ ] Import added to `fast_food_search_screen.dart`: `import '../../presentation/formatters/food_display_formatter.dart';`
- [ ] Import added: `import 'package:flutter/foundation.dart';`
- [ ] `FastFoodSearchScreen._buildFoodTile()` updated to use `buildFoodDisplayStrings()`
- [ ] `FastFoodSearchScreenLegacy._buildFoodTile()` updated
- [ ] All `food.displayTitle` replaced with `display.title`
- [ ] All `food.displaySubtitle` replaced with `display.subtitle`
- [ ] Avatar letter logic uses `display.leadingLetter`
- [ ] Subtitle format is: `display.subtitle` (single source of truth)
- [ ] Provider label wrapped in `if (kDebugMode && display.debugProviderLabel != null)`
- [ ] No string concatenation in subtitle building (`• ${food.calories} cal •` removed)
- [ ] `flutter analyze` passes with no warnings
- [ ] No compilation errors after hot reload

---

## Functional Testing (After Running App)

### Test 1: Basic Search
```
Query: "Coke"
Expected Results:
  ✅ Multiple "Coca-Cola" results (grouped variants)
  ✅ Titles clean: "Coca-Cola", "Coca-Cola Diet", "Coca-Cola Zero"
  ✅ No titles like: "COCA COLA COCA COLA", "MINI COKE", "Diet (Diet)"
  ✅ Subtitles like: "42 kcal · 355 ml" (single format, no repetition)
  ✅ Avatar letters all "C" (consistent)
```

### Test 2: No Duplicate Subtitles
```
Query: Any product with serving size
Expected:
  ✅ Subtitle format: "42 kcal · 355 ml"
  ✅ NOT: "42 kcal · 355 ml · 42 kcal · 355 ml"
  ✅ NOT: "42 kcal • 355 ml • 42 kcal"
  ✅ Scrolling doesn't change subtitle format
```

### Test 3: Variant Deduplication
```
Query: "Diet Coke"
Expected:
  ✅ Title: "Coca-Cola Diet" (not "Diet (Diet)" or "Coca-Cola (diet)")
  ✅ No exact duplicate rows
  ✅ Related but different variants shown separately:
      - "Coca-Cola" vs "Coca-Cola Diet"
      - "Coca-Cola Diet" vs "Coca-Cola Zero"
```

### Test 4: Restaurant Products
```
Query: "Pizza Hut"
Expected:
  ✅ Titles like: "Pizza Hut", "Pizza Hut Pepperoni Pizza"
  ✅ NOT: "PEPPERONI PIZZA PIZZA HUT"
  ✅ Subtitles like: "280 kcal · 1 slice"
  ✅ NO: "280 kcal · 1 slice · 280 kcal"
```

### Test 5: Debug Provider Label
```
Query: "Coke" (in DEBUG build)
Expected:
  ✅ Small grey text showing provider: "USDA", "OFF", "Local", etc.
  ✅ Text appears under title, before subtitle
  ✅ Font size ~10, color grey[500]
```

### Test 6: Release Build (No Provider Labels)
```
Build: flutter build apk --release
Query: "Coke"
Expected:
  ✅ No provider label visible
  ✅ NO "USDA" or "OFF" text anywhere
  ✅ Clean UI with just title and subtitle
```

### Test 7: Unit Normalization
```
Query: Any product from different databases
Expected:
  ✅ All volumes shown as "ml": "240 ml", "355 ml"
  ✅ NOT: "240 MLT", "355 FL OZ"
  ✅ All weights shown as "g": "100 g", "28 g"
  ✅ NOT: "100 GRM", "28 OZ"
  ✅ Generic qty: "1 slice", "1 can", "1 bottle"
```

### Test 8: Edge Cases
```
Edge Case 1: Empty title
  Expected: Avatar shows "?"
  Test: Does avatar appear correctly?

Edge Case 2: Product with no serving size
  Expected: Subtitle shows "? kcal · No serving"
  Test: Verify it doesn't crash

Edge Case 3: Missing calories
  Expected: Subtitle shows "0 kcal · Y ml"
  Test: Verify it displays something reasonable

Edge Case 4: Very long title
  Expected: Title truncated with "…"
  Test: Verify with `maxLines: 1, overflow: TextOverflow.ellipsis`

Edge Case 5: Special characters (®, ™, ™)
  Expected: Stripped from title
  Test: Search "Coca-Cola®" results should show "Coca-Cola"
```

### Test 9: Avatar Letter Consistency
```
Query: "Coca-Cola"
Expected:
  ✅ All Coca-Cola results have avatar letter "C"
  ✅ All Pizza Hut results have avatar letter "P"
  ✅ All McDonald's results have avatar letter "M"
  ✅ Consistent across page scrolls
```

### Test 10: Typography / Formatting
```
Expected:
  ✅ Title font: bold (fontWeight: FontWeight.w500)
  ✅ Subtitle font: normal, grey (Colors.grey[600])
  ✅ Leading avatar: blue[100] or grey[200] depending on serving status
  ✅ Provider label: small (fontSize: 10), grey (Colors.grey[500])
  ✅ No font size inconsistencies
```

---

## Regression Testing

### Regression Test 1: Favorites Still Work
```
Action: Add item to favorites, then search for it
Expected:
  ✅ Favorites list shows clean title and subtitle
  ✅ Using buildFoodDisplayStrings() format
  ✅ No corruption of favorite data
```

### Regression Test 2: Food Entry Still Works
```
Action: Search → Select food → Add to diary
Expected:
  ✅ Selected food has all required fields
  ✅ Calories, serving size, etc. correctly populated in diary
  ✅ displayTitle/displaySubtitle changes don't affect underlying FoodModel
```

### Regression Test 3: Barcode Scanner Results
```
Action: Scan a barcode → Check results display
Expected:
  ✅ Results show clean title
  ✅ Subtitle format: "X kcal · Y ml"
  ✅ No duplication
```

### Regression Test 4: Search History
```
Action: Search → Check recent searches
Expected:
  ✅ Recent search queries still populate
  ✅ Tapping recent query re-runs search
  ✅ Results display with clean formatting
```

### Regression Test 5: Filter/Sort Still Works
```
Action: Search → Apply filters (calories, brand, etc)
Expected:
  ✅ Filters work correctly
  ✅ Filtered results use new formatter
  ✅ Sort order not affected
```

---

## Performance Testing

### Performance Test 1: Large Result Sets
```
Query: "Food" (very common, returns 100+ results)
Expected:
  ✅ No lag when scrolling through results
  ✅ Formatting completes quickly
  ✅ No dropped frames
  ✅ Memory usage stable
```

### Performance Test 2: Rapid Searches
```
Action: Type quickly into search box: "c", "co", "cok", "coke"
Expected:
  ✅ Each keystroke results update smoothly
  ✅ No lag or stutter
  ✅ Formatting keeps up with search updates
```

### Performance Test 3: Hot Reload
```
Action: Make a change to formatter → Hot reload
Expected:
  ✅ Hot reload succeeds in < 1 second
  ✅ Results immediately reflect new formatting
  ✅ No state corruption
```

---

## Code Quality Checks

### Code Quality 1: No Console Errors
```
Command: flutter run
Expected:
  ✅ No red error messages in console
  ✅ No yellow warnings (in production code)
  ✅ All types are properly typed
```

### Code Quality 2: Static Analysis
```
Command: flutter analyze
Expected:
  ✅ No errors
  ✅ No warnings (in lib/ - ignore test/ warnings if any)
  ✅ All imports used
```

### Code Quality 3: Formatting
```
Command: dart format lib/presentation/formatters/food_display_formatter.dart
Command: dart format lib/presentation/screens/fast_food_search_screen.dart
Expected:
  ✅ No formatting changes needed
  ✅ Code style consistent
```

### Code Quality 4: Test Assertions
```
Command: (if runFoodDisplayTests() is called on startup)
Expected:
  ✅ All test assertions pass
  ✅ stripNoiseTokens works correctly
  ✅ removeDuplicateWords works correctly
  ✅ normalizeUnit works correctly
  ✅ titleCase works correctly
```

---

## Comparison: Before vs After

| Aspect | Before | After | ✓ |
|--------|--------|-------|---|
| Title | "COCA COLA COCA COLA" | "Coca-Cola" | ✓ |
| Subtitle | "42 kcal • 355 ml • 42 kcal • 355 ml" | "42 kcal · 355 ml" | ✓ |
| Provider | Always shown | Hidden (debug only) | ✓ |
| Variant repeats | "Diet (Diet)" | "Coca-Cola Diet" | ✓ |
| Avatar letter | Extracted each time | Cached in formatter | ✓ |
| Unit format | Mixed ("ML", "MLT", "ml") | Normalized ("ml") | ✓ |
| Code maintenance | Scattered logic | Centralized | ✓ |
| Null safety | Prone to errors | Safe | ✓ |

---

## Sign-Off Checklist

After all tests pass, confirm:

- [ ] All 10 functional tests passed
- [ ] All 5 regression tests passed
- [ ] All 3 performance tests passed
- [ ] All 4 code quality checks passed
- [ ] Before/After comparison shows improvements
- [ ] No console errors or warnings
- [ ] Debug build shows provider labels
- [ ] Release build hides provider labels
- [ ] UI matches MacroFactor/MyFitnessPal design
- [ ] Ready for production

---

## Failure Remediation

### If subtitle still shows duplicates:
1. Check that you're using `display.subtitle` directly (not concatenating)
2. Verify `buildSubtitle()` in formatter is correct
3. Verify `_selectBestServing()` returns exactly one serving

### If provider labels show in release:
1. Check `kDebugMode` import is from `package:flutter/foundation.dart`
2. Verify the if condition: `if (kDebugMode && display.debugProviderLabel != null)`
3. Check `--release` flag used when building

### If titles still messy:
1. Verify `stripNoiseTokens()` is being called
2. Check `noiseTokens` set includes expected tokens
3. Verify `removeDuplicateWords()` is processing variants

### If avatar letter is wrong:
1. Verify `getLeadingLetter()` returns first non-empty character
2. Check fallback to '?' for empty titles
3. Verify `titleCase()` is working correctly

---

## Documentation References

- **Formatter Source**: `lib/presentation/formatters/food_display_formatter.dart`
- **Integration Guide**: `FOOD_DISPLAY_INTEGRATION.md`
- **Step-by-Step**: `INTEGRATION_STEP_BY_STEP.md`
- **Previous Phases**: `CANONICAL_IMPLEMENTATION_COMPLETE.md`

---

## Questions?

If something doesn't work as expected:

1. **Check the formatter file** - Verify all functions exist and compile
2. **Check the import** - Make sure you added `import '../../presentation/formatters/food_display_formatter.dart';`
3. **Check the usage** - Make sure you're calling `buildFoodDisplayStrings(food)` not just accessing properties
4. **Run `flutter analyze`** - Catch any type errors
5. **Hot reload** - Ensure latest code is loaded
6. **Check the test assertions** - They validate the formatter works correctly

---

## Success Criteria

✅ **You'll know it's working when:**
1. Subtitles show exactly once: "42 kcal · 355 ml"
2. Titles are clean: "Coca-Cola Diet" (not "COCA COLA DIET (Diet)")
3. Provider labels hidden in release builds
4. Avatar letters consistent
5. Units normalized (ml, not MLT)
6. No crashes when searching
7. UI looks like MacroFactor/MyFitnessPal
