import '../models/reentry_mode_state.dart';
import 'database_service.dart';
import 'fat_estimate_calculator.dart';

class ReentryModeService {
  final DatabaseService _databaseService;

  ReentryModeService({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  /// Start reentry mode for a user
  Future<void> startReentryMode({
    required int userId,
    required DateTime startDate,
    DateTime? endDate,
    double? preReentryWeight,
  }) async {
    final state = ReentryModeState(
      userId: userId.toString(),
      isActive: true,
      startDate: startDate,
      endDate: endDate,
      preReentryWeight: preReentryWeight,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _databaseService.createOrUpdateReentryMode(state);
  }

  /// Get current reentry mode state for user
  Future<ReentryModeState?> getReentryMode(int userId) async {
    return await _databaseService.getReentryModeState(userId);
  }

  /// End reentry mode (return flow)
  Future<void> endReentryMode({
    required int userId,
    required double returnWeight,
    required IntakeDelta intakeDelta,
    required ActivityDelta activityDelta,
  }) async {
    final currentState = await _databaseService.getReentryModeState(userId);
    if (currentState == null || !currentState.isActive) {
      throw Exception('Reentry mode is not currently active');
    }

    // Calculate reentry window days
    final reentryDays = FatEstimateCalculator.getReentryDays(
      currentState.startDate,
      endDate: currentState.endDate,
    );

    // Get preReentryWeight (use provided or from current state or estimate as current)
    final preWeight = currentState.preReentryWeight ?? returnWeight;

    // Calculate fat estimate
    final estimate = FatEstimateCalculator.calculateFatEstimate(
      preReentryWeight: preWeight,
      returnWeight: returnWeight,
      intakeDelta: intakeDelta,
      activityDelta: activityDelta,
      reentryDays: reentryDays,
    );

    // Update state: mark inactive and set estimates
    final updatedState = currentState.copyWith(
      isActive: false,
      returnWeight: returnWeight,
      intakeDelta: intakeDelta,
      activityDelta: activityDelta,
      fatEstimateLowLb: estimate.low,
      fatEstimateHighLb: estimate.high,
      refineUntil: DateTime.now().add(const Duration(days: 7)),
      lastRefineWeightDate: DateTime.now(),
      lastKnownWeight: returnWeight,
    );

    await _databaseService.createOrUpdateReentryMode(updatedState);
  }

  /// Refine fat estimate on new weigh-in (called during post-return window)
  Future<void> refineEstimateOnWeighIn({
    required int userId,
    required double currentWeight,
  }) async {
    final currentState = await _databaseService.getReentryModeState(userId);
    if (currentState == null || currentState.isActive) {
      return; // Not in refinement window
    }

    // Check if we're still in the refinement window
    final now = DateTime.now();
    if (currentState.refineUntil == null ||
        now.isAfter(currentState.refineUntil!)) {
      return; // Refinement window has ended
    }

    // Don't refine if we already refined with this weight
    if (currentState.lastKnownWeight != null &&
        (currentState.lastKnownWeight! - currentWeight).abs() < 0.1) {
      return; // Same weight (within margin), skip refinement
    }

    final preWeight =
        currentState.preReentryWeight ?? currentState.returnWeight;
    if (preWeight == null) return; // Can't refine without baseline

    // Calculate days from reentry start to current weigh-in
    final daysSinceReentryStart = currentWeight == currentState.lastKnownWeight
        ? FatEstimateCalculator.getReentryDays(
            currentState.startDate,
            endDate: currentState.endDate,
          )
        : now
              .difference(currentState.startDate)
              .inDays
              .clamp(1, double.infinity as int);

    final refined = FatEstimateCalculator.refineFatEstimate(
      preReentryWeight: preWeight,
      currentWeight: currentWeight,
      intakeDelta: currentState.intakeDelta ?? IntakeDelta.same,
      activityDelta: currentState.activityDelta ?? ActivityDelta.same,
      reentryStartToCurrentDays: daysSinceReentryStart,
      previousEstimateLow: currentState.fatEstimateLowLb ?? 0.0,
      previousEstimateHigh: currentState.fatEstimateHighLb ?? 0.0,
      lastRefineWeightDate: currentState.lastRefineWeightDate,
    );

    // Update with refined estimates
    final updatedState = currentState.copyWith(
      fatEstimateLowLb: refined.low,
      fatEstimateHighLb: refined.high,
      lastRefineWeightDate: now,
      lastKnownWeight: currentWeight,
    );

    await _databaseService.createOrUpdateReentryMode(updatedState);
  }

  /// Check if a date falls within active reentry window
  Future<bool> isDateInReentryWindow(int userId, DateTime date) async {
    return await _databaseService.isDateInReentryWindow(userId, date);
  }

  /// Get daily logs excluding reentry window
  Future<List<dynamic>> getDailyLogsExcludingReentry(
    int userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _databaseService.getDailyLogsExcludingReentry(
      userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Format fat estimate for display
  String formatFatEstimate(ReentryModeState? state) {
    if (state == null ||
        state.fatEstimateLowLb == null ||
        state.fatEstimateHighLb == null) {
      return 'Not available';
    }
    return FatEstimateCalculator.formatFatEstimate(
      state.fatEstimateLowLb,
      state.fatEstimateHighLb,
    );
  }

  /// Clear reentry mode data for user
  Future<void> clearReentryMode(int userId) async {
    await _databaseService.deleteReentryMode(userId);
  }
}
