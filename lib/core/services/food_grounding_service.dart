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

  /// Ground every entry (in parallel), replacing each AI estimate with the
  /// best verified database match where one is found.
  Future<List<AiStructuredFoodEntry>> groundEntries(
    List<AiStructuredFoodEntry> entries,
  ) {
    return Future.wait(entries.map(_groundOne));
  }

  Future<AiStructuredFoodEntry> _groundOne(AiStructuredFoodEntry e) async {
    final name = e.name.trim();
    if (name.isEmpty) return e;
    final brand = e.brand?.trim();

    // 1. Prefer the *specific* restaurant/brand — its official menu numbers.
    if (brand != null && brand.isNotEmpty) {
      final branded = await _search('$brand $name');
      final best = _firstBrandMatch(branded, brand.toLowerCase());
      if (best != null) return _grounded(e, best, generic: false);
    }

    // 2. Restaurant unknown (a taqueria, a hole-in-the-wall): fall back to the
    //    generic dish so the number is still real data, not a free-form guess.
    final generic = await _search(name);
    if (generic.isNotEmpty && _nameOverlaps(name, generic.first.displayTitle)) {
      return _grounded(e, generic.first, generic: true);
    }

    // 3. Nothing confident — keep the AI estimate.
    return e;
  }

  AiStructuredFoodEntry _grounded(
    AiStructuredFoodEntry e,
    FoodModel best, {
    required bool generic,
  }) {
    AppLogger.i(
      '[Grounding] "${e.name}" -> ${best.displayTitle} '
      '(${generic ? 'generic' : 'branded'}, ${best.source})',
    );
    return _toEntry(best, e, generic: generic);
  }

  Future<List<FoodModel>> _search(String query) async {
    try {
      final result = await _repository
          .searchFoods(query)
          .firstWhere((r) => r.results.isNotEmpty)
          .timeout(const Duration(seconds: 8));
      return result.results;
    } catch (_) {
      return const [];
    }
  }

  /// First candidate whose brand matches, or null — a wrong match is worse
  /// than the estimate.
  FoodModel? _firstBrandMatch(List<FoodModel> candidates, String brand) {
    for (final c in candidates) {
      if (_brandMatches(c, brand)) return c;
    }
    return null;
  }

  bool _brandMatches(FoodModel c, String brand) {
    final cb = c.displayBrand.toLowerCase();
    return cb.isNotEmpty && (cb.contains(brand) || brand.contains(cb));
  }

  /// Convert a database food into an entry, scaling to the AI-estimated amount
  /// when both the AI and database have a gram weight; otherwise using the
  /// database serving as-is.
  AiStructuredFoodEntry _toEntry(
    FoodModel f,
    AiStructuredFoodEntry base, {
    bool generic = false,
  }) {
    final aiGrams = base.grams;
    final dbGrams = f.servingWeightGrams;
    final mult =
        (aiGrams != null && aiGrams > 0 && dbGrams != null && dbGrams > 0)
        ? aiGrams / dbGrams
        : 1.0;
    return base.copyWith(
      name: _cleanTitle(f.displayTitle),
      // A generic match borrows another entry's nutrition, not its brand —
      // keep the place the user actually named (or none) rather than claiming
      // the lookalike's restaurant.
      brand: generic
          ? base.brand
          : (f.displayBrand.isNotEmpty ? f.displayBrand : base.brand),
      serving: _servingLabel(f, mult),
      calories: (f.calories * mult).round(),
      protein: (f.protein * mult).round(),
      carbs: (f.carbs * mult).round(),
      fat: (f.fat * mult).round(),
      grams: dbGrams != null ? (dbGrams * mult).round() : base.grams,
      source: generic ? 'Generic' : _sourceLabel(f.source),
      confidence: generic ? 'medium' : 'high',
    );
  }

  /// Database titles occasionally carry leading/trailing punctuation noise
  /// (e.g. ". Ft. Worth Ribeye & Ribs"); trim it so the name reads cleanly.
  String _cleanTitle(String title) => title
      .replaceAll(RegExp(r'^[\s.,;:\-]+'), '')
      .replaceAll(RegExp(r'[\s.,;:]+$'), '')
      .trim();

  String _servingLabel(FoodModel f, double mult) {
    final unit = f.servingUnit.trim();
    final qty = f.servingSize * mult;
    if (unit.isEmpty || unit.toLowerCase() == 'serving') {
      return mult == 1.0 ? '1 serving' : '${_fmt(mult)} servings';
    }
    return '${_fmt(qty)} $unit';
  }

  String _fmt(double v) => v == v.truncateToDouble()
      ? v.truncate().toString()
      : v.toStringAsFixed(1);

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
