import 'package:flutter/foundation.dart';
import '../../shared/date_utils.dart';
import '../../providers/user_state.dart';

class DashboardDayData {
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int carbsConsumed;
  final int fatConsumed;
  final int stepsTaken;
  final int stepsGoal;

  const DashboardDayData({
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.carbsConsumed,
    required this.fatConsumed,
    required this.stepsTaken,
    required this.stepsGoal,
  });
}

class DashboardState extends ChangeNotifier {
  DashboardState({
    DateTime? initialDate,
    this.userState,
  }) : _selectedDate = AppDateUtils.normalizeDate(initialDate ?? DateTime.now()) {
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
      final log = await userState!.db.getDailyLogByUserAndDate(user.id!, _selectedDate);
      final foodEntryMaps = await userState!.db.getFoodEntriesForDay(user.id!, _selectedDate);

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

      if (log != null) {
        _cachedData[_selectedDate] = DashboardDayData(
          caloriesConsumed: log.caloriesConsumed + foodCalories,
          caloriesGoal: user.dailyCaloricGoal,
          proteinConsumed: log.protein + foodProtein,
          carbsConsumed: log.carbs + foodCarbs,
          fatConsumed: log.fat + foodFat,
          stepsTaken: log.stepsCount,
          stepsGoal: user.dailyStepsGoal,
        );
      } else {
        _cachedData[_selectedDate] = DashboardDayData(
          caloriesConsumed: foodCalories,
          caloriesGoal: user.dailyCaloricGoal,
          proteinConsumed: foodProtein,
          carbsConsumed: foodCarbs,
          fatConsumed: foodFat,
          stepsTaken: 0,
          stepsGoal: user.dailyStepsGoal,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DashboardDayData _defaultDataFor(DateTime date) {
    // Return zero values if not in cache
    return DashboardDayData(
      caloriesConsumed: 0,
      caloriesGoal: 2200,
      proteinConsumed: 0,
      carbsConsumed: 0,
      fatConsumed: 0,
      stepsTaken: 0,
      stepsGoal: 8000,
    );
  }
}
