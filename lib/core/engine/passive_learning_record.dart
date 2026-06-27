/// Foundation data class for the passive learning system.
///
/// V1: Records are tracked and stored but NOT used to auto-adjust calibration.
/// The adaptive adjustment logic is a stub — this class is infrastructure for
/// future versions.
///
/// Future versions may use these records to:
///   • Refine wearable device calibration multipliers
///   • Refine per-bucket MET / wearable blend weights
///   • Personalise energy estimation per user
class PassiveLearningRecord {
  final int userId;
  final DateTime date;

  /// TDEE estimated by the formula on this day (kcal).
  final double predictedTDEE;

  /// Actual weight change observed vs previous day (lbs).
  /// Null if weight was not logged on either day.
  final double? actualWeightChangeLbs;

  /// Expected weight change derived from calorie math (lbs).
  final double? expectedWeightChangeLbs;

  /// Prediction error: actual − expected (lbs).
  /// Positive = less loss than expected (TDEE may be overestimated).
  /// Negative = more loss than expected (TDEE may be underestimated).
  final double? predictionErrorLbs;

  /// Wearable family that contributed workout data (storage string form).
  final String? wearableFamily;

  /// Internal workout bucket for the primary workout.
  final String? workoutBucket;

  /// Raw workout type string from HealthKit / Health Connect.
  final String? rawWorkoutType;

  /// Whether food intake was logged for this day.
  final bool intakeLogged;

  /// Whether body weight was logged for this day.
  final bool weightLogged;

  const PassiveLearningRecord({
    required this.userId,
    required this.date,
    required this.predictedTDEE,
    this.actualWeightChangeLbs,
    this.expectedWeightChangeLbs,
    this.predictionErrorLbs,
    this.wearableFamily,
    this.workoutBucket,
    this.rawWorkoutType,
    required this.intakeLogged,
    required this.weightLogged,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'date': date.toIso8601String(),
    'predictedTDEE': predictedTDEE,
    'actualWeightChangeLbs': actualWeightChangeLbs,
    'expectedWeightChangeLbs': expectedWeightChangeLbs,
    'predictionErrorLbs': predictionErrorLbs,
    'wearableFamily': wearableFamily,
    'workoutBucket': workoutBucket,
    'rawWorkoutType': rawWorkoutType,
    'intakeLogged': intakeLogged ? 1 : 0,
    'weightLogged': weightLogged ? 1 : 0,
  };

  factory PassiveLearningRecord.fromMap(Map<String, dynamic> map) =>
      PassiveLearningRecord(
        userId: map['userId'] as int,
        date: DateTime.parse(map['date'] as String),
        predictedTDEE: (map['predictedTDEE'] as num).toDouble(),
        actualWeightChangeLbs: (map['actualWeightChangeLbs'] as num?)
            ?.toDouble(),
        expectedWeightChangeLbs: (map['expectedWeightChangeLbs'] as num?)
            ?.toDouble(),
        predictionErrorLbs: (map['predictionErrorLbs'] as num?)?.toDouble(),
        wearableFamily: map['wearableFamily'] as String?,
        workoutBucket: map['workoutBucket'] as String?,
        rawWorkoutType: map['rawWorkoutType'] as String?,
        intakeLogged: (map['intakeLogged'] as int? ?? 0) == 1,
        weightLogged: (map['weightLogged'] as int? ?? 0) == 1,
      );

  /// V1 stub: Returns null. Future versions will emit an adjustment suggestion.
  // ignore: unused_element
  double? get suggestedCalibrationAdjustment => null;
}
