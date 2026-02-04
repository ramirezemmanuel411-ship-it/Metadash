# Exercise Logging Integration Guide

Quick setup to add exercise logging to your Metadash app.

## Step 1: Add to FAB Dumbbell Icon

In your FAB menu (likely in `app_shell.dart` or main screen):

```dart
// Import the main screen
import 'presentation/screens/exercise_logging/exercise_main_screen.dart';

// In your FAB menu definition, add:
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExerciseMainScreen()),
    );
  },
  tooltip: 'Log Exercise',
  child: const Icon(Icons.fitness_center),
),
```

## Step 2: Verify Structure

Make sure these files exist:

```
lib/
├── models/
│   └── exercise_model.dart                    ✅
├── presentation/
│   ├── screens/exercise_logging/
│   │   ├── exercise_main_screen.dart          ✅
│   │   ├── exercise_run_screen.dart           ✅
│   │   ├── exercise_describe_screen.dart      ✅
│   │   └── exercise_manual_screen.dart        ✅
│   └── widgets/
│       ├── exercise_card.dart                 ✅
│       ├── intensity_selector.dart            ✅
│       └── duration_selector.dart             ✅
```

## Step 3: Test Navigation

Run the app and tap the exercise logging button:

```bash
flutter run
```

You should see:
1. **Main screen** with 4 cards (Run, Weight Lifting, Describe, Manual)
2. **Each card** navigates to its respective flow
3. **Bottom buttons** disable/enable based on input validation

## Step 4: Next - Implement Data Persistence

Once UI is tested, create an exercise repository:

```dart
// lib/data/repositories/exercise_repository.dart
class ExerciseRepository {
  Future<void> saveExercise(Exercise exercise) async {
    // TODO: Save to local DB + sync to backend
  }
  
  Future<List<Exercise>> getTodayExercises() async {
    // TODO: Load from local DB
  }
}
```

Then update each screen's submit handler:

```dart
// In exercise_run_screen.dart
void _onContinue() {
  final exercise = Exercise.run(...);
  final repo = ExerciseRepository();
  await repo.saveExercise(exercise);
  
  // Update daily results
  final results = DailyResults();
  results.addExercise(exercise);
  
  Navigator.pop(context);
}
```

## Step 5: Connect to Results Tab

Add exercises to your daily calorie calculation:

```dart
// In your Results/Dashboard screen
Future<void> _loadTodayData() {
  final exercises = await exerciseRepository.getTodayExercises();
  final totalBurned = exercises
    .map((e) => e.getEstimatedCalories(userWeight))
    .whereType<int>()
    .fold(0, (a, b) => a + b);
  
  setState(() {
    caloriesBurned = totalBurned;
  });
}
```

## Available Methods

### Create Exercises
```dart
// Run
Exercise.run(intensity: ExerciseIntensity.high, durationMinutes: 30)

// Described
Exercise.described(description: "30 min HIIT")

// Manual
Exercise.manual(caloriesBurned: 300)
```

### Get Calories
```dart
final exercise = Exercise.run(intensity: ExerciseIntensity.medium, durationMinutes: 30);
final calories = exercise.getEstimatedCalories(userWeight: 75); // int
```

### Exercise Properties
```dart
exercise.id;               // String (timestamp)
exercise.type;             // ExerciseType
exercise.timestamp;        // DateTime
exercise.intensity;        // ExerciseIntensity? (run only)
exercise.durationMinutes;  // int? (run only)
exercise.description;      // String? (described only)
exercise.caloriesBurned;   // int? (manual only)
```

## Styling Customization

### Change Primary Color
Replace `Colors.blue` throughout the files:
```dart
// exercise_run_screen.dart line ~65
backgroundColor: Colors.green,  // Change to your color
```

### Change Card Style
In `exercise_card.dart`:
```dart
color: Colors.grey[100],  // Background
borderRadius: BorderRadius.circular(12),  // Roundness
```

### Change Intensity Options
In `exercise_model.dart`, update the enum:
```dart
enum ExerciseIntensity {
  low('Easy', 'Your description'),
  medium('Medium', 'Your description'),
  high('Hard', 'Your description'),
}
```

## Debug Tips

### Print Exercise Data
```dart
print('Exercise: ${exercise.type}');
print('Intensity: ${exercise.intensity?.label}');
print('Duration: ${exercise.durationMinutes} min');
print('Calories: ${exercise.caloriesBurned}');
```

### Test Estimation Formula
```dart
final ex = Exercise.run(intensity: ExerciseIntensity.high, durationMinutes: 30);
final cals = ex.getEstimatedCalories(userWeight: 75);
print('Estimated: $cals calories'); // Should be ~360
```

### Verify Navigation
Add logging to screen builders:
```dart
@override
Widget build(BuildContext context) {
  print('ExerciseRunScreen opened');
  return Scaffold(...);
}
```

## Common Issues

### Import Errors
- Verify file paths match exactly
- Make sure `.dart` extension is included
- Check relative paths from target file location

### Null Safety Warnings
- All fields that can be null are marked with `?`
- Use `?.` for optional access
- Check before using optional values

### UI Not Updating
- Verify `setState()` is called after state changes
- Check `onChanged` callbacks are wired correctly
- Ensure `TextEditingController` is properly initialized

## Next Iteration Features

Based on TODO comments in code:

1. **Weight Lifting Screen** (1-2 hours)
   - Exercise library + search
   - Set/rep entry
   - Weight tracking

2. **AI Integration** (2-4 hours)
   - Replace example text with API
   - Parse descriptions
   - Estimate calories from text

3. **HealthKit Integration** (2-3 hours)
   - Import user stats
   - Sync workouts
   - Real-time heart rate

4. **Data Persistence** (1-2 hours)
   - SQLite storage
   - Repository pattern
   - Sync logic

5. **Results Integration** (2-3 hours)
   - Add to daily totals
   - Update fat delta
   - History view

---

**Ready to test!** Just navigate to the FAB exercise icon.
