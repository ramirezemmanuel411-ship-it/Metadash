import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/diary_entry_food.dart';
import 'models.dart';

class FoodDetailScreen extends StatefulWidget {
  final FoodItem item;
  final String? mealName;
  final UserState? userState;
  const FoodDetailScreen({super.key, required this.item, this.mealName, this.userState});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  int quantity = 1;

  int get totalCalories => widget.item.calories * quantity;
  double get totalProtein => widget.item.protein * quantity;
  double get totalCarbs => widget.item.carbs * quantity;
  double get totalFat => widget.item.fat * quantity;

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
                Text('Protein: ${_formatMacro(totalProtein)}'),
                Text('Carbs: ${_formatMacro(totalCarbs)}'),
                Text('Fat: ${_formatMacro(totalFat)}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _addToDiary(context),
            child: const Text('Add to Diary'),
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

  String _formatMacro(double value) {
    final formatted = value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '${formatted}g';
  }

  Future<void> _addToDiary(BuildContext context) async {
    print('🔵 Add to diary button pressed');
    final userState = widget.userState ?? context.read<UserState>();
    final user = userState.currentUser;
    
    print('🔵 User: ${user?.id}, ${user?.email}');
    
    if (user == null) {
      print('❌ No user logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    final entry = DiaryEntryFood(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.id!,
      timestamp: DateTime.now(),
      name: widget.item.name,
      calories: totalCalories,
      proteinG: totalProtein.toInt(),
      carbsG: totalCarbs.toInt(),
      fatG: totalFat.toInt(),
      source: 'search',
    );

    print('🔵 Created entry: ${entry.name}, ${entry.calories} kcal');
    
    try {
      await userState.db.addFoodEntry(entry);
      print('✅ Entry saved to database');
    } catch (e) {
      print('❌ Error saving entry: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      return;
    }
    
    if (context.mounted) {
      print('🔵 Showing success message and popping');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.item.name} added to diary')),
      );
      Navigator.of(context).pop();
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
}
