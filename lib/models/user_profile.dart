import 'dart:convert';

class UserProfile {
  final int? id;
  final String name;
  final String email;
  final double weight; // in lbs
  final double height; // in inches
  final int age;
  final String gender; // 'Male', 'Female', 'Other'
  final DateTime dateOfBirth;
  final double bmr; // Basal Metabolic Rate
  final double goalWeight;
  final int dailyCaloricGoal;
  final String activityLevel; // 'Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'
  final int dailyStepsGoal;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int>? macroTargets; // {protein, carbs, fat} in grams

  UserProfile({
    this.id,
    required this.name,
    required this.email,
    required this.weight,
    required this.height,
    required this.age,
    required this.gender,
    required this.dateOfBirth,
    required this.bmr,
    required this.goalWeight,
    required this.dailyCaloricGoal,
    required this.activityLevel,
    required this.dailyStepsGoal,
    required this.createdAt,
    required this.updatedAt,
    this.macroTargets,
  });

  // Convert UserProfile to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'weight': weight,
      'height': height,
      'age': age,
      'gender': gender,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'bmr': bmr,
      'goalWeight': goalWeight,
      'dailyCaloricGoal': dailyCaloricGoal,
      'activityLevel': activityLevel,
      'dailyStepsGoal': dailyStepsGoal,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'macroTargets': macroTargets != null ? jsonEncode(macroTargets) : null,
    };
  }

  // Create UserProfile from Map
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      weight: (map['weight'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      age: map['age'],
      gender: map['gender'],
      dateOfBirth: DateTime.parse(map['dateOfBirth']),
      bmr: (map['bmr'] as num).toDouble(),
      goalWeight: (map['goalWeight'] as num).toDouble(),
      dailyCaloricGoal: map['dailyCaloricGoal'],
      activityLevel: map['activityLevel'],
      dailyStepsGoal: map['dailyStepsGoal'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      macroTargets: map['macroTargets'] != null ? Map<String, int>.from(jsonDecode(map['macroTargets'])) : null,
    );
  }

  // Copy with updates
  UserProfile copyWith({
    int? id,
    String? name,
    String? email,
    double? weight,
    double? height,
    int? age,
    String? gender,
    DateTime? dateOfBirth,
    double? bmr,
    double? goalWeight,
    int? dailyCaloricGoal,
    String? activityLevel,
    int? dailyStepsGoal,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, int>? macroTargets,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bmr: bmr ?? this.bmr,
      goalWeight: goalWeight ?? this.goalWeight,
      dailyCaloricGoal: dailyCaloricGoal ?? this.dailyCaloricGoal,
      activityLevel: activityLevel ?? this.activityLevel,
      dailyStepsGoal: dailyStepsGoal ?? this.dailyStepsGoal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      macroTargets: macroTargets ?? this.macroTargets,
    );
  }
}
