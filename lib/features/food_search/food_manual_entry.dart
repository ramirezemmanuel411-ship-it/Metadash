import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import 'models.dart';

class FoodManualEntry extends StatefulWidget {
  final MealName? mealName;
  const FoodManualEntry({super.key, this.mealName});

  @override
  State<FoodManualEntry> createState() => _FoodManualEntryState();
}

class _FoodManualEntryState extends State<FoodManualEntry> {
  final proteinCtrl = TextEditingController();
  final carbsCtrl = TextEditingController();
  final fatCtrl = TextEditingController();

  int get protein => int.tryParse(proteinCtrl.text) ?? 0;
  int get carbs => int.tryParse(carbsCtrl.text) ?? 0;
  int get fat => int.tryParse(fatCtrl.text) ?? 0;
  int get calories => protein * 4 + carbs * 4 + fat * 9;

  @override
  void dispose() {
    proteinCtrl.dispose();
    carbsCtrl.dispose();
    fatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.warmNeutral,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Manual Entry', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.lightStone,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _row('Protein (g)', proteinCtrl),
                  _row('Carbs (g)', carbsCtrl),
                  _row('Fat (g)', fatCtrl),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Text('Calories', style: TextStyle(color: Colors.grey)),
                const Spacer(),
                Text('$calories kcal', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {},
            child: Text('Add to ${widget.mealName?.name ?? 'Meal'}'),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _row(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(hintText: '0'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
