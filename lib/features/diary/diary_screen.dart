import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import '../food_search/food_search_screen.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _selectedDay = DateTime.now();

  void _shiftDays(int delta) {
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: delta));
    });
  }

  String get _dayLabel {
    final now = DateTime.now();
    final diff = DateUtils.dateOnly(_selectedDay).difference(DateUtils.dateOnly(now)).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return '${_selectedDay.month}/${_selectedDay.day}/${_selectedDay.year}';
  }

  final Map<String, List<_MealItem>> _meals = {
    'Breakfast': const [
      _MealItem(name: 'Oats', calories: 150, macro: 'P 5g • C 27g • F 3g'),
      _MealItem(name: 'Greek Yogurt', calories: 100, macro: 'P 17g • C 6g • F 0g'),
    ],
    'Lunch': const [
      _MealItem(name: 'Chicken Breast', calories: 165, macro: 'P 31g • C 0g • F 3g'),
    ],
    'Dinner': const [
      _MealItem(name: 'Salmon', calories: 208, macro: 'P 22g • C 0g • F 13g'),
    ],
    'Snacks': const [
      _MealItem(name: 'Banana', calories: 105, macro: 'P 1g • C 27g • F 0g'),
    ],
  };

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
          for (final entry in _meals.entries) ...[
            _MealCard(title: entry.key, items: entry.value),
            const SizedBox(height: 8),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftDays(-1),
            icon: const Icon(Icons.chevron_left),
            splashRadius: 20,
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
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final String title;
  final List<_MealItem> items;

  const _MealCard({required this.title, required this.items});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$totalCalories kcal', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _MealRow(item: items[i]),
                if (i != items.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1.0, thickness: 0.5),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: navigate to FoodSearchScreen to add to this meal
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final _MealItem item;

  const _MealRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(item.macro, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('${item.calories} kcal', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MealItem {
  final String name;
  final int calories;
  final String macro;

  const _MealItem({required this.name, required this.calories, required this.macro});
}
