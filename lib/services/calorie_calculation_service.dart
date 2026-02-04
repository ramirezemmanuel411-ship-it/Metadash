import '../models/user_profile.dart';
import '../models/daily_log.dart';

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

  /// Calculate workout calories with fallback logic
  /// Primary: Use device reported calories with 0.8 multiplier
  /// Fallback: Use running steps with 2.0x multiplier (6mph average pace)
  static double calculateWorkoutCalories({
    required double? deviceWorkoutCalories,
    required double runningSteps,
    required double weightLbs,
  }) {
    if (deviceWorkoutCalories != null && deviceWorkoutCalories > 0) {
      // Primary: Device data available
      return deviceWorkoutCalories * 0.8;
    } else if (runningSteps > 0) {
      // Fallback: Estimate from running steps
      final stepCalPerStep = calculateStepCaloriePerStep(weightLbs);
      return runningSteps * stepCalPerStep * 2.0; // 2.0x multiplier for ~6mph running
    }
    return 0;
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
  }) {
    final neat = calculateNEAT(walkingSteps: walkingSteps, weightLbs: weightLbs);
    final workoutCalories = calculateWorkoutCalories(
      deviceWorkoutCalories: deviceWorkoutCalories,
      runningSteps: runningSteps,
      weightLbs: weightLbs,
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
  }) {
    final tdee = calculateTDEE(
      bmr: user.bmr,
      walkingSteps: (log.stepsCount - (log.runningSteps ?? 0)).toDouble(),
      deviceWorkoutCalories: log.workoutCalories?.toDouble(),
      runningSteps: (log.runningSteps ?? 0).toDouble(),
      weightLbs: user.weight,
      proteinGrams: log.protein,
      carbsGrams: log.carbs,
      fatGrams: log.fat,
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
      ),
      tef: tef,
      tdee: tdee,
      caloriesConsumed: log.caloriesConsumed,
      dailyDeficitSurplus: dailyDeficit,
      dailyFatChange: dailyFatChange,
      weeklyFatChange: weeklyFatChange,
    );
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
