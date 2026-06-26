import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:metadash/core/providers/dashboard_layout_provider.dart';
import 'package:metadash/core/providers/user_state.dart';
import 'package:metadash/core/services/calorie_calculation_service.dart';
import 'package:metadash/core/shared/date_utils.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:metadash/features/dashboard/calorie_progress_ring.dart';
import 'package:metadash/features/dashboard/dashboard_state.dart';
import 'package:metadash/features/dashboard/horizontal_date_wheel_picker.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  final DateTime selectedDay;
  final Function(int) onDayChanged;
  final VoidCallback? onOpenDiary;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int carbsConsumed;
  final int fatConsumed;
  final int stepsTaken;
  final int stepsGoal;
  final UserState? userState;

  const DashboardScreen({
    super.key,
    required this.selectedDay,
    required this.onDayChanged,
    this.onOpenDiary,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.carbsConsumed,
    required this.fatConsumed,
    required this.stepsTaken,
    required this.stepsGoal,
    this.userState,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<double> _weeklyDeficit = List<double>.filled(7, 0);
  List<double> _weeklyTDEE = List<double>.filled(7, 0);
  bool _loadingWeekly = false;
  late final DashboardState _dashboardState;
  DateTime? _lastNotifiedDate;

  @override
  void initState() {
    super.initState();
    _dashboardState = DashboardState(
      initialDate: widget.selectedDay,
      userState: widget.userState,
    );
    _lastNotifiedDate = _dashboardState.selectedDate;
    _dashboardState.addListener(_handleSelectedDateChanged);
    _loadWeeklyDeficit();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.selectedDay, widget.selectedDay)) {
      _dashboardState.setSelectedDateFromExternal(widget.selectedDay);
    }
    if (oldWidget.userState != widget.userState) {
      _loadWeeklyDeficit();
    }
  }

  @override
  void dispose() {
    _dashboardState.removeListener(_handleSelectedDateChanged);
    _dashboardState.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _handleSelectedDateChanged() {
    final selectedDate = _dashboardState.selectedDate;
    if (_lastNotifiedDate != null &&
        AppDateUtils.isSameDay(_lastNotifiedDate!, selectedDate)) {
      return;
    }
    final daysDiff = DateUtils.dateOnly(
      selectedDate,
    ).difference(DateUtils.dateOnly(widget.selectedDay)).inDays;
    if (daysDiff != 0) {
      widget.onDayChanged(daysDiff);
    }
    _lastNotifiedDate = selectedDate;
    _loadWeeklyDeficit();
  }

  Future<void> _loadWeeklyDeficit() async {
    final userState = widget.userState;
    final user = userState?.currentUser;
    if (userState == null || user == null) {
      if (!mounted) return;
      setState(() {
        _weeklyDeficit = List<double>.filled(7, 0);
        _weeklyTDEE = List<double>.filled(7, 0);
      });
      return;
    }

    setState(() => _loadingWeekly = true);

    final settings = userState.metabolicSettings;
    final endDate = DateUtils.dateOnly(_dashboardState.selectedDate);
    final startDate = endDate.subtract(const Duration(days: 6));
    final logs = await userState.db.getDailyLogsByUserAndDateRange(
      user.id!,
      startDate,
      endDate,
    );

    final logByDate = <DateTime, dynamic>{
      for (final log in logs) DateUtils.dateOnly(log.date): log,
    };

    final deficitValues = <double>[];
    final tdeeValues = <double>[];
    for (var i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final log = logByDate[DateUtils.dateOnly(date)];
      if (log != null) {
        final metrics = CalorieCalculationService.calculateDayMetrics(
          user: user,
          log: log,
          settings: settings,
          inputs: userState.dataInputsSettings,
        );
        deficitValues.add(metrics.dailyDeficitSurplus);
        tdeeValues.add(metrics.tdee);
      } else {
        deficitValues.add(0);
        tdeeValues.add(0);
      }
    }

    if (!mounted) return;
    setState(() {
      _weeklyDeficit = deficitValues;
      _weeklyTDEE = tdeeValues;
      _loadingWeekly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _dashboardState,
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.background,
          elevation: 0,
          title: const Text(
            'Dashboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        body: _DashboardBody(
          weeklyDeficit: _weeklyDeficit,
          weeklyTDEE: _weeklyTDEE,
          loadingWeekly: _loadingWeekly,
          onOpenDiary: widget.onOpenDiary,
          greeting: _greeting(),
          userName: widget.userState?.currentUser?.name.split(' ').first,
        ),
      ),
    );
  }
}

// ── _DashboardBody ────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final List<double> weeklyDeficit;
  final List<double> weeklyTDEE;
  final bool loadingWeekly;
  final VoidCallback? onOpenDiary;
  final String greeting;
  final String? userName;

  const _DashboardBody({
    required this.weeklyDeficit,
    required this.weeklyTDEE,
    required this.loadingWeekly,
    this.onOpenDiary,
    required this.greeting,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final layout = context.watch<DashboardLayoutProvider>();
    final state = context.watch<DashboardState>();
    final data = state.selectedData;
    final userWeight = context.read<UserState>().currentUser?.weight ?? 0.0;

    // ── Pre-computed derived values ─────────────────────────────────────────────────
    final profileUser = context.read<UserState>().currentUser;
    double? profileBMI;
    if (profileUser != null &&
        profileUser.weight > 0 &&
        profileUser.height > 0) {
      profileBMI =
          (profileUser.weight / (profileUser.height * profileUser.height)) *
          703;
    }
    int movementStreakDays = 0;
    for (int i = weeklyDeficit.length - 1; i >= 0; i--) {
      if (weeklyDeficit[i] != 0) {
        movementStreakDays++;
      } else {
        break;
      }
    }
    final weekTotalDeficit = weeklyDeficit.fold(0.0, (a, b) => a + b);
    final nonZeroTDEE = weeklyTDEE.where((v) => v > 0).toList();
    final avgWeeklyTDEE = nonZeroTDEE.isNotEmpty
        ? nonZeroTDEE.fold(0.0, (a, b) => a + b) / nonZeroTDEE.length
        : 0.0;

    // Build ordered rows, pairing compact widgets side-by-side
    final rows = <Widget>[];
    final buf = <String>[];
    final seenWidgetIds = <String>{};

    String normalizeWidgetId(String id) {
      if (id == 'calories') return 'calorie_balance';
      if (id == 'weight_trend') return 'weight';
      return id;
    }

    Widget fullCard(String id) {
      switch (id) {
        case 'calorie_balance':
        case 'calories':
          {
            final remaining = data.caloriesGoal - data.caloriesConsumed;
            final isOverGoal = remaining < 0;
            final onPaceThreshold = math.max(75, data.caloriesGoal * 0.05);
            final isOnPace = !isOverGoal && remaining <= onPaceThreshold;
            final statusBadge = isOverGoal
                ? 'Over Goal'
                : isOnPace
                ? 'On Pace'
                : 'In Deficit';
            final statusColor = isOverGoal
                ? const Color(0xFFB03030)
                : Palette.forestGreen;
            return _CalorieBalanceCard(
              onTap: onOpenDiary,
              consumed: data.caloriesConsumed,
              target: data.caloriesGoal,
              statusBadge: statusBadge,
              statusColor: statusColor,
              accentColor: context.colors.accent,
            );
          }
        case 'macros':
          {
            final pPct = data.proteinGoal > 0
                ? (data.proteinConsumed / data.proteinGoal * 100).round()
                : 0;
            final statusText = pPct >= 90
                ? 'Protein on track'
                : pPct >= 60
                ? 'Needs more protein'
                : 'Protein gap';
            return GestureDetector(
              onTap: onOpenDiary,
              child: _CardSection(
                title: 'Macros',
                tintColor: Palette.widgetProteinDay,
                statusBadge: statusText,
                statusColor: pPct >= 90
                    ? Palette.widgetActivityDay
                    : Palette.widgetProteinDay,
                child: _MacrosCard(
                  proteinConsumed: data.proteinConsumed,
                  proteinGoal: data.proteinGoal,
                  carbsConsumed: data.carbsConsumed,
                  carbsGoal: data.carbsGoal,
                  fatConsumed: data.fatConsumed,
                  fatGoal: data.fatGoal,
                ),
              ),
            );
          }
        case 'steps':
          {
            final stepPct = data.stepsGoal > 0
                ? data.stepsTaken / data.stepsGoal
                : 0.0;
            final stepStatus = stepPct >= 1.0
                ? 'Goal reached!'
                : stepPct >= 0.75
                ? 'Almost there'
                : stepPct >= 0.5
                ? 'Halfway'
                : 'Keep moving';
            return _CardSection(
              title: 'Activity',
              tintColor: Palette.widgetStepsDay,
              statusBadge: stepStatus,
              statusColor: stepPct >= 1.0
                  ? Palette.widgetActivityDay
                  : Palette.widgetStepsDay,
              child: _StepsCard(
                stepsTaken: data.stepsTaken,
                stepsGoal: data.stepsGoal,
              ),
            );
          }
        case 'weekly_deficit':
          {
            final weekLbs = weekTotalDeficit / 3500;
            final energyTint = Theme.of(context).brightness == Brightness.dark
                ? Palette.widgetEnergyDay
                : Palette.forestGreen;
            final weekStatus = weekLbs < -0.05
                ? '${weekLbs.abs().toStringAsFixed(2)} lb deficit pace'
                : weekLbs > 0.05
                ? '+${weekLbs.abs().toStringAsFixed(2)} lb surplus pace'
                : 'Maintenance pace';
            return _CardSection(
              title: 'Energy Balance',
              tintColor: energyTint,
              statusBadge: weekLbs < -0.02
                  ? 'In Deficit'
                  : weekLbs > 0.02
                  ? 'In Surplus'
                  : 'Maintenance',
              statusColor: weekLbs < -0.02
                  ? Palette.widgetActivityDay
                  : weekLbs > 0.02
                  ? const Color(0xFFB03030)
                  : energyTint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekStatus,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _WeeklyDeficitChart(
                    dailyDeficit: weeklyDeficit,
                    dailyTDEE: weeklyTDEE,
                    endDate: state.selectedDate,
                    isLoading: loadingWeekly,
                  ),
                ],
              ),
            );
          }
        case 'goal_projection':
          {
            final goalWeight = profileUser?.goalWeight ?? 0;
            final weeklyRateLbs = weekTotalDeficit / 3500;
            final hasGoal = userWeight > 0 && goalWeight > 0;
            final needToLose = userWeight > goalWeight;
            final towardRate = needToLose ? -weeklyRateLbs : weeklyRateLbs;
            final reached = hasGoal && (userWeight - goalWeight).abs() < 0.5;
            final onPace = towardRate > 0.05;
            return _CardSection(
              title: 'Goal Projection',
              tintColor: Palette.widgetTDEEDay,
              statusBadge: !hasGoal
                  ? null
                  : reached
                  ? 'Reached'
                  : onPace
                  ? 'On pace'
                  : 'Off pace',
              statusColor: (reached || onPace)
                  ? Palette.widgetActivityDay
                  : const Color(0xFFB03030),
              child: !hasGoal
                  ? const _EmptyMetricCard(
                      hint: 'Set a goal weight',
                      icon: Icons.flag_outlined,
                      color: Palette.widgetTDEEDay,
                    )
                  : _GoalProjectionCard(
                      currentWeight: userWeight,
                      goalWeight: goalWeight,
                      weeklyChangeLbs: weeklyRateLbs,
                    ),
            );
          }
        case 'water_intake':
          return _CardSection(
            title: 'Water Intake',
            child: _WaterIntakeCard(waterOz: data.waterOz),
          );
        case 'sleep_score':
          return _CardSection(
            title: 'Sleep',
            child: _SleepCard(sleepMinutes: data.sleepMinutes),
          );
        case 'workout_performance':
          return _CardSection(
            title: 'Workout Performance',
            tintColor: const Color(0xFFAA5A10),
            child: _WorkoutPerformanceCard(
              calories: data.workoutCalories,
              durationMinutes: data.workoutDurationMinutes,
              workoutType: data.workoutType,
            ),
          );
        case 'weight':
        case 'weight_trend':
          return _CardSection(
            title: 'Weight',
            tintColor: Palette.widgetWeightDay,
            statusBadge: userWeight > 0 ? 'Logged' : 'Not logged',
            statusColor: userWeight > 0
                ? Palette.widgetWeightDay
                : context.colors.textMuted,
            child: _WeightCard(currentWeight: userWeight),
          );
        case 'tdee':
          {
            final lastTDEE = weeklyTDEE.lastWhere(
              (v) => v > 0,
              orElse: () => 0,
            );
            final delta = avgWeeklyTDEE > 0 ? lastTDEE - avgWeeklyTDEE : 0;
            final hasTrend = avgWeeklyTDEE > 0 && lastTDEE > 0;
            final trendBadge = !hasTrend
                ? (data.tdee != null && data.tdee! > 0 ? 'Active' : 'No data')
                : delta > 50
                ? 'Rising'
                : delta < -50
                ? 'Trending down'
                : 'Stable';
            return _CardSection(
              title: 'Metabolism',
              tintColor: Palette.widgetTDEEDay,
              statusBadge: trendBadge,
              statusColor: Palette.widgetTDEEDay,
              child: _TDEECard(
                tdee: data.tdee,
                avgTDEE: avgWeeklyTDEE,
                weeklyTDEE: weeklyTDEE,
              ),
            );
          }
        case 'resting_hr':
          return _CardSection(
            title: 'Resting Heart Rate',
            child: _RestingHRCard(bpm: data.restingHR),
          );
        case 'body_composition':
          return _CardSection(
            title: 'Body Composition',
            tintColor: const Color(0xFF6B42A0),
            child: _BodyCompositionCard(bmi: profileBMI),
          );
        case 'workout_consistency':
          {
            final activeDaysCount = weeklyTDEE.where((v) => v > 0).length;
            final consistStatus = activeDaysCount >= 6
                ? 'Outstanding'
                : activeDaysCount >= 4
                ? 'Strong week'
                : activeDaysCount >= 2
                ? 'Keep pushing'
                : 'Just getting started';
            return _CardSection(
              title: 'Consistency',
              tintColor: Palette.widgetConsistDay,
              statusBadge: consistStatus,
              statusColor: activeDaysCount >= 4
                  ? Palette.widgetActivityDay
                  : Palette.widgetConsistDay,
              child: _WorkoutConsistencyCard(
                weeklyTDEE: weeklyTDEE,
                streakDays: movementStreakDays,
              ),
            );
          }
        case 'meal_timing':
          {
            final firstMeal = data.firstMealTime;
            final lastMeal = data.lastMealTime;
            return _CardSection(
              title: 'Meal Timing',
              tintColor: const Color(0xFF2E8B57),
              statusBadge: firstMeal != null ? 'Tracking' : null,
              statusColor: const Color(0xFF2E8B57),
              child: (firstMeal == null || lastMeal == null)
                  ? const _EmptyMetricCard(
                      hint: 'No meals logged yet',
                      icon: Icons.schedule_outlined,
                      color: Color(0xFF2E8B57),
                    )
                  : _MealTimingCard(first: firstMeal, last: lastMeal),
            );
          }
        case 'fiber':
          return const _CardSection(
            title: 'Fiber & Micronutrients',
            child: _EmptyMetricCard(
              hint: 'No data yet',
              icon: Icons.grass_outlined,
              color: Color(0xFF2E8B57),
            ),
          );
        case 'measurements':
          return const _CardSection(
            title: 'Body Measurements',
            child: _EmptyMetricCard(
              hint: 'No measurements yet',
              icon: Icons.straighten_outlined,
              color: Color(0xFF8B5CF6),
            ),
          );
        case 'recovery_index':
          {
            final hrv = data.hrv ?? 0;
            if (hrv <= 0) {
              return const _CardSection(
                title: 'Recovery Index',
                tintColor: Color(0xFF0EA5E9),
                child: _EmptyMetricCard(
                  hint: 'Connect Apple Health (HRV)',
                  icon: Icons.battery_charging_full_outlined,
                  color: Color(0xFF0EA5E9),
                ),
              );
            }
            final r = _recoveryScore(hrv, data.sleepMinutes, data.restingHR);
            final sleepH = (data.sleepMinutes ?? 0) / 60;
            return _CardSection(
              title: 'Recovery Index',
              tintColor: const Color(0xFF0EA5E9),
              statusBadge: r.label,
              statusColor: r.color,
              child: _ScoreMetricCard(
                icon: Icons.battery_charging_full_rounded,
                color: r.color,
                score: r.score,
                caption:
                    'HRV ${hrv.round()}ms · ${sleepH.toStringAsFixed(1)}h sleep',
              ),
            );
          }
        case 'stress_level':
          {
            final hrv = data.hrv ?? 0;
            if (hrv <= 0) {
              return const _CardSection(
                title: 'Stress',
                tintColor: Color(0xFF8B5CF6),
                child: _EmptyMetricCard(
                  hint: 'Connect Apple Health (HRV)',
                  icon: Icons.self_improvement_outlined,
                  color: Color(0xFF8B5CF6),
                ),
              );
            }
            final st = _stressScore(hrv, data.restingHR, data.workoutCalories);
            return _CardSection(
              title: 'Stress',
              tintColor: const Color(0xFF8B5CF6),
              statusBadge: st.label,
              statusColor: st.color,
              child: _ScoreMetricCard(
                icon: Icons.self_improvement_rounded,
                color: st.color,
                score: st.score,
                caption:
                    'HRV ${hrv.round()}ms · RHR ${data.restingHR ?? '—'} bpm',
              ),
            );
          }
        case 'mindfulness':
          return const _CardSection(
            title: 'Mindfulness',
            child: _EmptyMetricCard(
              hint: 'No sessions logged',
              icon: Icons.spa_outlined,
              color: Color(0xFF0EA5E9),
            ),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    Widget compactCard(String id) {
      switch (id) {
        case 'calorie_balance':
        case 'calories':
          return _CompactCalorieBalanceCard(
            consumed: data.caloriesConsumed,
            target: data.caloriesGoal,
            accentColor: context.colors.accent,
          );
        case 'macros':
          return _CompactCard(
            title: 'Protein',
            icon: Icons.pie_chart_outline,
            color: Palette.macroProtein,
            value: '${data.proteinConsumed}g',
            subtitle: 'of ${data.proteinGoal}g',
            progress: data.proteinGoal > 0
                ? (data.proteinConsumed / data.proteinGoal).clamp(0, 1)
                : 0,
          );
        case 'steps':
          return _CompactCard(
            title: 'Steps',
            icon: Icons.directions_walk,
            color: const Color(0xFFEF8C2E),
            value: data.stepsTaken >= 1000
                ? '${(data.stepsTaken / 1000).toStringAsFixed(1)}k'
                : '${data.stepsTaken}',
            subtitle: 'of ${data.stepsGoal}',
            progress: data.stepsGoal > 0
                ? (data.stepsTaken / data.stepsGoal).clamp(0, 1)
                : 0,
          );
        case 'water_intake':
          return _CompactCard(
            title: 'Water',
            icon: Icons.water_drop,
            color: const Color(0xFF0EA5E9),
            value: '${data.waterOz.round()}',
            subtitle: 'of 64 oz',
            progress: (data.waterOz / 64).clamp(0.0, 1.0),
          );
        case 'sleep_score':
          {
            final sm = data.sleepMinutes ?? 0;
            return _CompactCard(
              title: 'Sleep',
              icon: Icons.bedtime,
              color: const Color(0xFF0EA5E9),
              value: sm > 0 ? '${sm ~/ 60}h ${sm % 60}m' : '—',
              subtitle: sm > 0 ? 'last night' : 'No data yet',
            );
          }
        case 'workout_performance':
          {
            final wc = data.workoutCalories ?? 0;
            return _CompactCard(
              title: 'Workout',
              icon: Icons.fitness_center,
              color: const Color(0xFFEF8C2E),
              value: wc > 0 ? '$wc' : '—',
              subtitle: wc > 0 ? 'kcal burned' : 'No data yet',
            );
          }
        case 'weight':
        case 'weight_trend':
          return _CompactCard(
            title: 'Weight',
            icon: Icons.monitor_weight_outlined,
            color: const Color(0xFF8B5CF6),
            value: userWeight > 0 ? userWeight.toStringAsFixed(1) : '—',
            subtitle: 'lbs',
          );
        case 'tdee':
          return _CompactCard(
            title: 'TDEE',
            icon: Icons.local_fire_department_outlined,
            color: const Color(0xFF4C7FA8),
            value: data.tdee != null ? '${data.tdee!.round()}' : '—',
            subtitle: 'kcal/day',
          );
        case 'resting_hr':
          return _CompactCard(
            title: 'Resting HR',
            icon: Icons.favorite_outline,
            color: const Color(0xFFD0021B),
            value: data.restingHR != null ? '${data.restingHR}' : '—',
            subtitle: 'bpm',
          );
        case 'body_composition':
          return _CompactCard(
            title: 'BMI',
            icon: Icons.accessibility_new_outlined,
            color: const Color(0xFF8B5CF6),
            value: profileBMI != null ? profileBMI.toStringAsFixed(1) : '—',
            subtitle: 'Body Mass Index',
          );
        case 'workout_consistency':
          return _CompactCard(
            title: 'Consistency',
            icon: Icons.event_available_outlined,
            color: const Color(0xFFEF8C2E),
            value: '${weeklyTDEE.where((v) => v > 0).length}/7',
            subtitle: 'active days',
            progress: weeklyTDEE.where((v) => v > 0).length / 7,
          );
        case 'recovery_index':
          {
            final hrv = data.hrv ?? 0;
            final r = hrv > 0
                ? _recoveryScore(hrv, data.sleepMinutes, data.restingHR)
                : null;
            return _CompactCard(
              title: 'Recovery',
              icon: Icons.battery_charging_full_outlined,
              color: const Color(0xFF0EA5E9),
              value: r != null ? '${r.score}' : '—',
              subtitle: r != null ? r.label : 'No HRV data',
              progress: r != null ? r.score / 100 : null,
            );
          }
        case 'stress_level':
          {
            final hrv = data.hrv ?? 0;
            final st = hrv > 0
                ? _stressScore(hrv, data.restingHR, data.workoutCalories)
                : null;
            return _CompactCard(
              title: 'Stress',
              icon: Icons.self_improvement_outlined,
              color: const Color(0xFF8B5CF6),
              value: st != null ? '${st.score}' : '—',
              subtitle: st != null ? st.label : 'No HRV data',
              progress: st != null ? st.score / 100 : null,
            );
          }
        case 'goal_projection':
          {
            final goalWeight = profileUser?.goalWeight ?? 0;
            final has = userWeight > 0 && goalWeight > 0;
            final remaining = (userWeight - goalWeight).abs();
            return _CompactCard(
              title: 'Goal',
              icon: Icons.flag_outlined,
              color: Palette.widgetTDEEDay,
              value: has ? remaining.toStringAsFixed(1) : '—',
              subtitle: has ? 'lb to goal' : 'Set a goal',
            );
          }
        case 'meal_timing':
          {
            final firstMeal = data.firstMealTime;
            return _CompactCard(
              title: 'Meal Timing',
              icon: Icons.schedule_outlined,
              color: const Color(0xFF2E8B57),
              value: firstMeal != null ? _formatTimeOfDay(firstMeal) : '—',
              subtitle: firstMeal != null ? 'first meal' : 'No data yet',
            );
          }
        default:
          final info = DashboardLayoutProvider.catalog.firstWhere(
            (w) => w.id == id,
            orElse: () => DashWidgetInfo(
              id: id,
              name: id,
              icon: Icons.widgets_outlined,
              description: '',
              category: DashWidgetCategory.performance,
            ),
          );
          return _CompactCard(
            title: info.name,
            icon: info.icon,
            color: info.category.color,
            value: '—',
            subtitle: '',
          );
      }
    }

    void flushBuf() {
      if (buf.isEmpty) return;
      if (buf.length == 1) {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: compactCard(buf[0])),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        );
      } else {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: compactCard(buf[0])),
              const SizedBox(width: 12),
              Expanded(child: compactCard(buf[1])),
            ],
          ),
        );
      }
      rows.add(const SizedBox(height: 12));
      buf.clear();
    }

    for (final rawId in layout.activeIds) {
      final id = normalizeWidgetId(rawId);
      if (!seenWidgetIds.add(id)) continue;

      final sz = layout.sizeOf(id);
      if (sz == DashWidgetSize.compact) {
        buf.add(id);
        if (buf.length == 2) flushBuf();
      } else {
        flushBuf();
        final w = fullCard(id);
        if (w is! SizedBox) {
          rows.add(w);
          rows.add(const SizedBox(height: 12));
        }
      }
    }
    flushBuf();
    rows.add(
      _CardSection(
        title: 'Quick Actions',
        tintColor: context.colors.accent,
        child: const _QuickActionsRow(),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: greeting,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.textMuted,
                ),
              ),
              if (userName != null)
                TextSpan(
                  text: ', $userName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        HorizontalDateWheelPicker(
          selectedDate: state.selectedDate,
          onSelectedDateChanged: state.setSelectedDate,
        ),
        const SizedBox(height: 16),
        ...rows,
      ],
    );
  }
}

// ── Premium compact square card ───────────────────────────────────────────────
// Each compact card gets a subtle tinted background derived from its accent
// color, a bold value, a status subtitle, and an optional progress bar.

class _CompactCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String subtitle;
  final double? progress;

  const _CompactCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.subtitle,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isDark ? 0.16 : 0.11),
              colors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.22 : 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.12 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConceptIconTile(color: color, icon: icon, size: 30, iconSize: 16),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (progress != null) ...[
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (progress!).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: color.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 8.5,
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Concept A baseline card ──────────────────────────────────────────────────
// This is the first concrete Meta Dash widget language: calm biometric surface,
// centered data instrument, status pill, and a lower inset metrics panel.

class _CalorieBalanceCard extends StatelessWidget {
  final int consumed;
  final int target;
  final String statusBadge;
  final Color statusColor;
  final Color accentColor;
  final VoidCallback? onTap;

  const _CalorieBalanceCard({
    required this.consumed,
    required this.target,
    required this.statusBadge,
    required this.statusColor,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(target - consumed, 0);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conceptText = colors.textPrimary;
    final conceptSecondary = colors.textSecondary;
    final rimColor = isDark
        ? accentColor.withValues(alpha: 0.22)
        : colors.textMuted.withValues(alpha: 0.16);
    final insetSurface = isDark ? colors.surfaceVariant : colors.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.background, colors.surface],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: rimColor, width: 1.2),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            splashColor: accentColor.withValues(alpha: 0.08),
            highlightColor: accentColor.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _ConceptIconTile(color: accentColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Calorie Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            color: conceptText,
                          ),
                        ),
                      ),
                      _ConceptStatusPill(
                        label: statusBadge,
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CalorieProgressRing(
                    consumed: consumed,
                    target: target,
                    accentColor: accentColor,
                    statusColor: statusColor,
                    textColor: conceptText,
                    secondaryTextColor: conceptSecondary,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      color: insetSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: rimColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ConceptMetric(
                            label: 'Remaining',
                            value: _formatCompactInt(remaining),
                            unit: 'kcal',
                            color: statusColor,
                            textColor: conceptText,
                            secondaryTextColor: conceptSecondary,
                          ),
                        ),
                        Container(width: 1, height: 38, color: rimColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: _ConceptMetric(
                              label: 'Goal',
                              value: _formatCompactInt(target),
                              unit: 'kcal',
                              color: conceptText,
                              textColor: conceptText,
                              secondaryTextColor: conceptSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactCalorieBalanceCard extends StatelessWidget {
  final int consumed;
  final int target;
  final Color accentColor;

  const _CompactCalorieBalanceCard({
    required this.consumed,
    required this.target,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conceptText = colors.textPrimary;
    final conceptSecondary = colors.textSecondary;
    final rim = isDark
        ? accentColor.withValues(alpha: 0.20)
        : colors.textMuted.withValues(alpha: 0.15);

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.background, colors.surface],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: rim),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ConceptIconTile(color: accentColor, size: 32, iconSize: 17),
                const Spacer(),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              _formatCompactInt(consumed),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 0.92,
                color: conceptText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'of ${_formatCompactInt(target)} kcal goal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: conceptSecondary,
              ),
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colors.textMuted.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(accentColor),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'CALORIE BALANCE',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptIconTile extends StatelessWidget {
  final Color color;
  final double size;
  final double iconSize;
  final IconData icon;

  const _ConceptIconTile({
    required this.color,
    this.size = 50,
    this.iconSize = 25,
    this.icon = Icons.local_fire_department_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: 0.44),
              color.withValues(alpha: 0.10),
            ),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _ConceptStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _ConceptStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptMetric extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color textColor;
  final Color secondaryTextColor;

  const _ConceptMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: secondaryTextColor,
          ),
        ),
        const SizedBox(height: 3),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatCompactInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return buffer.toString();
}

String _formatTimeOfDay(DateTime t) {
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h12:${t.minute.toString().padLeft(2, '0')} $ampm';
}

const List<String> _kMonthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatShortDate(DateTime d) {
  final base = '${_kMonthAbbr[d.month - 1]} ${d.day}';
  return d.year == DateTime.now().year ? base : '$base, ${d.year}';
}

// ── Recovery & stress scoring (from Apple Health HRV + sleep + resting HR) ────

double _hrvScore(double hrv) {
  if (hrv >= 70) return 1.0;
  if (hrv >= 50) return 0.8;
  if (hrv >= 35) return 0.6;
  if (hrv >= 20) return 0.4;
  return 0.25;
}

double _rhrScore(int? rhr) {
  if (rhr == null || rhr == 0) return 0.6; // neutral when unknown
  if (rhr < 55) return 1.0;
  if (rhr <= 65) return 0.85;
  if (rhr <= 75) return 0.65;
  if (rhr <= 85) return 0.45;
  return 0.3;
}

/// Readiness: weighted blend of HRV, sleep and resting HR.
({int score, String label, Color color}) _recoveryScore(
  double hrv,
  int? sleepMinutes,
  int? restingHR,
) {
  final sleepScore = ((sleepMinutes ?? 0) / 480).clamp(0.0, 1.0);
  final s =
      0.4 * _hrvScore(hrv) + 0.4 * sleepScore + 0.2 * _rhrScore(restingHR);
  final score = (s * 100).round();
  final label = score >= 80
      ? 'Primed'
      : score >= 60
      ? 'Ready'
      : score >= 40
      ? 'Moderate'
      : 'Strained';
  final color = score >= 60
      ? Palette.widgetActivityDay
      : score >= 40
      ? Palette.widgetWeightDay
      : const Color(0xFFB03030);
  return (score: score, label: label, color: color);
}

/// Physiological strain: low HRV + elevated resting HR + training load.
({int score, String label, Color color}) _stressScore(
  double hrv,
  int? restingHR,
  int? workoutCalories,
) {
  final load = ((workoutCalories ?? 0) / 700).clamp(0.0, 1.0);
  final s =
      0.5 * (1 - _hrvScore(hrv)) +
      0.3 * (1 - _rhrScore(restingHR)) +
      0.2 * load;
  final score = (s * 100).round();
  final label = score >= 70
      ? 'High'
      : score >= 45
      ? 'Elevated'
      : score >= 25
      ? 'Moderate'
      : 'Low';
  final color = score >= 70
      ? const Color(0xFFB03030)
      : score >= 45
      ? Palette.widgetWeightDay
      : Palette.widgetActivityDay;
  return (score: score, label: label, color: color);
}

/// A 0–100 score widget with an icon tile, value, progress bar and caption.
class _ScoreMetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int score;
  final String caption;
  const _ScoreMetricCard({
    required this.icon,
    required this.color,
    required this.score,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        _ConceptIconTile(color: color, icon: icon, size: 46, iconSize: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    ' /100',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (score / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                caption,
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Projects the date the user reaches their goal weight at the current weekly
/// pace (derived from the rolling 7-day calorie deficit/surplus).
class _GoalProjectionCard extends StatelessWidget {
  final double currentWeight;
  final double goalWeight;
  final double weeklyChangeLbs; // signed; negative = losing weight
  const _GoalProjectionCard({
    required this.currentWeight,
    required this.goalWeight,
    required this.weeklyChangeLbs,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const tint = Palette.widgetTDEEDay;
    final needToLose = currentWeight > goalWeight;
    final remaining = (currentWeight - goalWeight).abs();
    final towardRate = needToLose ? -weeklyChangeLbs : weeklyChangeLbs;
    final reached = remaining < 0.5;
    final onPace = towardRate > 0.05;

    String headline;
    String sub;
    if (reached) {
      headline = 'Reached';
      sub = "You're at your goal weight";
    } else if (!onPace) {
      headline = '${remaining.toStringAsFixed(1)} lb to go';
      sub = needToLose
          ? 'Not in a deficit this week'
          : 'Not in a surplus this week';
    } else {
      final weeks = remaining / towardRate;
      if (weeks > 104) {
        headline = '2+ yrs';
        sub =
            '${remaining.toStringAsFixed(1)} lb · ${towardRate.toStringAsFixed(1)} lb/wk';
      } else {
        final date = DateTime.now().add(Duration(days: (weeks * 7).round()));
        headline = _formatShortDate(date);
        sub =
            '${remaining.toStringAsFixed(1)} lb to go · ${towardRate.toStringAsFixed(1)} lb/wk';
      }
    }

    return Row(
      children: [
        const _ConceptIconTile(
          color: tint,
          icon: Icons.flag_rounded,
          size: 46,
          iconSize: 24,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ],
          ),
        ),
        Text(
          '${goalWeight.toStringAsFixed(0)} lb',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: tint,
          ),
        ),
      ],
    );
  }
}

/// Meal timing widget — eating window between the first and last logged meal,
/// derived from the day's food entries.
class _MealTimingCard extends StatelessWidget {
  final DateTime first;
  final DateTime last;
  const _MealTimingCard({required this.first, required this.last});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final single = !last.isAfter(first);
    final window = last.difference(first);
    final wH = window.inHours;
    final wM = window.inMinutes % 60;
    return Row(
      children: [
        const _ConceptIconTile(
          color: Color(0xFF2E8B57),
          icon: Icons.schedule_rounded,
          size: 46,
          iconSize: 24,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                single ? _formatTimeOfDay(first) : '${wH}h ${wM}m',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                single
                    ? 'First meal logged'
                    : '${_formatTimeOfDay(first)} – ${_formatTimeOfDay(last)}',
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ],
          ),
        ),
        if (!single)
          Text(
            'window',
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
      ],
    );
  }
}

// ── Tinted full-width card section ───────────────────────────────────────────
// Used for all named full-width dashboard widgets.
// When [tintColor] is provided, the card uses a subtle tinted background
// instead of the plain surface color.

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? tintColor;
  final String? statusBadge;
  final Color? statusColor;

  const _CardSection({
    required this.title,
    required this.child,
    this.tintColor,
    this.statusBadge,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = tintColor;
    final surface = context.colors.surface;
    final borderColor = tc != null
        ? tc.withValues(alpha: isDark ? 0.20 : 0.14)
        : context.colors.divider;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tc != null
              ? [tc.withValues(alpha: isDark ? 0.16 : 0.11), surface]
              : [surface, surface],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          if (tc != null)
            BoxShadow(
              color: tc.withValues(alpha: isDark ? 0.10 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: tc ?? context.colors.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              if (statusBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (statusColor ?? context.colors.accent).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusBadge!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor ?? context.colors.accent,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  final int stepsTaken;
  final int stepsGoal;

  const _StepsCard({required this.stepsTaken, required this.stepsGoal});

  @override
  Widget build(BuildContext context) {
    const tint = Palette.widgetStepsDay;
    final progress = stepsGoal > 0
        ? (stepsTaken / stepsGoal).clamp(0.0, 1.0)
        : 0.0;
    final isGoalMet = stepsTaken >= stepsGoal && stepsGoal > 0;
    final stepsStr = stepsTaken >= 1000
        ? '${(stepsTaken / 1000).toStringAsFixed(1)}k'
        : '$stepsTaken';
    final statusStr = isGoalMet
        ? 'Goal reached!'
        : stepsGoal > 0
        ? '${((1 - progress) * stepsGoal).round().toString()} steps to go'
        : 'No goal set';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _ConceptIconTile(
              color: tint,
              icon: Icons.directions_walk_rounded,
              size: 46,
              iconSize: 24,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: stepsStr,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                          height: 1.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text: '  steps',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  statusStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isGoalMet ? tint : context.colors.textMuted,
                    fontWeight: isGoalMet ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (stepsGoal > 0)
              Text(
                'Goal: ${stepsGoal >= 1000 ? '${(stepsGoal / 1000).toStringAsFixed(0)}k' : '$stepsGoal'}',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: tint.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(
              isGoalMet ? tint : tint.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyDeficitChart extends StatelessWidget {
  final List<double> dailyDeficit; // negative = deficit, positive = surplus
  final List<double> dailyTDEE; // TDEE for each day
  final DateTime endDate;
  final bool isLoading;

  const _WeeklyDeficitChart({
    required this.dailyDeficit,
    required this.dailyTDEE,
    required this.endDate,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final values = dailyDeficit.length == 7
        ? dailyDeficit
        : List<double>.filled(7, 0);
    final tdeeValues = dailyTDEE.length == 7
        ? dailyTDEE
        : List<double>.filled(7, 0);
    final maxAbs = values
        .map((v) => v.abs())
        .fold(0.0, (a, b) => math.max(a, b));
    final maxTDEE = tdeeValues.fold(0.0, (a, b) => math.max(a, b));
    final safeMax = math.max(maxAbs, maxTDEE);
    final safeMaxVal = safeMax == 0 ? 1.0 : safeMax;
    final startDate = DateUtils.dateOnly(
      endDate,
    ).subtract(const Duration(days: 6));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 32,
              right: 8,
              top: 8,
              bottom: 24,
            ),
            child: CustomPaint(
              painter: _ComboChartPainter(
                deficitValues: values,
                tdeeValues: tdeeValues,
                maxValue: safeMaxVal,
                startDate: startDate,
                labelColor: context.colors.textSecondary,
                gridLineColor: context.colors.divider,
                axisColor: context.colors.textSecondary,
                centerLineColor: context.colors.divider,
                deficitColor: context.colors.accent,
                surplusColor: Theme.of(context).colorScheme.error,
                avgLineColor: context.colors.accent,
              ),
              child: Container(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _LegendDot(color: context.colors.accent, label: 'Deficit'),
            const SizedBox(width: 12),
            _LegendDot(
              color: Theme.of(context).colorScheme.error,
              label: 'Surplus',
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 2, color: context.colors.accent),
                const SizedBox(width: 6),
                Text(
                  'Avg TDEE',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ComboChartPainter extends CustomPainter {
  final List<double> deficitValues;
  final List<double> tdeeValues;
  final double maxValue;
  final DateTime startDate;
  final Color labelColor;
  final Color gridLineColor;
  final Color axisColor;
  final Color centerLineColor;
  final Color deficitColor;
  final Color surplusColor;
  final Color avgLineColor;

  _ComboChartPainter({
    required this.deficitValues,
    required this.tdeeValues,
    required this.maxValue,
    required this.startDate,
    required this.labelColor,
    required this.gridLineColor,
    required this.axisColor,
    required this.centerLineColor,
    required this.deficitColor,
    required this.surplusColor,
    required this.avgLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (deficitValues.isEmpty) return;

    final chartHeight = size.height * 0.85;
    const chartTop = 0.0;
    final chartBottom = chartHeight;
    final chartRight = size.width;
    const barWidth = 10.0;
    const spacing = 28.0;

    // Draw Y-axis labels
    const tickCount = 5;
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= tickCount; i++) {
      final factor = i / tickCount;
      final value = maxValue * (1 - factor);
      final y = chartTop + (chartHeight * factor);

      labelPaint.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: TextStyle(fontSize: 8, color: labelColor),
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(-labelPaint.width - 4, y - labelPaint.height / 2),
      );

      // Draw horizontal grid line
      canvas.drawLine(
        Offset(0, y),
        Offset(chartRight, y),
        Paint()
          ..color = gridLineColor
          ..strokeWidth = 0.5,
      );
    }

    // Draw Y-axis
    canvas.drawLine(
      const Offset(0, chartTop),
      Offset(0, chartBottom),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );

    // Draw center line
    canvas.drawLine(
      Offset(0, chartHeight / 2),
      Offset(chartRight, chartHeight / 2),
      Paint()
        ..color = centerLineColor
        ..strokeWidth = 1,
    );

    // Draw bars for deficit/surplus
    for (var i = 0; i < deficitValues.length; i++) {
      final value = deficitValues[i];
      final x = (spacing * i) + spacing / 2;

      if (value > 0) {
        // Surplus (red, top)
        final factor = (value / maxValue).clamp(0.0, 1.0);
        final barHeight = (chartHeight / 2) * factor;
        final rect = Rect.fromLTWH(
          x - barWidth / 2,
          (chartHeight / 2) - barHeight,
          barWidth,
          barHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = surplusColor,
        );
      } else if (value < 0) {
        // Deficit (green, bottom)
        final factor = (value.abs() / maxValue).clamp(0.0, 1.0);
        final barHeight = (chartHeight / 2) * factor;
        final rect = Rect.fromLTWH(
          x - barWidth / 2,
          chartHeight / 2,
          barWidth,
          barHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = deficitColor,
        );
      }
    }

    // Draw dashed line for average TDEE
    final avgTDEE = tdeeValues.fold(0.0, (a, b) => a + b) / 7;
    final avgFactor = (avgTDEE / maxValue).clamp(0.0, 1.0);
    final lineY =
        chartTop + (chartHeight * 0.5) - (chartHeight * avgFactor * 0.5);

    _drawDashedLine(
      canvas,
      Offset(0, lineY),
      Offset(chartRight, lineY),
      color: avgLineColor,
      strokeWidth: 2,
    );

    // Draw weekday labels
    for (var i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final label = _weekdayLabel(date.weekday);
      final x = (spacing * i) + spacing / 2;

      labelPaint.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10,
          color: labelColor,
          fontWeight: FontWeight.w500,
        ),
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(x - labelPaint.width / 2, chartBottom + 6),
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end, {
    double dashWidth = 4,
    double dashSpace = 2,
    required Color color,
    double strokeWidth = 1,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final steps = (distance / (dashWidth + dashSpace)).ceil();

    for (int i = 0; i < steps; i++) {
      final t1 = (i * (dashWidth + dashSpace)) / distance;
      final t2 = ((i * (dashWidth + dashSpace)) + dashWidth) / distance;

      final p1 = Offset(start.dx + dx * t1, start.dy + dy * t1);
      final p2 = Offset(
        start.dx + dx * t2.clamp(0, 1),
        start.dy + dy * t2.clamp(0, 1),
      );

      canvas.drawLine(p1, p2, paint);
    }
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'T';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'S';
    }
    return '';
  }

  @override
  bool shouldRepaint(_ComboChartPainter oldDelegate) =>
      oldDelegate.deficitValues != deficitValues ||
      oldDelegate.tdeeValues != tdeeValues;
}

/// Polished empty state for a widget that has no data yet — shows the widget's
/// gradient icon tile, a dash placeholder, and a short helper hint. Looks like
/// a finished, ready-to-use widget that will populate once data exists.
class _EmptyMetricCard extends StatelessWidget {
  final String hint;
  final IconData icon;
  final Color color;
  const _EmptyMetricCard({
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ConceptIconTile(color: color, icon: icon, size: 46, iconSize: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '—',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actions = [
      (Icons.add_circle_outline, 'Add Food', Palette.widgetNutritionDay),
      (Icons.fitness_center_outlined, 'Add Workout', Palette.widgetStepsDay),
      (Icons.monitor_weight_outlined, 'Log Weight', Palette.widgetWeightDay),
      (Icons.auto_awesome_outlined, 'AI Assist', accent),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 3.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: actions.map((a) {
        final (icon, label, color) = a;
        return GestureDetector(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.14 : 0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.25 : 0.18),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── New widget cards ─────────────────────────────────────────────────────────

class _MacrosCard extends StatelessWidget {
  final int proteinConsumed;
  final int proteinGoal;
  final int carbsConsumed;
  final int carbsGoal;
  final int fatConsumed;
  final int fatGoal;

  const _MacrosCard({
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbsConsumed,
    required this.carbsGoal,
    required this.fatConsumed,
    required this.fatGoal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MacroRow(
          label: 'Protein',
          consumed: proteinConsumed,
          goal: proteinGoal,
          color: Palette.macroProtein,
        ),
        const SizedBox(height: 12),
        _MacroRow(
          label: 'Carbs',
          consumed: carbsConsumed,
          goal: carbsGoal,
          color: Palette.macroCarbs,
        ),
        const SizedBox(height: 12),
        _MacroRow(
          label: 'Fat',
          consumed: fatConsumed,
          goal: fatGoal,
          color: Palette.macroFat,
        ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final int consumed;
  final int goal;
  final Color color;

  const _MacroRow({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;
    final pct = goal > 0 ? (progress * 100).round() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$consumed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${goal}g',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                  TextSpan(
                    text: '  $pct%',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _WaterIntakeCard extends StatelessWidget {
  final double waterOz;
  const _WaterIntakeCard({this.waterOz = 0});

  @override
  Widget build(BuildContext context) {
    const goalOz = 64.0;
    final progress = (waterOz / goalOz).clamp(0.0, 1.0);
    final cups = (waterOz / 8).round();
    return Row(
      children: [
        const _ConceptIconTile(
          color: Color(0xFF0EA5E9),
          icon: Icons.water_drop_rounded,
          size: 46,
          iconSize: 24,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$cups cups · ${waterOz.toStringAsFixed(0)} oz',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: const Color(
                    0xFF0EA5E9,
                  ).withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${goalOz.round()} oz goal',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SleepCard extends StatelessWidget {
  final int? sleepMinutes;
  const _SleepCard({this.sleepMinutes});

  @override
  Widget build(BuildContext context) {
    if (sleepMinutes == null || sleepMinutes == 0) {
      return const _EmptyMetricCard(
        hint: 'Connect Apple Health',
        icon: Icons.bedtime_outlined,
        color: Color(0xFF0EA5E9),
      );
    }
    final hours = sleepMinutes! ~/ 60;
    final mins = sleepMinutes! % 60;
    final quality = sleepMinutes! >= 480
        ? 'Excellent'
        : sleepMinutes! >= 420
        ? 'Good'
        : sleepMinutes! >= 360
        ? 'Fair'
        : 'Poor';
    final qualityColor = sleepMinutes! >= 480
        ? const Color(0xFF2E8B57)
        : sleepMinutes! >= 420
        ? const Color(0xFF4C7FA8)
        : sleepMinutes! >= 360
        ? const Color(0xFFEF8C2E)
        : const Color(0xFFD0021B);
    final progress = (sleepMinutes! / 480).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                backgroundColor: const Color(
                  0xFF0EA5E9,
                ).withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
              ),
              const Icon(
                Icons.bedtime_rounded,
                size: 18,
                color: Color(0xFF0EA5E9),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${hours}h ${mins}m',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
                height: 1.1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              quality,
              style: TextStyle(
                fontSize: 12,
                color: qualityColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkoutPerformanceCard extends StatelessWidget {
  final int? calories;
  final int? durationMinutes;
  final String? workoutType;
  const _WorkoutPerformanceCard({
    this.calories,
    this.durationMinutes,
    this.workoutType,
  });

  @override
  Widget build(BuildContext context) {
    if ((calories ?? 0) == 0) {
      return const _EmptyMetricCard(
        hint: 'No workout logged',
        icon: Icons.fitness_center_rounded,
        color: Color(0xFFEF8C2E),
      );
    }
    return Row(
      children: [
        const _ConceptIconTile(
          color: Color(0xFFEF8C2E),
          icon: Icons.fitness_center_rounded,
          size: 52,
          iconSize: 26,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workoutType ?? 'Workout',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  if (durationMinutes != null) ...[
                    Icon(
                      Icons.timer_outlined,
                      size: 12,
                      color: context.colors.textMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${durationMinutes}min',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(
                    Icons.local_fire_department_outlined,
                    size: 12,
                    color: Color(0xFFEF8C2E),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$calories kcal',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF8C2E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightCard extends StatelessWidget {
  final double currentWeight;
  const _WeightCard({required this.currentWeight});

  @override
  Widget build(BuildContext context) {
    const tint = Palette.widgetWeightDay;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ConceptIconTile(
          color: tint,
          icon: Icons.monitor_weight_outlined,
          size: 48,
          iconSize: 24,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              currentWeight > 0
                  ? RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: currentWeight.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary,
                              height: 1.0,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          TextSpan(
                            text: ' lb',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      '— lb',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMuted,
                      ),
                    ),
              const SizedBox(height: 3),
              Text(
                currentWeight > 0 ? 'Tap to update' : 'Not yet logged',
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
            ],
          ),
        ),
        // Tap hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.edit_outlined, size: 14, color: tint),
        ),
      ],
    );
  }
}

// ── New health widget cards ───────────────────────────────────────────────────

class _TDEECard extends StatelessWidget {
  final double? tdee;
  final double avgTDEE;
  final List<double> weeklyTDEE;
  const _TDEECard({this.tdee, this.avgTDEE = 0, this.weeklyTDEE = const []});

  @override
  Widget build(BuildContext context) {
    const tint = Palette.widgetTDEEDay;
    if (tdee == null || tdee == 0) {
      return const _EmptyMetricCard(
        hint: 'Log food & activity',
        icon: Icons.local_fire_department_outlined,
        color: tint,
      );
    }
    final tdeeVal = tdee!.round();
    final category = tdeeVal >= 2800
        ? 'High output'
        : tdeeVal >= 2200
        ? 'Active'
        : tdeeVal >= 1800
        ? 'Moderate'
        : 'Low output';
    final hasTrend = avgTDEE > 0 && weeklyTDEE.any((v) => v > 0);
    final delta = avgTDEE > 0 ? tdeeVal - avgTDEE : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ConceptIconTile(color: tint, size: 48, iconSize: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$tdeeVal',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                            height: 1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        TextSpan(
                          text: ' kcal/day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current TDEE',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasTrend) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${avgTDEE.round()} kcal/day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '7-day avg',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${delta >= 0 ? '+' : '−'}${delta.abs().round()} vs avg',
                  style: const TextStyle(
                    fontSize: 11,
                    color: tint,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(weeklyTDEE.length, (i) {
                final v = weeklyTDEE[i];
                final maxVal = weeklyTDEE.fold(0.0, (a, b) => math.max(a, b));
                final h = maxVal > 0 ? (v / maxVal).clamp(0.0, 1.0) : 0.0;
                final isLatest = i == weeklyTDEE.length - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 40 * h,
                      decoration: BoxDecoration(
                        color: isLatest ? tint : tint.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ],
    );
  }
}

class _RestingHRCard extends StatelessWidget {
  final int? bpm;
  const _RestingHRCard({this.bpm});

  @override
  Widget build(BuildContext context) {
    if (bpm == null || bpm == 0) {
      return const _EmptyMetricCard(
        hint: 'Connect Apple Health',
        icon: Icons.favorite_outline,
        color: Color(0xFFD0021B),
      );
    }
    final hrColor = bpm! < 60
        ? const Color(0xFF2E8B57)
        : bpm! <= 80
        ? const Color(0xFF4C7FA8)
        : bpm! <= 100
        ? const Color(0xFFEF8C2E)
        : const Color(0xFFD0021B);
    final hrLabel = bpm! < 60
        ? 'Athletic'
        : bpm! <= 80
        ? 'Normal'
        : bpm! <= 100
        ? 'Elevated'
        : 'High';
    return Row(
      children: [
        _ConceptIconTile(
          color: hrColor,
          icon: Icons.favorite_rounded,
          size: 52,
          iconSize: 26,
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$bpm',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: ' bpm',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              hrLabel,
              style: TextStyle(
                fontSize: 12,
                color: hrColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BodyCompositionCard extends StatelessWidget {
  final double? bmi;
  const _BodyCompositionCard({this.bmi});

  @override
  Widget build(BuildContext context) {
    if (bmi == null) {
      return const _EmptyMetricCard(
        hint: 'Add height & weight',
        icon: Icons.accessibility_new_outlined,
        color: Color(0xFF8B5CF6),
      );
    }
    final bmiLabel = bmi! < 18.5
        ? 'Underweight'
        : bmi! < 25.0
        ? 'Normal'
        : bmi! < 30.0
        ? 'Overweight'
        : 'Obese';
    final bmiColor = bmi! >= 18.5 && bmi! < 25.0
        ? const Color(0xFF2E8B57)
        : bmi! < 18.5
        ? const Color(0xFF0EA5E9)
        : const Color(0xFFEF8C2E);
    return Row(
      children: [
        const _ConceptIconTile(
          color: Color(0xFF8B5CF6),
          icon: Icons.accessibility_new_outlined,
          size: 52,
          iconSize: 26,
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: bmi!.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      height: 1.0,
                    ),
                  ),
                  TextSpan(
                    text: ' BMI',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              bmiLabel,
              style: TextStyle(
                fontSize: 12,
                color: bmiColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkoutConsistencyCard extends StatelessWidget {
  final List<double> weeklyTDEE;
  final int streakDays;
  const _WorkoutConsistencyCard({
    required this.weeklyTDEE,
    this.streakDays = 0,
  });

  @override
  Widget build(BuildContext context) {
    const tint = Palette.widgetConsistDay;
    final activeDays = weeklyTDEE.where((v) => v > 0).length;
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final streakPhrase = activeDays >= 6
        ? 'Incredible week'
        : activeDays >= 5
        ? 'Strong performance'
        : activeDays >= 3
        ? 'Keep the momentum'
        : activeDays >= 1
        ? 'Building consistency'
        : 'Start logging today';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$activeDays',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: ' / 7',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'days logged',
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
            ),
            const Spacer(),
            if (streakDays > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 13,
                        color: tint,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$streakDays day${streakDays == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: tint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          streakPhrase,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tint,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final active = i < weeklyTDEE.length && weeklyTDEE[i] > 0;
            return Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? tint.withValues(alpha: 0.20)
                        : context.colors.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active
                          ? tint.withValues(alpha: 0.55)
                          : context.colors.divider,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Icon(
                    active ? Icons.check_rounded : Icons.remove,
                    size: 15,
                    color: active ? tint : context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  dayLabels[i].substring(0, 1),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? tint : context.colors.textMuted,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}
