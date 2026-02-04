// ignore_for_file: unused_import, undefined_class, undefined_identifier, unused_element, unused_local_variable

import 'package:flutter/material.dart';

/// EXAMPLE INTEGRATION CODE
/// 
/// This file shows how to integrate the exercise logging system
/// into the rest of your app. Copy patterns from here into your actual code.

// ============================================================================
// 1. FAB MENU INTEGRATION (In your main app shell)
// ============================================================================

void _exampleFABIntegration(BuildContext context) {
  // Import at top:
  // import 'presentation/screens/exercise_logging/exercise_main_screen.dart';
  
  Navigator.push(
    context,
    // MaterialPageRoute(builder: (_) => const ExerciseMainScreen()),
    MaterialPageRoute(builder: (_) => const SizedBox()), // TODO: Replace with ExerciseMainScreen
  );
}

// ============================================================================
// 2. EXERCISE REPOSITORY (Create this file next)
// ============================================================================

/// TODO: Create lib/data/repositories/exercise_repository.dart
class ExerciseRepository {
  // TODO: Initialize with local DB (sqflite)
  
  /// Save exercise to local DB and queue for backend sync
  Future<void> saveExercise(Exercise exercise) async {
    // TODO: Save to SQLite
    // await _database.insert('exercises', exercise.toJson());
    
    // TODO: Sync to backend (if online)
    // await _apiService.postExercise(exercise);
  }

  /// Get today's exercises
  Future<List<dynamic>> getTodayExercises() async {
    // TODO: Query SQLite for today
    // final today = DateTime.now();
    // return _database.query(
    //   'exercises',
    //   where: 'date(timestamp) = date(?)',
    //   whereArgs: [today.toIso8601String()],
    // );
    return [];
  }

  /// Get all exercises (with pagination)
  Future<List<dynamic>> getAllExercises({int limit = 100, int offset = 0}) async {
    // TODO: Implement
    return [];
  }

  /// Delete exercise by ID
  Future<void> deleteExercise(String id) async {
    // TODO: Delete from DB
  }
}

// ============================================================================
// 3. DAILY RESULTS INTEGRATION
// ============================================================================

/// Example: Add this to your daily results calculation
Future<int> _calculateTodayCaloriesBurned(
  ExerciseRepository exerciseRepository,
  double? userWeight,
) async {
  final exercises = await exerciseRepository.getTodayExercises();
  
  int totalBurned = 0;
  for (final exercise in exercises) {
    // For run exercises, use estimation formula
    if (exercise.type == ExerciseType.run) {
      final estimated = exercise.getEstimatedCalories(userWeight);
      totalBurned += ((estimated ?? 0) as num).toInt();
    }
    // For manual exercises, use direct value
    else if (exercise.type == ExerciseType.manual) {
      totalBurned += ((exercise.caloriesBurned ?? 0) as num).toInt();
    }
    // TODO: For described exercises, use AI-extracted value
    // TODO: For weight lifting, use estimated based on sets/reps
  }
  
  return totalBurned;
}

// ============================================================================
// 4. RESULTS SCREEN INTEGRATION
// ============================================================================

class ExampleResultsScreen extends StatefulWidget {
  const ExampleResultsScreen({super.key});

  @override
  State<ExampleResultsScreen> createState() => _ExampleResultsScreenState();
}

class _ExampleResultsScreenState extends State<ExampleResultsScreen> {
  final exerciseRepository = ExerciseRepository();
  List<dynamic>? todayExercises;
  int caloriesBurned = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayExercises();
  }

  Future<void> _loadTodayExercises() async {
    try {
      final exercises = await exerciseRepository.getTodayExercises();
      
      // Calculate total burned
      int total = 0;
      for (final ex in exercises) {
        if (ex.type == ExerciseType.run) {
          total += ((ex.getEstimatedCalories(75) ?? 0) as num).toInt(); // TODO: Get real user weight
        } else if (ex.type == ExerciseType.manual) {
          total += ((ex.caloriesBurned ?? 0) as num).toInt();
        }
      }

      setState(() {
        todayExercises = exercises;
        caloriesBurned = total;
      });
    } catch (e) {
      print('Error loading exercises: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Calories burned section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Calories Burned'),
                  Text(
                    '🔥',
                    style: TextStyle(fontSize: 32),
                  ),
                ],
              ),
              Text(
                '$caloriesBurned cal',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Today's exercises list
        if (todayExercises != null && todayExercises!.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: todayExercises!.length,
              itemBuilder: (context, index) {
                final exercise = todayExercises![index];
                return _buildExerciseTile(exercise);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildExerciseTile(Exercise exercise) {
    final icon = switch (exercise.type) {
      ExerciseType.run => Icons.directions_run,
      ExerciseType.weightLifting => Icons.fitness_center,
      ExerciseType.described => Icons.edit,
      ExerciseType.manual => Icons.local_fire_department,
    };

    final title = switch (exercise.type) {
      ExerciseType.run => '${exercise.intensity?.label} - ${exercise.durationMinutes} min',
      ExerciseType.weightLifting => 'Weight Lifting',
      ExerciseType.described => 'Custom Workout',
      ExerciseType.manual => '${exercise.caloriesBurned} cal',
    };

    final subtitle = switch (exercise.type) {
      ExerciseType.run => '${exercise.getEstimatedCalories(75)} cal burned',
      ExerciseType.weightLifting => 'TODO',
      ExerciseType.described => exercise.description,
      ExerciseType.manual => 'Manual entry',
    };

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle ?? ''),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          // TODO: Delete exercise
        },
      ),
    );
  }
}

// ============================================================================
// 5. DAILY RESULTS MODEL EXTENSION
// ============================================================================

/// Add this to your DailyResults class
extension ExerciseTracking on DailyResults {
  /// Add exercise to today's results
  void addExercise(Exercise exercise) {
    // TODO: Add to exercises list
    // _exercises.add(exercise);
    
    // TODO: Update calorie calculation
    // _recalculateStats();
  }

  /// Get total calories burned today
  int getTotalBurned() {
    // TODO: Calculate from exercises list
    return 0;
  }

  /// Get exercise breakdown
  Map<String, int> getExerciseBreakdown() {
    // TODO: Count by type
    return {
      'run': 0,
      'weightLifting': 0,
      'described': 0,
      'manual': 0,
    };
  }
}

// ============================================================================
// 6. AI SERVICE INTEGRATION
// ============================================================================

/// TODO: Create lib/services/ai_service.dart
class AIService {
  /// Parse exercise description and extract metadata
  /// Returns: (duration, intensity, estimatedCalories)
  Future<(int?, ExerciseIntensity?, int?)> parseExerciseDescription(
    String description,
  ) async {
    // TODO: Call AI API
    // Example response:
    // "HIIT for 20 mins, 5/10 intensity"
    // → (20, medium, 250)
    
    return (null, null, null);
  }
}

// Example usage in ExerciseDescribeScreen:
Future<void> _parseWithAI(String description) async {
  final aiService = AIService();
  final (duration, intensity, calories) = await aiService.parseExerciseDescription(description);
  
  // TODO: Create exercise with extracted data
  final exercise = Exercise.described(description: description);
  // Could enhance with: intensity, estimatedCalories from parsing
}

// ============================================================================
// 7. HEALTHKIT INTEGRATION
// ============================================================================

/// TODO: Create lib/services/healthkit_service.dart
class HealthKitService {
  /// Get user's weight for calorie calculations
  Future<double?> getUserWeight() async {
    // TODO: Query HealthKit
    // Example: return 75.0; // kg
    return null;
  }

  /// Import workouts from HealthKit
  Future<List<dynamic>> importWorkouts() async {
    // TODO: Fetch from HealthKit
    return [];
  }

  /// Sync logged exercises to HealthKit
  Future<void> syncExercise(Exercise exercise) async {
    // TODO: Write to HealthKit
  }
}

// Example usage in screens:
Future<void> _syncToHealthKit(Exercise exercise) async {
  final hkService = HealthKitService();
  await hkService.syncExercise(exercise);
}

// ============================================================================
// 8. NAVIGATION EXAMPLE (Update your app routing)
// ============================================================================

/// Add to your app's routing setup
// if (route.name == '/exercise')
//   return MaterialPageRoute(
//     builder: (_) => const ExerciseMainScreen(),
//     settings: route,
//   );

// Or use named navigation:
// Navigator.pushNamed(context, '/exercise');

// ============================================================================
// 9. TESTING EXAMPLES
// ============================================================================

void main() {
  // Test creating exercises
  testExerciseCreation();
  testCalorieCalculation();
}

void testExerciseCreation() {
  print('Testing Exercise Creation...');
  
  // Run
  final run = Exercise.run(
    intensity: ExerciseIntensity.high,
    durationMinutes: 30,
  );
  assert(run.type == ExerciseType.run);
  print('✓ Run exercise created: ${run.id}');

  // Described
  final described = Exercise.described(
    description: 'HIIT for 20 mins',
  );
  assert(described.type == ExerciseType.described);
  print('✓ Described exercise created');

  // Manual
  final manual = Exercise.manual(caloriesBurned: 300);
  assert(manual.caloriesBurned == 300);
  print('✓ Manual exercise created');
}

void testCalorieCalculation() {
  print('Testing Calorie Calculation...');
  
  final low = Exercise.run(
    intensity: ExerciseIntensity.low,
    durationMinutes: 30,
  );
  final lowCals = low.getEstimatedCalories(75);
  print('Low 30min: $lowCals cal (expected ~120)');

  final medium = Exercise.run(
    intensity: ExerciseIntensity.medium,
    durationMinutes: 30,
  );
  final mediumCals = medium.getEstimatedCalories(75);
  print('Medium 30min: $mediumCals cal (expected ~210)');

  final high = Exercise.run(
    intensity: ExerciseIntensity.high,
    durationMinutes: 30,
  );
  final highCals = high.getEstimatedCalories(75);
  print('High 30min: $highCals cal (expected ~360)');
}

// ============================================================================
// 10. MIGRATION CHECKLIST
// ============================================================================

/// Copy this checklist to your project management:
/// 
/// - [ ] Create ExerciseRepository with DB layer
/// - [ ] Add Exercise field to DailyResults model
/// - [ ] Update Results screen to show exercises
/// - [ ] Create AIService stub (placeholder API call)
/// - [ ] Create HealthKitService (if needed)
/// - [ ] Add FAB navigation to ExerciseMainScreen
/// - [ ] Test all 4 exercise types end-to-end
/// - [ ] Verify data persistence
/// - [ ] Verify TDEE recalculation on new exercise
/// - [ ] Test HealthKit sync (if applicable)
/// - [ ] UI polish and theming
/// - [ ] Analytics integration (optional)

// ============================================================================
// Notes for Implementation
// ============================================================================

/// 1. START SIMPLE
///    - Get basic save/load working first
///    - Use in-memory store initially (List<Exercise>)
///    - Move to SQLite only after UI testing
///
/// 2. TEST DATA
///    - Add mock exercises for development
///    - Use same Exercise factories in tests
///    - Verify calorie math with known values
///
/// 3. ERROR HANDLING
///    - All TODOs should have try/catch
///    - Show user-friendly error messages
///    - Log detailed errors for debugging
///
/// 4. PERFORMANCE
///    - Lazy-load exercise details
///    - Paginate long lists
///    - Use StreamBuilder for real-time updates
///
/// 5. PRIVACY
///    - All data stored locally first
///    - Explicit user consent for cloud sync
///    - No fitness data shared without permission
///
/// 6. ITERATION
///    - Test each feature in isolation
///    - Get user feedback early
///    - Refine before full integration
