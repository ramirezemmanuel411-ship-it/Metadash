# FoodDisplayFormatter - Quick Reference Card

## TL;DR - 2-Minute Integration

### What It Does
Converts messy raw food data → clean, consistent UI format

### Before vs After
```dart
// BEFORE (Messy)
title: "COCA COLA COCA COLA"
subtitle: "42 kcal • 355 ml • 42 kcal • 355 ml"  // Duplicated!

// AFTER (Clean)
title: "Coca-Cola"
subtitle: "42 kcal · 355 ml"  // Single, normalized
```

---

## 3 Steps to Integration

### Step 1: Import (2 lines)
```dart
import '../../presentation/formatters/food_display_formatter.dart';
import 'package:flutter/foundation.dart'; // for kDebugMode
```

### Step 2: Build Display (1 line)
```dart
final display = buildFoodDisplayStrings(food);
```

### Step 3: Use in UI (3 replacements)
```dart
// Replace these:
food.displayTitle          → display.title
food.displaySubtitle       → display.subtitle
food.displayTitle[0]       → display.leadingLetter

// Add this (debug only):
display.debugProviderLabel  // Shows "USDA", "OFF", etc. in debug build
```

---

## 5 Key Functions

| Function | Input | Output | Example |
|----------|-------|--------|---------|
| `buildFoodDisplayStrings()` | FoodModel | FoodDisplayStrings | Main entry point |
| `buildTitle()` | FoodModel | String | "Coca-Cola Diet" |
| `buildSubtitle()` | FoodModel | String | "42 kcal · 355 ml" |
| `stripNoiseTokens()` | String | String | "Inc, LLC" → "" |
| `removeDuplicateWords()` | String | String | "cherry cherry" → "cherry" |

---

## The DTO (What You Get Back)

```dart
class FoodDisplayStrings {
  String title;              // "Coca-Cola Diet"
  String subtitle;           // "42 kcal · 355 ml"
  String leadingLetter;      // "C"
  String? debugProviderLabel;// "USDA" (debug only, null in release)
}
```

---

## Integration Patterns

### Pattern 1: Simple ListTile
```dart
final display = buildFoodDisplayStrings(food);
ListTile(
  title: Text(display.title),
  subtitle: Text(display.subtitle),
  leading: CircleAvatar(child: Text(display.leadingLetter)),
)
```

### Pattern 2: With Debug Provider
```dart
final display = buildFoodDisplayStrings(food);
ListTile(
  title: Text(display.title),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (kDebugMode && display.debugProviderLabel != null)
        Text(display.debugProviderLabel!, style: TextStyle(fontSize: 10)),
      Text(display.subtitle),
    ],
  ),
)
```

### Pattern 3: Batch Processing
```dart
final results = await search(query);
for (var food in results) {
  final display = buildFoodDisplayStrings(food);
  // Use display.title, display.subtitle, etc.
}
```

---

## What Gets Fixed

| Problem | Solution |
|---------|----------|
| "COCA COLA COCA COLA" | `stripNoiseTokens()` + `titleCase()` |
| "42 kcal • 355 ml • 42 kcal • 355 ml" | `_selectBestServing()` (one call only) |
| "Diet (Diet)" | `removeDuplicateWords()` |
| "USDA", "OFF" showing to users | `debugProviderLabel` (debug-only) |
| Mixed units: "ML", "MLT", "ml" | `normalizeUnit()` |

---

## Files to Update

```
lib/presentation/screens/fast_food_search_screen.dart
├── Line ~347: FastFoodSearchScreen._buildFoodTile()
└── Line ~755: FastFoodSearchScreenLegacy._buildFoodTile()

lib/features/food_search/food_search_results.dart
└── Any ListTile using result.displayTitle/displaySubtitle
```

---

## Testing (5 Checks)

1. **Search "Coke"** → Title should be "Coca-Cola" (not "MINI COKE")
2. **Check subtitle** → "42 kcal · 355 ml" (NOT repeated)
3. **Debug mode** → Provider label visible (small grey text)
4. **Release mode** → Provider label hidden
5. **Avatar letter** → All "C" for Coke results (consistent)

---

## Constants Included

```dart
const unitNormalizationMap = {
  'mlt': 'ml',    // MLT → ml
  'grm': 'g',     // GRM → g
  'floz': 'fl oz' // FL OZ → fl oz
  // ... 20+ more
};

const genericKeywords = {
  'food', 'item', 'product', 'serving', // Generic product detection
  // ...
};

const noiseTokens = {
  'Inc', 'LLC', 'USA Operations', // Company noise
  // ...
};
```

---

## Common Mistakes

❌ **DON'T**: Concatenate subtitle
```dart
// WRONG: This defeats the purpose!
Text('${display.subtitle} • ${food.calories} cal')
```

✅ **DO**: Use display directly
```dart
// RIGHT: Single source of truth
Text(display.subtitle)
```

---

## Debug vs Release

### Debug Build
```dart
display.debugProviderLabel = "USDA"
display.debugProviderLabel = "OFF"
display.debugProviderLabel = "Local"
```

### Release Build
```dart
display.debugProviderLabel = null  // Always null
```

**Usage**:
```dart
if (kDebugMode && display.debugProviderLabel != null)
  Text(display.debugProviderLabel!)  // Only shows in debug
```

---

## Performance

✅ **Fast**: O(n) where n = string length
✅ **Safe**: No network calls, no DB queries
✅ **Thread-safe**: All static methods
✅ **Memory**: No memory leaks
✅ **Cacheable**: Can cache if needed (usually not required)

---

## No Breaking Changes

✅ FoodModel unchanged
✅ SearchRepository unchanged
✅ Database unchanged
✅ API unchanged
✅ Fully backward compatible

---

## File Locations

```
lib/
├── data/
│   └── models/
│       ├── food_model.dart (unchanged)
│       └── food_search_result_raw.dart (unchanged)
├── presentation/
│   ├── formatters/
│   │   └── food_display_formatter.dart ← NEW (You are here)
│   └── screens/
│       └── fast_food_search_screen.dart ← MODIFY (2 locations)
└── features/
    └── food_search/
        └── food_search_results.dart ← MODIFY (1+ locations)
```

---

## Success Checklist

- [ ] Import added to all updated files
- [ ] `buildFoodDisplayStrings()` called before rendering
- [ ] `display.title` used instead of `food.displayTitle`
- [ ] `display.subtitle` used instead of concatenation
- [ ] `display.leadingLetter` used instead of substring
- [ ] Provider label wrapped in `if (kDebugMode ...)`
- [ ] No compilation errors
- [ ] `flutter analyze` passes
- [ ] Search results show clean titles
- [ ] Subtitles NOT duplicated
- [ ] Debug labels show in debug build
- [ ] Debug labels hidden in release build

---

## One-Minute Example

```dart
// In your search results screen:
import '../../presentation/formatters/food_display_formatter.dart';

@override
Widget build(BuildContext context) {
  return ListView.builder(
    itemCount: results.length,
    itemBuilder: (context, index) {
      final food = results[index];
      final display = buildFoodDisplayStrings(food);  // ← One line!
      
      return ListTile(
        leading: CircleAvatar(child: Text(display.leadingLetter)),
        title: Text(display.title),
        subtitle: Text(display.subtitle),
      );
    },
  );
}
```

That's it! Your UI is now clean, consistent, and MacroFactor-like. 🎯

---

## Reference Docs

- **Full Integration**: `INTEGRATION_STEP_BY_STEP.md`
- **Testing**: `VERIFICATION_CHECKLIST.md`
- **Overview**: `FOOD_DISPLAY_INTEGRATION.md`
- **Summary**: `FOOD_DISPLAY_FORMATTER_SUMMARY.md`
- **Source**: `lib/presentation/formatters/food_display_formatter.dart`

---

## Questions?

| Question | Answer |
|----------|--------|
| Will this break my data? | No. Data unchanged, only display. |
| Do I need to change the API? | No. Pure presentation layer. |
| Can I revert if needed? | Yes. Just use food.displayTitle again. |
| What if I don't use it? | Results will still work but won't be clean. |
| Is it tested? | Yes. Test assertions included in file. |
| Will hot reload work? | Yes. Instant with no state loss. |

---

**Status**: 🟢 Ready to integrate in < 15 minutes
