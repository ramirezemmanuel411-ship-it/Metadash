import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import 'models.dart';

class FoodDetailScreen extends StatefulWidget {
  final FoodItemV2 item;
  final String? mealName;
  const FoodDetailScreen({super.key, required this.item, this.mealName});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  int quantity = 1;

  int get totalCalories => widget.item.calories * quantity;
  List<Nutrient> get totalNutrients => widget.item.nutrients
      .map((n) => Nutrient(category: n.category, amount: n.amount * quantity))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        title: const Text('Food Detail'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            title: 'Food',
            child: Text(widget.item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Quantity',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quantity: $quantity'),
                Row(
                  children: [
                    IconButton(
                      onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => setState(() => quantity++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Nutrition',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calories: $totalCalories kcal', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...totalNutrients.map((n) => Text('${n.category.name[0].toUpperCase()}${n.category.name.substring(1)}: ${n.amount}g')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(), // handle add later
            child: Text('Add to ${widget.mealName ?? 'Meal'}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
}
