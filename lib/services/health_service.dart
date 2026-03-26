// ignore_for_file: avoid_print

import 'package:health/health.dart';

/// Service for syncing health data from HealthKit (iOS) and Google Fit / Health Connect (Android)
class HealthService {
  static final HealthService _instance = HealthService._internal();

  factory HealthService() {
    return _instance;
  }

  HealthService._internal();

  final Health _health = Health();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// List of data types we want to track
  static const List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.DISTANCE_DELTA,
  ];

  /// Request permissions from the user
  /// Returns true if user granted permissions, false otherwise
  Future<bool> requestPermissions() async {
    try {
      await _ensureConfigured();
      final accessTypes = _dataTypes
          .map((_) => HealthDataAccess.READ)
          .toList(growable: false);
      final authorized = await _health.requestAuthorization(
        _dataTypes,
        permissions: accessTypes,
      );
      if (authorized) return true;

      // Fallback: request without explicit permissions (some iOS builds require this)
      final fallbackAuthorized = await _health.requestAuthorization(_dataTypes);
      if (fallbackAuthorized) return true;

      // Fallback: request minimal scopes
      final minimalTypes = <HealthDataType>[
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
      ];
      final minimalAccess = minimalTypes
          .map((_) => HealthDataAccess.READ)
          .toList(growable: false);
      final minimalAuthorized = await _health.requestAuthorization(
        minimalTypes,
        permissions: minimalAccess,
      );
      return minimalAuthorized;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  /// Check if we have permissions to read health data
  Future<bool> hasPermissions() async {
    try {
      await _ensureConfigured();
      final results = await Future.wait(
        _dataTypes.map(_hasPermissionFor),
      );
      return results.any((value) => value);
    } catch (e) {
      print('Error checking health permissions: $e');
      return false;
    }
  }

  Future<bool> _hasPermissionFor(HealthDataType type) async {
    await _ensureConfigured();
    final withPermissions = await _health.hasPermissions(
      [type],
      permissions: const [HealthDataAccess.READ],
    );
    if (withPermissions ?? false) return true;

    // Fallback: check without explicit permissions
    final withoutPermissions = await _health.hasPermissions([type]);
    if (withoutPermissions ?? false) return true;

    // Fallback: try a lightweight read to confirm access (HealthKit may still allow reads)
    try {
      final now = DateTime.now();
      await _health.getHealthDataFromTypes(
        types: [type],
        startTime: now.subtract(const Duration(minutes: 5)),
        endTime: now,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, bool>> readPermissionStatus() async {
    await _ensureConfigured();
    final steps = await _hasPermissionFor(HealthDataType.STEPS);
    final calories = await _hasPermissionFor(HealthDataType.ACTIVE_ENERGY_BURNED);
    final workouts = await _hasPermissionFor(HealthDataType.WORKOUT);
    return {
      'Steps': steps,
      'Active Energy': calories,
      'Workouts': workouts,
    };
  }

  Future<Map<String, dynamic>> fetchHealthDiagnostics(DateTime date) async {
    await _ensureConfigured();
    final diagnostics = <String, dynamic>{};
    final hasSteps = await _hasPermissionFor(HealthDataType.STEPS);
    final hasCalories = await _hasPermissionFor(HealthDataType.ACTIVE_ENERGY_BURNED);
    final hasWorkouts = await _hasPermissionFor(HealthDataType.WORKOUT);
    diagnostics['permissions'] = {
      'steps': hasSteps,
      'activeEnergy': hasCalories,
      'workouts': hasWorkouts,
    };

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    diagnostics['steps'] = await _readDiagnosticsForType(
      type: HealthDataType.STEPS,
      start: startOfDay,
      end: endOfDay,
      enabled: hasSteps,
    );

    diagnostics['activeEnergy'] = await _readDiagnosticsForType(
      type: HealthDataType.ACTIVE_ENERGY_BURNED,
      start: startOfDay,
      end: endOfDay,
      enabled: hasCalories,
    );

    diagnostics['workouts'] = await _readDiagnosticsForType(
      type: HealthDataType.WORKOUT,
      start: startOfDay,
      end: endOfDay,
      enabled: hasWorkouts,
    );

    return diagnostics;
  }

  Future<Map<String, dynamic>> fetchHealthDiagnosticsRange(
    DateTime start,
    DateTime end,
  ) async {
    await _ensureConfigured();
    final diagnostics = <String, dynamic>{};
    final hasSteps = await _hasPermissionFor(HealthDataType.STEPS);
    final hasCalories = await _hasPermissionFor(HealthDataType.ACTIVE_ENERGY_BURNED);
    final hasWorkouts = await _hasPermissionFor(HealthDataType.WORKOUT);
    diagnostics['permissions'] = {
      'steps': hasSteps,
      'activeEnergy': hasCalories,
      'workouts': hasWorkouts,
    };

    diagnostics['steps'] = await _readDiagnosticsForType(
      type: HealthDataType.STEPS,
      start: start,
      end: end,
      enabled: hasSteps,
    );

    diagnostics['activeEnergy'] = await _readDiagnosticsForType(
      type: HealthDataType.ACTIVE_ENERGY_BURNED,
      start: start,
      end: end,
      enabled: hasCalories,
    );

    diagnostics['workouts'] = await _readDiagnosticsForType(
      type: HealthDataType.WORKOUT,
      start: start,
      end: end,
      enabled: hasWorkouts,
    );

    return diagnostics;
  }

  Future<Map<DateTime, HealthMetrics>> fetchDailyMetricsRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _ensureConfigured();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final endExclusive = DateTime(endDate.year, endDate.month, endDate.day)
        .add(const Duration(days: 1));

    final stepsByDay = <DateTime, int>{};
    final caloriesByDay = <DateTime, int>{};
    final workoutCaloriesByDay = <DateTime, int>{};
    final workoutTypeByDay = <DateTime, String>{};
    final runningStepsByDay = <DateTime, int>{};
    final workoutMinutesByDay = <DateTime, int>{};
    final sleepMinutesByDay = <DateTime, int>{};
    final sleepAsleepDays = <DateTime, bool>{};
    final restingHrSumByDay = <DateTime, int>{};
    final restingHrCountByDay = <DateTime, int>{};
    final avgHrSumByDay = <DateTime, int>{};
    final avgHrCountByDay = <DateTime, int>{};
    final distanceByDay = <DateTime, double>{};

    var usedTotals = false;
    try {
      DateTime current = start;
      while (current.isBefore(endExclusive)) {
        final next = current.add(const Duration(days: 1));
        final total = await _health.getTotalStepsInInterval(current, next);
        if (total != null) {
          stepsByDay[current] = total;
          usedTotals = true;
        }
        current = next;
      }
    } catch (_) {}

    if (!usedTotals) {
      try {
        final stepData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: start,
          endTime: endExclusive,
        );

        // Fallback: sum all values from samples
        for (final point in stepData) {
          final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
          final pointValue = _extractNumericValue(point);
          stepsByDay[day] = (stepsByDay[day] ?? 0) + pointValue;
        }
      } catch (_) {}
    }

    try {
      final calorieData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: start,
        endTime: endExclusive,
      );
      for (final point in calorieData) {
        final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
        final pointValue = _extractNumericValue(point);
        caloriesByDay[day] = (caloriesByDay[day] ?? 0) + pointValue;
      }
    } catch (_) {}

    try {
      final workoutData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: start,
        endTime: endExclusive,
      );
      final runningIntervalsByDay = <DateTime, List<_WorkoutInterval>>{};
      for (final point in workoutData) {
        final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
        int calories = 0;
        String type = '';
        final workoutValue = point.value;
        if (workoutValue is WorkoutHealthValue) {
          calories = workoutValue.totalEnergyBurned ?? 0;
          type = workoutValue.workoutActivityType.name;
        } else {
          calories = _extractNumericValue(point);
          type = _extractWorkoutType(point);
        }
        final existing = workoutCaloriesByDay[day] ?? 0;
        if (calories > existing) {
          workoutCaloriesByDay[day] = calories;
          workoutTypeByDay[day] = type;
        }

        final minutes = point.dateTo.difference(point.dateFrom).inMinutes;
        workoutMinutesByDay[day] = (workoutMinutesByDay[day] ?? 0) + minutes;

        if (_isRunningWorkoutType(type)) {
          runningIntervalsByDay.putIfAbsent(day, () => []);
          runningIntervalsByDay[day]!.add(
            _WorkoutInterval(point.dateFrom, point.dateTo),
          );
        }
      }

      if (runningIntervalsByDay.isNotEmpty) {
        try {
          final stepData = await _health.getHealthDataFromTypes(
            types: [HealthDataType.STEPS],
            startTime: start,
            endTime: endExclusive,
          );
          for (final point in stepData) {
            final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
            final intervals = runningIntervalsByDay[day];
            if (intervals == null || intervals.isEmpty) continue;
            if (_overlapsAnyInterval(point.dateFrom, point.dateTo, intervals)) {
              final value = _extractNumericValue(point);
              runningStepsByDay[day] = (runningStepsByDay[day] ?? 0) + value;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final sleepData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: start,
        endTime: endExclusive,
      );
      for (final point in sleepData) {
        final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
        final minutes = point.dateTo.difference(point.dateFrom).inMinutes;
        sleepMinutesByDay[day] = (sleepMinutesByDay[day] ?? 0) + minutes;
        sleepAsleepDays[day] = true;
      }
    } catch (_) {}

    try {
      final sleepInBedData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_IN_BED],
        startTime: start,
        endTime: endExclusive,
      );
      for (final point in sleepInBedData) {
        final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
        if (sleepAsleepDays[day] == true) continue;
        final minutes = point.dateTo.difference(point.dateFrom).inMinutes;
        sleepMinutesByDay[day] = (sleepMinutesByDay[day] ?? 0) + minutes;
      }
    } catch (_) {}

    try {
      final hrData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: endExclusive,
      );
      for (final point in hrData) {
        final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
        final value = _extractNumericValue(point);
        avgHrSumByDay[day] = (avgHrSumByDay[day] ?? 0) + value;
        avgHrCountByDay[day] = (avgHrCountByDay[day] ?? 0) + 1;
      }
    } catch (_) {}

    try {
      final restingData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.RESTING_HEART_RATE],
        startTime: start,
        endTime: endExclusive,
      );
      for (final point in restingData) {
        final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
        final value = _extractNumericValue(point);
        restingHrSumByDay[day] = (restingHrSumByDay[day] ?? 0) + value;
        restingHrCountByDay[day] = (restingHrCountByDay[day] ?? 0) + 1;
      }
    } catch (_) {}

    try {
      final distanceData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_DELTA],
        startTime: start,
        endTime: endExclusive,
      );
      for (final point in distanceData) {
        final day = DateTime(point.dateFrom.year, point.dateFrom.month, point.dateFrom.day);
        final value = _extractNumericValue(point).toDouble();
        distanceByDay[day] = (distanceByDay[day] ?? 0) + value;
      }
    } catch (_) {}


    final results = <DateTime, HealthMetrics>{};
    DateTime current = start;
    while (current.isBefore(endExclusive)) {
      final steps = stepsByDay[current] ?? 0;
      final calories = caloriesByDay[current] ?? 0;
      final workoutCalories = workoutCaloriesByDay[current] ?? 0;
      final workoutType = workoutTypeByDay[current] ?? '';
      final workoutMinutes = workoutMinutesByDay[current] ?? 0;
      final sleepMinutes = sleepMinutesByDay[current] ?? 0;
      final restingHr = restingHrCountByDay[current] != null && restingHrCountByDay[current]! > 0
          ? (restingHrSumByDay[current]! / restingHrCountByDay[current]!).round()
          : 0;
      final avgHr = avgHrCountByDay[current] != null && avgHrCountByDay[current]! > 0
          ? (avgHrSumByDay[current]! / avgHrCountByDay[current]!).round()
          : 0;
      final distanceMeters = distanceByDay[current] ?? 0;
      const vo2Max = 0.0;
      if (steps > 0 || calories > 0 || workoutCalories > 0 || workoutType.isNotEmpty) {
        final runningSteps = runningStepsByDay[current] ?? _inferRunningSteps(steps, workoutType);
        results[current] = HealthMetrics(
          totalSteps: steps,
          runningSteps: runningSteps,
          walkingSteps: steps - runningSteps,
          activeCalories: calories,
          workoutType: workoutType,
          workoutCalories: workoutCalories,
          workoutDurationMinutes: workoutMinutes,
          sleepMinutes: sleepMinutes,
          restingHeartRate: restingHr,
          averageHeartRate: avgHr,
          distanceMeters: distanceMeters,
          vo2Max: vo2Max,
        );
      }
      current = current.add(const Duration(days: 1));
    }

    return results;
  }

  Future<Map<String, dynamic>> _readDiagnosticsForType({
    required HealthDataType type,
    required DateTime start,
    required DateTime end,
    required bool enabled,
  }) async {
    await _ensureConfigured();
    final result = <String, dynamic>{
      'enabled': enabled,
      'count': 0,
      'sum': 0,
      'sources': <String>[],
      'error': '',
    };
    if (!enabled) return result;

    try {
      final data = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
      result['count'] = data.length;
      result['sum'] = data.fold<int>(0, (sum, point) {
        return sum + _extractNumericValue(point);
      });
      final sources = <String>{};
      for (final point in data) {
        if (point.sourceName.isNotEmpty) {
          sources.add(point.sourceName);
        } else if (point.sourceId.isNotEmpty) {
          sources.add(point.sourceId);
        }
      }
      result['sources'] = sources.toList()..sort();
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  /// Fetch health data for a specific date
  /// Returns health metrics for that day
  Future<HealthMetrics?> fetchHealthDataForDate(DateTime date) async {
    await _ensureConfigured();
    final hasSteps = await _hasPermissionFor(HealthDataType.STEPS);
    final hasCalories = await _hasPermissionFor(HealthDataType.ACTIVE_ENERGY_BURNED);
    final hasWorkouts = await _hasPermissionFor(HealthDataType.WORKOUT);

    // Fetch data for this day
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Fetch steps - prefer HealthKit daily total
    int totalSteps = 0;
    int runningSteps = 0;
    List<_WorkoutInterval> runningIntervals = [];
    try {
      var gotTotal = false;
      try {
        final total = await _health.getTotalStepsInInterval(
          startOfDay,
          endOfDay,
        );
        if (total != null) {
          totalSteps = total;
          gotTotal = true;
        }
      } catch (_) {}

      if (!gotTotal) {
        final stepData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: startOfDay,
          endTime: endOfDay,
        );

        if (stepData.isNotEmpty) {
          // Fallback: sum all incremental samples throughout the day
          totalSteps = stepData.fold<int>(0, (sum, data) {
            return sum + _extractNumericValue(data);
          });
        }
      }
    } catch (e) {
      if (hasSteps) {
        print('Error fetching steps: $e');
      }
    }

    // Fetch active calories - take MAX value, not sum
    // Same reason: HealthKit has overlapping cumulative data
    int activeCalories = 0;
    int workoutDurationMinutes = 0;
    int sleepMinutes = 0;
    int restingHeartRate = 0;
    int averageHeartRate = 0;
    double distanceMeters = 0;
    const double vo2Max = 0;
    try {
      final calorieData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      if (calorieData.isNotEmpty) {
        // SUM all incremental samples throughout the day
        activeCalories = calorieData.fold<int>(0, (sum, data) {
          return sum + _extractNumericValue(data);
        });
      }
    } catch (e) {
      if (hasCalories) {
        print('Error fetching active calories: $e');
      }
    }

    // Fetch workouts
    String workoutType = '';
    int workoutCalories = 0;
    try {
      final workoutData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      if (workoutData.isNotEmpty) {
        // Get the first workout (most significant)
        final workout = workoutData.first;

        // Extract workout type and calories from value
        final workoutValue = workout.value;
        if (workoutValue is WorkoutHealthValue) {
          workoutType = workoutValue.workoutActivityType.name;
          workoutCalories = workoutValue.totalEnergyBurned ?? 0;
        } else {
          workoutType = _extractWorkoutType(workout);
          workoutCalories = _extractNumericValue(workout);
        }

        for (final w in workoutData) {
          String type = '';
          final workoutValue = w.value;
          if (workoutValue is WorkoutHealthValue) {
            type = workoutValue.workoutActivityType.name;
          } else {
            type = _extractWorkoutType(w);
          }
          if (_isRunningWorkoutType(type)) {
            runningIntervals.add(_WorkoutInterval(w.dateFrom, w.dateTo));
          }
          workoutDurationMinutes += w.dateTo.difference(w.dateFrom).inMinutes;
        }
      }
    } catch (e) {
      if (hasWorkouts) {
        print('Error fetching workouts: $e');
      }
    }

    // Use step samples within running workout intervals to estimate running steps
    if (runningIntervals.isNotEmpty) {
      try {
        final stepData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: startOfDay,
          endTime: endOfDay,
        );
        for (final point in stepData) {
          if (_overlapsAnyInterval(point.dateFrom, point.dateTo, runningIntervals)) {
            runningSteps += _extractNumericValue(point);
          }
        }
      } catch (_) {}
    }

    if (runningSteps == 0) {
      // Estimate running vs walking steps based on workout type
      runningSteps = _inferRunningSteps(totalSteps, workoutType);
    }

    try {
      final sleepData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: startOfDay,
        endTime: endOfDay,
      );
      for (final point in sleepData) {
        sleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
      }
    } catch (_) {}

    if (sleepMinutes == 0) {
      try {
        final sleepInBedData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_IN_BED],
          startTime: startOfDay,
          endTime: endOfDay,
        );
        for (final point in sleepInBedData) {
          sleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
        }
      } catch (_) {}
    }

    try {
      final restingData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.RESTING_HEART_RATE],
        startTime: startOfDay,
        endTime: endOfDay,
      );
      if (restingData.isNotEmpty) {
        final sum = restingData.fold<int>(0, (s, p) => s + _extractNumericValue(p));
        restingHeartRate = (sum / restingData.length).round();
      }
    } catch (_) {}

    try {
      final hrData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startOfDay,
        endTime: endOfDay,
      );
      if (hrData.isNotEmpty) {
        final sum = hrData.fold<int>(0, (s, p) => s + _extractNumericValue(p));
        averageHeartRate = (sum / hrData.length).round();
      }
    } catch (_) {}

    try {
      final distanceData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_DELTA],
        startTime: startOfDay,
        endTime: endOfDay,
      );
      if (distanceData.isNotEmpty) {
        distanceMeters = distanceData.fold<double>(
          0,
          (s, p) => s + _extractNumericValue(p).toDouble(),
        );
      }
    } catch (_) {}


    return HealthMetrics(
      totalSteps: totalSteps,
      runningSteps: runningSteps,
      walkingSteps: totalSteps - runningSteps,
      activeCalories: activeCalories,
      workoutType: workoutType,
      workoutCalories: workoutCalories,
      workoutDurationMinutes: workoutDurationMinutes,
      sleepMinutes: sleepMinutes,
      restingHeartRate: restingHeartRate,
      averageHeartRate: averageHeartRate,
      distanceMeters: distanceMeters,
      vo2Max: vo2Max,
    );
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

  int _inferRunningSteps(int totalSteps, String workoutType) {
    if (totalSteps <= 0) return 0;
    final type = workoutType.toLowerCase();
    if (type.contains('running') || type.contains('marathon')) {
      return totalSteps;
    }
    if (type.contains('walking') || type.contains('hiking')) {
      return 0;
    }
    return 0;
  }

  bool _isRunningWorkoutType(String workoutType) {
    final type = workoutType.toLowerCase();
    return type.contains('running') || type.contains('marathon');
  }

  bool _overlapsAnyInterval(
    DateTime start,
    DateTime end,
    List<_WorkoutInterval> intervals,
  ) {
    for (final interval in intervals) {
      if (start.isBefore(interval.end) && end.isAfter(interval.start)) {
        return true;
      }
    }
    return false;
  }

  int _extractNumericValue(HealthDataPoint data) {
    final value = data.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toInt();
    }
    if (value is WorkoutHealthValue) {
      return value.totalEnergyBurned ?? 0;
    }
    return 0;
  }



  /// Debug: Get all raw step data points for a specific date
  /// Prints to console so you can see what Apple Health is returning
  Future<Map<String, dynamic>> debugStepDataForDate(DateTime date) async {
    await _ensureConfigured();
    final result = <String, dynamic>{};
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final stepData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: endOfDay,
      );

      result['count'] = stepData.length;
      result['dataPoints'] = [];
      
      print('\n=== DEBUG STEP DATA FOR ${date.toString().split(' ')[0]} ===');
      print('Total data points: ${stepData.length}');
      
      for (int i = 0; i < stepData.length; i++) {
        final point = stepData[i];
        final value = _extractNumericValue(point);
        final timeStr = '${point.dateFrom.hour}:${point.dateFrom.minute.toString().padLeft(2, '0')}';
        print('[$i] $timeStr: $value steps');
        (result['dataPoints'] as List).add({
          'time': timeStr,
          'value': value,
          'dateFrom': point.dateFrom.toString(),
          'dateTo': point.dateTo.toString(),
        });
      }
      
      // Show what max value we'd get from samples
      if (stepData.isNotEmpty) {
        final max = stepData.fold<int>(0, (maxVal, point) {
          final value = _extractNumericValue(point);
          return value > maxVal ? value : maxVal;
        });
        print('MAX VALUE (raw sample max): $max');
        result['maxValue'] = max;
      }

      try {
        final total = await _health.getTotalStepsInInterval(
          startOfDay,
          endOfDay,
        );
        if (total != null) {
          print('TOTAL STEPS (HealthKit interval): $total');
          result['totalStepsInterval'] = total;
        }
      } catch (_) {}
      
    } catch (e) {
      print('Error fetching step data: $e');
      result['error'] = e.toString();
    }
    
    return result;
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
  final int workoutDurationMinutes;
  final int sleepMinutes;
  final int restingHeartRate;
  final int averageHeartRate;
  final double distanceMeters;
  final double vo2Max;

  HealthMetrics({
    required this.totalSteps,
    required this.runningSteps,
    required this.walkingSteps,
    required this.activeCalories,
    required this.workoutType,
    required this.workoutCalories,
    required this.workoutDurationMinutes,
    required this.sleepMinutes,
    required this.restingHeartRate,
    required this.averageHeartRate,
    required this.distanceMeters,
    required this.vo2Max,
  });

  @override
  String toString() =>
      'HealthMetrics(steps: $totalSteps, running: $runningSteps, calories: $activeCalories, workout: $workoutType, sleep: $sleepMinutes)';
}

class _WorkoutInterval {
  final DateTime start;
  final DateTime end;

  const _WorkoutInterval(this.start, this.end);
}

