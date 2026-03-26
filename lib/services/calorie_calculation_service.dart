import '../models/user_profile.dart';
import '../models/daily_log.dart';
import '../models/metabolic_settings.dart';
import '../models/data_inputs_settings.dart';
import 'adaptive_tdee_service.dart';

class CalorieCalculationService {
  /// Calculate step calories per step based on body weight
  /// Formula: step_cal_per_step = 0.04 × (weight_lbs / 170)
  static double calculateStepCaloriePerStep(double weightLbs) {
    const baseCaloriesPerStep = 0.04;
    const referenceWeight = 170.0;
    return baseCaloriesPerStep * (weightLbs / referenceWeight);
  }

  /// Calculate NEAT (Non-Exercise Activity Thermogenesis) from walking steps
  static double calculateNEAT({
    required double walkingSteps,
    required double weightLbs,
  }) {
    final stepCalPerStep = calculateStepCaloriePerStep(weightLbs);
    return walkingSteps * stepCalPerStep;
  }

  /// Calculate workout calories with fallback logic and accuracy multiplier
  /// Primary: Use device reported calories with accuracy multiplier
  /// Fallback: Use running steps with 2.0x multiplier (6mph average pace)
  static double calculateWorkoutCalories({
    required double? deviceWorkoutCalories,
    required double runningSteps,
    required double weightLbs,
    double accuracyMultiplier = 0.8, // From metabolic settings
    String? accuracyLabel,
    String? workoutType,
    bool includeStrengthInExpenditure = true,
    bool useTrackedWorkoutCalories = true,
  }) {
    final type = (workoutType ?? '').toLowerCase();
    final isStrength = type.contains('strength') || type.contains('weight') || type.contains('resistance');
    final typeMultiplier = _workoutTypeAccuracyMultiplier(type, accuracyLabel) ?? accuracyMultiplier;

    if (!includeStrengthInExpenditure && isStrength) {
      return 0;
    }

    final effectiveDeviceCalories = useTrackedWorkoutCalories ? deviceWorkoutCalories : null;
    final effectiveAccuracy = typeMultiplier;

    if (effectiveDeviceCalories != null && effectiveDeviceCalories > 0) {
      // Primary: Device data available - apply accuracy multiplier
      return effectiveDeviceCalories * effectiveAccuracy;
    } else if (runningSteps > 0) {
      // Fallback: Estimate from running steps
      final stepCalPerStep = calculateStepCaloriePerStep(weightLbs);
      return runningSteps * stepCalPerStep * 2.0 * effectiveAccuracy;
    }
    return 0;
  }

  static double? _workoutTypeAccuracyMultiplier(String type, String? accuracyLabel) {
    if (accuracyLabel == null || accuracyLabel.isEmpty) return null;

    final label = accuracyLabel.toLowerCase();
    final useLow = label.contains('strict') || label.contains('conservative');
    final useHigh = label.contains('flexible') || label.contains('generous');

    double low;
    double high;

    if (type.contains('running') || type.contains('marathon')) {
      low = 0.80;
      high = 1.00;
    } else if (type.contains('cycling') || type.contains('bike')) {
      low = 0.75;
      high = 1.00;
    } else if (type.contains('hiit') || type.contains('interval') || type.contains('cardio')) {
      low = 0.70;
      high = 0.95;
    } else if (type.contains('strength') || type.contains('weight') || type.contains('resistance')) {
      low = 0.60;
      high = 0.90;
    } else if (type.contains('swim')) {
      low = 0.60;
      high = 0.90;
    } else {
      low = 0.75;
      high = 0.95;
    }

    if (useLow) return low;
    if (useHigh) return high;
    return (low + high) / 2.0; // Balanced
  }

  static double _mapWorkoutAccuracyMultiplier(String accuracy) {
    switch (accuracy) {
      case 'Conservative':
        return 0.7;
      case 'Generous':
        return 1.0;
      case 'Balanced':
      default:
        return 0.8;
    }
  }

  /// Calculate TEF (Thermic Effect of Food) based on macronutrients
  /// Different macros have different thermic effects:
  /// - Protein: ~20% (most thermic)
  /// - Carbs: ~5%
  /// - Fat: ~0% (least thermic)
  /// Formula: TEF = (protein_g × 0.20) + (carbs_g × 0.05) + (fat_g × 0.00)
  static double calculateTEF({
    required int proteinGrams,
    required int carbsGrams,
    required int fatGrams,
  }) {
    const proteinThermic = 0.20; // 20% of protein calories burned in digestion
    const carbsThermic = 0.05; // 5% of carbs calories
    const fatThermic = 0.00; // ~0% of fat calories

    // Convert grams to calories, then apply thermic effect
    final proteinCalories = proteinGrams * 4; // 4 cal per gram
    final carbsCalories = carbsGrams * 4; // 4 cal per gram
    final fatCalories = fatGrams * 9; // 9 cal per gram

    return (proteinCalories * proteinThermic) +
        (carbsCalories * carbsThermic) +
        (fatCalories * fatThermic);
  }

  /// Calculate TDEE (Total Daily Energy Expenditure)
  /// Formula: TDEE = BMR + NEAT + Workout_Calories + TEF
  static double calculateTDEE({
    required double bmr,
    required double walkingSteps,
    required double? deviceWorkoutCalories,
    required double runningSteps,
    required double weightLbs,
    required int proteinGrams,
    required int carbsGrams,
    required int fatGrams,
    double workoutAccuracyMultiplier = 0.8, // From metabolic settings
    String? workoutAccuracyLabel,
    String? workoutType,
    bool includeStrengthInExpenditure = true,
    bool useTrackedWorkoutCalories = true,
  }) {
    final neat = calculateNEAT(walkingSteps: walkingSteps, weightLbs: weightLbs);
    final workoutCalories = calculateWorkoutCalories(
      deviceWorkoutCalories: deviceWorkoutCalories,
      runningSteps: runningSteps,
      weightLbs: weightLbs,
      accuracyMultiplier: workoutAccuracyMultiplier,
      accuracyLabel: workoutAccuracyLabel,
      workoutType: workoutType,
      includeStrengthInExpenditure: includeStrengthInExpenditure,
      useTrackedWorkoutCalories: useTrackedWorkoutCalories,
    );
    final tef = calculateTEF(
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
    );

    return bmr + neat + workoutCalories + tef;
  }

  /// Calculate daily deficit/surplus
  /// Formula: daily_deficit_surplus = calories_consumed - TDEE
  /// Negative = deficit (weight loss), Positive = surplus (weight gain)
  static double calculateDailyDeficitSurplus({
    required double caloriesConsumed,
    required double tdee,
  }) {
    return caloriesConsumed - tdee;
  }

  /// Calculate daily fat change in pounds
  /// Formula: daily_fat_change = (daily_deficit_surplus / 3500) × 0.75
  /// 0.75 multiplier accounts for ~25% water weight in weight loss
  static double calculateDailyFatChange(double dailyDeficitSurplus) {
    const caloriesPerPound = 3500.0;
    const waterWeightMultiplier = 0.75; // 75% fat loss, 25% water loss
    return (dailyDeficitSurplus / caloriesPerPound) * waterWeightMultiplier;
  }

  /// Calculate weekly fat change in pounds
  /// Multiply daily fat change by 7 (no additional multiplier to avoid double counting)
  static double calculateWeeklyFatChange(double dailyDeficitSurplus) {
    final dailyFatChange = calculateDailyFatChange(dailyDeficitSurplus);
    return dailyFatChange * 7;
  }

  /// Calculate cumulative fat change over a date range
  /// Sum daily fat changes (water weight adjustment already applied to each day)
  static double calculateCumulativeFatChange(List<double> dailyDeficitSurplus) {
    final dailyFatChanges = dailyDeficitSurplus.map((d) => calculateDailyFatChange(d));
    return dailyFatChanges.reduce((a, b) => a + b);
  }

  /// Complete calculation for a single day
  /// Returns all relevant metrics
  static DayEnergyMetrics calculateDayMetrics({
    required UserProfile user,
    required DailyLog log,
    MetabolicSettings? settings,
    DataInputsSettings? inputs,
  }) {
    final metabolicSettings = settings ?? MetabolicSettings.defaults();
    final workoutAccuracyMultiplier = inputs != null
        ? _mapWorkoutAccuracyMultiplier(inputs.workoutAccuracy)
        : metabolicSettings.workoutCalorieMultiplier;
    final workoutAccuracyLabel = inputs?.workoutAccuracy ?? metabolicSettings.workoutAccuracy;
    final includeStrength = inputs?.includeStrengthInExpenditure ?? true;
    final useTrackedWorkoutCalories = inputs?.useTrackedWorkoutCalories ?? true;
    
    final tdee = calculateTDEE(
      bmr: user.bmr,
      walkingSteps: (log.stepsCount - (log.runningSteps ?? 0)).toDouble(),
      deviceWorkoutCalories: log.workoutCalories?.toDouble(),
      runningSteps: (log.runningSteps ?? 0).toDouble(),
      weightLbs: user.weight,
      proteinGrams: log.protein,
      carbsGrams: log.carbs,
      fatGrams: log.fat,
      workoutAccuracyMultiplier: workoutAccuracyMultiplier,
      workoutAccuracyLabel: workoutAccuracyLabel,
      workoutType: log.workoutType,
      includeStrengthInExpenditure: includeStrength,
      useTrackedWorkoutCalories: useTrackedWorkoutCalories,
    );

    final dailyDeficit = calculateDailyDeficitSurplus(
      caloriesConsumed: log.caloriesConsumed.toDouble(),
      tdee: tdee,
    );

    final dailyFatChange = calculateDailyFatChange(dailyDeficit);
    final weeklyFatChange = calculateWeeklyFatChange(dailyDeficit);

    final tef = calculateTEF(
      proteinGrams: log.protein,
      carbsGrams: log.carbs,
      fatGrams: log.fat,
    );

    return DayEnergyMetrics(
      bmr: user.bmr,
      neat: calculateNEAT(
        walkingSteps: (log.stepsCount - (log.runningSteps ?? 0)).toDouble(),
        weightLbs: user.weight,
      ),
      workoutCalories: calculateWorkoutCalories(
        deviceWorkoutCalories: log.workoutCalories?.toDouble(),
        runningSteps: (log.runningSteps ?? 0).toDouble(),
        weightLbs: user.weight,
        accuracyMultiplier: workoutAccuracyMultiplier,
        accuracyLabel: workoutAccuracyLabel,
        workoutType: log.workoutType,
        includeStrengthInExpenditure: includeStrength,
        useTrackedWorkoutCalories: useTrackedWorkoutCalories,
      ),
      tef: tef,
      tdee: tdee,
      caloriesConsumed: log.caloriesConsumed,
      dailyDeficitSurplus: dailyDeficit,
      dailyFatChange: dailyFatChange,
      weeklyFatChange: weeklyFatChange,
    );
  }

  /// Calculate adaptive TDEE with weight history
  /// Returns adjusted TDEE based on expected vs actual weight changes
  static AdaptiveTDEEResult calculateAdaptiveTDEE({
    required UserProfile user,
    required DailyLog todayLog,
    required List<DailyLog> recentLogs, // Last 3-7 days with weight data
    required MetabolicSettings settings,
  }) {
    // Calculate formula-based TDEE
    final formulaTDEE = calculateTDEE(
      bmr: user.bmr,
      walkingSteps: (todayLog.stepsCount - (todayLog.runningSteps ?? 0)).toDouble(),
      deviceWorkoutCalories: todayLog.workoutCalories?.toDouble(),
      runningSteps: (todayLog.runningSteps ?? 0).toDouble(),
      weightLbs: user.weight,
      proteinGrams: todayLog.protein,
      carbsGrams: todayLog.carbs,
      fatGrams: todayLog.fat,
      workoutAccuracyMultiplier: settings.workoutCalorieMultiplier,
      workoutAccuracyLabel: settings.workoutAccuracy,
      workoutType: todayLog.workoutType,
    );

    // Static mode: no adaptive adjustment
    if (settings.isStaticOnly) {
      return AdaptiveTDEEResult(
        formulaTDEE: formulaTDEE,
        expectedFatDelta: 0.0,
        actualWeightChange: 0.0,
        tdeeAdjustment: 0.0,
        adjustedTDEE: formulaTDEE,
        adjustmentReason: 'Static mode - no adaptive adjustments',
      );
    }

    // Need at least 2 days with weight data for comparison
    final logsWithWeight = recentLogs.where((log) => log.weight != null).toList();
    if (logsWithWeight.length < 2 || todayLog.weight == null) {
      return AdaptiveTDEEResult(
        formulaTDEE: formulaTDEE,
        expectedFatDelta: 0.0,
        actualWeightChange: 0.0,
        tdeeAdjustment: 0.0,
        adjustedTDEE: formulaTDEE,
        adjustmentReason: 'Insufficient weight data for adaptive calculation',
      );
    }

    // Get smoothed weights
    final recentWeights = logsWithWeight.map((log) => log.weight!).toList();
    final yesterdaySmoothed = AdaptiveTDEEService.calculateSmoothedWeight(
      recentWeights.sublist(0, recentWeights.length - 1),
    );
    final todaySmoothed = AdaptiveTDEEService.calculateSmoothedWeight(recentWeights);
    final actualWeightChange = todaySmoothed - yesterdaySmoothed;

    // Calculate expected fat delta from yesterday's data
    final yesterdayLog = logsWithWeight[logsWithWeight.length - 2];
    final yesterdayTDEE = calculateTDEE(
      bmr: user.bmr,
      walkingSteps: (yesterdayLog.stepsCount - (yesterdayLog.runningSteps ?? 0)).toDouble(),
      deviceWorkoutCalories: yesterdayLog.workoutCalories?.toDouble(),
      runningSteps: (yesterdayLog.runningSteps ?? 0).toDouble(),
      weightLbs: user.weight,
      proteinGrams: yesterdayLog.protein,
      carbsGrams: yesterdayLog.carbs,
      fatGrams: yesterdayLog.fat,
      workoutAccuracyMultiplier: settings.workoutCalorieMultiplier,
      workoutAccuracyLabel: settings.workoutAccuracy,
      workoutType: yesterdayLog.workoutType,
    );

    final expectedFatDelta = AdaptiveTDEEService.calculateExpectedFatDelta(
      caloriesConsumed: yesterdayLog.caloriesConsumed,
      tdee: yesterdayTDEE,
    );

    // Calculate today's TDEE adjustment
    final todayAdjustment = AdaptiveTDEEService.calculateTDEEAdjustment(
      expectedFatDelta: expectedFatDelta,
      actualWeightChange: actualWeightChange,
      settings: settings,
    );

    // Get previous cumulative adjustment
    final previousAdjustment = yesterdayLog.tdeeAdjustment ?? 0.0;

    // Calculate adjusted TDEE
    final adjustedTDEE = AdaptiveTDEEService.calculateAdaptiveTDEE(
      formulaTDEE: formulaTDEE,
      previousAdjustment: previousAdjustment,
      todayAdjustment: todayAdjustment,
      settings: settings,
    );

    final adjustmentReason = _getAdjustmentReason(
      expectedFatDelta: expectedFatDelta,
      actualWeightChange: actualWeightChange,
      adjustment: todayAdjustment,
      energyModel: settings.energyModel,
    );

    return AdaptiveTDEEResult(
      formulaTDEE: formulaTDEE,
      expectedFatDelta: expectedFatDelta,
      actualWeightChange: actualWeightChange,
      tdeeAdjustment: previousAdjustment + todayAdjustment,
      adjustedTDEE: adjustedTDEE,
      adjustmentReason: adjustmentReason,
    );
  }

  static String _getAdjustmentReason({
    required double expectedFatDelta,
    required double actualWeightChange,
    required double adjustment,
    required String energyModel,
  }) {
    if (adjustment.abs() < 10) {
      return 'Weight change matches expectation - minimal adjustment';
    }

    final lostMore = actualWeightChange < expectedFatDelta;
    final mode = energyModel == 'Hybrid (Recommended)' ? 'dampened' : 'full';

    if (lostMore) {
      return 'Lost more than expected → TDEE underestimated → $mode increase';
    } else {
      return 'Lost less than expected → TDEE overestimated → $mode decrease';
    }
  }
}


/// Data class for daily energy metrics
class DayEnergyMetrics {
  final double bmr;
  final double neat;
  final double workoutCalories;
  final double tef;
  final double tdee;
  final int caloriesConsumed;
  final double dailyDeficitSurplus;
  final double dailyFatChange;
  final double weeklyFatChange;

  DayEnergyMetrics({
    required this.bmr,
    required this.neat,
    required this.workoutCalories,
    required this.tef,
    required this.tdee,
    required this.caloriesConsumed,
    required this.dailyDeficitSurplus,
    required this.dailyFatChange,
    required this.weeklyFatChange,
  });

  @override
  String toString() => '''
DayEnergyMetrics(
  BMR: ${bmr.toStringAsFixed(0)},
  NEAT: ${neat.toStringAsFixed(0)},
  Workout: ${workoutCalories.toStringAsFixed(0)},
  TEF: ${tef.toStringAsFixed(0)},
  TDEE: ${tdee.toStringAsFixed(0)},
  Consumed: $caloriesConsumed,
  Deficit/Surplus: ${dailyDeficitSurplus.toStringAsFixed(0)},
  Daily Fat Change: ${dailyFatChange.toStringAsFixed(3)} lbs,
  Weekly Fat Change: ${weeklyFatChange.toStringAsFixed(2)} lbs,
)''';
}
