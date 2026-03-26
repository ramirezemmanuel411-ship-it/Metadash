## Metabolic Engine Settings - Implementation Summary

### What Was Done

The metabolic engine settings have been fully wired up to persist user preferences and affect actual TDEE calculations.

### Architecture

**1. Data Model** (`/lib/models/metabolic_settings.dart`)
- `MetabolicSettings` class stores user preferences
- Two settings:
  - **Energy Model**: 'Static', 'Adaptive', or 'Hybrid (Recommended)'
  - **Workout Accuracy**: 'Strict', 'Balanced', or 'Flexible'
- Provides helper properties:
  - `workoutCalorieMultiplier`: 0.7 (Strict), 0.8 (Balanced), 1.0 (Flexible)
  - `isAdaptiveEnabled`: true for Adaptive/Hybrid models
  - `isStaticOnly`: true for Static model
- JSON serialization for persistence

**2. State Management** (`/lib/providers/user_state.dart`)
- `UserState` now includes `metabolicSettings` property
- Settings are:
  - **Loaded** from SharedPreferences on user login
  - **Saved** automatically when updated
  - **Accessible** via `context.read<UserState>().metabolicSettings`
- Methods:
  - `updateMetabolicSettings()`: Updates settings and persists to storage
  - `_loadMetabolicSettings()`: Loads from SharedPreferences
  - `_saveMetabolicSettings()`: Saves to SharedPreferences

**3. UI Integration** (`/lib/features/control_center/metabolic_engine_screen.dart`)
- Screen initializes with current settings from `UserState`
- When user taps an option:
  1. Local state updates (for immediate UI feedback)
  2. `_updateSettings()` called
  3. UserState updates and persists to SharedPreferences
  4. All listeners notified
- Settings persist across app restarts

**4. Calculation Engine** (`/lib/services/calorie_calculation_service.dart`)
- `calculateWorkoutCalories()` now accepts `accuracyMultiplier` parameter
- `calculateTDEE()` accepts `workoutAccuracyMultiplier` parameter
- `calculateDayMetrics()` accepts optional `MetabolicSettings` parameter
- Workout calories are multiplied by the user's accuracy preference:
  - **Strict** (0.7): Most conservative, reduces device calories by 30%
  - **Balanced** (0.8): Default, reduces by 20%
  - **Flexible** (1.0): Trusts device data fully

### How It Works

**Setting Workout Accuracy:**
1. User opens Control Center → Metabolic Engine
2. Taps "Flexible" under Workout Accuracy
3. UI updates radio button immediately
4. `_updateSettings()` saves to UserState
5. UserState persists to SharedPreferences
6. Next TDEE calculation uses 1.0 multiplier instead of 0.8

**Using in Calculations:**
```dart
// In any screen that calculates TDEE
final userState = Provider.of<UserState>(context);
final metrics = CalorieCalculationService.calculateDayMetrics(
  user: userState.currentUser!,
  log: todayLog,
  settings: userState.metabolicSettings, // Pass settings here
);
```

### Energy Model (Future Implementation)

The **Energy Model** setting is saved and accessible, but adaptive behavior needs to be implemented:

**Static Mode:**
- Use BMR-based TDEE without adjustments
- Treat each day independently

**Adaptive Mode:**
- Analyze weight trends over time
- Adjust TDEE estimates based on actual weight loss/gain
- Use rolling averages and regression

**Hybrid Mode (Current Behavior):**
- Start with BMR baseline
- Gradually incorporate adaptive adjustments as data accumulates
- Balance stability with responsiveness

### Testing the Implementation

**Test Persistence:**
1. Open Metabolic Engine screen
2. Select "Strict" workout accuracy
3. Close app completely
4. Reopen app
5. Navigate back to Metabolic Engine
6. Verify "Strict" is still selected

**Test Calculation Impact:**
```dart
// Before: Balanced (0.8 multiplier)
// Device reports: 500 calories from workout
// Actual used: 500 × 0.8 = 400 calories

// After switching to Flexible (1.0 multiplier)
// Device reports: 500 calories
// Actual used: 500 × 1.0 = 500 calories
```

### Files Modified

1. **Created:**
   - `/lib/models/metabolic_settings.dart` - Settings data model

2. **Modified:**
   - `/lib/providers/user_state.dart` - Added settings state management
   - `/lib/features/control_center/metabolic_engine_screen.dart` - Wired UI to UserState
   - `/lib/services/calorie_calculation_service.dart` - Uses workout accuracy multiplier

### Dependencies

- `shared_preferences: ^2.2.2` - Already in pubspec.yaml
- `provider` - Already in use for UserState

### Next Steps (Optional Enhancements)

1. **Implement Adaptive Algorithm:**
   - Track weight trends over 7-14 days
   - Calculate actual vs expected weight loss
   - Adjust TDEE accordingly

2. **Add Settings Indicator:**
   - Show current settings on Dashboard
   - Display workout multiplier effect in results

3. **Export Settings:**
   - Include in user data backup/export
   - Allow settings import for new devices

4. **Analytics:**
   - Track which settings users prefer
   - Analyze accuracy of different models
