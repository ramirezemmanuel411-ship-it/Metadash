// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import '../../services/food_service.dart';
import '../food/food_detail_page.dart';
import 'models.dart';

class FoodSearchResults extends StatefulWidget {
  final String searchText;
  final List<FoodItem> recent;
  final void Function(FoodItem) onSelect;
  final void Function(String) onSearchChanged;

  const FoodSearchResults({
    super.key,
    required this.searchText,
    required this.recent,
    required this.onSelect,
    required this.onSearchChanged,
  });

  @override
  State<FoodSearchResults> createState() => _FoodSearchResultsState();
}

class _FoodSearchResultsState extends State<FoodSearchResults> {
  final FoodService _foodService = FoodService();
  List<Food>? _searchResults;
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isLoading = false;
      });
      return;
    }

    // Only search if at least 2 characters (faster)
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = null;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Search Open Food Facts first - show results ASAP
      final offResults = await _foodService.searchOpenFoodFactsOnly(query);

      if (mounted) {
        setState(() {
          _searchResults = offResults;
          _isLoading = false;
        });
      }

      // Search USDA in background with timeout
      _foodService
          .searchUSDAOnly(query)
          .timeout(const Duration(seconds: 3), onTimeout: () => [])
          .then((usdaResults) {
            if (mounted &&
                usdaResults.isNotEmpty &&
                _searchResults != null &&
                _searchResults!.isNotEmpty) {
              // Only append USDA results that aren't already in OFF
              final newResults = usdaResults
                  .where(
                    (usda) => !_searchResults!.any(
                      (off) =>
                          off.name.toLowerCase() == usda.name.toLowerCase() &&
                          off.brand?.toLowerCase() == usda.brand?.toLowerCase(),
                    ),
                  )
                  .toList();

              if (newResults.isNotEmpty) {
                setState(() {
                  _searchResults = [..._searchResults!, ...newResults];
                });
              }
            }
          })
          .catchError((e) {
            print('Background USDA search error: $e');
          });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search error: $e')));
      }
    }
  }

  void _onSearchChanged(String v) {
    widget.onSearchChanged(v);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _performSearch(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.warmNeutral,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _searchField(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      if (widget.searchText.trim().isEmpty &&
                          widget.recent.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 6),
                          child: Text(
                            'Recent',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _roundedList(
                          children: widget.recent
                              .map(
                                (i) => _FoodRow(
                                  item: i,
                                  onTap: () => widget.onSelect(i),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (widget.searchText.trim().isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 6),
                          child: Text(
                            'Results',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_searchResults == null || _searchResults!.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'No foods found for "${widget.searchText}"',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          _roundedList(
                            children: _searchResults!
                                .map(
                                  (food) => _DatabaseFoodRow(
                                    food: food,
                                    onTap: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FoodDetailPage(food: food),
                                        ),
                                      );
                                      if (result != null && mounted) {
                                        Navigator.pop(context, result);
                                      }
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search foods',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                autocorrect: false,
                onChanged: _onSearchChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundedList({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Container(
              color: Palette.lightStone,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: children[i],
              ),
            ),
            if (i != children.length - 1) const SizedBox(height: 0),
          ],
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;

  const _FoodRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  item.macroLine,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '${item.calories} kcal',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatabaseFoodRow extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;

  const _DatabaseFoodRow({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final macroLine =
        'P ${food.protein.toInt()}g • C ${food.carbs.toInt()}g • F ${food.fat.toInt()}g';

    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.brand != null
                      ? '${food.name} By ${food.brand}'
                      : food.name,
                  style: const TextStyle(fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  macroLine,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '${food.calories.toInt()} kcal',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
