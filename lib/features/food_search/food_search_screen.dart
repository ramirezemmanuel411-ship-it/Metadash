import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../services/food_service.dart';
import '../../data/repositories/search_repository.dart';
import '../../presentation/bloc/food_search_bloc.dart';
import '../../presentation/screens/fast_food_search_screen.dart';
import '../../providers/user_state.dart';
import '../../models/user_food_item.dart';
import '../../models/diary_entry_food.dart';
import '../../services/cloud_food_service.dart';
import '../food/barcode_scanner_screen.dart';
import '../food/food_detail_page.dart';
import 'models.dart';
import 'food_manual_entry.dart';
import 'food_detail_screen.dart';

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

  void _onSelectFood(FoodItem item) {
    if (widget.returnOnSelect) {
      Navigator.of(context).pop(item);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          item: item,
          mealName: null,
          userState: widget.userState,
          targetTimestamp: widget.targetTimestamp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (FoodSearchTab.barcode, Icons.qr_code, 'Barcode'),
      (FoodSearchTab.search, Icons.search, 'Search'),
      (FoodSearchTab.manual, Icons.bolt, 'Quick Add'),
      (FoodSearchTab.saved, Icons.book, 'Saved Foods'),
    ];

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
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        title: const Text('Add Food'),
      ),
      body: Column(
        children: [
          if (mealLabel != null)
            Container(
              width: double.infinity,
              color: Palette.forestGreen,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Adding to $mealLabel',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: tabs.map((t) {
                final selected = _selected == t.$1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t.$2,
                          size: 16,
                          color: selected
                              ? Palette.warmNeutral
                              : Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Text(t.$3),
                      ],
                    ),
                    selectedColor: Palette.forestGreen,
                    backgroundColor: Palette.lightStone,
                    labelStyle: TextStyle(
                      color: selected ? Palette.warmNeutral : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    onSelected: (_) => setState(() => _selected = t.$1),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildTab(),
            ),
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
          create: (_) => FoodSearchBloc(
            repository: SearchRepository.withFatSecret(),
          )..add(const LoadInitialData()),
          child: FastFoodSearchScreenLegacy(
            key: const ValueKey('search'),
            focusNode: _searchFocusNode,
            onFoodSelected: (food) {
              final item = FoodItem(
                name: food.name,
                calories: food.calories.toInt(),
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
              );
              _onSelectFood(item);
            },
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
  List<UserFoodItem> _libraryFoods = [];
  List<UserFoodItem> _globalFoods = [];
  bool _isLoading = true;
  bool _isSearchingGlobal = false;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
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
      _searchGlobal(query);
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
    final existsLocally = _libraryFoods.any((f) => f.name == food.name && f.brand == food.brand);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${food.name} to your log')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItemCount = _libraryFoods.length +
        (_globalFoods.isEmpty ? 0 : _globalFoods.length + 1);

    return Container(
      color: Palette.warmNeutral,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search my library...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Palette.lightStone,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => _loadLibrary(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : totalItemCount == 0
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Your library is empty.\nGo to Quick Add to create a custom food!'
                              : 'No matching foods found.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: totalItemCount,
                        itemBuilder: (context, index) {
                          // Local Library Section
                          if (index < _libraryFoods.length) {
                            final food = _libraryFoods[index];
                            return _buildFoodItem(food);
                          }

                          // Community Header
                          final adjustedIndex = index - _libraryFoods.length;
                          if (adjustedIndex == 0) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.public,
                                      size: 18, color: Palette.forestGreen),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Community Results',
                                    style: TextStyle(
                                      color: Palette.forestGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (_isSearchingGlobal)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 12),
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }

                          // Global Library Section
                          final globalFood = _globalFoods[adjustedIndex - 1];
                          return _buildFoodItem(globalFood, isGlobal: true);
                        },
                      ),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Palette.lightStone,
            borderRadius: BorderRadius.circular(12),
            border: isGlobal
                ? Border.all(color: Palette.forestGreen.withOpacity(0.1))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (food.brand != null)
                      Text(
                        food.brand!,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${food.calories.toInt()} kcal',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Palette.forestGreen,
                    ),
                  ),
                  Text(
                    'P: ${food.protein.toInt()}g C: ${food.carbs.toInt()}g F: ${food.fat.toInt()}g',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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
      if (mounted) {
        setState(() => _isLoading = false);
        if (food != null) {
          // Navigate to food detail page to show full nutrition info
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FoodDetailPage(food: food)),
          );

          // If user added food to log, return the result
          if (result != null && mounted) {
            Navigator.pop(context, result);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product not found. Try manual search.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Palette.warmNeutral,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return BarcodeScannerScreen(onBarcodeScanned: _handleBarcodeScanned);
  }
}

