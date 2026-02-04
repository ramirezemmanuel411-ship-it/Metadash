# Exercise Logging System

Complete UI implementation for logging exercises in Metadash with 4 different entry methods.

## Overview

This system provides a flexible way for users to log exercises with different levels of detail and input methods. The architecture is designed to be extensible for future AI integration, HealthKit support, and calorie calculations.

## Features

### ✅ Implemented
- **4 Exercise Types**: Run, Weight Lifting, Describe, Manual
- **Run Logging**: Intensity selector (low/medium/high) + duration picker
- **Weight Lifting**: Placeholder (ready to implement)
- **Describe Exercise**: AI-ready text input with example helper
- **Manual Entry**: Number keypad for direct calorie input
- **Reusable Widgets**: ExerciseCard, IntensitySelector, DurationSelector
- **Local State Management**: StatefulWidget-based (no BLoC complexity)
- **iOS-First Design**: Smooth transitions, native styling
- **Validation**: Proper checks before allowing submission

### 🔜 TODO (Marked in Code)

1. **AI Integration**
   - Replace example text in describe screen with actual API call
   - Parse exercise descriptions to extract duration, intensity, calories
   - Location: `ExerciseDescribeScreen._fillWithAIExample()`

2. **HealthKit Integration**
   - Fetch user weight for calorie calculations
   - Validate user's VO2 max for intensity suggestions
   - Location: `Exercise.getEstimatedCalories()`

3. **Data Persistence**
   - Create exercise repository for local storage
   - Sync with backend API
   - Location: `ExerciseRunScreen._onContinue()`, etc.

4. **TDEE Integration**
   - Add logged exercise calories to daily totals
   - Update fat delta calculations
   - Update Results tab
   - Location: All screens' submit handlers

5. **Weight Lifting Screen**
   - Exercise selection/library
   - Set + rep logging
   - Weight tracking
   - Location: Create `exercise_weight_lifting_screen.dart`

## File Structure

```
lib/
├── models/
│   └── exercise_model.dart          # Exercise, ExerciseType, ExerciseIntensity
│
├── presentation/
│   ├── screens/exercise_logging/
│   │   ├── exercise_main_screen.dart          # Screen 1: Type selector
│   │   ├── exercise_run_screen.dart           # Screen 2: Run logging
│   │   ├── exercise_describe_screen.dart      # Screen 3: AI describe
│   │   └── exercise_manual_screen.dart        # Screen 4: Manual entry
│   │
│   └── widgets/
│       ├── exercise_card.dart           # Reusable selection card
│       ├── intensity_selector.dart      # Wheel picker for intensity
│       └── duration_selector.dart       # Pill buttons + custom input
```

## Data Model

### Exercise Class
```dart
Exercise(
  id: "timestamp",
  type: ExerciseType.run,
  timestamp: DateTime.now(),
  
  // Run-specific
  intensity: ExerciseIntensity.medium,
  durationMinutes: 30,
  
  // Described exercise
  description: "HIIT for 20 mins, 5/10 intensity",
  
  // Manual entry
  caloriesBurned: 300,
)
```

### ExerciseIntensity Enum
```dart
enum ExerciseIntensity {
  low,     // "Chill walk – 3 mph"
  medium,  // "Jogging – 6 mph"
  high,    // "Sprinting – 14 mph"
}
```

### ExerciseType Enum
```dart
enum ExerciseType {
  run,            // Cardio with intensity
  weightLifting,  // Strength training
  described,      // AI-parsed text
  manual,         // Direct calorie input
}
```

## Usage

### Navigate to Main Screen

From the FAB dumbbell icon:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const ExerciseMainScreen()),
);
```

### Create Exercise Programmatically

```dart
// Run
final runExercise = Exercise.run(
  intensity: ExerciseIntensity.high,
  durationMinutes: 45,
);

// Described
final describedExercise = Exercise.described(
  description: "HIIT for 20 mins",
);

// Manual
final manualExercise = Exercise.manual(
  caloriesBurned: 300,
);
```

### Get Estimated Calories

```dart
final exercise = Exercise.run(
  intensity: ExerciseIntensity.medium,
  durationMinutes: 30,
);

final calories = exercise.getEstimatedCalories(userWeight: 75); // 210 cal
```

## Screens Breakdown

### Screen 1: Exercise Main (4 Cards)
- **Location**: `exercise_main_screen.dart`
- **Cards**: Run, Weight Lifting, Describe, Manual
- **Navigation**: Direct to respective screens
- **Styling**: Soft background, full-width tappable cards

### Screen 2: Run Exercise
- **Location**: `exercise_run_screen.dart`
- **Intensity**: ListWheelScrollView with 3 options
- **Duration**: Quick-select pills (15, 30, 60, 90) + custom input
- **Submit**: Fixed bottom button, validation required

### Screen 3: Describe Exercise
- **Location**: `exercise_describe_screen.dart`
- **Input**: Multiline TextField
- **AI Button**: Fills example text (TODO: API call)
- **Helper**: Amber badge with example format
- **Submit**: "Add Exercise" button

### Screen 4: Manual Entry
- **Location**: `exercise_manual_screen.dart`
- **Keypad**: 3x4 grid (0-9, DEL, C)
- **Display**: Circular flame indicator with running total
- **Input**: Number keypad only (no text editing)
- **Submit**: "Add" button

## Styling

### Colors
- **Primary**: `Colors.blue` (buttons, selection highlights)
- **Accent**: `Colors.amber` (AI badges)
- **Background**: `Colors.grey[100]` (cards, inputs)
- **Warning**: `Colors.red` (delete button)

### Spacing
- **Card padding**: 16px
- **Section spacing**: 40px (between intensity and duration)
- **Button height**: 56px (touch target minimum)

### Typography
- **Title**: 18px bold
- **Card subtitle**: 14px medium gray
- **Keypad**: 20px bold

## Next Steps

1. **Connect to Repository**
   ```dart
   final exerciseRepository = ExerciseRepository();
   await exerciseRepository.saveExercise(exercise);
   ```

2. **Add to Daily Results**
   ```dart
   dailyResults.addExercise(exercise);
   dailyResults.recalculateTDEE();
   ```

3. **Implement Weight Lifting Screen**
   - Add exercise library (rows, squats, bench press, etc.)
   - Set + rep interface
   - Weight tracking per exercise

4. **AI Integration**
   - Replace `_fillWithAIExample()` with API call
   - Parse description for intensity, duration, exercise type
   - Suggest calories based on user profile

5. **HealthKit Integration**
   - Fetch user stats for calculations
   - Pull existing workout data
   - Real-time activity ring updates

## Testing

### Manual Testing Checklist
- [ ] Navigate through all 4 exercise types
- [ ] Run: Select intensity, duration, submit
- [ ] Describe: Type text, click AI button, submit
- [ ] Manual: Use keypad, DEL, C, submit
- [ ] Back button works from all screens
- [ ] Bottom buttons disable when invalid
- [ ] Error messages show when needed

### State Management
- Currently using `StatefulWidget`
- Ready for migration to BLoC if needed
- All local state in screen widgets
- TODO: Move to repository pattern once persistence is added

## Architecture Notes

### Why StatefulWidget?
- Simple, local-only state
- No complex data flow
- Clear cause/effect for UI updates
- Easy to test incrementally

### Why This Structure?
- **Separation of concerns**: Each screen handles one exercise type
- **Reusable widgets**: ExerciseCard, IntensitySelector, DurationSelector
- **Scalable**: Easy to add more exercise types
- **Future-proof**: Ready for repository, API, and AI integration

### Extensibility Hooks
- `Exercise.getEstimatedCalories()` - For TDEE math
- Screen submit handlers - For persistence
- `_fillWithAIExample()` - For AI service calls
- `ExerciseType` enum - For adding new types

## Known Limitations (By Design)

1. **No Backend Integration Yet** - Data not persisted
2. **Weight Lifting Stubbed** - Shows toast, no UI
3. **AI Placeholder** - Example text only
4. **No Image/Video Support** - Text/numbers only
5. **No History View** - No scrollback of logged exercises

These are intentionally left as TODO comments for iterative development.

## Questions to Answer Later

1. Should past exercises be editable?
2. Do we need bulk import from HealthKit?
3. What AI model for parsing descriptions?
4. Should intensity affect calorie calc directly?
5. Integration with nutrition logging (today's totals)?

---

**Status**: ✅ UI Complete | 🔄 Integration Ready | 🧠 AI Ready
