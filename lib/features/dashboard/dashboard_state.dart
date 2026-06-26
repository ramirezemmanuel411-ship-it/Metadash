import 'package:flutter/foundation.dart';
import 'package:metadash/core/logging/app_logger.dart';

import 'package:metadash/models/data_inputs_settings.dart';
import 'package:metadash/providers/user_state.dart';
import 'package:metadash/services/calorie_calculation_service.dart';
import 'package:metadash/shared/date_utils.dart';

class DashboardDayData {
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbsConsumed;
  final int carbsGoal;
  final int fatConsumed;
  final int fatGoal;
  final int stepsTaken;
  final int stepsGoal;
  // ─ HealthKit / DailyLog passthrough ────────────────────────────────────────
  final int? sleepMinutes;
  final int? restingHR;
  final int? workoutCalories;
  final int? workoutDurationMinutes;
  final String? workoutType;
  final double waterOz;
  final double? tdee;
  final DateTime? firstMealTime;
  final DateTime? lastMealTime;
  final double? hrv;
  final int? mindfulnessMinutes;

  const DashboardDayData({
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbsConsumed,
    required this.carbsGoal,
    required this.fatConsumed,
    required this.fatGoal,
    required this.stepsTaken,
    required this.stepsGoal,
    this.sleepMinutes,
    this.restingHR,
    this.workoutCalories,
    this.workoutDurationMinutes,
    this.workoutType,
    this.waterOz = 0,
    this.tdee,
    this.firstMealTime,
    this.lastMealTime,
    this.hrv,
    this.mindfulnessMinutes,
  });
}

class DashboardState extends ChangeNotifier {
  DashboardState({DateTime? initialDate, this.userState})
    : _selectedDate = AppDateUtils.normalizeDate(
        initialDate ?? DateTime.now(),
      ) {
    if (userState != null) {
      _loadDailyData();
    }
  }

  final UserState? userState;
  final Map<DateTime, DashboardDayData> _cachedData = {};
  DateTime _selectedDate;
  bool _isLoading = false;

  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  DashboardDayData get selectedData =>
      _cachedData[_selectedDate] ?? _defaultDataFor(_selectedDate);

  void setSelectedDate(DateTime date) {
    final normalized = AppDateUtils.normalizeDate(date);
    if (AppDateUtils.isSameDay(normalized, _selectedDate)) return;
    _selectedDate = normalized;
    notifyListeners();
    _loadDailyData();
  }

  void setSelectedDateFromExternal(DateTime date) {
    final normalized = AppDateUtils.normalizeDate(date);
    if (AppDateUtils.isSameDay(normalized, _selectedDate)) return;
    _selectedDate = normalized;
    notifyListeners();
    _loadDailyData();
  }

  Future<void> _loadDailyData() async {
    if (userState == null) return;

    final user = userState!.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final log = await userState!.db.getDailyLogByUserAndDate(
        user.id!,
        _selectedDate,
      );
      final foodEntryMaps = await userState!.db.getFoodEntriesForDay(
        user.id!,
        _selectedDate,
      );
      final settings =
          await userState!.db.getDataInputsSettings(user.id!) ??
          DataInputsSettings.defaults(
            user.id!,
          ).copyWith(stepGoal: user.dailyStepsGoal);
      await userState!.db.createOrUpdateDataInputsSettings(settings);

      int foodCalories = 0;
      int foodProtein = 0;
      int foodCarbs = 0;
      int foodFat = 0;

      for (final map in foodEntryMaps) {
        foodCalories += (map['calories'] as int?) ?? 0;
        foodProtein += (map['proteinG'] as int?) ?? 0;
        foodCarbs += (map['carbsG'] as int?) ?? 0;
        foodFat += (map['fatG'] as int?) ?? 0;
      }

      // First & last meal times for the Meal Timing widget.
      DateTime? firstMeal;
      DateTime? lastMeal;
      for (final map in foodEntryMaps) {
        final ts = DateTime.tryParse(map['timestamp'] as String? ?? '');
        if (ts == null) continue;
        if (firstMeal == null || ts.isBefore(firstMeal)) firstMeal = ts;
        if (lastMeal == null || ts.isAfter(lastMeal)) lastMeal = ts;
      }

      // Debugging: Log values for calories calculation
      AppLogger.d('Log caloriesConsumed: \\${log?.caloriesConsumed ?? 0}');
      AppLogger.d('Food calories: \\$foodCalories');
      AppLogger.d('Daily caloric goal: \\$user.dailyCaloricGoal');

      // Additional debugging to verify data fetching
      AppLogger.d('Log: \\$log');
      AppLogger.d('Food Entry Maps: \\$foodEntryMaps');
      AppLogger.d('Settings: \\$settings');

      // Compute TDEE from today's log data
      double? todayTDEE;
      if (log != null) {
        try {
          final metrics = CalorieCalculationService.calculateDayMetrics(
            user: user,
            log: log,
            settings: userState!.metabolicSettings,
            inputs: userState!.dataInputsSettings,
          );
          todayTDEE = metrics.tdee;
        } catch (_) {}
      }

      if (log != null) {
        _cachedData[_selectedDate] = DashboardDayData(
          caloriesConsumed: log.caloriesConsumed + foodCalories,
          caloriesGoal: user.dailyCaloricGoal,
          proteinConsumed: log.protein + foodProtein,
          proteinGoal:
              user.macroTargets?['protein'] ?? (user.dailyCaloricGoal ~/ 8),
          carbsConsumed: log.carbs + foodCarbs,
          carbsGoal:
              user.macroTargets?['carbs'] ?? (user.dailyCaloricGoal ~/ 2),
          fatConsumed: log.fat + foodFat,
          fatGoal: user.macroTargets?['fat'] ?? (user.dailyCaloricGoal ~/ 4),
          stepsTaken: log.stepsCount,
          stepsGoal: settings.stepGoal,
          sleepMinutes: log.sleepMinutes,
          restingHR: log.restingHeartRate,
          workoutCalories: log.workoutCalories,
          workoutDurationMinutes: log.workoutDurationMinutes,
          workoutType: log.workoutType,
          waterOz: log.waterIntake,
          tdee: todayTDEE,
          firstMealTime: firstMeal,
          lastMealTime: lastMeal,
          hrv: log.hrv,
          mindfulnessMinutes: log.mindfulnessMinutes,
        );
      } else {
        _cachedData[_selectedDate] = DashboardDayData(
          caloriesConsumed: foodCalories,
          caloriesGoal: user.dailyCaloricGoal,
          proteinConsumed: foodProtein,
          proteinGoal:
              user.macroTargets?['protein'] ?? (user.dailyCaloricGoal ~/ 8),
          carbsConsumed: foodCarbs,
          carbsGoal:
              user.macroTargets?['carbs'] ?? (user.dailyCaloricGoal ~/ 2),
          fatConsumed: foodFat,
          fatGoal: user.macroTargets?['fat'] ?? (user.dailyCaloricGoal ~/ 4),
          stepsTaken: 0,
          stepsGoal: settings.stepGoal,
          firstMealTime: firstMeal,
          lastMealTime: lastMeal,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DashboardDayData _defaultDataFor(DateTime date) {
    // Return zero values if not in cache
    return const DashboardDayData(
      caloriesConsumed: 0,
      caloriesGoal: 2000,
      proteinConsumed: 0,
      proteinGoal: 150,
      carbsConsumed: 0,
      carbsGoal: 200,
      fatConsumed: 0,
      fatGoal: 65,
      stepsTaken: 0,
      stepsGoal: 8000,
    );
  }
}
