# 🏋️ Exercise Logging System - Visual Guide

## System Overview Diagram

```
┌─────────────────────────────────────────────────────┐
│           EXERCISE MAIN SCREEN (4 Cards)            │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌────────────────┐  ┌──────────────────┐          │
│  │   🏃 RUN       │  │ 🏋️ WEIGHT LIFT   │          │
│  │ Running, etc   │  │ Machines, etc    │          │
│  └────────────────┘  └──────────────────┘          │
│                                                     │
│  ┌────────────────┐  ┌──────────────────┐          │
│  │   ✏️ DESCRIBE   │  │ 🔥 MANUAL        │          │
│  │ Write workout  │  │ Enter calories   │          │
│  │ ✨ AI Powered  │  │                  │          │
│  └────────────────┘  └──────────────────┘          │
│                                                     │
└─────────────────────────────────────────────────────┘
         ↓              ↓              ↓
      Screen 2       Screen 3       Screen 4
      (Run)        (Describe)      (Manual)
```

---

## Screen 2: Run Exercise

```
┌──────────────────────────────┐
│          RUN                 │
├──────────────────────────────┤
│                              │
│  Set Intensity               │
│  ┌────────────────────────┐  │
│  │ 🔘 HIGH ◄─── wheel     │  │
│  │    Sprinting - 14mph   │  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │    MEDIUM              │  │
│  │    Jogging - 6mph      │  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │    LOW                 │  │
│  │    Walk - 3mph         │  │
│  └────────────────────────┘  │
│                              │
│  Duration                    │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐        │
│  │15│ │30│ │60│ │90│ min    │
│  └──┘ └──┘ └──┘ └──┘        │
│  ┌─────────────────────────┐ │
│  │ 30    min               │ │
│  └─────────────────────────┘ │
│                              │
├──────────────────────────────┤
│    ┌──────────────────────┐  │
│    │    CONTINUE          │  │
│    └──────────────────────┘  │
└──────────────────────────────┘
```

---

## Screen 3: Describe Exercise

```
┌──────────────────────────────┐
│    DESCRIBE EXERCISE         │
├──────────────────────────────┤
│                              │
│ ┌────────────────────────┐   │
│ │ Describe workout time, │   │
│ │ intensity, etc.        │   │
│ │ [text input area]      │   │
│ │                        │   │
│ └────────────────────────┘   │
│                              │
│ ┌─ Example: ────────────────┐│
│ │ HIIT for 20 mins, 5/10    ││
│ │ intensity                 ││
│ └──────────────────────────┘│
│                              │
│ ┌──────────────────────────┐ │
│ │  ✨ Created by AI        │ │
│ └──────────────────────────┘ │
│                              │
├──────────────────────────────┤
│  ┌──────────────────────┐   │
│  │   ADD EXERCISE       │   │
│  └──────────────────────┘   │
└──────────────────────────────┘
```

---

## Screen 4: Manual Entry

```
┌──────────────────────────────┐
│       MANUAL                 │
├──────────────────────────────┤
│                              │
│        ┌─────────────┐       │
│        │   🔥   300  │       │
│        │  calories   │       │
│        └─────────────┘       │
│                              │
│  ┌────────────────────────┐  │
│  │       300 cal          │  │ ← Display
│  └────────────────────────┘  │
│                              │
│  ┌───┬───┬───┐               │
│  │ 1 │ 2 │ 3 │               │
│  ├───┼───┼───┤               │
│  │ 4 │ 5 │ 6 │               │
│  ├───┼───┼───┤               │
│  │ 7 │ 8 │ 9 │               │
│  ├───┼───┼───┤               │
│  │DEL│ 0 │ C │ ← Keypad     │
│  └───┴───┴───┘               │
│                              │
├──────────────────────────────┤
│  ┌──────────────────────┐   │
│  │      ADD             │   │
│  └──────────────────────┘   │
└──────────────────────────────┘
```

---

## Data Flow Diagram

```
┌──────────────────┐
│  EXERCISE TYPES  │
└──────────────────┘
        │
        ├─→ RUN
        │    ├─ Intensity (Low/Medium/High)
        │    └─ Duration (minutes)
        │
        ├─→ WEIGHT LIFTING
        │    ├─ Exercise (bench, squat, etc)
        │    ├─ Sets
        │    └─ Reps
        │
        ├─→ DESCRIBED
        │    ├─ Description (text)
        │    └─ AI parsing → calories
        │
        └─→ MANUAL
             └─ Calories (direct input)

                    ↓ ALL ↓

┌──────────────────────────────┐
│    EXERCISE OBJECT           │
├──────────────────────────────┤
│ • id: timestamp              │
│ • type: ExerciseType         │
│ • timestamp: DateTime        │
│ • calories: int?             │
│ • metadata: ?                │
└──────────────────────────────┘

                    ↓

┌──────────────────────────────┐
│   TODO: REPOSITORY LAYER     │
├──────────────────────────────┤
│ • Save to SQLite             │
│ • Query by date              │
│ • Sync to backend            │
└──────────────────────────────┘

                    ↓

┌──────────────────────────────┐
│   TODO: RESULTS INTEGRATION  │
├──────────────────────────────┤
│ • Add to daily totals        │
│ • Update TDEE calc           │
│ • Calculate fat delta        │
│ • Show in results tab        │
└──────────────────────────────┘
```

---

## File Organization Tree

```
lib/
│
├── models/
│   └── exercise_model.dart
│       ├── Exercise (immutable class)
│       ├── ExerciseType enum
│       │   ├─ run
│       │   ├─ weightLifting
│       │   ├─ described
│       │   └─ manual
│       ├── ExerciseIntensity enum
│       │   ├─ low
│       │   ├─ medium
│       │   └─ high
│       └── Calorie calculations
│
├── presentation/
│   │
│   ├── screens/exercise_logging/
│   │   ├── exercise_main_screen.dart (4 cards)
│   │   ├── exercise_run_screen.dart (intensity + duration)
│   │   ├── exercise_describe_screen.dart (text + AI)
│   │   └── exercise_manual_screen.dart (keypad)
│   │
│   └── widgets/
│       ├── exercise_card.dart (reusable selection card)
│       ├── intensity_selector.dart (wheel picker)
│       └── duration_selector.dart (pills + input)
│
└── (other existing app code...)
```

---

## Widget Hierarchy

```
ExerciseMainScreen
├── AppBar
└── SingleChildScrollView
    └── Column
        ├── ExerciseCard (Run)
        ├── ExerciseCard (Weight Lifting)
        ├── ExerciseCard (Describe)
        └── ExerciseCard (Manual)

ExerciseRunScreen
├── AppBar
└── Column
    ├── Expanded
    │   └── SingleChildScrollView
    │       └── Column
    │           ├── IntensitySelector
    │           │   └── ListWheelScrollView
    │           └── DurationSelector
    │               └── Column
    │                   ├── Wrap (quick-select pills)
    │                   └── TextField
    │
    └── ElevatedButton (Continue)

ExerciseDescribeScreen
├── AppBar
└── Column
    ├── Expanded
    │   └── SingleChildScrollView
    │       └── Column
    │           ├── TextField
    │           ├── Container (example)
    │           └── ElevatedButton (AI)
    │
    └── ElevatedButton (Add)

ExerciseManualScreen
├── AppBar
└── Column
    ├── Expanded
    │   └── SingleChildScrollView
    │       └── Column
    │           ├── Circle (flame indicator)
    │           ├── Container (display)
    │           └── GridView (keypad)
    │
    └── ElevatedButton (Add)
```

---

## State Management Flow

```
Screen Loads
    ↓
initialize() → initialize controllers/state
    ↓
build() → render UI
    ↓
User Input
    ├─ Taps card → navigate to screen
    ├─ Selects intensity → setState()
    ├─ Changes duration → setState()
    ├─ Types text → setState()
    ├─ Taps keypad → setState()
    │
    ↓
Validation
    ├─ Check intensity selected?
    ├─ Check duration > 0?
    ├─ Check text not empty?
    ├─ Check calories > 0?
    │
    ↓
Submit
    ├─ Create Exercise object
    ├─ TODO: Save to repository
    ├─ Pop screen
    └─ Show success message
```

---

## Color Palette

```
Primary Actions
├─ Button: Colors.blue
├─ Selection: Colors.blue
└─ Border: Colors.blue[600]

Secondary
├─ AI Badge: Colors.amber
├─ Background: Colors.grey[100]
└─ Text: Colors.black87

Status
├─ Disabled: Colors.grey[300]
├─ Error: Colors.red
└─ Success: Colors.green[400]

Text
├─ Primary: Colors.black87
├─ Secondary: Colors.grey[600]
└─ Disabled: Colors.grey[400]
```

---

## User Journey

```
START: Home Screen
    ↓
User taps FAB (dumbbell icon)
    ↓
ExerciseMainScreen loads (4 cards)
    ↓
User selects type:
    ├─ RUN → ExerciseRunScreen
    │   └─ Select intensity & duration
    │       └─ Click Continue
    │           └─ Create Exercise.run()
    │
    ├─ WEIGHT LIFTING → TODO
    │
    ├─ DESCRIBE → ExerciseDescribeScreen
    │   └─ Type or generate description
    │       └─ Click Add Exercise
    │           └─ Create Exercise.described()
    │
    └─ MANUAL → ExerciseManualScreen
        └─ Use keypad to enter calories
            └─ Click Add
                └─ Create Exercise.manual()

(All paths)
    ↓
TODO: Save to repository
    ↓
TODO: Add to daily results
    ↓
Pop to Results screen
    ↓
Show success message
    ↓
Update calorie totals
    ↓
DONE: Return to normal flow
```

---

## Integration Points (Visual)

```
Current State (✅ Complete)
┌────────────────────────┐
│  Exercise Logging UI   │
│  ├─ 4 Screens        │
│  ├─ 3 Widgets        │
│  └─ Models           │
└────────────────────────┘
         ↓
        👇 (YOU ARE HERE)


Next State (🔜 TODO)
┌────────────────────────┐
│ Add Repository Layer   │
├─ ExerciseRepository   │
├─ SQLite Schema        │
└─ CRUD Operations      │
└────────────────────────┘
         ↓
┌────────────────────────┐
│ Connect to Results Tab │
├─ Show exercises       │
├─ Update totals        │
└─ Update fat delta     │
└────────────────────────┘
         ↓
┌────────────────────────┐
│ Add AI Integration     │
├─ Parse descriptions   │
├─ Estimate calories    │
└─ Suggest intensity    │
└────────────────────────┘
         ↓
┌────────────────────────┐
│ Add HealthKit (opt)    │
├─ Import workouts      │
├─ Sync user stats      │
└─ Real-time updates    │
└────────────────────────┘
```

---

## Quick Reference

### Create Exercises
```dart
Exercise.run(
  intensity: ExerciseIntensity.high,
  durationMinutes: 30,
)

Exercise.described(
  description: "HIIT for 20 mins"
)

Exercise.manual(
  caloriesBurned: 300
)
```

### Get Calories
```dart
exercise.getEstimatedCalories(userWeight: 75)
// Returns: int? (null if not available)
```

### Access Data
```dart
exercise.type           // ExerciseType
exercise.timestamp      // DateTime
exercise.intensity      // ExerciseIntensity? (run only)
exercise.durationMinutes // int? (run only)
exercise.description    // String? (described only)
exercise.caloriesBurned // int? (manual only)
```

---

**This visual guide should help you navigate the system!**
