import 'dart:async';
import 'package:flutter/foundation.dart';

import '../data/models/food_model.dart';
import 'food_search_pipeline.dart';

/// **Food Search Engine** - High-level API for food search
/// 
/// Provides clean, production-ready search with:
/// - Text normalization and query processing
/// - Intelligent scoring and ranking
/// - Smart deduplication (removes duplicates, keeps variants)
/// - Clean display formatting
/// - Consistent behavior across all brands and products
/// 
/// **Usage:**
/// ```dart
/// final results = FoodSearchEngine.search(
///   query: userInput,
///   items: allFoodItems,
///   limit: 25,
/// );
/// 
/// // Render results
/// for (final food in results) {
///   print(food.displayTitle);      // "Coca Cola Original"
///   print(food.displaySubtitle);   // "Coca Cola • 140 cal • 355 ml"
/// }
/// ```
/// 
/// **Features:**
/// 1. **Normalization**: Handles accents, punctuation, case, whitespace
/// 2. **Ranking**: Most relevant items first (exact > prefix > word > substring)
/// 3. **Deduplication**: Removes language variants and serving duplicates
/// 4. **Display**: Clean titles with proper capitalization and formatting
/// 5. **Universal**: Works for all brands (Coke, Pepsi, Hershey, Pizza Hut, etc.)
/// 
/// **Test Coverage:**
/// See `test/food_search_integration_test.dart` for comprehensive tests
class FoodSearchEngine {
  
  /// Search foods with full normalization, ranking, and deduplication
  /// 
  /// **Parameters:**
  /// - `query`: User's search text (normalized automatically)
  /// - `items`: List of all food items to search through
  /// - `limit`: Maximum number of results to return (default: 25)
  /// - `debug`: Print detailed scoring information (default: false)
  /// 
  /// **Returns:**
  /// List of FoodModel items, ranked by relevance, deduplicated, with clean display properties
  /// 
  /// **Example:**
  /// ```dart
  /// // Search for "coke"
  /// final results = FoodSearchEngine.search(
  ///   query: 'coke',
  ///   items: database.getAllFoods(),
  ///   limit: 25,
  /// );
  /// 
  /// // Top results:
  /// // 1. "Coca Cola Original" (Coca Cola • 140 cal • 355 ml)
  /// // 2. "Diet Coke" (Coca Cola • 0 cal • 355 ml)
  /// // 3. "Coke Zero Sugar" (Coca Cola • 0 cal • 355 ml)
  /// // 4. "Cherry Coke" (Coca Cola • 150 cal • 355 ml)
  /// ```
  static List<FoodModel> search({
    required String query,
    required List<FoodModel> items,
    int limit = 25,
    bool debug = false,
  }) {
    // Input validation
    if (items.isEmpty) return [];
    
    // Short queries: return recent/popular items instead of noise
    if (query.trim().isEmpty || query.trim().length < 2) {
      return items.take(limit).toList();
    }
    
    // Full pipeline: normalize → score → group → deduplicate → rank
    return FoodSearchPipeline.process(
      rawResults: items,
      query: query,
      maxResults: limit,
      debug: debug,
    );
  }
  
  /// Quick search with default settings (25 results, no debug)
  /// 
  /// **Usage:**
  /// ```dart
  /// final results = FoodSearchEngine.quickSearch('pizza hut', allFoods);
  /// ```
  static List<FoodModel> quickSearch(String query, List<FoodModel> items) {
    return search(query: query, items: items, limit: 25, debug: false);
  }
  
  /// Search with debug output (prints scoring details to console)
  /// 
  /// **Usage:**
  /// ```dart
  /// final results = FoodSearchEngine.debugSearch('coke', allFoods);
  /// // Console output:
  /// // 🔍 [FOOD SEARCH PIPELINE] Query: "coke"
  /// //    📥 Final results: 5 (showing top 12)
  /// //     1. Coca Cola Original
  /// //        Score: 65.0 | Brand: cocacola | Calories: 140cal/355ml
  /// ```
  static List<FoodModel> debugSearch(String query, List<FoodModel> items, {int limit = 25}) {
    return search(query: query, items: items, limit: limit, debug: true);
  }
}

/// **Search Result View Model** - Ready-to-display food item
/// 
/// This is a convenience wrapper around FoodModel for UI rendering.
/// In practice, you can use FoodModel directly since it already has
/// clean display properties (displayTitle, displaySubtitle, servingLine).
/// 
/// **Usage:**
/// ```dart
/// final viewModel = FoodItemViewModel.fromModel(foodModel);
/// 
/// ListTile(
///   leading: CircleAvatar(child: Text(viewModel.avatarLetter)),
///   title: Text(viewModel.title),
///   subtitle: Text(viewModel.subtitle),
///   trailing: Text(viewModel.caloriesText),
/// )
/// ```
class FoodItemViewModel {
  final FoodModel model;
  
  FoodItemViewModel(this.model);
  
  /// Factory constructor from FoodModel
  factory FoodItemViewModel.fromModel(FoodModel model) {
    return FoodItemViewModel(model);
  }
  
  /// Clean display title (e.g., "Coca Cola Original")
  String get title => model.displayTitle;
  
  /// Subtitle with brand and serving info (e.g., "Coca Cola • 140 cal • 355 ml")
  String get subtitle => model.displaySubtitle;
  
  /// Avatar letter for CircleAvatar (first letter of title)
  String get avatarLetter {
    final title = model.displayTitle;
    return title.isNotEmpty ? title[0].toUpperCase() : '?';
  }
  
  /// Calories text for trailing widget (e.g., "140 cal")
  String get caloriesText => '${model.calories} cal';
  
  /// Full serving info (e.g., "355 ml")
  String get servingText => model.servingLine;
  
  /// Brand name (e.g., "Coca Cola")
  String get brand => model.displayBrand;
  
  /// Access to underlying model for selection/navigation
  FoodModel get foodModel => model;
}

/// **Debounced Search Helper** - For real-time search as user types
/// 
/// Prevents excessive search calls by debouncing user input.
/// Recommended debounce duration: 250-350ms
/// 
/// **Usage:**
/// ```dart
/// class MySearchWidget extends StatefulWidget {
///   @override
///   _MySearchWidgetState createState() => _MySearchWidgetState();
/// }
/// 
/// class _MySearchWidgetState extends State<MySearchWidget> {
///   final _searchDebouncer = SearchDebouncer(
///     duration: Duration(milliseconds: 300),
///   );
///   List<FoodModel> _results = [];
/// 
///   void _onSearchChanged(String query) {
///     _searchDebouncer.debounce(() {
///       setState(() {
///         _results = FoodSearchEngine.search(
///           query: query,
///           items: widget.allFoods,
///         );
///       });
///     });
///   }
/// 
///   @override
///   void dispose() {
///     _searchDebouncer.dispose();
///     super.dispose();
///   }
/// }
/// ```
class SearchDebouncer {
  final Duration duration;
  Timer? _timer;
  
  SearchDebouncer({this.duration = const Duration(milliseconds: 300)});
  
  /// Debounce a callback - only runs after user stops typing
  void debounce(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(duration, callback);
  }
  
  /// Cancel any pending debounced call
  void cancel() {
    _timer?.cancel();
  }
  
  /// Dispose and cleanup
  void dispose() {
    _timer?.cancel();
  }
}
