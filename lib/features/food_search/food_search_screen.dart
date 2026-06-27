import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metadash/core/providers/food_plate_provider.dart';
import 'package:metadash/core/providers/user_state.dart';
import 'package:metadash/core/services/cloud_food_service.dart';
import 'package:metadash/core/services/food_service.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:metadash/core/shared/widgets/food_plate_pill.dart';
import 'package:metadash/data/models/diary_entry_food.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/data/models/user_food_item.dart';
import 'package:metadash/data/repositories/search_repository.dart';
import 'package:metadash/features/food/barcode_scanner_screen.dart';
import 'package:metadash/features/food_search/bloc/food_search_bloc.dart';
import 'package:metadash/features/food_search/fast_food_search_screen.dart';
import 'package:metadash/features/food_search/food_detail_screen.dart';
import 'package:metadash/features/food_search/food_manual_entry.dart';
import 'package:metadash/features/food_search/models.dart';

enum FoodSearchTab { saved, barcode, search, manual }

class FoodSearchScreen extends StatefulWidget {
  final MealName? targetMeal;
  final bool returnOnSelect;
  final UserState? userState;
  final bool autofocusSearch;
  final FoodSearchTab? initialTab;
  final DateTime? targetTimestamp;

  const FoodSearchScreen({
    super.key,
    this.targetMeal,
    this.returnOnSelect = false,
    this.userState,
    this.autofocusSearch = false,
    this.initialTab,
    this.targetTimestamp,
  });

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  late FoodSearchTab _selected;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTab ?? FoodSearchTab.search;
    _searchFocusNode = FocusNode();
    if (widget.autofocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Stage a search result onto the Food Plate (pre-diary tray).
  void _quickAddFood(FoodModel food) {
    final item = FoodPlateItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${food.id}',
      name: food.displayTitle,
      calories: food.calories.toInt(),
      proteinG: food.protein.toInt(),
      carbsG: food.carbs.toInt(),
      fatG: food.fat.toInt(),
      source: 'search',
      serving: food.displayBrand.isNotEmpty
          ? food.displayBrand
          : food.servingUnit,
      // Carry the one-serving base macros + weight so the plate keypad can
      // rescale by weight (matches the food-detail add path).
      baseCalories: food.calories.toDouble(),
      baseProtein: food.protein,
      baseCarbs: food.carbs,
      baseFat: food.fat,
      baseGrams: food.servingWeightGrams,
    );
    context.read<FoodPlateProvider>().add(item);
  }

  void _onSelectFood(FoodModel food) {
    if (widget.returnOnSelect) {
      Navigator.of(context).pop(
        FoodItem(
          name: food.name,
          calories: food.calories.toInt(),
          protein: food.protein,
          carbs: food.carbs,
          fat: food.fat,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          food: food,
          userState: widget.userState,
          targetTimestamp: widget.targetTimestamp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? mealLabel;
    if (widget.targetMeal != null) {
      switch (widget.targetMeal!) {
        case MealName.breakfast:
          mealLabel = 'Breakfast';
          break;
        case MealName.lunch:
          mealLabel = 'Lunch';
          break;
        case MealName.dinner:
          mealLabel = 'Dinner';
          break;
      }
    }

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.bg,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        title: mealLabel != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add Food',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  Text(
                    'Adding to $mealLabel',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              )
            : const Text(
                'Add Food',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _PremiumTabBar(
                selected: _selected,
                onTabSelected: (tab) => setState(() => _selected = tab),
              ),

              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _buildTab(),
                ),
              ),
            ],
          ),
          // Food Plate floating pill — hidden on barcode tab
          if (_selected != FoodSearchTab.barcode)
            const Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(child: FoodPlatePill()),
            ),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_selected) {
      case FoodSearchTab.saved:
        return _SavedLibraryTab(
          key: const ValueKey('saved'),
          userState: widget.userState ?? context.read<UserState>(),
          mealName: widget.targetMeal,
          targetTimestamp: widget.targetTimestamp,
        );
      case FoodSearchTab.barcode:
        return const _ScannerStub(key: ValueKey('barcode'));
      case FoodSearchTab.search:
        return BlocProvider(
          create: (_) =>
              FoodSearchBloc(repository: SearchRepository.withFatSecret())
                ..add(const LoadInitialData()),
          child: FastFoodSearchScreenLegacy(
            key: const ValueKey('search'),
            focusNode: _searchFocusNode,
            targetTimestamp: widget.targetTimestamp,
            onFoodSelected: (food) => _onSelectFood(food),
            onFoodQuickAdd: (food) => _quickAddFood(food),
          ),
        );
      case FoodSearchTab.manual:
        return FoodManualEntry(
          key: const ValueKey('manual'),
          mealName: widget.targetMeal,
          userState: widget.userState,
          targetTimestamp: widget.targetTimestamp,
        );
    }
  }
}

// ── Premium Tab Bar ─────────────────────────────────────────────────────────

class _PremiumTabBar extends StatelessWidget {
  final FoodSearchTab selected;
  final void Function(FoodSearchTab) onTabSelected;

  const _PremiumTabBar({required this.selected, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      (FoodSearchTab.barcode, Icons.qr_code_scanner_rounded, 'Scan'),
      (FoodSearchTab.search, Icons.search_rounded, 'Search'),
      (FoodSearchTab.manual, Icons.bolt_rounded, 'Quick Add'),
      (FoodSearchTab.saved, Icons.bookmark_rounded, 'Saved'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: tabs.map((t) {
          final isSelected = selected == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(t.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? context.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.$2,
                      size: 17,
                      color: isSelected ? Colors.white : context.textSecondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.$3,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SavedLibraryTab extends StatefulWidget {
  final UserState userState;
  final MealName? mealName;
  final DateTime? targetTimestamp;

  const _SavedLibraryTab({
    super.key,
    required this.userState,
    this.mealName,
    this.targetTimestamp,
  });

  @override
  State<_SavedLibraryTab> createState() => _SavedLibraryTabState();
}

class _SavedLibraryTabState extends State<_SavedLibraryTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  double _dragAccum = 0;
  List<UserFoodItem> _libraryFoods = [];
  List<UserFoodItem> _globalFoods = [];
  bool _isLoading = true;
  bool _isSearchingGlobal = false;
  int _subTab = 0; // 0 = Saved Foods, 1 = Recipes
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Auto-hide the search bar when user scrolls down into content (bar is empty).
  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.position.pixels > 10 &&
        _showSearch &&
        _searchController.text.isEmpty) {
      setState(() => _showSearch = false);
    }
  }

  Future<void> _loadLibrary() async {
    final user = widget.userState.currentUser;
    if (user == null) return;

    final query = _searchController.text.trim();
    final results = await widget.userState.db.searchUserFoodLibrary(
      user.id!,
      query,
    );

    if (mounted) {
      setState(() {
        _libraryFoods = results;
        _isLoading = false;
      });
    }

    if (query.isNotEmpty) {
      unawaited(_searchGlobal(query));
    } else {
      setState(() => _globalFoods = []);
    }
  }

  Future<void> _searchGlobal(String query) async {
    setState(() => _isSearchingGlobal = true);
    try {
      final results = await CloudFoodService().searchGlobalLibrary(query);
      if (mounted) {
        setState(() {
          _globalFoods = results;
          _isSearchingGlobal = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearchingGlobal = false);
    }
  }

  Future<void> _logFood(UserFoodItem food) async {
    final user = widget.userState.currentUser;
    if (user == null) return;

    // If global food, save to user library for next time
    // items from cloud will have a String ID (normalized name_brand)
    // while locally new items might be UUIDs.
    // We check if it's already in our local matching list.
    final existsLocally = _libraryFoods.any(
      (f) => f.name == food.name && f.brand == food.brand,
    );
    if (!existsLocally) {
      await widget.userState.db.saveUserFood(food.copyWith(userId: user.id!));
    }

    final entry = DiaryEntryFood(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.id!,
      timestamp: widget.targetTimestamp ?? DateTime.now(),
      name: food.name,
      calories: food.calories.toInt(),
      proteinG: food.protein.toInt(),
      carbsG: food.carbs.toInt(),
      fatG: food.fat.toInt(),
      source: 'manual',
      serving: food.brand,
    );

    await widget.userState.db.addFoodEntry(entry);
    await widget.userState.db.updateFoodLastUsed(food.id);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = _searchController.text.isNotEmpty;
    final totalItemCount =
        _libraryFoods.length +
        (_globalFoods.isEmpty ? 0 : _globalFoods.length + 1);

    return Container(
      color: context.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Pull-down search bar (hidden by default, like Apple Music) ───────
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            height: _showSearch ? 60 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: _showSearch
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.divider),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search saved foods…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: context.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: context.textMuted,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _loadLibrary();
                                    setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(
                                      Icons.cancel_rounded,
                                      size: 18,
                                      color: context.textMuted,
                                    ),
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => _loadLibrary(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Sub-tab segmented control ─────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, _showSearch ? 4 : 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _subTabButton(context, 'Saved Foods', 0),
                  _subTabButton(context, 'Recipes', 1),
                ],
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: Listener(
              // Track vertical drag accumulation — when user pulls down
              // >= 52px while at the very top, reveal the search bar.
              onPointerDown: (_) => _dragAccum = 0,
              onPointerMove: (e) {
                _dragAccum += e.delta.dy;
                final atTop =
                    !_scrollController.hasClients ||
                    _scrollController.position.pixels <= 1;
                // Pull-down at top → reveal search bar
                if (_dragAccum > 52 && atTop && !_showSearch) {
                  setState(() {
                    _showSearch = true;
                    _dragAccum = 0;
                  });
                }
                // Swipe-up → hide search bar (only if query is empty)
                if (_dragAccum < -36 &&
                    _showSearch &&
                    _searchController.text.isEmpty) {
                  setState(() {
                    _showSearch = false;
                    _dragAccum = 0;
                  });
                }
              },
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _subTab == 0
                  ? (hasSearch
                        ? (totalItemCount == 0
                              ? _buildEmptySearch()
                              : _buildSearchResults(totalItemCount))
                        : _buildSavedFoodsContent())
                  : _buildRecipesContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subTabButton(BuildContext context, String label, int index) {
    final sel = _subTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _subTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? context.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: sel ? Colors.white : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: context.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No matching foods found.',
            style: TextStyle(
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(int totalCount) {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < _libraryFoods.length) {
          return _buildFoodItem(_libraryFoods[index]);
        }
        final adj = index - _libraryFoods.length;
        if (adj == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.public_rounded, size: 14, color: context.accent),
                const SizedBox(width: 6),
                Text(
                  'COMMUNITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                    letterSpacing: 1.1,
                  ),
                ),
                if (_isSearchingGlobal) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accent,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return _buildFoodItem(_globalFoods[adj - 1], isGlobal: true);
      },
    );
  }

  Widget _buildSavedFoodsContent() {
    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        // Subtle pull-down hint shown when search is hidden
        if (!_showSearch)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 13,
                  color: context.textMuted.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 3),
                Text(
                  'Pull down to search',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textMuted.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),

        // Section header
        Row(
          children: [
            Text(
              'MY SAVED FOODS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            if (_libraryFoods.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_libraryFoods.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (_libraryFoods.isEmpty)
          _emptyFoodsCard()
        else
          ..._libraryFoods.map((f) => _buildFoodItem(f)),
      ],
    );
  }

  Widget _buildRecipesContent() {
    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.divider),
          ),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 32,
                  color: context.accent.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Recipes',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Build multi-ingredient meals\nand log them with a single tap.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyFoodsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 34,
            color: context.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'No saved foods yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use Quick Add to create custom foods\nor star foods in Search to save them here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(UserFoodItem food, {bool isGlobal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _logFood(food),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isGlobal
                  ? context.accent.withValues(alpha: 0.15)
                  : context.divider,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    food.name.isNotEmpty ? food.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: context.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + brand
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (food.brand != null && food.brand!.isNotEmpty)
                      Text(
                        food.brand!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Nutrition
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${food.calories.toInt()} kcal',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: context.accent,
                    ),
                  ),
                  Text(
                    'P${food.protein.toInt()} · C${food.carbs.toInt()} · F${food.fat.toInt()}',
                    style: TextStyle(fontSize: 11, color: context.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerStub extends StatefulWidget {
  const _ScannerStub({super.key});

  @override
  State<_ScannerStub> createState() => _ScannerStubState();
}

class _ScannerStubState extends State<_ScannerStub> {
  final FoodService _foodService = FoodService();
  bool _isLoading = false;

  Future<void> _handleBarcodeScanned(String barcode) async {
    setState(() => _isLoading = true);
    try {
      final food = await _foodService.searchByBarcode(barcode);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (food != null) {
        // Route through the same detail → Food Plate flow as a tapped search
        // result, so the user can tweak the serving before logging.
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  FoodDetailScreen(food: _foodModelFromLegacy(food)),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No product found for that barcode')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Adapt a legacy [Food] (barcode lookup) into the [FoodModel] used by the
  /// search → detail → Food Plate flow. When the serving is expressed in grams
  /// or millilitres, carry that as the serving weight so the plate keypad can
  /// rescale macros by weight.
  FoodModel _foodModelFromLegacy(Food f) {
    final unit = f.servingUnit.toLowerCase();
    final isWeightOrVolume =
        unit == 'g' ||
        unit == 'gram' ||
        unit == 'grams' ||
        unit == 'ml' ||
        unit == 'milliliter' ||
        unit == 'milliliters';
    final fm = FoodModel.create(
      id: f.id,
      name: f.name,
      brand: f.brand,
      servingSize: f.servingSize,
      servingUnit: f.servingUnit,
      calories: f.calories,
      protein: f.protein,
      carbs: f.carbs,
      fat: f.fat,
      source: f.source,
    );
    if (isWeightOrVolume && f.servingSize > 0) {
      return fm.copyWith(servingWeightGrams: f.servingSize);
    }
    return fm;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: context.bg,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    return BarcodeScannerScreen(onBarcodeScanned: _handleBarcodeScanned);
  }
}
