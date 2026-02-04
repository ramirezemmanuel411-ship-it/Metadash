class DailyLog {
  final int? id;
  final int userId;
  final DateTime date;
  final int caloriesConsumed;
  final int stepsCount;
  final int? runningSteps; // Running steps (for TDEE calculation)
  final int? workoutCalories; // Device-reported active calories (Apple Watch, etc.)
  final String? workoutType; // 'Running', 'Strength', 'Cardio', etc.
  final double waterIntake; // in ounces
  final List<String> workoutActivities; // JSON serialized
  final int protein; // in grams
  final int carbs; // in grams
  final int fat; // in grams
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyLog({
    this.id,
    required this.userId,
    required this.date,
    required this.caloriesConsumed,
    required this.stepsCount,
    this.runningSteps,
    this.workoutCalories,
    this.workoutType,
    required this.waterIntake,
    required this.workoutActivities,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'caloriesConsumed': caloriesConsumed,
      'stepsCount': stepsCount,
      'runningSteps': runningSteps,
      'workoutCalories': workoutCalories,
      'workoutType': workoutType,
      'waterIntake': waterIntake,
      'workoutActivities': workoutActivities.join(','), // Store as comma-separated
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      id: map['id'],
      userId: map['userId'],
      date: DateTime.parse(map['date']),
      caloriesConsumed: map['caloriesConsumed'],
      stepsCount: map['stepsCount'],
      runningSteps: map['runningSteps'],
      workoutCalories: map['workoutCalories'],
      workoutType: map['workoutType'],
      waterIntake: (map['waterIntake'] as num).toDouble(),
      workoutActivities: (map['workoutActivities'] as String).isEmpty ? [] : (map['workoutActivities'] as String).split(','),
      protein: map['protein'],
      carbs: map['carbs'],
      fat: map['fat'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  DailyLog copyWith({
    int? id,
    int? userId,
    DateTime? date,
    int? caloriesConsumed,
    int? stepsCount,
    int? runningSteps,
    int? workoutCalories,
    String? workoutType,
    double? waterIntake,
    List<String>? workoutActivities,
    int? protein,
    int? carbs,
    int? fat,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      caloriesConsumed: caloriesConsumed ?? this.caloriesConsumed,
      stepsCount: stepsCount ?? this.stepsCount,
      runningSteps: runningSteps ?? this.runningSteps,
      workoutCalories: workoutCalories ?? this.workoutCalories,
      workoutType: workoutType ?? this.workoutType,
      waterIntake: waterIntake ?? this.waterIntake,
      workoutActivities: workoutActivities ?? this.workoutActivities,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
