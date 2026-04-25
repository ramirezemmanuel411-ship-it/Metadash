import 'package:uuid/uuid.dart';

class UserFoodItem {
  final String id;
  final int userId;
  final String name;
  final String? brand;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? servingSize;
  final String? servingUnit;
  final DateTime? lastUsed;
  final DateTime createdAt;

  UserFoodItem({
    required this.id,
    required this.userId,
    required this.name,
    this.brand,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.servingSize,
    this.servingUnit,
    this.lastUsed,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  UserFoodItem copyWith({
    String? id,
    int? userId,
    String? name,
    String? brand,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? servingSize,
    String? servingUnit,
    DateTime? lastUsed,
    DateTime? createdAt,
  }) {
    return UserFoodItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      lastUsed: lastUsed ?? this.lastUsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static UserFoodItem createNew({
    required int userId,
    required String name,
    String? brand,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double? servingSize,
    String? servingUnit,
  }) {
    return UserFoodItem(
      id: const Uuid().v4(),
      userId: userId,
      name: name,
      brand: brand,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      servingSize: servingSize,
      servingUnit: servingUnit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'brand': brand,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'lastUsed': lastUsed?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserFoodItem.fromMap(Map<String, dynamic> map) {
    return UserFoodItem(
      id: map['id'],
      userId: map['userId'],
      name: map['name'],
      brand: map['brand'],
      calories: (map['calories'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      servingSize: map['servingSize'] != null ? (map['servingSize'] as num).toDouble() : null,
      servingUnit: map['servingUnit'],
      lastUsed: map['lastUsed'] != null ? DateTime.parse(map['lastUsed']) : null,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
