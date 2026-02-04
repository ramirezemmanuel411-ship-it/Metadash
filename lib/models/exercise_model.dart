import 'package:equatable/equatable.dart';

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
enum ExerciseType {
  run,
  weightLifting,
  described,
  manual,
}

/// Core exercise data model
class Exercise extends Equatable {
  final String id;
  final ExerciseType type;
  final DateTime timestamp;
  
  // Run-specific fields
  final ExerciseIntensity? intensity;
  final int? durationMinutes;
  
  // Described exercise fields
  final String? description;
  
  // Manual exercise fields
  final int? caloriesBurned;

  const Exercise({
    required this.id,
    required this.type,
    required this.timestamp,
    this.intensity,
    this.durationMinutes,
    this.description,
    this.caloriesBurned,
  });

  /// Create a run exercise
  factory Exercise.run({
    required ExerciseIntensity intensity,
    required int durationMinutes,
  }) {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ExerciseType.run,
      timestamp: DateTime.now(),
      intensity: intensity,
      durationMinutes: durationMinutes,
    );
  }

  /// Create a weight lifting exercise
  factory Exercise.weightLifting() {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ExerciseType.weightLifting,
      timestamp: DateTime.now(),
    );
  }

  /// Create a described exercise
  factory Exercise.described({
    required String description,
  }) {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ExerciseType.described,
      timestamp: DateTime.now(),
      description: description,
    );
  }

  /// Create a manual exercise
  factory Exercise.manual({
    required int caloriesBurned,
  }) {
    return Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ExerciseType.manual,
      timestamp: DateTime.now(),
      caloriesBurned: caloriesBurned,
    );
  }

  /// Get estimated calories burned for run
  /// TODO: Integrate with HealthKit data and user profile
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

  @override
  List<Object?> get props => [
    id,
    type,
    timestamp,
    intensity,
    durationMinutes,
    description,
    caloriesBurned,
  ];
}
