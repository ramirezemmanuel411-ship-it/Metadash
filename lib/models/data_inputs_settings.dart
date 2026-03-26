class DataInputsSettings {
  final int userId;
  final String stepCalorieMethod;
  final int stepGoal;
  final bool includeStepsInExpenditure;
  final bool useTrackedWorkoutCalories;
  final String workoutAccuracy;
  final bool includeStrengthInExpenditure;
  final String foodPrimarySource;
  final bool showVerifiedItemsFirst;
  final bool preferBarcodeMatches;
  final String macroCalcMode;
  final bool showFiber;
  final bool showSugar;
  final bool appleHealthConnected;
  final bool googleFitConnected;
  final bool garminConnected;
  final bool fitbitConnected;
  final bool stravaConnected;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DataInputsSettings({
    required this.userId,
    required this.stepCalorieMethod,
    required this.stepGoal,
    required this.includeStepsInExpenditure,
    required this.useTrackedWorkoutCalories,
    required this.workoutAccuracy,
    required this.includeStrengthInExpenditure,
    required this.foodPrimarySource,
    required this.showVerifiedItemsFirst,
    required this.preferBarcodeMatches,
    required this.macroCalcMode,
    required this.showFiber,
    required this.showSugar,
    required this.appleHealthConnected,
    required this.googleFitConnected,
    required this.garminConnected,
    required this.fitbitConnected,
    required this.stravaConnected,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DataInputsSettings.defaults(int userId) {
    final now = DateTime.now();
    return DataInputsSettings(
      userId: userId,
      stepCalorieMethod: 'Standard',
      stepGoal: 8000,
      includeStepsInExpenditure: true,
      useTrackedWorkoutCalories: true,
      workoutAccuracy: 'Balanced',
      includeStrengthInExpenditure: true,
      foodPrimarySource: 'Branded Database',
      showVerifiedItemsFirst: true,
      preferBarcodeMatches: true,
      macroCalcMode: 'Standard (4/4/9)',
      showFiber: true,
      showSugar: false,
      appleHealthConnected: false,
      googleFitConnected: false,
      garminConnected: false,
      fitbitConnected: false,
      stravaConnected: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  DataInputsSettings copyWith({
    String? stepCalorieMethod,
    int? stepGoal,
    bool? includeStepsInExpenditure,
    bool? useTrackedWorkoutCalories,
    String? workoutAccuracy,
    bool? includeStrengthInExpenditure,
    String? foodPrimarySource,
    bool? showVerifiedItemsFirst,
    bool? preferBarcodeMatches,
    String? macroCalcMode,
    bool? showFiber,
    bool? showSugar,
    bool? appleHealthConnected,
    bool? googleFitConnected,
    bool? garminConnected,
    bool? fitbitConnected,
    bool? stravaConnected,
    DateTime? updatedAt,
  }) {
    return DataInputsSettings(
      userId: userId,
      stepCalorieMethod: stepCalorieMethod ?? this.stepCalorieMethod,
      stepGoal: stepGoal ?? this.stepGoal,
      includeStepsInExpenditure: includeStepsInExpenditure ?? this.includeStepsInExpenditure,
      useTrackedWorkoutCalories: useTrackedWorkoutCalories ?? this.useTrackedWorkoutCalories,
      workoutAccuracy: workoutAccuracy ?? this.workoutAccuracy,
      includeStrengthInExpenditure: includeStrengthInExpenditure ?? this.includeStrengthInExpenditure,
      foodPrimarySource: foodPrimarySource ?? this.foodPrimarySource,
      showVerifiedItemsFirst: showVerifiedItemsFirst ?? this.showVerifiedItemsFirst,
      preferBarcodeMatches: preferBarcodeMatches ?? this.preferBarcodeMatches,
      macroCalcMode: macroCalcMode ?? this.macroCalcMode,
      showFiber: showFiber ?? this.showFiber,
      showSugar: showSugar ?? this.showSugar,
      appleHealthConnected: appleHealthConnected ?? this.appleHealthConnected,
      googleFitConnected: googleFitConnected ?? this.googleFitConnected,
      garminConnected: garminConnected ?? this.garminConnected,
      fitbitConnected: fitbitConnected ?? this.fitbitConnected,
      stravaConnected: stravaConnected ?? this.stravaConnected,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'stepCalorieMethod': stepCalorieMethod,
      'stepGoal': stepGoal,
      'includeStepsInExpenditure': includeStepsInExpenditure ? 1 : 0,
      'useTrackedWorkoutCalories': useTrackedWorkoutCalories ? 1 : 0,
      'workoutAccuracy': workoutAccuracy,
      'includeStrengthInExpenditure': includeStrengthInExpenditure ? 1 : 0,
      'foodPrimarySource': foodPrimarySource,
      'showVerifiedItemsFirst': showVerifiedItemsFirst ? 1 : 0,
      'preferBarcodeMatches': preferBarcodeMatches ? 1 : 0,
      'macroCalcMode': macroCalcMode,
      'showFiber': showFiber ? 1 : 0,
      'showSugar': showSugar ? 1 : 0,
      'appleHealthConnected': appleHealthConnected ? 1 : 0,
      'googleFitConnected': googleFitConnected ? 1 : 0,
      'garminConnected': garminConnected ? 1 : 0,
      'fitbitConnected': fitbitConnected ? 1 : 0,
      'stravaConnected': stravaConnected ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DataInputsSettings.fromMap(Map<String, dynamic> map) {
    return DataInputsSettings(
      userId: map['userId'],
      stepCalorieMethod: map['stepCalorieMethod'] as String,
      stepGoal: map['stepGoal'] as int,
      includeStepsInExpenditure: (map['includeStepsInExpenditure'] as int) == 1,
      useTrackedWorkoutCalories: (map['useTrackedWorkoutCalories'] as int) == 1,
      workoutAccuracy: map['workoutAccuracy'] as String,
      includeStrengthInExpenditure: (map['includeStrengthInExpenditure'] as int) == 1,
      foodPrimarySource: map['foodPrimarySource'] as String,
      showVerifiedItemsFirst: (map['showVerifiedItemsFirst'] as int) == 1,
      preferBarcodeMatches: (map['preferBarcodeMatches'] as int) == 1,
      macroCalcMode: map['macroCalcMode'] as String,
      showFiber: (map['showFiber'] as int) == 1,
      showSugar: (map['showSugar'] as int) == 1,
      appleHealthConnected: (map['appleHealthConnected'] as int) == 1,
      googleFitConnected: (map['googleFitConnected'] as int) == 1,
      garminConnected: (map['garminConnected'] as int) == 1,
      fitbitConnected: (map['fitbitConnected'] as int) == 1,
      stravaConnected: (map['stravaConnected'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
