import 'package:metadash/core/logging/app_logger.dart';
import 'package:metadash/data/models/ai_router_result.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/data/repositories/search_repository.dart';

/// One AI food item after grounding: the best (verified) [entry], plus
/// alternative database servings/sizes the user can switch to (e.g. the 12 oz
/// vs 14 oz vs bone-in ribeye at a restaurant).
class GroundedItem {
  const GroundedItem(this.entry, this.variants);

  final AiStructuredFoodEntry entry;
  final List<AiStructuredFoodEntry> variants;
}

/// Replaces AI-*estimated* nutrition with *verified* values from the food
/// database (FatSecret → USDA → Open Food Facts) whenever a confident match is
/// found, so calorie numbers are traceable to a real source instead of being a
/// free-form guess. Items with no confident match keep their AI estimate.
class FoodGroundingService {
  FoodGroundingService(this._repository);

  final SearchRepository _repository;

  /// Ground every entry (in parallel), returning the verified best match plus
  /// any alternative servings/sizes.
  Future<List<GroundedItem>> groundEntries(
    List<AiStructuredFoodEntry> entries,
  ) {
    return Future.wait(entries.map(_groundOne));
  }

  Future<GroundedItem> _groundOne(AiStructuredFoodEntry e) async {
    final query = [
      e.brand,
      e.name,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();
    if (query.isEmpty) return GroundedItem(e, const []);

    final candidates = await _search(query);
    if (candidates.isEmpty) return GroundedItem(e, const []);

    final best = _pickBest(candidates, e);
    if (best == null) return GroundedItem(e, const []);

    AppLogger.i(
      '[Grounding] "${e.name}" -> ${best.displayTitle} (${best.source})',
    );

    // The best match is scaled to the AI-estimated portion when both have a
    // gram weight; alternative sizes are shown at their own serving.
    final grounded = _toEntry(best, e, scaleToPortion: true);
    final variants = candidates
        .where((c) => c.id != best.id && _relevant(c, e))
        .take(4)
        .map((c) => _toEntry(c, e, scaleToPortion: false))
        .toList();

    return GroundedItem(grounded, variants);
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

  /// Best confident match, or null — a wrong match is worse than the estimate.
  FoodModel? _pickBest(List<FoodModel> candidates, AiStructuredFoodEntry e) {
    final brand = e.brand?.toLowerCase().trim();
    if (brand != null && brand.isNotEmpty) {
      // Brand named (e.g. a restaurant): require the brand to match.
      for (final c in candidates) {
        if (_brandMatches(c, brand)) return c;
      }
      return null;
    }
    // No brand: top result only if its name overlaps the query.
    final top = candidates.first;
    return _nameOverlaps(e.name, top.displayTitle) ? top : null;
  }

  bool _relevant(FoodModel c, AiStructuredFoodEntry e) {
    final brand = e.brand?.toLowerCase().trim();
    if (brand != null && brand.isNotEmpty) return _brandMatches(c, brand);
    return _nameOverlaps(e.name, c.displayTitle);
  }

  bool _brandMatches(FoodModel c, String brand) {
    final cb = c.displayBrand.toLowerCase();
    return cb.isNotEmpty && (cb.contains(brand) || brand.contains(cb));
  }

  /// Convert a database food into an entry. When [scaleToPortion] and both the
  /// AI and database have a gram weight, scale to the AI-estimated amount;
  /// otherwise use the database serving as-is.
  AiStructuredFoodEntry _toEntry(
    FoodModel f,
    AiStructuredFoodEntry base, {
    required bool scaleToPortion,
  }) {
    final aiGrams = base.grams;
    final dbGrams = f.servingWeightGrams;
    final mult =
        (scaleToPortion &&
            aiGrams != null &&
            aiGrams > 0 &&
            dbGrams != null &&
            dbGrams > 0)
        ? aiGrams / dbGrams
        : 1.0;
    return base.copyWith(
      name: f.displayTitle,
      brand: f.displayBrand.isNotEmpty ? f.displayBrand : base.brand,
      serving: _servingLabel(f, mult),
      calories: (f.calories * mult).round(),
      protein: (f.protein * mult).round(),
      carbs: (f.carbs * mult).round(),
      fat: (f.fat * mult).round(),
      grams: dbGrams != null ? (dbGrams * mult).round() : base.grams,
      source: _sourceLabel(f.source),
      confidence: 'high',
    );
  }

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
