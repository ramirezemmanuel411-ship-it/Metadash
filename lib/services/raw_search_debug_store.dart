import '../data/models/food_search_result_raw.dart';

class RawSearchDebugStore {
  static String? _latestQuery;
  static List<FoodSearchResultRaw> _latestResults = const [];

  static void setResults(String query, List<FoodSearchResultRaw> results) {
    _latestQuery = query;
    _latestResults = results;
  }

  static void addResults(String query, List<FoodSearchResultRaw> results) {
    if (_latestQuery != query) {
      _latestQuery = query;
      _latestResults = results;
      return;
    }

    _latestResults = [..._latestResults, ...results];
  }

  static String? get latestQuery => _latestQuery;
  static List<FoodSearchResultRaw> get latestResults => _latestResults;

  static void clear() {
    _latestQuery = null;
    _latestResults = const [];
  }
}
