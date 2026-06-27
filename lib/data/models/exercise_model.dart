import 'package:equatable/equatable.dart';

/// Intensity levels for general workouts
enum WorkoutIntensity {
  light('Light', 'Easy effort, could hold a conversation'),
  moderate('Moderate', 'Steady effort, slightly breathless'),
  intense('Intense', 'Hard effort, difficult to speak');

  final String label;
  final String description;

  const WorkoutIntensity(this.label, this.description);
}

/// Exercise intensity levels for cardio workouts
enum ExerciseIntensity {
  low('Low', 'Chill walk – 3 mph (20 minute miles)'),
  medium('Medium', 'Jogging – 6 mph (10 minute miles)'),
  high('High', 'Sprinting – 14 mph (4 minute miles)');

  final String label;
  final String description;

  const ExerciseIntensity(this.label, this.description);
}

/// Types of exercises that can be logged
enum ExerciseType { run, weightLifting, described, manual }

/// Core exercise data model
class Exercise extends Equatable {
  final String id;
  final ExerciseType type;
  final DateTime timestamp;

  // Run-specific fields
  final ExerciseIntensity? intensity;
  final int? durationMinutes;

  // General workout fields
  final WorkoutIntensity? workoutIntensity;
  final String? workoutType;

  // Described exercise fields
  final String? description;

  // Manual exercise fields
  final int? caloriesBurned;

  // Heart rate
  final int? avgHeartRate;

  const Exercise({
    required this.id,
    required this.type,
    required this.timestamp,
    this.intensity,
    this.durationMinutes,
    this.workoutIntensity,
    this.workoutType,
    this.description,
    this.caloriesBurned,
    this.avgHeartRate,
  });

  /// Create a run exercise
  factory Exercise.run({
    required ExerciseIntensity intensity,
    required int durationMinutes,
    int? avgHeartRate,
  }) {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ExerciseType.run,
      timestamp: DateTime.now(),
      intensity: intensity,
      durationMinutes: durationMinutes,
      avgHeartRate: avgHeartRate,
    );
  }

  /// Create a general workout exercise
  factory Exercise.weightLifting({
    required WorkoutIntensity workoutIntensity,
    required int durationMinutes,
    String? workoutType,
    int? avgHeartRate,
  }) {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ExerciseType.weightLifting,
      timestamp: DateTime.now(),
      workoutIntensity: workoutIntensity,
      durationMinutes: durationMinutes,
      workoutType: workoutType,
      avgHeartRate: avgHeartRate,
    );
  }

  /// Create a described exercise
  factory Exercise.described({required String description}) {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ExerciseType.described,
      timestamp: DateTime.now(),
      description: description,
    );
  }

  /// Create a manual exercise
  factory Exercise.manual({required int caloriesBurned}) {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ExerciseType.manual,
      timestamp: DateTime.now(),
      caloriesBurned: caloriesBurned,
    );
  }

  /// Get estimated calories burned for run
  /// Note: planned integration with HealthKit data and user profile.
  int? getEstimatedCalories(double? userWeight) {
    if (type != ExerciseType.run || durationMinutes == null) return null;

    // Basic formula: duration * intensity multiplier * weight factor
    // This is placeholder; will be replaced with proper HealthKit/TDEE logic
    final baseCaloriesPerMinute = switch (intensity) {
      ExerciseIntensity.low => 4.0,
      ExerciseIntensity.medium => 7.0,
      ExerciseIntensity.high => 12.0,
      _ => 0.0,
    };

    return (baseCaloriesPerMinute * durationMinutes!).toInt();
  }

  /// MET values by workout type (Apple Health / Strava categories)
  static const _workoutTypeMets = {
    'Walking': 3.5,
    'Hiking': 6.0,
    'Cycling': 7.5,
    'Indoor Cycling': 6.8,
    'Swimming': 8.0,
    'Rowing': 7.0,
    'Indoor Rowing': 6.5,
    'Elliptical': 5.0,
    'Stair Climber': 9.0,
    'Jump Rope': 10.0,
    'HIIT': 8.0,
    'Circuit Training': 7.0,
    'Strength Training': 5.0,
    'CrossFit': 7.5,
    'Functional Training': 6.0,
    'Yoga': 3.0,
    'Pilates': 3.5,
    'Stretching': 2.5,
    'Tai Chi': 3.0,
    'Barre': 4.0,
    'Dance': 5.5,
    'Zumba': 6.5,
    'Boxing': 9.0,
    'Kickboxing': 9.5,
    'Martial Arts': 8.0,
    'Basketball': 8.0,
    'Soccer': 9.0,
    'Tennis': 7.5,
    'Volleyball': 6.0,
    'Golf': 4.5,
    'Rock Climbing': 8.5,
    'Skiing': 7.0,
    'Snowboarding': 6.0,
    'Surfing': 6.0,
    'Kayaking': 5.0,
    'Paddleboarding': 5.0,
  };

  /// Get estimated calories burned for a general workout (MET-based)
  int? getEstimatedWorkoutCalories(double? userWeightKg) {
    if (type != ExerciseType.weightLifting || durationMinutes == null) {
      return null;
    }
    final weightKg = userWeightKg ?? 75.0;
    // Use workout-type-specific MET if available, otherwise fall back to intensity
    final baseMet = workoutType != null
        ? (_workoutTypeMets[workoutType] ?? 5.0)
        : switch (workoutIntensity) {
            WorkoutIntensity.light => 3.0,
            WorkoutIntensity.moderate => 5.0,
            WorkoutIntensity.intense => 7.5,
            _ => 5.0,
          };
    // Intensity modifier: ±15% on top of base MET
    final intensityMod = switch (workoutIntensity) {
      WorkoutIntensity.light => 0.85,
      WorkoutIntensity.moderate => 1.0,
      WorkoutIntensity.intense => 1.15,
      _ => 1.0,
    };
    return ((baseMet * intensityMod * weightKg * durationMinutes!) / 60)
        .round();
  }

  @override
  List<Object?> get props => [
    id,
    type,
    timestamp,
    intensity,
    durationMinutes,
    workoutIntensity,
    workoutType,
    description,
    caloriesBurned,
    avgHeartRate,
  ];
}
