import 'package:metadash/core/engine/workout_bucket.dart';

/// Separates locomotion workout steps from total daily steps to prevent
/// double-counting in the NEAT (Non-Exercise Activity Thermogenesis) formula.
///
/// Only locomotion workouts overlap with step counts. Strength, sport, and
/// other buckets do not generate step samples in HealthKit, so they need no
/// de-duplication.
class StepDeduplicator {
  StepDeduplicator._();

  /// Returns the non-workout steps to feed into NEAT.
  ///
  /// [totalDailySteps]      — raw step count from HealthKit for the full day.
  /// [locomotionWorkoutSteps] — steps attributed to locomotion workout sessions.
  ///                            Null means no reliable workout-step data; falls
  ///                            back to 0 (conservative — avoids over-subtracting).
  /// [bucket]               — workout classification. De-duplication is only
  ///                            applied when the bucket is [WorkoutBucket.locomotion].
  static int nonWorkoutSteps({
    required int totalDailySteps,
    required int? locomotionWorkoutSteps,
    required WorkoutBucket bucket,
  }) {
    if (bucket != WorkoutBucket.locomotion) return totalDailySteps;

    final deducted = locomotionWorkoutSteps ?? 0;
    // Clamp at zero — step sensors can have minor discrepancies.
    return (totalDailySteps - deducted).clamp(0, totalDailySteps);
  }

  /// Estimates locomotion workout steps from distance when direct step samples
  /// are unavailable.
  ///
  /// Uses average stride length of 0.762 m (≈ 2.5 ft) as a conservative
  /// fallback. Overridden as soon as real step data is available.
  static int estimateFromDistance({
    required double distanceMeters,
    double strideMeters = 0.762,
  }) {
    if (distanceMeters <= 0 || strideMeters <= 0) return 0;
    return (distanceMeters / strideMeters).round();
  }
}
