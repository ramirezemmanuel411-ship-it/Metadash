import '../../models/exercise_model.dart';
import '../../services/database_service.dart';
import '../../providers/user_state.dart';

/// Repository for exercise persistence and retrieval
class ExerciseRepository {
  final DatabaseService _db;
  final UserState _userState;

  ExerciseRepository({
    DatabaseService? db,
    required UserState userState,
  })  : _db = db ?? DatabaseService(),
        _userState = userState;

  /// Save exercise to local database
  Future<void> saveExercise(Exercise exercise) async {
    final userId = _userState.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final date = DateTime(
      exercise.timestamp.year,
      exercise.timestamp.month,
      exercise.timestamp.day,
    );

    await _db.createExercise({
      'id': exercise.id,
      'userId': userId,
      'date': date.toIso8601String(),
      'type': exercise.type.toString().split('.').last, // Enum to string
      'intensity': exercise.intensity?.toString().split('.').last,
      'durationMinutes': exercise.durationMinutes,
      'description': exercise.description,
      'caloriesBurned': exercise.caloriesBurned,
      'timestamp': exercise.timestamp.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Get today's exercises
  Future<List<Exercise>> getTodayExercises() async {
    final userId = _userState.currentUser?.id;
    if (userId == null) {
      return [];
    }

    final today = DateTime.now();
    final maps = await _db.getExercisesByUserAndDate(userId, today);
    return maps.map((m) => _mapToExercise(m)).toList();
  }

  /// Get exercises for a specific date
  Future<List<Exercise>> getExercisesByDate(DateTime date) async {
    final userId = _userState.currentUser?.id;
    if (userId == null) {
      return [];
    }

    final maps = await _db.getExercisesByUserAndDate(userId, date);
    return maps.map((m) => _mapToExercise(m)).toList();
  }

  /// Get all exercises for the current user
  Future<List<Exercise>> getAllExercises() async {
    final userId = _userState.currentUser?.id;
    if (userId == null) {
      return [];
    }

    final maps = await _db.getExercisesByUser(userId);
    return maps.map((m) => _mapToExercise(m)).toList();
  }

  /// Delete exercise by ID
  Future<void> deleteExercise(String id) async {
    await _db.deleteExercise(id);
  }

  /// Calculate total calories burned today
  Future<int> getTodayCaloriesBurned() async {
    final exercises = await getTodayExercises();
    int total = 0;

    for (final exercise in exercises) {
      // For manual exercises, use direct value
      if (exercise.type == ExerciseType.manual && exercise.caloriesBurned != null) {
        total += exercise.caloriesBurned!;
      }
      // For run exercises, use estimated (requires user weight)
      else if (exercise.type == ExerciseType.run) {
        final weight = _userState.currentUser?.weight;
        if (weight != null) {
          final estimated = exercise.getEstimatedCalories(weight);
          if (estimated != null) total += estimated;
        }
      }
      // For described exercises, parse from AI extraction in future enhancement.
      // For weight lifting, calculate from sets/reps in future enhancement.
    }

    return total;
  }

  /// Convert database map to Exercise object
  Exercise _mapToExercise(Map<String, dynamic> map) {
    final type = ExerciseType.values.firstWhere(
      (e) => e.toString().split('.').last == map['type'],
      orElse: () => ExerciseType.manual,
    );

    final intensity = map['intensity'] != null
        ? ExerciseIntensity.values.firstWhere(
            (e) => e.toString().split('.').last == map['intensity'],
            orElse: () => ExerciseIntensity.medium,
          )
        : null;

    switch (type) {
      case ExerciseType.run:
        return Exercise.run(
          intensity: intensity ?? ExerciseIntensity.medium,
          durationMinutes: map['durationMinutes'] ?? 30,
        );

      case ExerciseType.weightLifting:
        return Exercise.run(
          intensity: intensity ?? ExerciseIntensity.medium,
          durationMinutes: map['durationMinutes'] ?? 30,
        );

      case ExerciseType.described:
        return Exercise.described(description: map['description'] ?? '');

      case ExerciseType.manual:
        return Exercise.manual(caloriesBurned: map['caloriesBurned']);
    }
  }
}
