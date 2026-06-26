import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Category ─────────────────────────────────────────────────────────────────

enum DashWidgetCategory { performance, nutrition, body, recovery, activity }

extension DashWidgetCategoryX on DashWidgetCategory {
  String get label {
    switch (this) {
      case DashWidgetCategory.performance:
        return 'Performance';
      case DashWidgetCategory.nutrition:
        return 'Nutrition';
      case DashWidgetCategory.body:
        return 'Body';
      case DashWidgetCategory.recovery:
        return 'Recovery';
      case DashWidgetCategory.activity:
        return 'Activity';
    }
  }

  IconData get icon {
    switch (this) {
      case DashWidgetCategory.performance:
        return Icons.speed_outlined;
      case DashWidgetCategory.nutrition:
        return Icons.restaurant_outlined;
      case DashWidgetCategory.body:
        return Icons.monitor_weight_outlined;
      case DashWidgetCategory.recovery:
        return Icons.bedtime_outlined;
      case DashWidgetCategory.activity:
        return Icons.directions_run_outlined;
    }
  }

  Color get color {
    switch (this) {
      case DashWidgetCategory.performance:
        return const Color(0xFF4C7FA8);
      case DashWidgetCategory.nutrition:
        return const Color(0xFF2E8B57);
      case DashWidgetCategory.body:
        return const Color(0xFF8B5CF6);
      case DashWidgetCategory.recovery:
        return const Color(0xFF0EA5E9);
      case DashWidgetCategory.activity:
        return const Color(0xFFEF8C2E);
    }
  }
}

// ─── Widget Info ──────────────────────────────────────────────────────────────

class DashWidgetInfo {
  final String id;
  final String name;
  final IconData icon;
  final String description;
  final DashWidgetCategory category;

  const DashWidgetInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.category,
  });
}

// ─── Widget Size ─────────────────────────────────────────────────────────────

enum DashWidgetSize { compact, full }

// ─── Provider ─────────────────────────────────────────────────────────────────

class DashboardLayoutProvider extends ChangeNotifier {
  static const String _prefsKey = 'dashboard_active_widget_ids_v2';

  static const List<String> kDefaultActiveIds = [
    'calorie_balance',
    'macros',
    'goal_projection',
    'weekly_deficit',
    'steps',
    'water_intake',
    'sleep_score',
    'workout_performance',
  ];

  static const List<DashWidgetInfo> catalog = [
    // ── Performance ───────────────────────────────────────────────────────────
    DashWidgetInfo(
      id: 'calorie_balance',
      name: 'Calorie Balance',
      icon: Icons.bolt_outlined,
      description:
          'Calories consumed vs. burned — your real-time energy delta.',
      category: DashWidgetCategory.performance,
    ),
    DashWidgetInfo(
      id: 'tdee',
      name: 'Energy Output (TDEE)',
      icon: Icons.local_fire_department_outlined,
      description:
          'Total daily energy expenditure with its 7-day average and trend.',
      category: DashWidgetCategory.performance,
    ),
    DashWidgetInfo(
      id: 'weekly_deficit',
      name: 'Weekly Deficit',
      icon: Icons.trending_down_outlined,
      description: '7-day cumulative calorie deficit or surplus.',
      category: DashWidgetCategory.performance,
    ),
    DashWidgetInfo(
      id: 'goal_projection',
      name: 'Goal Projection',
      icon: Icons.flag_outlined,
      description:
          "Projected date you'll reach your goal weight at your current pace.",
      category: DashWidgetCategory.performance,
    ),
    // ── Nutrition ─────────────────────────────────────────────────────────────
    DashWidgetInfo(
      id: 'macros',
      name: 'Macros Breakdown',
      icon: Icons.pie_chart_outline,
      description: 'Protein, carbs, and fat split for the current day.',
      category: DashWidgetCategory.nutrition,
    ),
    DashWidgetInfo(
      id: 'water_intake',
      name: 'Water Intake',
      icon: Icons.water_drop_outlined,
      description: 'Hydration progress toward your daily fluid goal.',
      category: DashWidgetCategory.nutrition,
    ),
    DashWidgetInfo(
      id: 'meal_timing',
      name: 'Meal Timing',
      icon: Icons.schedule_outlined,
      description: 'First and last meal windows — eating pattern at a glance.',
      category: DashWidgetCategory.nutrition,
    ),
    DashWidgetInfo(
      id: 'fiber',
      name: 'Fiber & Micronutrients',
      icon: Icons.grass_outlined,
      description: 'Fiber intake and key micronutrient tracking.',
      category: DashWidgetCategory.nutrition,
    ),
    // ── Body ──────────────────────────────────────────────────────────────────
    DashWidgetInfo(
      id: 'weight',
      name: 'Weight',
      icon: Icons.monitor_weight_outlined,
      description: 'Current logged weight with delta from your last entry.',
      category: DashWidgetCategory.body,
    ),
    DashWidgetInfo(
      id: 'measurements',
      name: 'Body Measurements',
      icon: Icons.straighten_outlined,
      description: 'Key circumference measurements tracked over time.',
      category: DashWidgetCategory.body,
    ),
    DashWidgetInfo(
      id: 'body_composition',
      name: 'Body Composition',
      icon: Icons.accessibility_new_outlined,
      description: 'Estimated lean mass vs. body fat percentage.',
      category: DashWidgetCategory.body,
    ),
    DashWidgetInfo(
      id: 'resting_hr',
      name: 'Resting Heart Rate',
      icon: Icons.favorite_outline,
      description: 'RHR trend — a reliable proxy for cardiovascular fitness.',
      category: DashWidgetCategory.body,
    ),
    // ── Recovery ──────────────────────────────────────────────────────────────
    DashWidgetInfo(
      id: 'sleep_score',
      name: 'Sleep Score',
      icon: Icons.bedtime_outlined,
      description:
          'Quality score from duration, consistency & REM cycles. '
          'Sleep drives cortisol, HGH, and insulin sensitivity.',
      category: DashWidgetCategory.recovery,
    ),
    DashWidgetInfo(
      id: 'recovery_index',
      name: 'Recovery Index',
      icon: Icons.battery_charging_full_outlined,
      description:
          'Composite readiness score — sleep, HRV, and stress combined.',
      category: DashWidgetCategory.recovery,
    ),
    DashWidgetInfo(
      id: 'stress_level',
      name: 'Stress Level',
      icon: Icons.self_improvement_outlined,
      description:
          'Logged or inferred stress. Chronic stress elevates cortisol '
          'and promotes visceral fat storage.',
      category: DashWidgetCategory.recovery,
    ),
    DashWidgetInfo(
      id: 'mindfulness',
      name: 'Mindfulness Streak',
      icon: Icons.spa_outlined,
      description: 'Consecutive days of mindfulness or meditation logged.',
      category: DashWidgetCategory.recovery,
    ),
    // ── Activity ──────────────────────────────────────────────────────────────
    DashWidgetInfo(
      id: 'steps',
      name: 'Steps Today',
      icon: Icons.directions_walk_outlined,
      description: 'Step count progress toward your daily movement target.',
      category: DashWidgetCategory.activity,
    ),
    DashWidgetInfo(
      id: 'workout_performance',
      name: 'Workout Performance',
      icon: Icons.fitness_center_outlined,
      description: 'Volume, intensity, and output from your last session.',
      category: DashWidgetCategory.activity,
    ),
    DashWidgetInfo(
      id: 'workout_consistency',
      name: 'Workout Consistency',
      icon: Icons.event_available_outlined,
      description:
          'Active days this week plus your current consecutive-day streak.',
      category: DashWidgetCategory.activity,
    ),
  ];

  /// Maps widget IDs that were removed/merged in the de-duplication pass to the
  /// surviving widget that now covers their information. IDs mapping to `null`
  /// are dropped entirely. Applied to persisted layouts on load so existing
  /// users never see a blank tile for a retired widget.
  static const Map<String, String?> _migratedIds = {
    'calories': 'calorie_balance',
    'weight_trend': 'weight',
    'active_calories': 'workout_performance',
    'goal_pace': 'weekly_deficit',
    'metabolic_trend': 'tdee',
    'movement_streak': 'workout_consistency',
    'today_summary': null,
  };

  /// Rewrites a persisted ID list through [_migratedIds], dropping nulls and
  /// de-duplicating while preserving order.
  static List<String> _migrateIds(List<String> ids) {
    final result = <String>[];
    for (final id in ids) {
      final mapped = _migratedIds.containsKey(id) ? _migratedIds[id] : id;
      if (mapped != null && !result.contains(mapped)) result.add(mapped);
    }
    return result;
  }

  List<String> _activeIds = List.from(kDefaultActiveIds);

  List<String> get activeIds => List.unmodifiable(_activeIds);

  bool isActive(String id) => _activeIds.contains(id);

  DashWidgetInfo? infoFor(String id) {
    try {
      return catalog.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Sizes ────────────────────────────────────────────────────────────────
  static const String _sizesKey = 'dashboard_widget_sizes_v1';
  Map<String, DashWidgetSize> _widgetSizes = {};

  DashWidgetSize sizeOf(String id) => _widgetSizes[id] ?? DashWidgetSize.full;

  Future<void> setSize(String id, DashWidgetSize size) async {
    _widgetSizes[id] = size;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {for (final e in _widgetSizes.entries) e.key: e.value.name};
      await prefs.setString(_sizesKey, jsonEncode(map));
    } catch (_) {}
    notifyListeners();
  }

  DashboardLayoutProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null) {
        final list = _migrateIds((jsonDecode(json) as List).cast<String>());
        if (list.isNotEmpty) _activeIds = list;
      }
      final sizesJson = prefs.getString(_sizesKey);
      if (sizesJson != null) {
        final map = jsonDecode(sizesJson) as Map<String, dynamic>;
        final migrated = <String, DashWidgetSize>{};
        for (final e in map.entries) {
          final key = _migratedIds.containsKey(e.key)
              ? _migratedIds[e.key]
              : e.key;
          if (key == null) continue;
          migrated[key] = e.value == 'compact'
              ? DashWidgetSize.compact
              : DashWidgetSize.full;
        }
        _widgetSizes = migrated;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> commit(List<String> newIds) async {
    _activeIds = _migrateIds(List.from(newIds));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_activeIds));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> resetToDefaults() => commit(kDefaultActiveIds);
}
