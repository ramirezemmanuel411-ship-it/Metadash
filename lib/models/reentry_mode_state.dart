enum IntakeDelta { less, same, more }

enum ActivityDelta { less, same, more }

class ReentryModeState {
  final String userId;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final double? preReentryWeight;
  final double? returnWeight;
  final IntakeDelta? intakeDelta;
  final ActivityDelta? activityDelta;
  final double? fatEstimateLowLb;
  final double? fatEstimateHighLb;
  final DateTime? refineUntil;
  final DateTime? lastRefineWeightDate;
  final double? lastKnownWeight;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReentryModeState({
    required this.userId,
    required this.isActive,
    required this.startDate,
    this.endDate,
    this.preReentryWeight,
    this.returnWeight,
    this.intakeDelta,
    this.activityDelta,
    this.fatEstimateLowLb,
    this.fatEstimateHighLb,
    this.refineUntil,
    this.lastRefineWeightDate,
    this.lastKnownWeight,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the current excluded range (for excluding from goal evaluation)
  DateRange get excludedRange {
    final actualEndDate = endDate ?? DateTime.now();
    return DateRange(startDate, actualEndDate);
  }

  /// Check if a given date is within the reentry window
  bool isInReentryWindow(DateTime date) {
    if (!isActive) return false;
    return excludedRange.contains(date);
  }

  /// Create a copy with updated fields
  ReentryModeState copyWith({
    bool? isActive,
    DateTime? startDate,
    DateTime? endDate,
    double? preReentryWeight,
    double? returnWeight,
    IntakeDelta? intakeDelta,
    ActivityDelta? activityDelta,
    double? fatEstimateLowLb,
    double? fatEstimateHighLb,
    DateTime? refineUntil,
    DateTime? lastRefineWeightDate,
    double? lastKnownWeight,
  }) {
    return ReentryModeState(
      userId: userId,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      endDate: endDate,
      preReentryWeight: preReentryWeight ?? this.preReentryWeight,
      returnWeight: returnWeight ?? this.returnWeight,
      intakeDelta: intakeDelta ?? this.intakeDelta,
      activityDelta: activityDelta ?? this.activityDelta,
      fatEstimateLowLb: fatEstimateLowLb ?? this.fatEstimateLowLb,
      fatEstimateHighLb: fatEstimateHighLb ?? this.fatEstimateHighLb,
      refineUntil: refineUntil,
      lastRefineWeightDate: lastRefineWeightDate ?? this.lastRefineWeightDate,
      lastKnownWeight: lastKnownWeight ?? this.lastKnownWeight,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isActive': isActive ? 1 : 0,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'preReentryWeight': preReentryWeight,
      'returnWeight': returnWeight,
      'intakeDelta': intakeDelta?.toString().split('.').last,
      'activityDelta': activityDelta?.toString().split('.').last,
      'fatEstimateLowLb': fatEstimateLowLb,
      'fatEstimateHighLb': fatEstimateHighLb,
      'refineUntil': refineUntil?.toIso8601String(),
      'lastRefineWeightDate': lastRefineWeightDate?.toIso8601String(),
      'lastKnownWeight': lastKnownWeight,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON stored data
  factory ReentryModeState.fromMap(Map<String, dynamic> map) {
    return ReentryModeState(
      userId: map['userId'] as String,
      isActive: (map['isActive'] as int) == 1,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      preReentryWeight: map['preReentryWeight'] as double?,
      returnWeight: map['returnWeight'] as double?,
      intakeDelta: map['intakeDelta'] != null
          ? IntakeDelta.values.byName(map['intakeDelta'] as String)
          : null,
      activityDelta: map['activityDelta'] != null
          ? ActivityDelta.values.byName(map['activityDelta'] as String)
          : null,
      fatEstimateLowLb: map['fatEstimateLowLb'] as double?,
      fatEstimateHighLb: map['fatEstimateHighLb'] as double?,
      refineUntil: map['refineUntil'] != null
          ? DateTime.parse(map['refineUntil'] as String)
          : null,
      lastRefineWeightDate: map['lastRefineWeightDate'] != null
          ? DateTime.parse(map['lastRefineWeightDate'] as String)
          : null,
      lastKnownWeight: map['lastKnownWeight'] as double?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

/// Helper class for date ranges used in reentry exclusion
class DateRange {
  final DateTime startDate;
  final DateTime endDate;

  DateRange(this.startDate, this.endDate);

  /// Check if a date falls within this range (inclusive)
  bool contains(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
    return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly);
  }
}
