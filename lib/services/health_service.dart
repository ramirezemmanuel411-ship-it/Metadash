import 'package:health/health.dart';

/// Service for syncing health data from HealthKit (iOS) and Google Fit / Health Connect (Android)
class HealthService {
  static final HealthService _instance = HealthService._internal();

  factory HealthService() {
    return _instance;
  }

  HealthService._internal();

  final Health _health = Health();

  /// List of data types we want to track
  static const List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];

  /// Request permissions from the user
  /// Returns true if user granted permissions, false otherwise
  Future<bool> requestPermissions() async {
    try {
      final authorized = await _health.requestAuthorization(_dataTypes);
      return authorized;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  /// Check if we have permissions to read health data
  Future<bool> hasPermissions() async {
    try {
      final hasAuth = await _health.hasPermissions(_dataTypes);
      return hasAuth ?? false;
    } catch (e) {
      print('Error checking health permissions: $e');
      return false;
    }
  }

  /// Fetch health data for a specific date
  /// Returns health metrics for that day
  Future<HealthMetrics?> fetchHealthDataForDate(DateTime date) async {
    try {
      // Ensure permissions are granted
      bool hasAuth = await hasPermissions();
      if (!hasAuth) {
        print('No health permissions granted');
        return null;
      }

      // Fetch data for this day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Fetch steps
      int totalSteps = 0;
      int runningSteps = 0;
      final stepData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      if (stepData.isNotEmpty) {
        totalSteps = stepData
            .fold<int>(0, (sum, data) => sum + (data.value as int? ?? 0));
      }

      // Fetch active calories
      int activeCalories = 0;
      final calorieData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      if (calorieData.isNotEmpty) {
        activeCalories = calorieData
            .fold<int>(0, (sum, data) => sum + (data.value as int? ?? 0).toInt());
      }

      // Fetch workouts
      String workoutType = '';
      int workoutCalories = 0;
      final workoutData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      if (workoutData.isNotEmpty) {
        // Get the first workout (most significant)
        final workout = workoutData.first;
        
        // Extract workout type - health package stores workout type in sourceRevision
        workoutType = _extractWorkoutType(workout);
        
        // If workout has calories, use those; otherwise use active calories
        if (workout.value is num) {
          workoutCalories = (workout.value as num).toInt();
        }
      }

      // Estimate running vs walking steps
      // If workout type is running or high cardio, assume 30% running
      if (workoutType.toLowerCase().contains('running') ||
          workoutType.toLowerCase().contains('cardio')) {
        runningSteps = (totalSteps * 0.3).toInt();
      }

      return HealthMetrics(
        totalSteps: totalSteps,
        runningSteps: runningSteps,
        walkingSteps: totalSteps - runningSteps,
        activeCalories: activeCalories,
        workoutType: workoutType,
        workoutCalories: workoutCalories,
      );
    } catch (e) {
      print('Error fetching health data: $e');
      return null;
    }
  }

  /// Map health workout types to our internal types based on data point
  String _extractWorkoutType(HealthDataPoint workout) {
    // The health package includes workout type info in the data point
    // Default to generic workout types based on active calories
    if (workout.value is num && (workout.value as num) > 0) {
      // High calorie burn likely cardio
      return 'Cardio';
    }
    return '';
  }



  /// Fetch health data for a date range
  Future<List<HealthMetrics>> fetchHealthDataRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final metrics = <HealthMetrics>[];
    var currentDate = startDate;

    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final dayMetrics = await fetchHealthDataForDate(currentDate);
      if (dayMetrics != null) {
        metrics.add(dayMetrics);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return metrics;
  }
}

/// Data class holding health metrics from device
class HealthMetrics {
  final int totalSteps;
  final int runningSteps;
  final int walkingSteps;
  final int activeCalories;
  final String workoutType;
  final int workoutCalories;

  HealthMetrics({
    required this.totalSteps,
    required this.runningSteps,
    required this.walkingSteps,
    required this.activeCalories,
    required this.workoutType,
    required this.workoutCalories,
  });

  @override
  String toString() =>
      'HealthMetrics(steps: $totalSteps, running: $runningSteps, calories: $activeCalories, workout: $workoutType)';
}
