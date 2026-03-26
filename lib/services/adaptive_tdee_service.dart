import '../models/metabolic_settings.dart';
import 'dart:math' as math;

/// Service for calculating adaptive TDEE adjustments based on daily fat delta discrepancies
class AdaptiveTDEEService {
  /// Calculate expected fat delta from calorie deficit
  /// Formula: (deficit / 3500) × 0.75
  /// The 0.75 multiplier accounts for water weight (~25% of weight loss is water/glycogen)
  static double calculateExpectedFatDelta({
    required int caloriesConsumed,
    required double tdee,
  }) {
    const caloriesPerPoundFat = 3500.0;
    const waterWeightMultiplier = 0.75; // 75% fat, 25% water
    
    final dailyDeficit = caloriesConsumed - tdee;
    return (dailyDeficit / caloriesPerPoundFat) * waterWeightMultiplier;
  }

  /// Calculate smoothed weight using moving average
  /// Uses 3-day window to reduce water weight noise
  static double calculateSmoothedWeight(List<double> recentWeights) {
    if (recentWeights.isEmpty) return 0.0;
    
    // Use up to last 3 days
    final window = recentWeights.length >= 3 
        ? recentWeights.sublist(recentWeights.length - 3)
        : recentWeights;
    
    return window.reduce((a, b) => a + b) / window.length;
  }

  /// Calculate TDEE adjustment based on expected vs actual weight change
  /// Returns adjustment amount (positive = increase TDEE, negative = decrease TDEE)
  static double calculateTDEEAdjustment({
    required double expectedFatDelta,
    required double actualWeightChange,
    required MetabolicSettings settings,
  }) {
    // Static mode: no adjustments
    if (settings.isStaticOnly) return 0.0;

    // Calculate discrepancy in pounds
    final discrepancyLbs = actualWeightChange - expectedFatDelta;
    
    // Convert to calories
    const caloriesPerPoundFat = 3500.0;
    const waterWeightMultiplier = 0.75;
    final discrepancyCal = (discrepancyLbs * caloriesPerPoundFat) / waterWeightMultiplier;
    
    // Apply dampening based on energy model
    // Hybrid: 30% dampened (conservative)
    // Adaptive: 100% full adjustment (aggressive)
    final dampening = settings.energyModel == 'Hybrid (Recommended)' ? 0.3 : 1.0;
    
    // Negative because inverse relationship:
    // If lost MORE than expected → TDEE is HIGHER than calculated → increase it
    // If lost LESS than expected → TDEE is LOWER than calculated → decrease it
    return -discrepancyCal * dampening;
  }

  /// Calculate adjusted TDEE for today
  /// Combines formula-based TDEE with adaptive adjustments
  static double calculateAdaptiveTDEE({
    required double formulaTDEE,
    required double previousAdjustment,
    required double todayAdjustment,
    required MetabolicSettings settings,
  }) {
    if (settings.isStaticOnly) {
      return formulaTDEE;
    }

    // Cumulative adjustment: yesterday's + today's micro-adjustment
    final totalAdjustment = previousAdjustment + todayAdjustment;
    
    // Cap adjustments at ±500 calories to prevent extreme swings
    final cappedAdjustment = totalAdjustment.clamp(-500.0, 500.0);
    
    return formulaTDEE + cappedAdjustment;
  }

  /// Reset adaptive adjustment when baseline changes significantly
  /// (e.g., user loses 10+ lbs and BMR is recalculated)
  static bool shouldResetAdjustment({
    required double oldWeight,
    required double newWeight,
  }) {
    final weightChangeLbs = (oldWeight - newWeight).abs();
    return weightChangeLbs >= 10.0; // Reset if 10+ lb change
  }

  /// Calculate decay factor for old adjustments
  /// Gradually reduce influence of old adjustments over time
  /// Returns multiplier between 0.0 and 1.0
  static double calculateDecayFactor(int daysOld) {
    // 90% after 1 day, 81% after 2 days, etc.
    // Complete decay after ~30 days
    const dailyDecay = 0.97;
    return math.pow(dailyDecay, daysOld).toDouble();
  }
}

/// Data class to hold adaptive TDEE calculation results
class AdaptiveTDEEResult {
  final double formulaTDEE;
  final double expectedFatDelta;
  final double actualWeightChange;
  final double tdeeAdjustment;
  final double adjustedTDEE;
  final String adjustmentReason;

  const AdaptiveTDEEResult({
    required this.formulaTDEE,
    required this.expectedFatDelta,
    required this.actualWeightChange,
    required this.tdeeAdjustment,
    required this.adjustedTDEE,
    required this.adjustmentReason,
  });

  @override
  String toString() => '''
AdaptiveTDEEResult(
  Formula TDEE: ${formulaTDEE.toStringAsFixed(0)} cal
  Expected fat delta: ${expectedFatDelta.toStringAsFixed(3)} lbs
  Actual weight change: ${actualWeightChange.toStringAsFixed(3)} lbs
  TDEE adjustment: ${tdeeAdjustment >= 0 ? '+' : ''}${tdeeAdjustment.toStringAsFixed(0)} cal
  Adjusted TDEE: ${adjustedTDEE.toStringAsFixed(0)} cal
  Reason: $adjustmentReason
)''';
}
