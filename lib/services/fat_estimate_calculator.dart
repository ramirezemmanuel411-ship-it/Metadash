import '../models/reentry_mode_state.dart';

/// Fat estimate calculation logic for Reentry Mode
class FatEstimateCalculator {
  /// Map intake and activity deltas to a combined score
  static int _calculateDeltaScore({
    required IntakeDelta? intakeDelta,
    required ActivityDelta? activityDelta,
  }) {
    int intakeScore = 0;
    if (intakeDelta == IntakeDelta.less) {
      intakeScore = -1;
    } else if (intakeDelta == IntakeDelta.more) {
      intakeScore = 1;
    }

    int activityScore = 0;
    if (activityDelta == ActivityDelta.less) {
      activityScore = 1; // less activity = more likely to gain fat
    } else if (activityDelta == ActivityDelta.more) {
      activityScore = -1; // more activity = more likely to lose fat
    }

    return intakeScore + activityScore;
  }

  /// Get daily fat change rate range (lb/day) based on delta score
  static List<double> _getRateRange(int deltaScore) {
    switch (deltaScore) {
      case -2:
        return [-0.20, -0.08];
      case -1:
        return [-0.12, -0.03];
      case 0:
        return [-0.04, 0.04];
      case 1:
        return [0.03, 0.12];
      case 2:
        return [0.08, 0.20];
      default:
        return [0.0, 0.0];
    }
  }

  /// Calculate fat estimate based on inputs
  static ({double low, double high}) calculateFatEstimate({
    required double preReentryWeight,
    required double returnWeight,
    required IntakeDelta intakeDelta,
    required ActivityDelta activityDelta,
    required int reentryDays,
  }) {
    int deltaScore = _calculateDeltaScore(
      intakeDelta: intakeDelta,
      activityDelta: activityDelta,
    );

    List<double> rateRange = _getRateRange(deltaScore);
    double rateLow = rateRange[0];
    double rateHigh = rateRange[1];

    // Calculate fat range based on days
    double clampedDays = reentryDays.toDouble().clamp(1, double.infinity);
    double fatLow = rateLow * clampedDays;
    double fatHigh = rateHigh * clampedDays;

    // Bound by observed scale delta
    double deltaW = returnWeight - preReentryWeight;

    if (deltaW >= 0) {
      fatHigh = fatHigh.clamp(double.negativeInfinity, deltaW);
      fatLow = fatLow.clamp(double.negativeInfinity, deltaW);
    } else {
      fatLow = fatLow.clamp(deltaW, double.infinity);
      fatHigh = fatHigh.clamp(deltaW, double.infinity);
    }

    // Ensure fatLow <= fatHigh
    if (fatLow > fatHigh) {
      (fatLow, fatHigh) = (fatHigh, fatLow);
    }

    return (low: fatLow, high: fatHigh);
  }

  /// Refine fat estimate based on new weigh-in
  /// Uses smoothing to gradually tighten the range without over-reacting
  static ({double low, double high}) refineFatEstimate({
    required double preReentryWeight,
    required double currentWeight,
    required IntakeDelta intakeDelta,
    required ActivityDelta activityDelta,
    required int reentryStartToCurrentDays,
    required double previousEstimateLow,
    required double previousEstimateHigh,
    required DateTime? lastRefineWeightDate,
  }) {
    // Calculate raw estimate using current data
    List<double> rateRange = _getRateRange(
      _calculateDeltaScore(intakeDelta: intakeDelta, activityDelta: activityDelta),
    );

    double rateLow = rateRange[0];
    double rateHigh = rateRange[1];

    double clampedDays = reentryStartToCurrentDays.toDouble().clamp(1, double.infinity);
    double rawFatLow = rateLow * clampedDays;
    double rawFatHigh = rateHigh * clampedDays;

    // Bound by observed scale delta
    double deltaW = currentWeight - preReentryWeight;
    if (deltaW >= 0) {
      rawFatHigh = rawFatHigh.clamp(double.negativeInfinity, deltaW);
      rawFatLow = rawFatLow.clamp(double.negativeInfinity, deltaW);
    } else {
      rawFatLow = rawFatLow.clamp(deltaW, double.infinity);
      rawFatHigh = rawFatHigh.clamp(deltaW, double.infinity);
    }

    // Smooth blend toward new estimate (35% new, 65% old)
    double newLow = _lerp(previousEstimateLow, rawFatLow, 0.35);
    double newHigh = _lerp(previousEstimateHigh, rawFatHigh, 0.35);

    // Anti-punish guardrail: prevent sharp upward jumps
    if (lastRefineWeightDate != null) {
      DateTime now = DateTime.now();
      int daysSinceLastRefine = now.difference(lastRefineWeightDate).inDays.clamp(1, double.infinity as int);
      double maxIncreaseLow = 0.3 * daysSinceLastRefine;
      double maxIncreaseHigh = 0.3 * daysSinceLastRefine;

      newLow = newLow.clamp(previousEstimateLow - maxIncreaseLow, double.infinity);
      newHigh = (newHigh).clamp(double.negativeInfinity, previousEstimateHigh + maxIncreaseHigh);
    }

    // Ensure bounds are valid
    if (newLow > newHigh) {
      (newLow, newHigh) = (newHigh, newLow);
    }

    return (low: newLow, high: newHigh);
  }

  /// Linear interpolation helper
  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0, 1);
  }

  /// Format fat estimate for display
  static String formatFatEstimate(double? low, double? high) {
    if (low == null || high == null) {
      return 'Not available';
    }

    // Round to 0.1 lb
    double roundedLow = (low * 10).round() / 10;
    double roundedHigh = (high * 10).round() / 10;

    // Check if both are near zero
    if (roundedLow.abs() < 0.05 && roundedHigh.abs() < 0.05) {
      return 'No meaningful fat change detected';
    }

    if (roundedLow >= 0) {
      return 'Estimated fat gain: $roundedLow to $roundedHigh lb';
    } else if (roundedHigh <= 0) {
      return 'Estimated fat loss: ${roundedLow.abs().toStringAsFixed(1)} to ${roundedHigh.abs().toStringAsFixed(1)} lb';
    } else {
      return 'Estimated fat change: $roundedLow to $roundedHigh lb';
    }
  }

  /// Get days in reentry window
  static int getReentryDays(DateTime startDate, {DateTime? endDate}) {
    final actualEndDate = endDate ?? DateTime.now();
    return actualEndDate.difference(startDate).inDays.clamp(1, double.infinity as int);
  }
}
