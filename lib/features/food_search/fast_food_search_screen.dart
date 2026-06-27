// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metadash/core/domain/search_state.dart' as domain;
import 'package:metadash/core/formatters/food_display_formatter.dart';
import 'package:metadash/core/providers/food_plate_provider.dart';
import 'package:metadash/core/providers/user_state.dart';
import 'package:metadash/core/services/food_quality_engine.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/data/models/food_search_result_raw.dart';
import 'package:metadash/features/food_search/bloc/food_search_bloc.dart';

/// Food search screen used inside the Add Food tabs.
/// Invokes a callback on selection instead of popping navigation.
class FastFoodSearchScreenLegacy extends StatefulWidget {
  final void Function(FoodModel) onFoodSelected;
  final void Function(FoodModel)? onFoodQuickAdd;
  final FocusNode? focusNode;
  final DateTime? targetTimestamp;

  const FastFoodSearchScreenLegacy({
    super.key,
    required this.onFoodSelected,
    this.onFoodQuickAdd,
    this.focusNode,
    this.targetTimestamp,
  });

  @override
  State<FastFoodSearchScreenLegacy> createState() =>
      _FastFoodSearchScreenLegacyState();
}

class _FastFoodSearchScreenLegacyState
    extends State<FastFoodSearchScreenLegacy> {
  final TextEditingController _searchController = TextEditingController();
  late FocusNode _searchFocusNode;
  List<FoodModel> _latestResults = const [];
  bool _isFocused = false;
  List<Map<String, dynamic>> _recentlyLogged = [];

  @override
  void initState() {
    super.initState();
    _searchFocusNode = widget.focusNode ?? FocusNode();
    _searchFocusNode.addListener(_onFocusChange);
    context.read<FoodSearchBloc>().add(const LoadInitialData());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecentlyLogged());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _searchFocusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _searchFocusNode.hasFocus;
    if (_isFocused != focused) setState(() => _isFocused = focused);
  }

  Future<void> _loadRecentlyLogged() async {
    if (!mounted) return;
    try {
      final userState = context.read<UserState>();
      final user = userState.currentUser;
      if (user == null) return;
      final maps = await userState.db.getFoodEntriesForDay(
        user.id!,
        DateTime.now(),
      );
      if (mounted) setState(() => _recentlyLogged = maps.take(8).toList());
    } catch (_) {}
  }

  /// Stage a previously logged item onto the Food Plate (pre-diary tray).
  void _reAddLoggedEntry(Map<String, dynamic> entry) {
    if (!mounted) return;
    final name = entry['name'] as String? ?? 'Unknown';
    final item = FoodPlateItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_recentlog',
      name: name,
      calories: (entry['calories'] as num?)?.toInt() ?? 0,
      proteinG: (entry['proteinG'] as num?)?.toInt() ?? 0,
      carbsG: (entry['carbsG'] as num?)?.toInt() ?? 0,
      fatG: (entry['fatG'] as num?)?.toInt() ?? 0,
      source: 'search',
      serving: entry['serving'] as String?,
    );
    context.read<FoodPlateProvider>().add(item);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: BlocBuilder<FoodSearchBloc, domain.FoodSearchState>(
            builder: (context, state) {
              if (state is domain.SearchInitial) {
                return _buildInitialView(state);
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.divider),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: TextStyle(
              fontSize: 15,
              color: context.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            onChanged: (query) {
              if (query.isEmpty) {
                context.read<FoodSearchBloc>().add(const ClearSearch());
              } else if (query.length > 1) {
                context.read<FoodSearchBloc>().add(SearchQueryChanged(query));
              }
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Search 900,000+ foods...',
              hintStyle: TextStyle(
                fontSize: 15,
                color: context.textMuted,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: context.textSecondary,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        context.read<FoodSearchBloc>().add(const ClearSearch());
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
                vertical: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialView(domain.SearchInitial state) {
    // ── Focused: show search history (recents + favorites) ──────────────────
    if (_isFocused) {
      final hasRecents = state.recentSearches.isNotEmpty;
      final hasFavs = state.favorites.isNotEmpty;
      if (!hasRecents && !hasFavs) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 36,
                  color: context.textMuted.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 12),
                Text(
                  'No recent searches',
                  style: TextStyle(fontSize: 14, color: context.textSecondary),
                ),
              ],
            ),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        children: [
          if (hasRecents) ...[
            _sectionLabel('RECENT'),
            ...state.recentSearches.take(8).map(_recentRow),
            const SizedBox(height: 8),
          ],
          if (hasFavs) ...[
            if (hasRecents)
              Divider(height: 1, indent: 62, color: context.divider),
            const SizedBox(height: 12),
            _sectionLabel('FAVORITES'),
            ...state.favorites.map(_buildFoodTile),
          ],
        ],
      );
    }

    // ── Unfocused: show recently logged foods for today ─────────────────────
    if (_recentlyLogged.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_rounded,
                size: 52,
                color: context.textMuted.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 14),
              Text(
                'Search for any food',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '900,000+ foods from USDA & FatSecret',
                style: TextStyle(fontSize: 13, color: context.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      children: [
        _sectionLabel('RECENTLY LOGGED'),
        ..._recentlyLogged.map(_buildRecentlyLoggedTile),
      ],
    );
  }

  Widget _buildRecentlyLoggedTile(Map<String, dynamic> entry) {
    final name = entry['name'] as String? ?? 'Unknown';
    final calories = (entry['calories'] as num?)?.toInt() ?? 0;
    final protein = (entry['proteinG'] as num?)?.toInt() ?? 0;
    final carbs = (entry['carbsG'] as num?)?.toInt() ?? 0;
    final fat = (entry['fatG'] as num?)?.toInt() ?? 0;
    final serving = entry['serving'] as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.surfaceVariant,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: context.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (serving != null && serving.isNotEmpty)
                  Text(
                    serving,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '$calories cal  ·  ${protein}p  ${carbs}c  ${fat}f',
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _reAddLoggedEntry(entry),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.add_rounded, size: 18, color: context.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentRow(String query) {
    return InkWell(
      onTap: () {
        _searchController.text = query;
        context.read<FoodSearchBloc>().add(SearchQueryChanged(query));
        setState(() {});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.surfaceVariant,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 16,
                color: context.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                query,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
              ),
            ),
            Icon(Icons.north_west_rounded, size: 13, color: context.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.surfaceVariant,
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 7),
                      decoration: BoxDecoration(
                        color: context.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    Container(
                      height: 11,
                      width: 140,
                      decoration: BoxDecoration(
                        color: context.surfaceVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuccessView(domain.SearchSuccess state) {
    _latestResults = state.results;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: state.results.length,
      itemBuilder: (context, index) => _buildFoodTile(state.results[index]),
    );
  }

  void _exportRawResultsToClipboard() {
    if (!kDebugMode) return;

    final preview = _latestResults.take(20).toList();
    if (preview.isEmpty) return;

    final raw = preview.map(_toRaw).map((e) => e.toJson()).toList();
    final jsonText = jsonEncode(raw);

    Clipboard.setData(ClipboardData(text: jsonText));
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
    final quality = FoodQualityEngine.evaluate(
      food,
      query: _searchController.text,
    );
    final avatarColor = _verificationColor(quality.level);

    // Food name — always the primary title
    final foodName = food.displayTitle;
    final leadingLetter = foodName.isNotEmpty ? foodName[0].toUpperCase() : '?';

    // Brand — secondary line, hide if empty, generic, same-as-name,
    // or a bare cooking descriptor / standalone corporate suffix.
    final brand = food.displayBrand;
    const invalidBrandDisplay = {
      'inc',
      'inc.',
      'llc',
      'corp',
      'corp.',
      'ltd',
      'ltd.',
      'co',
      'rotisserie',
      'grilled',
      'roasted',
      'baked',
      'fried',
      'smoked',
      'boiled',
      'steamed',
      'raw',
      'cooked',
      'fresh',
      'frozen',
    };
    final showBrand =
        brand.isNotEmpty &&
        brand.toLowerCase() != 'generic' &&
        brand.toLowerCase() != foodName.toLowerCase() &&
        !invalidBrandDisplay.contains(brand.toLowerCase().trim());

    // Nutrition info line
    final display = buildFoodDisplayStrings(food);
    final nutritionLine = display.subtitle;

    return InkWell(
      onTap: () => widget.onFoodSelected(food),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  leadingLetter,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: avatarColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Food name
                  Text(
                    foodName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Brand (if meaningful)
                  if (showBrand)
                    Text(
                      brand,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  // Nutrition info
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      nutritionLine,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.onFoodQuickAdd != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onFoodQuickAdd!(food),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: context.accent,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.colors.divider,
              ),
          ],
        ),
      ),
    );
  }

  Color _verificationColor(FoodVerificationLevel level) => switch (level) {
    FoodVerificationLevel.metadashVerified => const Color(0xFF2E8B57),
    FoodVerificationLevel.consensusVerified => const Color(0xFF4C7FA8),
    FoodVerificationLevel.verifiedSource => const Color(0xFF2E8B57),
    FoodVerificationLevel.community ||
    FoodVerificationLevel.needsReview => const Color(0xFF888888),
  };

  Widget _buildEmptyView(domain.SearchEmpty state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: context.colors.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results for',
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              '“${state.query}”',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Try a different spelling or a more\ngeneral term like “chicken”',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(domain.SearchError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: context.colors.textMuted.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not reach the database',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
