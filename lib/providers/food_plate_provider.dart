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

  // Base (one-serving) macros + serving weight, so the plate can rescale macros
  // by weight when the serving/unit changes — not just relabel.
  final double baseCalories;
  final double baseProtein;
  final double baseCarbs;
  final double baseFat;
  final double? baseGrams;

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
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
    this.baseGrams,
  })  : addedAt = addedAt ?? DateTime.now(),
        baseCalories = baseCalories ?? calories.toDouble(),
        baseProtein = baseProtein ?? proteinG.toDouble(),
        baseCarbs = baseCarbs ?? carbsG.toDouble(),
        baseFat = baseFat ?? fatG.toDouble();

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
      baseCalories: baseCalories,
      baseProtein: baseProtein,
      baseCarbs: baseCarbs,
      baseFat: baseFat,
      baseGrams: baseGrams,
    );
  }

  /// Grams per one unit (named units resolve to one base serving's weight).
  static const unitGrams = <String, double>{
    'g': 1.0,
    'oz': 28.3495,
    'lb': 453.592,
    'ml': 1.0,
    'fl oz': 29.5735,
    'cup': 236.588,
    'tbsp': 14.787,
    'tsp': 4.929,
  };

  /// Grams represented by [quantity] of [unit].
  double? gramsFor(double quantity, String unit) {
    final w = unitGrams[unit.toLowerCase()];
    if (w != null) return quantity * w;
    if (baseGrams != null && baseGrams! > 0) return quantity * baseGrams!;
    return null;
  }

  /// A copy rescaled to [quantity]/[unit], recomputing macros. Uses the gram
  /// ratio when a serving weight is known, else scales by the serving count.
  FoodPlateItem rescaled(double quantity, String unit) {
    final qtyStr = quantity == quantity.truncateToDouble()
        ? quantity.truncate().toString()
        : quantity.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    final servingStr = '$qtyStr $unit';
    final grams = gramsFor(quantity, unit);
    // Scale by the gram ratio when we have a weight basis; otherwise treat the
    // quantity as a serving-count multiplier (1 unit == one base serving). This
    // mirrors the keypad's live preview so grams-less items (AI estimates, foods
    // without a serving weight) still rescale instead of only relabeling.
    final m = (grams != null && baseGrams != null && baseGrams! > 0)
        ? grams / baseGrams!
        : quantity;
    return copyWith(
      calories: (baseCalories * m).round(),
      proteinG: (baseProtein * m).round(),
      carbsG: (baseCarbs * m).round(),
      fatG: (baseFat * m).round(),
      serving: servingStr,
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
