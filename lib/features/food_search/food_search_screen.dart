import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/palette.dart';
import '../../services/food_service.dart';
import '../../data/repositories/search_repository.dart';
import '../../presentation/bloc/food_search_bloc.dart';
import '../../presentation/screens/fast_food_search_screen.dart';
import '../../providers/user_state.dart';
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

  const FoodSearchScreen({
    super.key,
    this.targetMeal,
    this.returnOnSelect = false,
    this.userState,
    this.autofocusSearch = false,
    this.initialTab,
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
        builder: (_) => FoodDetailScreen(item: item, mealName: null, userState: widget.userState),
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
        return const _SavedLibraryStub(key: ValueKey('saved'));
      case FoodSearchTab.barcode:
        return const _ScannerStub(key: ValueKey('barcode'));
      case FoodSearchTab.search:
        return BlocProvider(
          create: (_) => FoodSearchBloc(
            repository: SearchRepository(),
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
        return const FoodManualEntry(key: ValueKey('manual'), mealName: null);
    }
  }
}

class _SavedLibraryStub extends StatelessWidget {
  const _SavedLibraryStub({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.warmNeutral,
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          _sectionCard(
            title: 'Saved Foods',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Chicken Breast'),
                SizedBox(height: 6),
                Text('Greek Yogurt'),
                SizedBox(height: 6),
                Text('Oats'),
              ],
            ),
          ),
        ],
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

Widget _sectionCard({required String title, required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: Palette.lightStone,
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}
