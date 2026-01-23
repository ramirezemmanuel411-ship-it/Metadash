class Nutrient {
  final NutrientCategory category;
  final int amount;
  Nutrient({required this.category, required this.amount});
}

enum NutrientCategory { protein, carbs, fat }

class FoodItem {
  final String name;
  final int calories;
  final String macroLine;
  const FoodItem({required this.name, required this.calories, required this.macroLine});
}

enum FoodItemV2 {
  eggLarge,
  chickenBreast,
}

extension FoodItemV2Info on FoodItemV2 {
  String get name {
    switch (this) {
      case FoodItemV2.eggLarge:
        return 'Egg (large)';
      case FoodItemV2.chickenBreast:
        return 'Chicken Breast';
    }
  }

  int get calories {
    switch (this) {
      case FoodItemV2.eggLarge:
        return 78;
      case FoodItemV2.chickenBreast:
        return 165;
    }
  }

  List<Nutrient> get nutrients {
    switch (this) {
      case FoodItemV2.eggLarge:
        return [Nutrient(category: NutrientCategory.protein, amount: 6)];
      case FoodItemV2.chickenBreast:
        return [Nutrient(category: NutrientCategory.protein, amount: 31)];
    }
  }
}

enum MealName { breakfast, lunch, dinner }

const mockFoods = <FoodItem>[
  FoodItem(name: 'Chicken Breast', calories: 165, macroLine: 'P 31g • C 0g • F 3g'),
  FoodItem(name: 'Greek Yogurt', calories: 100, macroLine: 'P 17g • C 6g • F 0g'),
  FoodItem(name: 'Oats', calories: 150, macroLine: 'P 5g • C 27g • F 3g'),
  FoodItem(name: 'Banana', calories: 105, macroLine: 'P 1g • C 27g • F 0g'),
];
