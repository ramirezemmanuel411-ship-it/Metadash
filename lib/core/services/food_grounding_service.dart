import 'package:metadash/core/logging/app_logger.dart';
import 'package:metadash/data/models/ai_router_result.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/data/repositories/search_repository.dart';

/// Replaces AI-*estimated* nutrition with *verified* values from the food
/// database (FatSecret → USDA → Open Food Facts) whenever a confident match is
/// found, so calorie numbers are traceable to a real source instead of being a
/// free-form guess. Items with no confident match keep their AI estimate.
class FoodGroundingService {
  FoodGroundingService(this._repository);

  final SearchRepository _repository;

  /// Ground every entry that has a confident database match (in parallel).
  Future<List<AiStructuredFoodEntry>> groundEntries(
    List<AiStructuredFoodEntry> entries,
  ) {
    return Future.wait(entries.map(_groundOne));
  }

  Future<AiStructuredFoodEntry> _groundOne(AiStructuredFoodEntry e) async {
    final query = [
      e.brand,
      e.name,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();
    if (query.isEmpty) return e;

    final match = await _bestMatch(query, e);
    if (match == null) return e;

    // Scale the database serving to the AI-estimated portion when both have a
    // gram weight; otherwise use the database serving as-is (1 serving).
    final aiGrams = e.grams;
    final dbGrams = match.servingWeightGrams;
    final mult =
        (aiGrams != null && aiGrams > 0 && dbGrams != null && dbGrams > 0)
        ? aiGrams / dbGrams
        : 1.0;

    AppLogger.i(
      '[Grounding] "${e.name}" -> ${match.displayTitle} '
      '(${match.source}, x${mult.toStringAsFixed(2)})',
    );

    return e.copyWith(
      name: match.displayTitle,
      brand: match.displayBrand.isNotEmpty ? match.displayBrand : e.brand,
      calories: (match.calories * mult).round(),
      protein: (match.protein * mult).round(),
      carbs: (match.carbs * mult).round(),
      fat: (match.fat * mult).round(),
      grams: dbGrams != null ? (dbGrams * mult).round() : e.grams,
      source: _sourceLabel(match.source),
      confidence: 'high',
    );
  }

  /// Pick the best database match for [query], or null if none is confident
  /// enough — a wrong match is worse than the AI estimate.
  Future<FoodModel?> _bestMatch(String query, AiStructuredFoodEntry e) async {
    List<FoodModel> candidates;
    try {
      final result = await _repository
          .searchFoods(query)
          .firstWhere((r) => r.results.isNotEmpty)
          .timeout(const Duration(seconds: 8));
      candidates = result.results;
    } catch (_) {
      return null;
    }
    if (candidates.isEmpty) return null;

    final brand = e.brand?.toLowerCase().trim();
    if (brand != null && brand.isNotEmpty) {
      // Brand named (e.g. a restaurant): require the brand to match so we don't
      // attach the wrong company's product.
      for (final c in candidates) {
        final cb = c.displayBrand.toLowerCase();
        if (cb.isNotEmpty && (cb.contains(brand) || brand.contains(cb))) {
          return c;
        }
      }
      return null;
    }

    // No brand: take the top result only if its name overlaps the query enough
    // to be the same food (avoids grounding "soup" with a random product).
    final top = candidates.first;
    return _nameOverlaps(e.name, top.displayTitle) ? top : null;
  }

  bool _nameOverlaps(String aiName, String dbName) {
    final a = _tokens(aiName);
    if (a.isEmpty) return false;
    final b = _tokens(dbName);
    final shared = a.where(b.contains).length;
    return shared / a.length >= 0.5;
  }

  Set<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 2)
      .toSet();

  String _sourceLabel(String source) {
    final s = source.toLowerCase();
    if (s.contains('fatsecret')) return 'FatSecret';
    if (s.contains('usda')) return 'USDA';
    if (s.contains('open_food') || s.contains('off')) return 'Open Food Facts';
    return 'Verified';
  }
}
