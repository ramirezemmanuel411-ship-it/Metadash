import 'dart:math' as math;

import 'package:metadash/core/engine/wearable_calibration.dart';
import 'package:metadash/core/engine/workout_bucket.dart';
import 'package:metadash/core/engine/workout_telemetry.dart';

/// Result of a single [WorkoutEnergyEngine.compute] call.
class WorkoutEnergyResult {
  /// Final estimated workout calorie expenditure.
  final double calories;

  /// Device-calibrated wearable calories (pre-blend). Null if unavailable.
  final double? calibratedWearableCalories;

  /// MET-formula calories (pre-blend). Null if unavailable.
  final double? metCalories;

  /// Locomotion formula calories. Only set for [WorkoutBucket.locomotion].
  final double? locomotionFormulaCalories;

  /// Wearable signal weight used (0–1).
  final double wearableWeight;

  /// MET signal weight used (0–1).
  final double metWeight;

  /// Bucket resolved by the engine.
  final WorkoutBucket bucket;

  const WorkoutEnergyResult({
    required this.calories,
    this.calibratedWearableCalories,
    this.metCalories,
    this.locomotionFormulaCalories,
    required this.wearableWeight,
    required this.metWeight,
    required this.bucket,
  });
}

/// Core workout energy estimation engine.
///
/// Replaces the flat `accuracyMultiplier × wearableCalories` approach with:
///   • Locomotion  → distance-based formula (distanceMiles × weightLbs × 0.63)
///   • All others  → hybrid MET / wearable blend per workout bucket with
///                   device-family calibration applied to the wearable signal
///
/// The user-level accuracy preference from MetabolicSettings is still applied
/// on top of the engine output, preserving user control.
class WorkoutEnergyEngine {
  WorkoutEnergyEngine._();

  /// Compute workout calorie expenditure from [telemetry].
  static WorkoutEnergyResult compute(WorkoutTelemetry telemetry) {
    final bucket = telemetry.bucket;
    if (bucket == WorkoutBucket.locomotion) {
      return _locomotionCalories(telemetry);
    }
    return _hybridCalories(telemetry);
  }

  // ── LOCOMOTION ──────────────────────────────────────────────────────────────
  //
  // Primary formula: distanceMiles × bodyWeightLbs × 0.63
  // Fallback if distance unavailable: calibrated wearable calories.

  static WorkoutEnergyResult _locomotionCalories(WorkoutTelemetry t) {
    final distanceMiles = t.distanceMiles;
    final weightLbs = t.bodyWeightLbs;

    if (distanceMiles > 0 && weightLbs > 0) {
      final formulaCal = distanceMiles * weightLbs * 0.63;
      return WorkoutEnergyResult(
        calories: formulaCal,
        locomotionFormulaCalories: formulaCal,
        wearableWeight: 0.0,
        metWeight: 0.0,
        bucket: WorkoutBucket.locomotion,
      );
    }

    // Distance unavailable — fall back to calibrated wearable.
    final calibrated = _calibratedWearable(t);
    if (calibrated != null) {
      final adjusted = calibrated * t.userAccuracyMultiplier;
      return WorkoutEnergyResult(
        calories: math.max(0, adjusted),
        calibratedWearableCalories: calibrated,
        wearableWeight: 1.0,
        metWeight: 0.0,
        bucket: WorkoutBucket.locomotion,
      );
    }

    // No data at all.
    return const WorkoutEnergyResult(
      calories: 0,
      locomotionFormulaCalories: 0,
      wearableWeight: 0,
      metWeight: 0,
      bucket: WorkoutBucket.locomotion,
    );
  }

  // ── HYBRID (non-locomotion) ─────────────────────────────────────────────────
  //
  // FinalCalories = (calibratedWearable × wearableWeight)
  //              + (metCalories       × metWeight)
  // Then multiply by userAccuracyMultiplier.

  static WorkoutEnergyResult _hybridCalories(WorkoutTelemetry t) {
    final bucket = t.bucket;
    final (wWeight, mWeight) = _blendWeights(bucket);

    final calibrated = _calibratedWearable(t);
    final met = _metCalories(t);

    double raw = 0;
    if (calibrated != null && met != null) {
      raw = (calibrated * wWeight) + (met * mWeight);
    } else if (calibrated != null) {
      raw = calibrated; // No MET data → 100 % wearable.
    } else if (met != null) {
      raw = met; // No wearable data → 100 % MET.
    }

    final total = math.max(0.0, raw * t.userAccuracyMultiplier);

    return WorkoutEnergyResult(
      calories: total,
      calibratedWearableCalories: calibrated,
      metCalories: met,
      wearableWeight: wWeight,
      metWeight: mWeight,
      bucket: bucket,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Applies device-family calibration multiplier to raw wearable calories.
  static double? _calibratedWearable(WorkoutTelemetry t) {
    final raw = t.wearableCalories;
    if (raw == null || raw <= 0) return null;
    return raw * WearableCalibration.multiplierFor(t.wearableFamily);
  }

  /// Calculates calories from average METs.
  ///
  /// Formula (from ACSM):
  ///   caloriesPerMin = (MET × 3.5 × bodyWeightKg) / 200
  ///   METCalories    = caloriesPerMin × durationMinutes
  static double? _metCalories(WorkoutTelemetry t) {
    final mets = t.averageMets;
    if (mets == null || mets <= 0 || t.durationMinutes <= 0) return null;
    final calPerMin = (mets * 3.5 * t.bodyWeightKg) / 200.0;
    return calPerMin * t.durationMinutes;
  }

  /// Default MET / wearable blend weights per bucket.
  /// Returns (wearableWeight, metWeight). Both sum to 1.0.
  static (double, double) _blendWeights(WorkoutBucket bucket) {
    switch (bucket) {
      case WorkoutBucket.steadyCardio: // cycling, rowing, elliptical, swimming
        return (0.40, 0.60);
      case WorkoutBucket.lowImpact: // yoga, pilates, mobility
        return (0.20, 0.80);
      case WorkoutBucket.sport: // tennis, soccer, basketball, pickleball
        return (0.40, 0.60);
      case WorkoutBucket.strength:
        return (0.50, 0.50);
      case WorkoutBucket.golf:
        return (0.30, 0.70);
      case WorkoutBucket.locomotion: // handled in _locomotionCalories
        return (0.30, 0.70);
      case WorkoutBucket.mixed:
        return (0.50, 0.50);
    }
  }
}
