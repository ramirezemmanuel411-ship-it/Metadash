# Food Display Formatter Integration Guide

## Where to Use This New Formatter

### 1. **Search Results ListTile** 
**Location**: `lib/presentation/screens/fast_food_search_screen.dart`

**Current code (❌ BEFORE)**:
```dart
ListTile(
  leading: CircleAvatar(child: Text(food.displayTitle[0])),
  title: Text(food.displayTitle),  // ← Raw, might have dupes
  subtitle: Text(food.displaySubtitle),  // ← Might be duplicated
  trailing: Text('${food.calories} kcal'),
  onTap: () => onFoodSelected(food),
)
```

**New code (✅ AFTER)**:
```dart
final display = buildFoodDisplayStrings(food);

ListTile(
  leading: CircleAvatar(
    child: Text(display.leadingLetter),
  ),
  title: Text(display.title),  // ← Clean, no dupes
  subtitle: Text(display.subtitle),  // ← Single format: "X kcal · Y ml"
  trailing: display.debugProviderLabel != null
      ? Text(
          display.debugProviderLabel!,
          style: TextStyle(fontSize: 10, color: Colors.grey),
        )
      : null,
  onTap: () => onFoodSelected(food),
)
```

### 2. **Food Search Widget (FoodSearchResults)**
**Location**: `lib/features/food_search/food_search_results.dart`

**Apply to result tile builder**:
```dart
final display = buildFoodDisplayStrings(result);

ListTile(
  title: Text(display.title),
  subtitle: Text(display.subtitle),
  // ... rest of tile
)
```

### 3. **Barcode Scanner Dialog Results**
**Location**: `lib/features/food/barcode_scanner_screen.dart`

**In the search results dialog**:
```dart
final display = buildFoodDisplayStrings(food);

ListTile(
  title: Text(display.title),
  subtitle: Text(display.subtitle),
  leading: CircleAvatar(child: Text(display.leadingLetter)),
)
```

### 4. **Any Other Food Item Display**
Apply the same pattern everywhere:
```dart
final display = buildFoodDisplayStrings(foodModel);

// Use: display.title, display.subtitle, display.leadingLetter
```

---

## Integration Steps

### Step 1: Import the formatter
```dart
import '../../presentation/formatters/food_display_formatter.dart';
```

### Step 2: Build display strings when rendering
```dart
final display = buildFoodDisplayStrings(foodItem);
```

### Step 3: Use the fields in UI
- `display.title` - Clean product name
- `display.subtitle` - "X kcal · Y ml"
- `display.leadingLetter` - Single letter for avatar
- `display.debugProviderLabel` - Provider (debug only)

### Step 4: Optional deduplication
Before passing results to UI:
```dart
final deduped = deduplicateFoodResults(searchResults);
// Now use deduped in your ListView
```

---

## Code Patterns

### Pattern 1: In a ListView.builder
```dart
ListView.builder(
  itemCount: results.length,
  itemBuilder: (context, index) {
    final food = results[index];
    final display = buildFoodDisplayStrings(food);
    
    return ListTile(
      title: Text(display.title),
      subtitle: Text(display.subtitle),
      leading: CircleAvatar(
        child: Text(display.leadingLetter),
      ),
      onTap: () => selectFood(food),
    );
  },
)
```

### Pattern 2: In a StreamBuilder (real-time results)
```dart
StreamBuilder<List<FoodModel>>(
  stream: foodSearchStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final items = snapshot.data!;
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final display = buildFoodDisplayStrings(items[index]);
          return _buildFoodTile(display);
        },
      );
    }
    return Center(child: CircularProgressIndicator());
  },
)
```

### Pattern 3: With deduplication
```dart
Future<void> performSearch(String query) async {
  final raw = await foodService.search(query);
  
  // Optional: dedupe before display
  final deduped = deduplicateFoodResults(raw);
  
  setState(() {
    searchResults = deduped;
  });
}
```

---

## Test Checklist

Run this to verify everything is working:

```dart
// In main() or initState()
if (kDebugMode) {
  runFoodDisplayTests();
}
```

---

## Examples of What Changes

### Example 1: Coca-Cola Products
```
BEFORE:
Title: "COCA COLA COCA COLA"
Title: "COCA COLA USA OPERATIONS"
Title: "Diet Coke (diet)"
Subtitle: "42 kcal • 355ml • 42 kcal • 355ml"

AFTER:
Title: "Coca-Cola"
Title: "Coca-Cola"
Title: "Coca-Cola Diet"
Subtitle: "42 kcal · 355 ml"
```

### Example 2: USDA Results
```
BEFORE:
Title: "MINI COKE [USDA]"
Subtitle: "0 kcal · 222 ml · USDA"

AFTER (Release):
Title: "Coca-Cola"
Subtitle: "0 kcal · 222 ml"

AFTER (Debug):
Title: "Coca-Cola"
Subtitle: "0 kcal · 222 ml"
TrailingLabel: "USDA" (grey, small)
```

### Example 3: Restaurant Items
```
BEFORE:
Title: "PEPPERONI PIZZA PIZZA HUT"
Subtitle: "280 kcal · 1 slice · 280 kcal"

AFTER:
Title: "Pizza Hut"
Subtitle: "280 kcal · 1 slice"
```

---

## File Structure

```
lib/
  presentation/
    formatters/
      food_display_formatter.dart  ← NEW: All formatting logic
    screens/
      fast_food_search_screen.dart  ← MODIFY: Use FoodDisplayStrings
  features/
    food_search/
      food_search_results.dart  ← MODIFY: Use FoodDisplayStrings
    food/
      barcode_scanner_screen.dart  ← MODIFY: Use FoodDisplayStrings
```

---

## FAQ

**Q: Where does subtitle deduplication happen?**
A: In `buildSubtitle()`. It only calls `_selectBestServing()` once, so no duplicates.

**Q: What about per_100g nutrition basis?**
A: We never show it in subtitle. We only show the serving size (ml, g, or qty+unit).

**Q: Can I still access raw data?**
A: Yes! The `FoodModel` still has all raw fields. This formatter just controls *display*.

**Q: What if item has no title?**
A: `getLeadingLetter()` returns '?' as fallback.

**Q: How do I debug which source each result came from?**
A: In debug builds, `display.debugProviderLabel` shows "USDA", "OFF", "Local", etc.
In release builds, it's always `null`.

---

## Performance Notes

- ✅ Formatting is fast: O(n) over text length
- ✅ No network calls
- ✅ No database lookups
- ✅ Safe to run on every frame
- ✅ Dedup is O(n) hash map operation

---

## Summary

| Before | After |
|--------|-------|
| Raw DB strings in title | Clean brand + optional variant |
| Duplicate subtitle | Single format: "X kcal · Y ml" |
| Provider shown always | Provider hidden (debug label only) |
| Messy parentheses | Clean formatting |
| No avatar letter logic | Explicit avatar letter |
| Multiple serving units | Single best serving selected |
| Generic items mixed in | Can detect generic items |

Replace all food item displays with `buildFoodDisplayStrings()` and the UI will be clean, consistent, and MacroFactor-like.
