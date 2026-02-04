import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/food_model.dart';
import '../../data/models/food_search_result_raw.dart';
import '../../domain/search_state.dart' as domain;
import '../bloc/food_search_bloc.dart';
import '../../presentation/formatters/food_display_formatter.dart';
import '../../services/food_display_normalizer.dart';

/// Modern food search screen with local-first architecture
/// Features: debounced search, skeleton loading, progressive results
class FastFoodSearchScreen extends StatefulWidget {
  const FastFoodSearchScreen({super.key});

  @override
  State<FastFoodSearchScreen> createState() => _FastFoodSearchScreenState();
}

class _FastFoodSearchScreenState extends State<FastFoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Load initial data (recent searches + favorites)
    context.read<FoodSearchBloc>().add(const LoadInitialData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Foods'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),

          // Results
          Expanded(
            child: BlocBuilder<FoodSearchBloc, domain.FoodSearchState>(
              builder: (context, state) {
                if (state is domain.SearchInitial) {
                  return _buildInitialView(state);
                } else if (state is domain.SearchLoading) {
                  return _buildLoadingView(state);
                } else if (state is domain.SearchSuccess) {
                  return _buildSuccessView(state);
                } else if (state is domain.SearchEmpty) {
                  return _buildEmptyView(state);
                } else if (state is domain.SearchError) {
                  return _buildErrorView(state);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Search bar with clear button
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search foods...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<FoodSearchBloc>().add(const ClearSearch());
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (query) {
          context.read<FoodSearchBloc>().add(SearchQueryChanged(query));
          setState(() {}); // Refresh to show/hide clear button
        },
      ),
    );
  }

  /// Initial view (recent searches + favorites)
  Widget _buildInitialView(domain.SearchInitial state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recent searches
        if (state.recentSearches.isNotEmpty) ...[
          const Text(
            'Recent Searches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...state.recentSearches.map((query) => _buildRecentSearchTile(query)),
          const SizedBox(height: 24),
        ],

        // Favorites
        if (state.favorites.isNotEmpty) ...[
          const Text(
            'Favorites',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...state.favorites.map(_buildFoodTile),
        ],

        // Empty state
        if (state.recentSearches.isEmpty && state.favorites.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Start searching for foods',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Loading view with skeleton loaders
  Widget _buildLoadingView(domain.SearchLoading state) {
    // Show partial results if available, otherwise show skeletons
    if (state.partialResults.isNotEmpty) {
      return _buildResultsList(state.partialResults, isLoading: true);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) => _buildSkeletonTile(),
    );
  }

  /// Success view with results
  Widget _buildSuccessView(domain.SearchSuccess state) {
    return Column(
      children: [
        // Source indicator (local/cache/remote)
        _buildSourceIndicator(state.source, state.isLoadingMore),

        // Results list
        Expanded(
          child: _buildResultsList(
            state.results,
            isLoading: state.isLoadingMore,
          ),
        ),
      ],
    );
  }

  /// Empty results view
  Widget _buildEmptyView(domain.SearchEmpty state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "${state.query}"',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Error view
  Widget _buildErrorView(domain.SearchError state) {
    // Show fallback results if available
    if (state.fallbackResults.isNotEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.orange[100],
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[900]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing cached results (network unavailable)',
                    style: TextStyle(color: Colors.orange[900]),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildResultsList(state.fallbackResults),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Search failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// Source indicator chip
  Widget _buildSourceIndicator(domain.SearchSource source, bool isLoadingMore) {
    String label;
    Color color;

    switch (source) {
      case domain.SearchSource.local:
        label = 'Local results';
        color = Colors.green;
        break;
      case domain.SearchSource.cache:
        label = 'Cached results';
        color = Colors.blue;
        break;
      case domain.SearchSource.remote:
        label = 'Fresh results';
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Chip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            backgroundColor: color.withOpacity(0.1),
            labelStyle: TextStyle(color: color),
            avatar: Icon(Icons.circle, size: 8, color: color),
          ),
          if (isLoadingMore) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            const Text('Loading more...', style: TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  /// Results list with optional loading indicator
  Widget _buildResultsList(List<FoodModel> results, {bool isLoading = false}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length + (isLoading ? 3 : 0),
      itemBuilder: (context, index) {
        if (index < results.length) {
          return _buildFoodTile(results[index]);
        } else {
          return _buildSkeletonTile();
        }
      },
    );
  }

  /// Food tile
  Widget _buildFoodTile(FoodModel food) {
    // Use new normalizer for clean display values
    final normalized = FoodDisplayNormalizer.normalize(food);
    final isMissingServing = food.isMissingServing;
    
    // Build source label
    final sourceLabel = normalized.displaySourceTag.isNotEmpty 
        ? ' · ${normalized.displaySourceTag}' 
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isMissingServing ? Colors.grey[50] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isMissingServing ? Colors.grey[200] : Colors.blue[100],
          child: Text(
            normalized.displayTitle.isNotEmpty ? normalized.displayTitle[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          normalized.displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand line with source tag
            Text(
              '${normalized.displayBrandLine}$sourceLabel',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Single subtitle: "X kcal · Y ml" exactly once, no duplicates
            Row(
              children: [
                Expanded(
                  child: Text(
                    normalized.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMissingServing ? Colors.orange[700] : Colors.grey[600],
                      fontWeight: isMissingServing ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Warning icon for missing serving
                if (isMissingServing)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.warning_outlined,
                      size: 14,
                      color: Colors.orange[700],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            food.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: food.isFavorite ? Colors.red : null,
          ),
          onPressed: () {
            context.read<FoodSearchBloc>().add(ToggleFavorite(food.id));
          },
        ),
        onTap: () {
          // Navigate to detail screen
          // Navigator.push(context, MaterialPageRoute(builder: (_) => FoodDetailScreen(food: food)));
        },
      ),
    );
  }

  /// Recent search tile
  Widget _buildRecentSearchTile(String query) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(query),
        trailing: const Icon(Icons.north_west),
        onTap: () {
          _searchController.text = query;
          context.read<FoodSearchBloc>().add(SearchQueryChanged(query));
        },
      ),
    );
  }

  /// Skeleton loading tile
  Widget _buildSkeletonTile() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[300],
        ),
        title: Container(
          height: 16,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              height: 12,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 12,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper for FastFoodSearchScreen for use in tabs
/// Calls callback instead of popping navigation
class FastFoodSearchScreenLegacy extends StatefulWidget {
  final void Function(FoodModel) onFoodSelected;
  final FocusNode? focusNode;

  const FastFoodSearchScreenLegacy({
    super.key,
    required this.onFoodSelected,
    this.focusNode,
  });

  @override
  State<FastFoodSearchScreenLegacy> createState() =>
      _FastFoodSearchScreenLegacyState();
}

class _FastFoodSearchScreenLegacyState extends State<FastFoodSearchScreenLegacy> {
  final TextEditingController _searchController = TextEditingController();
  late FocusNode _searchFocusNode;
  List<FoodModel> _latestResults = const [];

  @override
  void initState() {
    super.initState();
    _searchFocusNode = widget.focusNode ?? FocusNode();
    context.read<FoodSearchBloc>().add(const LoadInitialData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Only dispose if we created the FocusNode (not passed from parent)
    if (widget.focusNode == null) {
      _searchFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        _buildSearchBar(),

        // Results
        Expanded(
          child: BlocBuilder<FoodSearchBloc, domain.FoodSearchState>(
            builder: (context, state) {
              if (state is domain.SearchInitial) {
                return _buildInitialView(context);
              } else if (state is domain.SearchLoading) {
                return _buildLoadingView();
              } else if (state is domain.SearchSuccess) {
                return _buildSuccessView(state);
              } else if (state is domain.SearchEmpty) {
                return _buildEmptyView(state);
              } else if (state is domain.SearchError) {
                return _buildErrorView(state);
              }
              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onLongPress: kDebugMode ? _exportRawResultsToClipboard : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (query) {
            if (query.isEmpty) {
              context.read<FoodSearchBloc>().add(const ClearSearch());
            } else if (query.length > 1) {
              context.read<FoodSearchBloc>().add(SearchQueryChanged(query));
            }
          },
          decoration: InputDecoration(
            hintText: 'Search foods...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      context.read<FoodSearchBloc>().add(const ClearSearch());
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialView(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Searches',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                BlocBuilder<FoodSearchBloc, domain.FoodSearchState>(
                  builder: (context, state) {
                    if (state is domain.SearchInitial) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: state.recentSearches.map((q) {
                          return ActionChip(
                            label: Text(q),
                            onPressed: () {
                              _searchController.text = q;
                              context
                                  .read<FoodSearchBloc>()
                                  .add(SearchQueryChanged(q));
                            },
                          );
                        }).toList(),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          // Favorites
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Favorites',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                BlocBuilder<FoodSearchBloc, domain.FoodSearchState>(
                  builder: (context, state) {
                    if (state is domain.SearchInitial && state.favorites.isNotEmpty) {
                      return Column(
                        children: state.favorites.map((food) {
                          return ListTile(
                            title: Text(
                              food.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${food.calories} cal • ${food.servingLine}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => widget.onFoodSelected(food),
                          );
                        }).toList(),
                      );
                    }
                    return const Text('No favorites yet');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccessView(domain.SearchSuccess state) {
    _latestResults = state.results;
    return ListView.builder(
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final food = state.results[index];
        return _buildFoodTile(food);
      },
    );
  }

  void _exportRawResultsToClipboard() {
    if (!kDebugMode) return;

    final preview = _latestResults.take(20).toList();
    if (preview.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No results to export yet.')),
      );
      return;
    }

    final raw = preview.map(_toRaw).map((e) => e.toJson()).toList();
    final jsonText = jsonEncode(raw);

    Clipboard.setData(ClipboardData(text: jsonText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Raw results copied to clipboard (first 20).')),
    );
  }

  FoodSearchResultRaw _toRaw(FoodModel item) {
    return FoodSearchResultRaw(
      id: item.id,
      source: item.source,
      sourceId: item.sourceId,
      barcode: item.barcode,
      verified: item.verified,
      providerScore: item.confidence,
      foodNameRaw: item.foodNameRaw,
      foodName: item.foodName ?? item.name,
      brandName: item.brandName ?? item.brand,
      brandOwner: item.brandOwner,
      restaurantName: item.restaurantName,
      category: item.category,
      subcategory: item.subcategory,
      languageCode: item.languageCode,
      servingQty: item.servingQty,
      servingUnit: item.servingUnitRaw ?? item.servingUnit,
      servingWeightGrams: item.servingWeightGrams,
      servingVolumeMl: item.servingVolumeMl,
      servingOptions: item.servingOptions,
      calories: item.calories.toDouble(),
      proteinG: item.protein,
      carbsG: item.carbs,
      fatG: item.fat,
      nutritionBasis: item.nutritionBasis ?? item.nutritionBasisType,
      rawJson: item.rawJson ?? const {},
      lastUpdated: item.lastUpdated ?? item.updatedAt,
      dataType: item.dataType,
      popularity: item.popularity,
      isGeneric: item.isGeneric,
      isBranded: item.isBranded,
    );
  }

  Widget _buildFoodTile(FoodModel food) {
    final display = buildFoodDisplayStrings(food);
    final isMissingServing = food.isMissingServing;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isMissingServing ? Colors.grey[200] : Colors.blue[100],
        child: Text(
          display.leadingLetter,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        display.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        display.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMissingServing ? Colors.orange[700] : Colors.grey[600],
        ),
      ),
      onTap: () => widget.onFoodSelected(food),
    );
  }

  Widget _buildEmptyView(domain.SearchEmpty state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No foods found for "${state.query}"',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(domain.SearchError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error: ${state.message}',
            style: TextStyle(color: Colors.red[600]),
          ),
        ],
      ),
    );
  }

  /// Debug method: Print normalized food display values for verification
  void _debugPrintNormalization(List<FoodModel> foods) {
    if (!kDebugMode || foods.isEmpty) return;

    debugPrint('\n=== FOOD NORMALIZATION DEBUG ===');
    debugPrint('Total items: ${foods.length}');
    debugPrint('');

    for (int i = 0; i < foods.take(10).length; i++) {
      final food = foods[i];
      final norm = FoodDisplayNormalizer.normalize(food);

      debugPrint('[$i] ${norm.displayTitle}');
      debugPrint('    Brand: ${norm.displayBrandLine}');
      debugPrint('    Source: ${norm.displaySourceTag}');
      debugPrint('    Calories: ${norm.displayCaloriesText}');
      debugPrint('    Serving: ${norm.displayServingText}');
      debugPrint('    Subtitle: ${norm.subtitle}');
      debugPrint('');
    }
    debugPrint('================================\n');
  }
}
