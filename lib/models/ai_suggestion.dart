enum AiSuggestionMode {
  none,
  meal,
  singleItem,
}

class AiSuggestionTotals {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const AiSuggestionTotals({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

class AiMealSuggestion {
  final String title;
  final String description;
  final List<String> items;
  final AiSuggestionTotals totals;
  final double confidence;
  final String source;
  final Map<String, dynamic> addActionPayload;

  const AiMealSuggestion({
    required this.title,
    required this.description,
    required this.items,
    required this.totals,
    required this.confidence,
    required this.source,
    required this.addActionPayload,
  });
}

class AiSingleItemSuggestion {
  final String foodName;
  final String serving;
  final AiSuggestionTotals totals;
  final double confidence;
  final String source;
  final Map<String, dynamic> addActionPayload;

  const AiSingleItemSuggestion({
    required this.foodName,
    required this.serving,
    required this.totals,
    required this.confidence,
    required this.source,
    required this.addActionPayload,
  });
}

class AiSuggestionGroup {
  final String title;
  final List<AiSingleItemSuggestion> items;

  const AiSuggestionGroup({
    required this.title,
    required this.items,
  });
}

class AiSuggestionResponse {
  final AiSuggestionMode mode;
  final String message;
  final List<AiMealSuggestion> meals;
  final List<AiSuggestionGroup> groups;

  const AiSuggestionResponse({
    required this.mode,
    required this.message,
    this.meals = const [],
    this.groups = const [],
  });
}

class AiSuggestionInput {
  final int calLeft;
  final int? calorieLimit;
  final int pLeft;
  final int cLeft;
  final int fLeft;
  final int pTarget;
  final int cTarget;
  final int fTarget;
  final String query;
  final String? restaurantName;

  const AiSuggestionInput({
    required this.calLeft,
    this.calorieLimit,
    required this.pLeft,
    required this.cLeft,
    required this.fLeft,
    required this.pTarget,
    required this.cTarget,
    required this.fTarget,
    required this.query,
    this.restaurantName,
  });
}

class AiSuggestionIntent {
  final bool isSuggestionIntent;
  final bool isRestaurantIntent;
  final String? restaurantName;

  const AiSuggestionIntent({
    required this.isSuggestionIntent,
    required this.isRestaurantIntent,
    this.restaurantName,
  });
}
