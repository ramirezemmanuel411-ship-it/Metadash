import 'package:equatable/equatable.dart';

import '../data/models/food_model.dart';

/// Search state for UI
abstract class FoodSearchState extends Equatable {
  const FoodSearchState();

  @override
  List<Object?> get props => [];
}

/// Initial state (no search yet)
class SearchInitial extends FoodSearchState {
  final List<String> recentSearches;
  final List<FoodModel> favorites;

  const SearchInitial({
    this.recentSearches = const [],
    this.favorites = const [],
  });

  @override
  List<Object?> get props => [recentSearches, favorites];
}

/// Loading state (searching in progress)
class SearchLoading extends FoodSearchState {
  final String query;
  final List<FoodModel> partialResults; // Show while loading more

  const SearchLoading({
    required this.query,
    this.partialResults = const [],
  });

  @override
  List<Object?> get props => [query, partialResults];
}

/// Success state (results loaded)
class SearchSuccess extends FoodSearchState {
  final String query;
  final List<FoodModel> results;
  final SearchSource source;
  final bool isLoadingMore; // True if fetching remote after showing cached

  const SearchSuccess({
    required this.query,
    required this.results,
    required this.source,
    this.isLoadingMore = false,
  });

  SearchSuccess copyWith({
    String? query,
    List<FoodModel>? results,
    SearchSource? source,
    bool? isLoadingMore,
  }) {
    return SearchSuccess(
      query: query ?? this.query,
      results: results ?? this.results,
      source: source ?? this.source,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [query, results, source, isLoadingMore];
}

/// Empty results state
class SearchEmpty extends FoodSearchState {
  final String query;

  const SearchEmpty({required this.query});

  @override
  List<Object?> get props => [query];
}

/// Error state
class SearchError extends FoodSearchState {
  final String message;
  final List<FoodModel> fallbackResults; // Show local results on error

  const SearchError({
    required this.message,
    this.fallbackResults = const [],
  });

  @override
  List<Object?> get props => [message, fallbackResults];
}

/// Source of search results (for UI feedback)
enum SearchSource {
  local,
  cache,
  remote,
}
