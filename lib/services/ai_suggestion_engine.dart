import 'package:flutter/foundation.dart';
import '../data/models/food_model.dart';
import '../models/ai_suggestion.dart';

class AiSuggestionEngine {
  static const double _high = 0.25;
  static const double _med = 0.12;

  int _effectiveCalLeft(AiSuggestionInput input) {
    final limit = input.calorieLimit;
    if (limit == null || limit <= 0) return input.calLeft;
    if (input.calLeft <= 0) return input.calLeft;
    return input.calLeft < limit ? input.calLeft : limit;
  }

  String _titleCaseRestaurant(String? name) {
    if (name == null || name.trim().isEmpty) return 'Meal';
    final cleaned = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          if (lower == 'kfc') return 'KFC';
          if (lower == 'mcdonalds' || lower == 'mcdonald') return "McDonald's";
          if (lower == 'cava') return 'CAVA';
          if (lower == 'in-n-out' || lower == 'in') return 'In-N-Out';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _resolveRestaurantName(FoodModel food, String? requestName) {
    final candidate = requestName?.trim().isNotEmpty == true
        ? requestName
        : (food.restaurantName ?? food.brandName ?? food.brand);
    return _titleCaseRestaurant(candidate);
  }

  List<String> _extractMenuItems(FoodModel food) {
    final rawName = (food.foodName ?? food.name).trim();
    final rawDesc = food.rawJson?['food_description']?.toString() ?? '';
    final parts = <String>[];

    void addPartsFrom(String text) {
      if (text.isEmpty) return;
      final cleaned = text
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\s*\([^\)]*\)'), '')
          .trim();
      if (cleaned.isEmpty) return;

      final split = cleaned
          .split(RegExp(r'\s*(?:,|\+|/|\-|–|—| with | w/ )\s*'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      parts.addAll(split);
    }

    addPartsFrom(rawName);

    if (parts.length < 2) {
      final descMatch = RegExp(r'Per\s+(.+?)\s+-', caseSensitive: false)
          .firstMatch(rawDesc);
      if (descMatch != null) {
        addPartsFrom(descMatch.group(1) ?? '');
      }
    }

    // Remove duplicates and overly generic tokens
    final seen = <String>{};
    final filtered = <String>[];
    for (final item in parts) {
      final normalized = item.toLowerCase();
      if (normalized == 'serving' || normalized == 'bowl' || normalized == 'meal') {
        continue;
      }
      if (seen.add(normalized)) {
        filtered.add(item);
      }
    }

    return filtered.isEmpty ? [food.name] : filtered;
  }

  AiSuggestionIntent detectIntent(String message) {
    final text = message.toLowerCase();

    final restaurantNames = [
      'chipotle',
      'cava',
      'starbucks',
      'texas roadhouse',
      'mcdonald',
      'mcdonalds',
      'taco bell',
      'subway',
      'panera',
      'wendy',
      'chick-fil-a',
      'chick fil a',
      'popeyes',
      'kfc',
      'domino',
      'pizza hut',
      'burger king',
      'in-n-out',
      'in n out',
    ];

    String? restaurantName;
    for (final name in restaurantNames) {
      if (text.contains(name)) {
        restaurantName = name;
        break;
      }
    }

    final hasRestaurantPhrase = text.contains('what can i order') ||
        text.contains('order at') ||
        text.contains('from ') ||
        text.contains('restaurant');

    final isRestaurantIntent = restaurantName != null || hasRestaurantPhrase;

    final isSuggestionIntent = text.contains('calories left') ||
        text.contains('calories remaining') ||
        text.contains('what can i eat') ||
        text.contains('what should i eat') ||
        text.contains('meal idea') ||
        text.contains('suggest') ||
        text.contains('what can i order') ||
        text.contains('order') ||
        text.contains('under') ||
        text.contains('remaining');

    return AiSuggestionIntent(
      isSuggestionIntent: isSuggestionIntent,
      isRestaurantIntent: isRestaurantIntent,
      restaurantName: restaurantName,
    );
  }

  AiSuggestionMode decideMode(AiSuggestionInput input) {
    final calLeft = _effectiveCalLeft(input);
    final pNeed = _need(input.pLeft);
    final cNeed = _need(input.cLeft);
    final fNeed = _need(input.fLeft);

    final calVeryTight = calLeft < 200;
    final calTight = calLeft < 350;

    final pRem = _ratio(pNeed, input.pTarget);
    final cRem = _ratio(cNeed, input.cTarget);
    final fRem = _ratio(fNeed, input.fTarget);

    final macroOpenCount = _count([pRem, cRem, fRem], _med);
    final macroHighCount = _count([pRem, cRem, fRem], _high);

    final proteinUrgent = (pRem >= 0.20) || (pNeed >= 35);

    if (calLeft <= 0) return AiSuggestionMode.none;
    if (calVeryTight) return AiSuggestionMode.singleItem;

    if (calLeft >= 550 && (macroOpenCount >= 2 || macroHighCount >= 1)) {
      return AiSuggestionMode.meal;
    }

    if (calLeft >= 450 && proteinUrgent) {
      return AiSuggestionMode.meal;
    }

    if (calLeft < 450 || macroOpenCount <= 1) {
      return AiSuggestionMode.singleItem;
    }

    if (calTight) {
      return AiSuggestionMode.singleItem;
    }

    return calLeft >= 450 ? AiSuggestionMode.meal : AiSuggestionMode.singleItem;
  }

  AiSuggestionResponse buildSuggestions({
    required AiSuggestionInput input,
    List<FoodModel> candidates = const [],
  }) {
    final mode = decideMode(input);
    final calLeft = _effectiveCalLeft(input);

    final pNeed = _need(input.pLeft);
    final cNeed = _need(input.cLeft);
    final fNeed = _need(input.fLeft);

    debugPrint(
      'AI SUGGESTIONS: calLeft=${input.calLeft}, pNeed=$pNeed, cNeed=$cNeed, fNeed=$fNeed, mode=$mode',
    );

    if (mode == AiSuggestionMode.none) {
      return const AiSuggestionResponse(
        mode: AiSuggestionMode.none,
        message: 'No suggestions; you are at or over your target.',
      );
    }

    if (mode == AiSuggestionMode.meal) {
      final meals = _buildMealSuggestions(
        input,
        candidates,
        calLeft: calLeft,
      );
      debugPrint('AI SUGGESTIONS: returned ${meals.length} meal options');
      return AiSuggestionResponse(
        mode: AiSuggestionMode.meal,
        message: 'Here are meal ideas within your remaining targets.',
        meals: meals,
      );
    }

    final groups = _buildSingleItemGroups(
      input,
      candidates,
      calLeft: calLeft,
    );
    debugPrint(
      'AI SUGGESTIONS: returned ${groups.fold<int>(0, (sum, g) => sum + g.items.length)} items',
    );
    return AiSuggestionResponse(
      mode: AiSuggestionMode.singleItem,
      message: 'Here are single-item suggestions within your remaining calories.',
      groups: groups,
    );
  }

  List<AiMealSuggestion> _buildMealSuggestions(
    AiSuggestionInput input,
    List<FoodModel> candidates,
    {required int calLeft},
  ) {
    if (candidates.isNotEmpty) {
      final filtered = candidates
          .where((f) => f.calories > 0 && f.calories <= calLeft)
          .toList();
      filtered.sort((a, b) => b.calories.compareTo(a.calories));
      final top = filtered.take(3).toList();
      return top
          .map((food) => _mealFromFood(food, input.restaurantName))
          .toList();
    }

    final restaurantTitle = _titleCaseRestaurant(input.restaurantName);

    final templates = [
      _MealTemplate(
        title: 'High Protein',
        description: 'Lean protein with veggies',
        items: ['7 oz chicken breast', '2 cups mixed veggies'],
        calories: 360,
        proteinG: 45,
        carbsG: 18,
        fatG: 8,
      ),
      _MealTemplate(
        title: 'Balanced',
        description: 'Protein + carbs + fats',
        items: ['5 oz salmon', '1 cup rice', 'side salad'],
        calories: 480,
        proteinG: 34,
        carbsG: 45,
        fatG: 14,
      ),
      _MealTemplate(
        title: restaurantTitle,
        description: 'Simple ordering option',
        items: ['Bowl or salad base', 'Lean protein', 'Veggies + salsa'],
        calories: 520,
        proteinG: 32,
        carbsG: 50,
        fatG: 16,
      ),
    ];

    final filteredTemplates = templates
        .where((t) => t.calories <= calLeft)
        .toList();

    final selected = filteredTemplates.isEmpty ? templates : filteredTemplates;
    return selected.map((t) => _mealFromTemplate(t, calLeft)).toList();
  }

  List<AiSuggestionGroup> _buildSingleItemGroups(
    AiSuggestionInput input,
    List<FoodModel> candidates,
    {required int calLeft},
  ) {
    final foods = candidates
        .where((f) => f.calories > 0 && f.calories <= calLeft)
        .toList();

    if (foods.isEmpty) {
      return _fallbackSingleItems(calLeft);
    }

    final used = <String>{};

    List<AiSingleItemSuggestion> select(
      Iterable<FoodModel> list,
      int count,
    ) {
      final selected = <AiSingleItemSuggestion>[];
      for (final food in list) {
        if (selected.length >= count) break;
        if (used.contains(food.id)) continue;
        used.add(food.id);
        selected.add(_singleFromFood(food));
      }
      return selected;
    }

    final byProtein = [...foods]
      ..sort((a, b) => _proteinPerCal(b).compareTo(_proteinPerCal(a)));

    final byLowCarb = foods.where((f) => f.carbs <= 10).toList()
      ..sort((a, b) => a.calories.compareTo(b.calories));

    final byLowFat = foods.where((f) => f.fat <= 6).toList()
      ..sort((a, b) => a.calories.compareTo(b.calories));

    final bySnack = [...foods]..sort((a, b) => a.calories.compareTo(b.calories));

    final groups = <AiSuggestionGroup>[];

    final proteinItems = select(byProtein, 3);
    if (proteinItems.isNotEmpty) {
      groups.add(AiSuggestionGroup(title: 'Best Protein per Calorie', items: proteinItems));
    }

    final lowCarbItems = select(byLowCarb, 3);
    if (lowCarbItems.isNotEmpty) {
      groups.add(AiSuggestionGroup(title: 'Low-Carb', items: lowCarbItems));
    }

    final lowFatItems = select(byLowFat, 3);
    if (lowFatItems.isNotEmpty) {
      groups.add(AiSuggestionGroup(title: 'Low-Fat', items: lowFatItems));
    }

    final snackItems = select(bySnack, 3);
    if (snackItems.isNotEmpty) {
      groups.add(AiSuggestionGroup(title: 'Quick Snack', items: snackItems));
    }

    return groups.isEmpty ? _fallbackSingleItems(calLeft) : groups;
  }

  List<AiSuggestionGroup> _fallbackSingleItems(int calLeft) {
    final items = [
      _fallbackSingle('Greek yogurt', '1 cup', 140, 20, 9, 0),
      _fallbackSingle('Protein shake', '1 bottle', 160, 30, 6, 3),
      _fallbackSingle('Apple + peanut butter', '1 apple + 1 tbsp', 180, 4, 24, 8),
      _fallbackSingle('Turkey jerky', '2 oz', 140, 20, 6, 2),
      _fallbackSingle('Cottage cheese', '1 cup', 180, 24, 8, 5),
      _fallbackSingle('Hard-boiled eggs', '2 eggs', 140, 12, 1, 10),
    ].where((item) => item.totals.calories <= calLeft).toList();

    return [AiSuggestionGroup(title: 'Quick Snack', items: items)];
  }

  AiMealSuggestion _mealFromTemplate(_MealTemplate t, int calLeft) {
    final scale = calLeft / t.calories;
    final ratio = scale < 1 ? scale : 1.0;
    final totals = AiSuggestionTotals(
      calories: (t.calories * ratio).round(),
      proteinG: (t.proteinG * ratio).round(),
      carbsG: (t.carbsG * ratio).round(),
      fatG: (t.fatG * ratio).round(),
    );

    return AiMealSuggestion(
      title: t.title,
      description: t.description,
      items: t.items,
      totals: totals,
      confidence: 0.55,
      source: 'ai_estimate',
      addActionPayload: _payloadFromTotals(
        name: t.title,
        totals: totals,
        source: 'ai_estimate',
        confidence: 0.55,
        notes: t.items,
      ),
    );
  }

  AiMealSuggestion _mealFromFood(FoodModel food, String? requestRestaurantName) {
    final totals = AiSuggestionTotals(
      calories: food.calories.round(),
      proteinG: food.protein.round(),
      carbsG: food.carbs.round(),
      fatG: food.fat.round(),
    );

    final serving = _servingLine(food);
    final items = _extractMenuItems(food);
    final restaurantTitle = _resolveRestaurantName(food, requestRestaurantName);
    final description = restaurantTitle == 'Meal'
        ? food.name
        : '$restaurantTitle • ${food.name}';

    return AiMealSuggestion(
      title: restaurantTitle,
      description: description,
      items: items.isEmpty
          ? [serving.isEmpty ? food.name : '${food.name} ($serving)']
          : items,
      totals: totals,
      confidence: 0.7,
      source: 'fatsecret',
      addActionPayload: _payloadFromTotals(
        name: food.name,
        totals: totals,
        source: 'fatsecret',
        confidence: 0.7,
        notes: [serving],
      ),
    );
  }

  AiSingleItemSuggestion _singleFromFood(FoodModel food) {
    final totals = AiSuggestionTotals(
      calories: food.calories.round(),
      proteinG: food.protein.round(),
      carbsG: food.carbs.round(),
      fatG: food.fat.round(),
    );

    return AiSingleItemSuggestion(
      foodName: food.name,
      serving: _servingLine(food),
      totals: totals,
      confidence: 0.7,
      source: 'fatsecret',
      addActionPayload: _payloadFromTotals(
        name: food.name,
        totals: totals,
        source: 'fatsecret',
        confidence: 0.7,
        notes: [_servingLine(food)],
      ),
    );
  }

  AiSingleItemSuggestion _fallbackSingle(
    String name,
    String serving,
    int calories,
    int protein,
    int carbs,
    int fat,
  ) {
    final totals = AiSuggestionTotals(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
    );

    return AiSingleItemSuggestion(
      foodName: name,
      serving: serving,
      totals: totals,
      confidence: 0.5,
      source: 'ai_estimate',
      addActionPayload: _payloadFromTotals(
        name: name,
        totals: totals,
        source: 'ai_estimate',
        confidence: 0.5,
        notes: [serving],
      ),
    );
  }

  Map<String, dynamic> _payloadFromTotals({
    required String name,
    required AiSuggestionTotals totals,
    required String source,
    required double confidence,
    List<String>? notes,
  }) {
    return {
      'name': name,
      'calories': totals.calories,
      'proteinG': totals.proteinG,
      'carbsG': totals.carbsG,
      'fatG': totals.fatG,
      'source': source,
      'confidence': confidence,
      'assumptions': notes ?? const [],
    };
  }

  String _servingLine(FoodModel food) {
    if (food.servingSize > 0 && food.servingUnit.isNotEmpty) {
      return '${food.servingSize} ${food.servingUnit}';
    }
    if (food.servingQty != null && (food.servingUnitRaw?.isNotEmpty ?? false)) {
      return '${food.servingQty} ${food.servingUnitRaw}';
    }
    return '';
  }

  double _proteinPerCal(FoodModel food) {
    if (food.calories <= 0) return 0;
    return food.protein / food.calories;
  }

  double _ratio(int numerator, int denominator) {
    if (denominator <= 0) return 0;
    final value = numerator / denominator;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  int _count(List<double> values, double threshold) {
    return values.where((v) => v >= threshold).length;
  }

  int _need(int value) => value > 0 ? value : 0;
}

class _MealTemplate {
  final String title;
  final String description;
  final List<String> items;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const _MealTemplate({
    required this.title,
    required this.description,
    required this.items,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}
