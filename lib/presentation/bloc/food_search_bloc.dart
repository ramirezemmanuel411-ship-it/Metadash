// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/search_repository.dart';
import '../../domain/search_state.dart' as domain;

// ==================== EVENTS ====================

abstract class FoodSearchEvent extends Equatable {
  const FoodSearchEvent();

  @override
  List<Object?> get props => [];
}

/// User typed in search box
class SearchQueryChanged extends FoodSearchEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// Load initial data (recent searches + favorites)
class LoadInitialData extends FoodSearchEvent {
  const LoadInitialData();
}

/// Clear search and return to initial state
class ClearSearch extends FoodSearchEvent {
  const ClearSearch();
}

/// Toggle favorite status
class ToggleFavorite extends FoodSearchEvent {
  final String foodId;

  const ToggleFavorite(this.foodId);

  @override
  List<Object?> get props => [foodId];
}

/// Clear recent searches
class ClearRecentSearches extends FoodSearchEvent {
  const ClearRecentSearches();
}

// ==================== BLOC ====================

/// BLoC managing food search with debouncing and cancellation
class FoodSearchBloc extends Bloc<FoodSearchEvent, domain.FoodSearchState> {
  final SearchRepository _repository;
  Timer? _debounceTimer;
  StreamSubscription? _searchSubscription;

  // Debounce duration (adjust for desired responsiveness)
  static const _debounceDuration = Duration(milliseconds: 150);

  FoodSearchBloc({SearchRepository? repository})
      : _repository = repository ?? SearchRepository.withFatSecret(),
        super(const domain.SearchInitial()) {
    on<LoadInitialData>(_onLoadInitialData);
    on<SearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: _debounceTransformer(_debounceDuration),
    );
    on<ClearSearch>(_onClearSearch);
    on<ToggleFavorite>(_onToggleFavorite);
    on<ClearRecentSearches>(_onClearRecentSearches);
  }

  /// Load recent searches and favorites on startup
  Future<void> _onLoadInitialData(
    LoadInitialData event,
    Emitter<domain.FoodSearchState> emit,
  ) async {
    try {
      final recent = await _repository.getRecentSearches(limit: 10);
      final favorites = await _repository.getFavorites(limit: 10);

      emit(domain.SearchInitial(
        recentSearches: recent,
        favorites: favorites,
      ));

      // Clean up old data in background
      _repository.cleanupOldData();
    } catch (e) {
      print('Error loading initial data: $e');
      emit(const domain.SearchInitial());
    }
  }

  /// Handle search query change with debouncing
  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<domain.FoodSearchState> emit,
  ) async {
    final query = event.query.trim();

    // Cancel previous search subscription
    await _searchSubscription?.cancel();

    // Empty query → return to initial state
    if (query.isEmpty) {
      add(const LoadInitialData());
      return;
    }

    // Query too short → don't search
    if (query.length < 2) {
      return;
    }

    // Start search with loading state
    emit(domain.SearchLoading(query: query));

    try {
      // Await all results from the search stream
      await for (final searchResult in _repository.searchFoods(query)) {
        if (!isClosed) {
          _handleSearchResult(searchResult, query, emit);
        }
      }
    } catch (e) {
      if (!isClosed) {
        emit(domain.SearchError(message: e.toString()));
      }
    }
  }

  /// Handle search result from repository
  void _handleSearchResult(
    SearchResult searchResult,
    String query,
    Emitter<domain.FoodSearchState> emit,
  ) {
    if (searchResult.results.isEmpty && searchResult.isComplete) {
      // No results found
      emit(domain.SearchEmpty(query: query));
      return;
    }

    // Convert repository SearchSource to domain SearchSource
    final source = _mapSearchSource(searchResult.source);

    // Emit success state
    emit(domain.SearchSuccess(
      query: query,
      results: searchResult.results,
      source: source,
      isLoadingMore: !searchResult.isComplete,
    ));
  }

  /// Map repository SearchSource to domain SearchSource
  domain.SearchSource _mapSearchSource(SearchSource source) {
    switch (source) {
      case SearchSource.local:
        return domain.SearchSource.local;
      case SearchSource.cache:
        return domain.SearchSource.cache;
      case SearchSource.remote:
        return domain.SearchSource.remote;
    }
  }

  /// Clear search and return to initial state
  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<domain.FoodSearchState> emit,
  ) async {
    await _searchSubscription?.cancel();
    add(const LoadInitialData());
  }

  /// Toggle favorite status
  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<domain.FoodSearchState> emit,
  ) async {
    try {
      await _repository.toggleFavorite(event.foodId);

      // Refresh current state if needed
      if (state is domain.SearchSuccess) {
        // You could reload or update the specific item
        // For now, just keep current state
      } else if (state is domain.SearchInitial) {
        // Reload initial data to reflect favorite change
        add(const LoadInitialData());
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  /// Clear recent searches
  Future<void> _onClearRecentSearches(
    ClearRecentSearches event,
    Emitter<domain.FoodSearchState> emit,
  ) async {
    try {
      await _repository.clearRecentSearches();
      add(const LoadInitialData());
    } catch (e) {
      print('Error clearing recent searches: $e');
    }
  }

  /// Custom transformer for debouncing
  EventTransformer<SearchQueryChanged> _debounceTransformer(
    Duration duration,
  ) {
    return (events, mapper) {
      return events
          .distinct((prev, next) => prev.query == next.query)
          .debounceTime(duration)
          .asyncExpand(mapper);
    };
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _searchSubscription?.cancel();
    _repository.dispose();
    return super.close();
  }
}

/// Extension to add debounceTime to Stream
extension StreamDebounceExtension<T> on Stream<T> {
  Stream<T> debounceTime(Duration duration) {
    return transform(_DebounceStreamTransformer<T>(duration));
  }
}

/// Stream transformer for debouncing
class _DebounceStreamTransformer<T> extends StreamTransformerBase<T, T> {
  final Duration duration;

  _DebounceStreamTransformer(this.duration);

  @override
  Stream<T> bind(Stream<T> stream) {
    late StreamController<T> controller;
    Timer? debounceTimer;
    late StreamSubscription<T> subscription;

    controller = StreamController<T>(
      onListen: () {
        subscription = stream.listen(
          (value) {
            debounceTimer?.cancel();
            debounceTimer = Timer(duration, () {
              controller.add(value);
            });
          },
          onError: controller.addError,
          onDone: () {
            debounceTimer?.cancel();
            controller.close();
          },
        );
      },
      onPause: () {
        subscription.pause();
        debounceTimer?.cancel();
      },
      onResume: () {
        subscription.resume();
      },
      onCancel: () {
        debounceTimer?.cancel();
        return subscription.cancel();
      },
    );

    return controller.stream;
  }
}
