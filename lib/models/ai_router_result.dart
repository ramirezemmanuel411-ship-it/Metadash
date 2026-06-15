// MetaDash AI Router — result models
// Each AI response is wrapped in [AiRouterResult] with a [AiRouteMode]
// and a list of [AiStructuredFoodEntry] objects ready for the Food Tray.

enum AiRouteMode {
  visionFoodEstimate,
  restaurantOrderHelper,
  mealStrategyHelper,
  structuredFoodLogger,
}

extension AiRouteModeLabel on AiRouteMode {
  String get displayName {
    switch (this) {
      case AiRouteMode.visionFoodEstimate:
        return 'Photo Analysis';
      case AiRouteMode.restaurantOrderHelper:
        return 'Restaurant Helper';
      case AiRouteMode.mealStrategyHelper:
        return 'Meal Strategy';
      case AiRouteMode.structuredFoodLogger:
        return 'Food Logger';
    }
  }

  String get shortLabel {
    switch (this) {
      case AiRouteMode.visionFoodEstimate:
        return 'PHOTO';
      case AiRouteMode.restaurantOrderHelper:
        return 'RESTAURANT';
      case AiRouteMode.mealStrategyHelper:
        return 'STRATEGY';
      case AiRouteMode.structuredFoodLogger:
        return 'LOGGER';
    }
  }
}

/// A single food entry structured from an AI response.
/// Every AI-suggested food normalises into this before touching the Food Tray.
class AiStructuredFoodEntry {
  final String name;
  final String? brand;
  final String serving;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int fiber;
  final String confidence; // 'high' | 'medium' | 'low'
  final String source; // 'AI estimate' | 'AI photo' | 'Restaurant data'

  const AiStructuredFoodEntry({
    required this.name,
    this.brand,
    required this.serving,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    required this.confidence,
    required this.source,
  });

  AiStructuredFoodEntry copyWith({
    String? name,
    String? brand,
    String? serving,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    int? fiber,
    String? confidence,
    String? source,
  }) {
    return AiStructuredFoodEntry(
      name: name ?? this.name,
      brand: brand ?? this.brand,
      serving: serving ?? this.serving,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
    );
  }

  factory AiStructuredFoodEntry.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v, {int fb = 0}) {
      if (v == null) return fb;
      if (v is int) return v;
      if (v is double) return v.round();
      return int.tryParse(v.toString()) ?? fb;
    }

    return AiStructuredFoodEntry(
      name: json['name'] ?? 'Unknown food',
      brand: json['brand'],
      serving: json['serving'] ?? '1 serving',
      calories: parseInt(json['calories']),
      protein: parseInt(json['protein']),
      carbs: parseInt(json['carbs']),
      fat: parseInt(json['fat']),
      fiber: parseInt(json['fiber']),
      confidence: json['confidence'] ?? 'medium',
      source: json['source'] ?? 'AI estimate',
    );
  }
}

/// An alternative suggestion (used by restaurant/strategy modes).
class AiSuggestionOption {
  final String title;
  final String? description;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String? reasoning;
  final bool isRecommended;
  final AiStructuredFoodEntry entry;

  const AiSuggestionOption({
    required this.title,
    this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.reasoning,
    this.isRecommended = false,
    required this.entry,
  });
}

/// The top-level result returned by [AiRouter].
class AiRouterResult {
  final AiRouteMode mode;

  /// Human-readable summary headline from the AI.
  final String headline;

  /// Supporting detail text (assumptions, reasoning, etc.).
  final String? detail;

  /// Confidence level: 'high' | 'medium' | 'low'
  final String confidence;

  /// Why confidence may be limited.
  final String? confidenceNote;

  /// Primary structured food entries ready for Food Tray.
  final List<AiStructuredFoodEntry> entries;

  /// Alternative options (restaurant / strategy modes).
  final List<AiSuggestionOption> alternatives;

  /// Best option index within [alternatives] (if provided).
  final int? bestAlternativeIndex;

  const AiRouterResult({
    required this.mode,
    required this.headline,
    this.detail,
    required this.confidence,
    this.confidenceNote,
    required this.entries,
    this.alternatives = const [],
    this.bestAlternativeIndex,
  });
}
