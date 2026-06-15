// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import '../models/ai_router_result.dart';
import 'ai_service.dart';

/// MetaDash AI Router
///
/// Classifies the user's request into one of four modes, selects the
/// appropriate prompt, calls the AI, and returns a fully structured
/// [AiRouterResult] ready for the Food Tray.
///
/// Modes:
///   1. visionFoodEstimate    — photo or image-based food analysis
///   2. restaurantOrderHelper — eating out / menu / ordering
///   3. mealStrategyHelper    — macro gaps / what to eat next
///   4. structuredFoodLogger  — fallback / direct food logging
class AiRouter {
  final AiService _aiService;

  AiRouter(this._aiService);

  // ── Intent detection ──────────────────────────────────────────────────────

  /// Determine which mode to use based on input signals.
  /// [hasImage] takes precedence over text.
  AiRouteMode detectIntent({
    required String text,
    bool hasImage = false,
    Map<String, dynamic>? diaryContext,
  }) {
    if (hasImage) return AiRouteMode.visionFoodEstimate;

    final lower = text.toLowerCase();

    // Restaurant / ordering signals
    final restaurantSignals = [
      'restaurant',
      'menu',
      'ordering',
      'order at',
      'eating out',
      'fast food',
      'eat out',
      "what can i order",
      'chipotle',
      'chick-fil-a',
      'mcdonald',
      'burger king',
      'subway',
      'taco bell',
      'starbucks',
      'texas roadhouse',
      'olive garden',
      'panera',
      "i'm at",
      "i am at",
      'dine',
      'dining',
    ];
    if (restaurantSignals.any((s) => lower.contains(s))) {
      return AiRouteMode.restaurantOrderHelper;
    }

    // Macro/calorie remaining signals
    final strategySignals = [
      'calories left',
      'calories remaining',
      'protein left',
      'protein remaining',
      'macros left',
      'macros remaining',
      'need more protein',
      'need protein',
      'what should i eat',
      'what can i eat',
      'still need',
      'hit my protein',
      'stay in my deficit',
      'deficit tonight',
      'reach my goal',
      'close the gap',
      'how do i',
      'what to eat',
    ];
    if (strategySignals.any((s) => lower.contains(s))) {
      return AiRouteMode.mealStrategyHelper;
    }

    // Default: treat as general food logging
    return AiRouteMode.structuredFoodLogger;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Route and process a text-based food request.
  Future<AiRouterResult> processText({
    required String userText,
    Map<String, dynamic>? diaryContext,
    AiRouteMode? forceMode,
  }) async {
    final mode = forceMode ??
        detectIntent(text: userText, diaryContext: diaryContext);

    switch (mode) {
      case AiRouteMode.restaurantOrderHelper:
        return _runRestaurantMode(userText, diaryContext);
      case AiRouteMode.mealStrategyHelper:
        return _runStrategyMode(userText, diaryContext);
      case AiRouteMode.visionFoodEstimate:
        // Text-only vision fallback — treat as food logger
        return _runLoggerMode(userText);
      case AiRouteMode.structuredFoodLogger:
        return _runLoggerMode(userText);
    }
  }

  /// Route and process an image (optionally with text description).
  Future<AiRouterResult> processImage({
    required File imageFile,
    String? userDescription,
    Map<String, dynamic>? diaryContext,
  }) async {
    return _runVisionMode(imageFile, userDescription);
  }

  // ── Mode 1 — Vision Food Estimate ─────────────────────────────────────────

  Future<AiRouterResult> _runVisionMode(
    File imageFile,
    String? description,
  ) async {
    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    String prompt = '''You are a nutrition expert analyzing a food photo for a metabolic tracking app.

Identify every food item visible in the image. Estimate reasonable portion sizes.
${description != null && description.isNotEmpty ? '\nUser context: "$description"\nUse this to refine portions. Trust image for item identification.' : ''}

Return ONLY valid JSON — no markdown, no text outside the JSON:
{
  "headline": "<1-line summary of what you see>",
  "confidence": "high|medium|low",
  "confidence_note": "<explain if low, else null>",
  "items": [
    {
      "name": "<food name>",
      "brand": null,
      "serving": "<e.g. 6 oz, 1 cup>",
      "calories": <int>,
      "protein": <int>,
      "carbs": <int>,
      "fat": <int>,
      "fiber": <int>
    }
  ],
  "assumptions": ["<key assumption 1>", "<key assumption 2>"]
}

Rules:
- List each component separately when clearly distinguishable.
- Use realistic restaurant/home portion sizing.
- confidence should be "medium" for most photos, "low" if very obscured.
- Never claim exact accuracy. This is an estimate.
''';

    try {
      final raw = await _aiService.callVisionAi(prompt, base64Image);
      final json = _safeParseJson(raw);
      if (json == null) throw Exception('Could not parse vision response');

      final items = (json['items'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map((e) => AiStructuredFoodEntry.fromJson({
                ...e,
                'source': 'AI photo estimate',
                'confidence': json['confidence'] ?? 'medium',
              }))
          .toList();

      final assumptions = (json['assumptions'] as List? ?? [])
          .cast<String>()
          .join('\n• ');
      final detail = assumptions.isNotEmpty ? '• $assumptions' : null;

      return AiRouterResult(
        mode: AiRouteMode.visionFoodEstimate,
        headline: json['headline'] ?? 'Meal analyzed from photo',
        detail: detail,
        confidence: json['confidence'] ?? 'medium',
        confidenceNote: json['confidence_note'],
        entries: items,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── Mode 2 — Restaurant Order Helper ──────────────────────────────────────

  Future<AiRouterResult> _runRestaurantMode(
    String userText,
    Map<String, dynamic>? context,
  ) async {
    final calLeft = context?['caloriesRemaining'] ?? 'unknown';
    final proteinLeft = context?['proteinRemaining'] ?? 'unknown';
    final userGoal = context?['goal'] ?? 'maintain weight';

    final prompt = '''You are a nutrition assistant helping someone order at a restaurant.

User request: "$userText"

User context:
- Calories remaining today: $calLeft kcal
- Protein remaining today: ${proteinLeft}g
- Goal: $userGoal

Suggest 2-4 specific menu items or meal combinations.
Mark the BEST option clearly.
All nutrition values are ESTIMATES — say so.

Return ONLY valid JSON:
{
  "headline": "<1 line summary, e.g. 'Best options at Chipotle for your protein goal'>",
  "best_index": 0,
  "confidence": "medium",
  "confidence_note": "Restaurant nutrition data is estimated and may vary.",
  "options": [
    {
      "title": "<order/item name>",
      "description": "<brief description>",
      "reasoning": "<why this fits the goal>",
      "calories": <int>,
      "protein": <int>,
      "carbs": <int>,
      "fat": <int>
    }
  ]
}

Rules:
- Stay practical and realistic. Real menu items only.
- Never claim exact calorie counts — these are estimates.
- If the restaurant is unknown, give generic healthy-eating suggestions.
- Prioritize hitting protein goal when mentioned.
''';

    try {
      final raw = await _aiService.callTextAi(prompt);
      final json = _safeParseJson(raw);
      if (json == null) throw Exception('Could not parse restaurant response');

      final options = (json['options'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .asMap()
          .entries
          .map((e) {
        final idx = e.key;
        final opt = e.value;
        final isBest = (json['best_index'] ?? 0) == idx;
        final entry = AiStructuredFoodEntry(
          name: opt['title'] ?? 'Menu item',
          serving: '1 order',
          calories: _parseInt(opt['calories']),
          protein: _parseInt(opt['protein']),
          carbs: _parseInt(opt['carbs']),
          fat: _parseInt(opt['fat']),
          confidence: 'medium',
          source: 'Restaurant estimate',
        );
        return AiSuggestionOption(
          title: opt['title'] ?? 'Option',
          description: opt['description'],
          calories: _parseInt(opt['calories']),
          protein: _parseInt(opt['protein']),
          carbs: _parseInt(opt['carbs']),
          fat: _parseInt(opt['fat']),
          reasoning: opt['reasoning'],
          isRecommended: isBest,
          entry: entry,
        );
      }).toList();

      final bestEntry = options.isNotEmpty
          ? options[json['best_index'] ?? 0].entry
          : null;

      return AiRouterResult(
        mode: AiRouteMode.restaurantOrderHelper,
        headline: json['headline'] ?? 'Restaurant suggestions',
        confidence: json['confidence'] ?? 'medium',
        confidenceNote: json['confidence_note'],
        entries: bestEntry != null ? [bestEntry] : [],
        alternatives: options,
        bestAlternativeIndex: json['best_index'],
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── Mode 3 — Meal Strategy Helper ─────────────────────────────────────────

  Future<AiRouterResult> _runStrategyMode(
    String userText,
    Map<String, dynamic>? context,
  ) async {
    final calLeft = context?['caloriesRemaining'] ?? 'unknown';
    final proteinLeft = context?['proteinRemaining'] ?? 'unknown';
    final carbsLeft = context?['carbsRemaining'] ?? 'unknown';
    final fatLeft = context?['fatRemaining'] ?? 'unknown';
    final userGoal = context?['goal'] ?? 'maintain weight';

    final prompt = '''You are a nutrition strategist for a metabolic tracking app.

User request: "$userText"

Current diary state:
- Calories remaining: $calLeft kcal
- Protein remaining: ${proteinLeft}g
- Carbs remaining: ${carbsLeft}g
- Fat remaining: ${fatLeft}g
- Goal: $userGoal

Suggest 2-3 practical meal or snack ideas that fit within the remaining macros.
Focus on hitting protein first if a deficit is present.

Return ONLY valid JSON:
{
  "headline": "<1 line, e.g. 'Options to close your protein gap tonight'>",
  "best_index": 0,
  "confidence": "medium",
  "confidence_note": null,
  "options": [
    {
      "title": "<meal name>",
      "description": "<brief description or ingredients>",
      "reasoning": "<why this fits>",
      "calories": <int>,
      "protein": <int>,
      "carbs": <int>,
      "fat": <int>
    }
  ]
}

Rules:
- Keep suggestions practical and realistic.
- Prefer whole foods. Include some quick/easy options.
- Say "approximately" or "estimated" in reasoning, not exact.
- Do not suggest meals that would exceed remaining calories significantly.
''';

    try {
      final raw = await _aiService.callTextAi(prompt);
      final json = _safeParseJson(raw);
      if (json == null) throw Exception('Could not parse strategy response');

      final options = (json['options'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .asMap()
          .entries
          .map((e) {
        final idx = e.key;
        final opt = e.value;
        final isBest = (json['best_index'] ?? 0) == idx;
        final entry = AiStructuredFoodEntry(
          name: opt['title'] ?? 'Meal',
          serving: '1 serving',
          calories: _parseInt(opt['calories']),
          protein: _parseInt(opt['protein']),
          carbs: _parseInt(opt['carbs']),
          fat: _parseInt(opt['fat']),
          confidence: 'medium',
          source: 'AI meal strategy',
        );
        return AiSuggestionOption(
          title: opt['title'] ?? 'Option',
          description: opt['description'],
          calories: _parseInt(opt['calories']),
          protein: _parseInt(opt['protein']),
          carbs: _parseInt(opt['carbs']),
          fat: _parseInt(opt['fat']),
          reasoning: opt['reasoning'],
          isRecommended: isBest,
          entry: entry,
        );
      }).toList();

      final bestEntry = options.isNotEmpty
          ? options[json['best_index'] ?? 0].entry
          : null;

      return AiRouterResult(
        mode: AiRouteMode.mealStrategyHelper,
        headline: json['headline'] ?? 'Meal strategy',
        confidence: json['confidence'] ?? 'medium',
        confidenceNote: json['confidence_note'],
        entries: bestEntry != null ? [bestEntry] : [],
        alternatives: options,
        bestAlternativeIndex: json['best_index'],
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── Mode 4 — Structured Food Logger ───────────────────────────────────────

  Future<AiRouterResult> _runLoggerMode(String userText) async {
    final prompt = '''You are a nutrition expert for a food tracking app.

Parse this food description into structured nutritional data.
If multiple items are mentioned, list each separately.

User input: "$userText"

Return ONLY valid JSON:
{
  "headline": "<1 line summary of what was logged>",
  "confidence": "high|medium|low",
  "confidence_note": "<explain if low, else null>",
  "items": [
    {
      "name": "<food name>",
      "brand": null,
      "serving": "<e.g. 1 cup, 6 oz, 2 pieces>",
      "calories": <int>,
      "protein": <int>,
      "carbs": <int>,
      "fat": <int>,
      "fiber": <int>
    }
  ]
}

Rules:
- Be realistic with portions. Default to standard serving if not specified.
- Separate distinct items (e.g., "chicken and rice" = 2 entries).
- confidence: "high" if item is well-known, "low" if vague.
- Never output markdown. JSON only.
''';

    try {
      final raw = await _aiService.callTextAi(prompt);
      final json = _safeParseJson(raw);
      if (json == null) throw Exception('Could not parse logger response');

      final items = (json['items'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map((e) => AiStructuredFoodEntry.fromJson({
                ...e,
                'source': 'AI estimate',
                'confidence': json['confidence'] ?? 'medium',
              }))
          .toList();

      return AiRouterResult(
        mode: AiRouteMode.structuredFoodLogger,
        headline: json['headline'] ?? 'Foods logged',
        confidence: json['confidence'] ?? 'medium',
        confidenceNote: json['confidence_note'],
        entries: items,
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic>? _safeParseJson(String text) {
    var trimmed = text.trim();
    final fence = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (fence != null) trimmed = fence.group(1)!.trim();

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // Try extracting a balanced object
    int depth = 0, start = -1;
    for (int i = 0; i < trimmed.length; i++) {
      if (trimmed[i] == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (trimmed[i] == '}') {
        if (depth > 0) depth--;
        if (depth == 0 && start != -1) {
          try {
            final extracted = trimmed.substring(start, i + 1);
            final decoded = jsonDecode(extracted);
            if (decoded is Map<String, dynamic>) return decoded;
          } catch (_) {}
        }
      }
    }
    return null;
  }

  int _parseInt(dynamic v, {int fb = 0}) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? fb;
  }
}
