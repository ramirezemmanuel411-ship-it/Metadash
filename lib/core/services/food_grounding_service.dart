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
    final name = e.name.trim();
    if (name.isEmpty) return GroundedItem(e, const []);
    final brand = e.brand?.trim();

    // 1. Prefer the *specific* restaurant/brand — its official menu numbers.
    if (brand != null && brand.isNotEmpty) {
      final branded = await _search('$brand $name');
      final best = _firstBrandMatch(branded, brand.toLowerCase());
      if (best != null) return _grounded(e, best, branded, generic: false);
    }

    // 2. Restaurant unknown (a taqueria, a hole-in-the-wall): fall back to the
    //    generic dish so the number is still real data, not a free-form guess.
    final generic = await _search(name);
    if (generic.isNotEmpty && _nameOverlaps(name, generic.first.displayTitle)) {
      return _grounded(e, generic.first, const [], generic: true);
    }

    // 3. Nothing confident — keep the AI estimate.
    return GroundedItem(e, const []);
  }

  GroundedItem _grounded(
    AiStructuredFoodEntry e,
    FoodModel best,
    List<FoodModel> brandCandidates, {
    required bool generic,
  }) {
    AppLogger.i(
      '[Grounding] "${e.name}" -> ${best.displayTitle} '
      '(${generic ? 'generic' : 'branded'}, ${best.source})',
    );
    final grounded = _toEntry(best, e, scaleToPortion: true, generic: generic);
    // Quick-pick chips only make sense for a known menu, and only for
    // genuinely different items — not the same dish at another size, which the
    // editable portion already covers.
    final variants = generic
        ? const <AiStructuredFoodEntry>[]
        : _distinctVariants(best, brandCandidates, e);
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

  /// First candidate whose brand matches, or null — a wrong match is worse
  /// than the estimate.
  FoodModel? _firstBrandMatch(List<FoodModel> candidates, String brand) {
    for (final c in candidates) {
      if (_brandMatches(c, brand)) return c;
    }
    return null;
  }

  /// Same-brand items that are *related but genuinely different* from [best]:
  /// they share its core food word (so a ribeye's chips stay ribeye, not the
  /// pork chop) yet aren't merely another size of the exact same dish — those
  /// are redundant with the editable portion. Deduped by name, capped at four.
  List<AiStructuredFoodEntry> _distinctVariants(
    FoodModel best,
    List<FoodModel> candidates,
    AiStructuredFoodEntry e,
  ) {
    final brand = e.brand?.toLowerCase().trim() ?? '';
    final bestCore = _coreTokens(best.displayTitle);
    if (bestCore.isEmpty) return const [];
    final seen = <String>{};
    final out = <AiStructuredFoodEntry>[];
    for (final c in candidates) {
      if (c.id == best.id) continue;
      if (brand.isNotEmpty && !_brandMatches(c, brand)) continue;
      final core = _coreTokens(c.displayTitle);
      final related = core.intersection(bestCore).isNotEmpty;
      final sameDish =
          core.length == bestCore.length && core.containsAll(bestCore);
      if (!related || sameDish) continue;
      if (!seen.add(_cleanTitle(c.displayTitle).toLowerCase())) continue;
      out.add(_toEntry(c, e, scaleToPortion: false));
      if (out.length == 4) break;
    }
    return out;
  }

  /// Core food words of a title: drop generic descriptors and pure sizes
  /// (e.g. "16oz") so "Ribeye", "Ft. Worth Ribeye" and "Ribeye 12 oz" all
  /// reduce to {ribeye}, while "Ribeye & Ribs" keeps {ribeye, ribs}.
  Set<String> _coreTokens(String title) => _tokens(title)
      .where((t) => !_dishModifiers.contains(t))
      .where((t) => !t.contains(RegExp(r'[0-9]')))
      .toSet();

  static const _dishModifiers = {
    'bone',
    'boneless',
    'and',
    'the',
    'cut',
    'cuts',
    'with',
    'without',
    'grilled',
    'fried',
    'baked',
    'roasted',
    'broiled',
    'seared',
    'fresh',
    'lean',
    'large',
    'small',
    'regular',
    'half',
    'full',
    'side',
    'order',
    'plate',
    'fort',
    'worth',
    'new',
    'style',
    'house',
    'special',
  };

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
    bool generic = false,
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
