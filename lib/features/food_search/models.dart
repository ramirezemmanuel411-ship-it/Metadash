class FoodItem {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  String get macroLine =>
      'P ${_formatMacro(protein)} • C ${_formatMacro(carbs)} • F ${_formatMacro(fat)}';

  String _formatMacro(double value) {
    if (value <= 0) return '0g';
    final formatted = value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '${formatted}g';
  }
}

enum MealName { breakfast, lunch, dinner }

const mockFoods = <FoodItem>[
  FoodItem(name: 'Chicken Breast', calories: 165, protein: 31, carbs: 0, fat: 3),
  FoodItem(name: 'Greek Yogurt', calories: 100, protein: 17, carbs: 6, fat: 0),
  FoodItem(name: 'Oats', calories: 150, protein: 5, carbs: 27, fat: 3),
  FoodItem(name: 'Banana', calories: 105, protein: 1, carbs: 27, fat: 0),
];
