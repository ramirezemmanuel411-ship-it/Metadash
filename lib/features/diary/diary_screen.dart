import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import '../food_search/food_search_screen.dart';
import '../food_search/models.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _selectedDay = DateTime.now();

  final Map<MealName, List<_MealItem>> _meals = {
    MealName.breakfast: [
      _MealItem(name: 'Oats', calories: 150, macro: 'P 5g • C 27g • F 3g'),
      _MealItem(name: 'Greek Yogurt', calories: 100, macro: 'P 17g • C 6g • F 0g'),
    ],
    MealName.lunch: [
      _MealItem(name: 'Chicken Breast', calories: 165, macro: 'P 31g • C 0g • F 3g'),
    ],
    MealName.dinner: [
      _MealItem(name: 'Salmon', calories: 208, macro: 'P 22g • C 0g • F 13g'),
    ],
    // snacks will be handled under a separate bucket (use lunch as default if needed)
  };

  void _shiftDays(int delta) {
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: delta));
    });
  }

  Future<void> _addFoodForMeal(MealName meal) async {
    final result = await Navigator.of(context).push<FoodItem?>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(targetMeal: meal, returnOnSelect: true),
      ),
    );

    if (result != null) {
      setState(() {
        final list = _meals.putIfAbsent(meal, () => []);
        list.add(_MealItem(name: result.name, calories: result.calories, macro: result.macroLine));
      });
    }
  }

  String get _dayLabel {
    final now = DateTime.now();
    final diff = DateUtils.dateOnly(_selectedDay).difference(DateUtils.dateOnly(now)).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return '${_selectedDay.month}/${_selectedDay.day}/${_selectedDay.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        title: const Text('Diary'),
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _dateSelector(),
          const SizedBox(height: 12),
          _MealCard(
            title: 'Breakfast',
            items: _meals[MealName.breakfast]!,
            onAdd: () => _addFoodForMeal(MealName.breakfast),
          ),
          const SizedBox(height: 8),
          _MealCard(
            title: 'Lunch',
            items: _meals[MealName.lunch]!,
            onAdd: () => _addFoodForMeal(MealName.lunch),
          ),
          const SizedBox(height: 8),
          _MealCard(
            title: 'Dinner',
            items: _meals[MealName.dinner]!,
            onAdd: () => _addFoodForMeal(MealName.dinner),
          ),
          const SizedBox(height: 8),
          _MealCard(
            title: 'Snacks',
            items: [
              _MealItem(name: 'Banana', calories: 105, macro: 'P 1g • C 27g • F 0g'),
            ],
            onAdd: () => _addFoodForMeal(MealName.lunch),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoodSearchScreen()));
        },
        label: const Text('Add Food'),
        icon: const Icon(Icons.add),
        backgroundColor: Palette.forestGreen,
        foregroundColor: Palette.warmNeutral,
      ),
    );
  }

  Widget _dateSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftDays(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                _dayLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _shiftDays(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final String title;
  final List<_MealItem> items;
  final VoidCallback? onAdd;

  const _MealCard({required this.title, required this.items, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final totalCalories = items.fold<int>(0, (sum, i) => sum + i.calories);
    return Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$totalCalories kcal', style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          for (final i in items) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.name),
                      const SizedBox(height: 2),
                      Text(i.macro, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Text('${i.calories} kcal', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              ],
            ),
            if (i != items.last) const Divider(height: 16),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealItem {
  final String name;
  final int calories;
  final String macro;

  const _MealItem({required this.name, required this.calories, required this.macro});
}

