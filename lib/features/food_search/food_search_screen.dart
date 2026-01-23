import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import 'models.dart';
import 'food_search_results.dart';
import 'food_manual_entry.dart';
import 'food_detail_screen.dart';

enum FoodSearchTab { saved, barcode, search, ai, manual }

class FoodSearchScreen extends StatefulWidget {
  final MealName? targetMeal;
  final bool returnOnSelect;

  const FoodSearchScreen({super.key, this.targetMeal, this.returnOnSelect = false});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  FoodSearchTab _selected = FoodSearchTab.search;
  String _searchText = '';
  final List<FoodItem> _recent = mockFoods.take(6).toList();

  void _onSelectFood(FoodItem item) {
    if (widget.returnOnSelect) {
      Navigator.of(context).pop(item);
      return;
    }

    final v2 = item.name.toLowerCase().contains('egg')
        ? FoodItemV2.eggLarge
        : FoodItemV2.chickenBreast;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(item: v2, mealName: null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (FoodSearchTab.barcode, Icons.qr_code, 'Barcode'),
      (FoodSearchTab.search, Icons.search, 'Search'),
      (FoodSearchTab.ai, Icons.auto_awesome, 'AI'),
      (FoodSearchTab.manual, Icons.bolt, 'Quick Add'),
      (FoodSearchTab.saved, Icons.book, 'Saved Foods'),
    ];

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
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.$2, size: 16, color: selected ? Palette.warmNeutral : Colors.black87),
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
        return FoodSearchResults(
          key: const ValueKey('search'),
          searchText: _searchText,
          recent: _recent,
          onSelect: _onSelectFood,
          onSearchChanged: (v) => setState(() => _searchText = v),
        );
      case FoodSearchTab.ai:
        return const _AIStub(key: ValueKey('ai'));
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

class _ScannerStub extends StatelessWidget {
  const _ScannerStub({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.warmNeutral,
      alignment: Alignment.center,
      child: const Text('Scanner (stub) — integrate mobile_scanner later'),
    );
  }
}

class _AIStub extends StatelessWidget {
  const _AIStub({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.warmNeutral,
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Chat with AI to estimate nutrition', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 4),
            Text(
              'Describe meals (e.g., at restaurants) and get AI-estimated nutrition to add to your log.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}
