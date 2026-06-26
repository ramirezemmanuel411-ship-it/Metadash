import 'package:metadash/core/engine/wearable_calibration.dart';
import 'package:metadash/core/engine/workout_bucket.dart';

/// All telemetry signals for one workout session fed into the energy engine.
///
/// All fields are optional — the engine degrades gracefully when data is
/// missing and falls back through the signal hierarchy.
class WorkoutTelemetry {
  /// Raw device-reported active / workout calories. Null when unavailable.
  final double? wearableCalories;

  /// Duration of the workout in minutes.
  final int durationMinutes;

  /// Steps attributed to this workout (linked step samples for locomotion).
  /// Used for step de-duplication to prevent NEAT double-counting.
  final int workoutSteps;

  /// Walking / running distance in metres.
  final double? distanceMeters;

  /// Average METs for this session (exposed by Apple Health on some workouts).
  final double? averageMets;

  /// Average heart rate during workout (bpm).
  final int? averageHeartRate;

  /// Body weight in lbs — used in locomotion formula and MET calculation.
  final double bodyWeightLbs;

  /// Raw workout type string from HealthKit / Health Connect.
  final String? rawWorkoutType;

  /// Override the auto-classified bucket when the caller already knows it.
  final WorkoutBucket? bucketOverride;

  /// Wearable device family for calibration. Defaults to [WearableFamily.unknown].
  final WearableFamily wearableFamily;

  /// User-level accuracy multiplier from MetabolicSettings
  /// (Strict ≈ 0.7 / Balanced ≈ 0.8 / Generous ≈ 1.0).
  final double userAccuracyMultiplier;

  const WorkoutTelemetry({
    this.wearableCalories,
    required this.durationMinutes,
    this.workoutSteps = 0,
    this.distanceMeters,
    this.averageMets,
    this.averageHeartRate,
    required this.bodyWeightLbs,
    this.rawWorkoutType,
    this.bucketOverride,
    this.wearableFamily = WearableFamily.unknown,
    this.userAccuracyMultiplier = 0.8,
  });

  /// Resolved bucket — uses [bucketOverride] if set, otherwise classifies
  /// from [rawWorkoutType].
  WorkoutBucket get bucket =>
      bucketOverride ?? WorkoutClassifier.classify(rawWorkoutType);

  double get distanceMiles => (distanceMeters ?? 0) / 1609.344;
  double get bodyWeightKg => bodyWeightLbs / 2.20462;

  /// Whether this telemetry has enough signal to use the new engine.
  /// Falls back to legacy calculation when false.
  bool get hasTelemetrySignal =>
      (distanceMeters != null && distanceMeters! > 0) ||
      (averageMets != null && averageMets! > 0) ||
      (wearableCalories != null && wearableCalories! > 0);
}
