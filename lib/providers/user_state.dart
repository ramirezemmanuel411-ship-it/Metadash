import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/daily_log.dart';
import '../models/metabolic_settings.dart';
import '../models/data_inputs_settings.dart';
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserState extends ChangeNotifier {
  UserProfile? _currentUser;
  DailyLog? _currentDayLog;
  MetabolicSettings _metabolicSettings = MetabolicSettings.defaults();
  DataInputsSettings? _dataInputsSettings;
  final DatabaseService _db = DatabaseService();

  UserProfile? get currentUser => _currentUser;
  DailyLog? get currentDayLog => _currentDayLog;
  MetabolicSettings get metabolicSettings => _metabolicSettings;
  DataInputsSettings? get dataInputsSettings => _dataInputsSettings;
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
    Map<String, int>? macroTargets,
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
      macroTargets: macroTargets,
    );

    final id = await _db.createUserProfile(user);
    final createdUser = user.copyWith(id: id.toInt());
    _currentUser = createdUser;
    notifyListeners();

    try {
      var uid = FirebaseAuth.instance.currentUser?.uid;
      uid ??= (await FirebaseAuth.instance.signInAnonymously()).user?.uid;
      final analyticsUserId = uid ?? createdUser.id.toString();
      await FirebaseAnalytics.instance.setUserId(id: analyticsUserId);
      await FirebaseAnalytics.instance.logEvent(
        name: 'create_user',
        parameters: {
          'gender': createdUser.gender,
          'activity_level': createdUser.activityLevel,
        },
      );

      final userDocId = uid ?? createdUser.id.toString();
      await FirebaseFirestore.instance.collection('users').doc(userDocId).set({
        'localUserId': createdUser.id,
        'name': createdUser.name,
        'email': createdUser.email,
        'weight': createdUser.weight,
        'height': createdUser.height,
        'age': createdUser.age,
        'gender': createdUser.gender,
        'dateOfBirth': createdUser.dateOfBirth.toIso8601String(),
        'bmr': createdUser.bmr,
        'goalWeight': createdUser.goalWeight,
        'dailyCaloricGoal': createdUser.dailyCaloricGoal,
        'activityLevel': createdUser.activityLevel,
        'dailyStepsGoal': createdUser.dailyStepsGoal,
        'macroTargets': createdUser.macroTargets,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase create_user sync failed: $e');
    }

    return createdUser;
  }

  // Login with a user
  Future<bool> loginUser(int userId) async {
    final user = await _db.getUserProfileById(userId);
    if (user != null) {
      _currentUser = user;
      await _loadMetabolicSettings();
      await _loadDataInputsSettings();
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

  // Update metabolic settings
  Future<void> updateMetabolicSettings(MetabolicSettings settings) async {
    _metabolicSettings = settings;
    await _saveMetabolicSettings();
    notifyListeners();
  }

  // Load metabolic settings from SharedPreferences
  Future<void> _loadMetabolicSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('metabolic_settings');
      if (settingsJson != null) {
        final json = jsonDecode(settingsJson) as Map<String, dynamic>;
        _metabolicSettings = MetabolicSettings.fromJson(json);
      }
    } catch (e) {
      // If loading fails, use defaults
      _metabolicSettings = MetabolicSettings.defaults();
    }
  }

  Future<void> _loadDataInputsSettings() async {
    if (_currentUser == null) return;
    try {
      final defaults = DataInputsSettings.defaults(_currentUser!.id!);
      final resolved = (await _db.getDataInputsSettings(_currentUser!.id!)) ?? defaults;
      await _db.createOrUpdateDataInputsSettings(resolved);
      _dataInputsSettings = resolved;
    } catch (_) {
      _dataInputsSettings = null;
    }
  }

  Future<void> refreshDataInputsSettings() async {
    await _loadDataInputsSettings();
    notifyListeners();
  }

  // Save metabolic settings to SharedPreferences
  Future<void> _saveMetabolicSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_metabolicSettings.toJson());
      await prefs.setString('metabolic_settings', settingsJson);
    } catch (e) {
      debugPrint('Failed to save metabolic settings: $e');
    }
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

    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'save_daily_log',
        parameters: {
          'calories': caloriesConsumed,
          'steps': stepsCount,
        },
      );

      var uid = FirebaseAuth.instance.currentUser?.uid;
      uid ??= (await FirebaseAuth.instance.signInAnonymously()).user?.uid;

      final dailyLogData = {
        'userId': _currentUser!.id,
        'firebaseUid': uid,
        'date': dateOnly.toIso8601String(),
        'caloriesConsumed': caloriesConsumed,
        'stepsCount': stepsCount,
        'waterIntake': waterIntake,
        'workoutActivities': workoutActivities,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('daily_logs')
            .doc(dateOnly.toIso8601String())
            .set(dailyLogData, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance
            .collection('daily_logs')
            .doc('${_currentUser!.id}_${dateOnly.toIso8601String()}')
            .set(dailyLogData, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Firebase save_daily_log sync failed: $e');
    }
  }

  // Get all users
  Future<List<UserProfile>> getAllUsers() async {
    return _db.getAllUserProfiles();
  }

  Future<bool> deleteUserByEmail(String email) async {
    final user = await _db.getUserProfileByEmail(email);
    if (user == null) return false;
    await _db.deleteUserProfile(user.id!);
    if (_currentUser?.id == user.id) {
      logout();
    }
    return true;
  }

  // Get recent daily logs with weight data for adaptive TDEE
  Future<List<DailyLog>> getRecentLogsWithWeight(int days) async {
    if (_currentUser == null) return [];
    
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));
    
    final allLogs = await _db.getDailyLogsByUserAndDateRange(
      _currentUser!.id!,
      startDate,
      endDate,
    );
    
    // Filter to only logs with weight data
    return allLogs.where((log) => log.weight != null).toList();
  }
}
