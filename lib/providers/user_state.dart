import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/daily_log.dart';
import '../services/database_service.dart';

class UserState extends ChangeNotifier {
  UserProfile? _currentUser;
  DailyLog? _currentDayLog;
  final DatabaseService _db = DatabaseService();

  UserProfile? get currentUser => _currentUser;
  DailyLog? get currentDayLog => _currentDayLog;
  DatabaseService get db => _db;

  bool get isLoggedIn => _currentUser != null;

  // Create a new user
  Future<UserProfile> createUser({
    required String name,
    required String email,
    required double weight,
    required double height,
    required int age,
    required String gender,
    required DateTime dateOfBirth,
    required double bmr,
    required double goalWeight,
    required int dailyCaloricGoal,
    required String activityLevel,
    required int dailyStepsGoal,
  }) async {
    final now = DateTime.now();
    final user = UserProfile(
      name: name,
      email: email,
      weight: weight,
      height: height,
      age: age,
      gender: gender,
      dateOfBirth: dateOfBirth,
      bmr: bmr,
      goalWeight: goalWeight,
      dailyCaloricGoal: dailyCaloricGoal,
      activityLevel: activityLevel,
      dailyStepsGoal: dailyStepsGoal,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _db.createUserProfile(user);
    final createdUser = user.copyWith(id: id.toInt());
    _currentUser = createdUser;
    notifyListeners();
    return createdUser;
  }

  // Login with a user
  Future<bool> loginUser(int userId) async {
    final user = await _db.getUserProfileById(userId);
    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }

  // Logout current user
  void logout() {
    _currentUser = null;
    _currentDayLog = null;
    notifyListeners();
  }

  // Update current user profile
  Future<void> updateCurrentUser(UserProfile updated) async {
    await _db.updateUserProfile(updated);
    _currentUser = updated;
    notifyListeners();
  }

  // Load daily log for a specific date
  Future<void> loadDailyLog(DateTime date) async {
    if (_currentUser == null) return;
    _currentDayLog = await _db.getDailyLogByUserAndDate(_currentUser!.id!, date);
    notifyListeners();
  }

  // Save or create daily log
  Future<void> saveDailyLog({
    required DateTime date,
    required int caloriesConsumed,
    required int stepsCount,
    required double waterIntake,
    required List<String> workoutActivities,
    required int protein,
    required int carbs,
    required int fat,
  }) async {
    if (_currentUser == null) return;

    final now = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);

    var log = DailyLog(
      id: _currentDayLog?.id,
      userId: _currentUser!.id!,
      date: dateOnly,
      caloriesConsumed: caloriesConsumed,
      stepsCount: stepsCount,
      waterIntake: waterIntake,
      workoutActivities: workoutActivities,
      protein: protein,
      carbs: carbs,
      fat: fat,
      createdAt: _currentDayLog?.createdAt ?? now,
      updatedAt: now,
    );

    if (_currentDayLog?.id != null) {
      await _db.updateDailyLog(log);
    } else {
      final id = await _db.createDailyLog(log);
      log = log.copyWith(id: id);
    }

    _currentDayLog = log;
    notifyListeners();
  }

  // Get all users
  Future<List<UserProfile>> getAllUsers() async {
    return _db.getAllUserProfiles();
  }
}
