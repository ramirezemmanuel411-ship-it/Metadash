import 'package:flutter/foundation.dart';
import '../models/diary_entry_food.dart';

/// A single staging item on the Food Plate.
/// Wraps [DiaryEntryFood] so we can reuse its rich fields.
class FoodPlateItem {
  final String id;
  final String name;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String source;
  final String? serving;
  final DateTime addedAt;

  FoodPlateItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.source,
    this.serving,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  FoodPlateItem copyWith({
    int? calories,
    int? proteinG,
    int? carbsG,
    int? fatG,
    String? serving,
  }) {
    return FoodPlateItem(
      id: id,
      name: name,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      source: source,
      serving: serving ?? this.serving,
      addedAt: addedAt,
    );
  }

  /// Convert to a DiaryEntryFood for persisting to the database.
  DiaryEntryFood toDiaryEntry({
    required int userId,
    required DateTime timestamp,
  }) {
    return DiaryEntryFood(
      id: '${DateTime.now().millisecondsSinceEpoch}_$id',
      userId: userId,
      timestamp: timestamp,
      name: name,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      source: source,
      serving: serving,
    );
  }
}

/// Keeps track of the user's pre-diary Food Plate (staging area).
class FoodPlateProvider extends ChangeNotifier {
  final List<FoodPlateItem> _items = [];

  List<FoodPlateItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get itemCount => _items.length;

  int get totalCalories => _items.fold(0, (s, i) => s + i.calories);
  int get totalProtein  => _items.fold(0, (s, i) => s + i.proteinG);
  int get totalCarbs    => _items.fold(0, (s, i) => s + i.carbsG);
  int get totalFat      => _items.fold(0, (s, i) => s + i.fatG);

  void add(FoodPlateItem item) {
    _items.add(item);
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void update(String id, FoodPlateItem updated) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    _items[idx] = updated;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
