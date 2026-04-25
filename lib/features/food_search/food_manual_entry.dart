import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/user_food_item.dart';
import '../../models/diary_entry_food.dart';
import '../../services/cloud_food_service.dart';
import 'models.dart';

class FoodManualEntry extends StatefulWidget {
  final MealName? mealName;
  final UserState? userState;
  final DateTime? targetTimestamp;

  const FoodManualEntry({
    super.key,
    this.mealName,
    this.userState,
    this.targetTimestamp,
  });

  @override
  State<FoodManualEntry> createState() => _FoodManualEntryState();
}

class _FoodManualEntryState extends State<FoodManualEntry> {
  final nameCtrl = TextEditingController();
  final brandCtrl = TextEditingController();
  final proteinCtrl = TextEditingController();
  final carbsCtrl = TextEditingController();
  final fatCtrl = TextEditingController();
  bool saveToLibrary = false;
  bool shareGlobally = true;

  int get protein => int.tryParse(proteinCtrl.text) ?? 0;
  int get carbs => int.tryParse(carbsCtrl.text) ?? 0;
  int get fat => int.tryParse(fatCtrl.text) ?? 0;
  int get calories => protein * 4 + carbs * 4 + fat * 9;

  @override
  void dispose() {
    nameCtrl.dispose();
    brandCtrl.dispose();
    proteinCtrl.dispose();
    carbsCtrl.dispose();
    fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _onAdd() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a food name')),
      );
      return;
    }

    final userState = widget.userState ?? context.read<UserState>();
    final user = userState.currentUser;
    if (user == null) return;

    // 1. Create diary entry
    final entry = DiaryEntryFood(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.id!,
      timestamp: widget.targetTimestamp ?? DateTime.now(),
      name: name,
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      source: 'manual',
      serving: brandCtrl.text.isNotEmpty ? brandCtrl.text : null,
    );

    await userState.db.addFoodEntry(entry);

    // 2. Optional: Save to library
    if (saveToLibrary) {
      final foodItem = UserFoodItem.createNew(
        userId: user.id!,
        name: name,
        brand: brandCtrl.text.trim(),
        calories: calories.toDouble(),
        protein: protein.toDouble(),
        carbs: carbs.toDouble(),
        fat: fat.toDouble(),
      );
      await userState.db.saveUserFood(foodItem);
      
      // 3. Optional: Share with community (Firestore)
      if (shareGlobally) {
        try {
          await CloudFoodService().contributeToGlobalLibrary(foodItem);
        } catch (e) {
          debugPrint('Failed to share food globally: $e');
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $name to your log')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.warmNeutral,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Text('Quick Add', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.lightStone,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _row('Food Name', nameCtrl, isText: true),
                  _row('Brand (Opt)', brandCtrl, isText: true),
                  const Divider(height: 24),
                  _row('Protein (g)', proteinCtrl),
                  _row('Carbs (g)', carbsCtrl),
                  _row('Fat (g)', fatCtrl),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const Text('Save to my food library', style: TextStyle(fontSize: 14)),
            value: saveToLibrary,
            onChanged: (v) => setState(() => saveToLibrary = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: Palette.forestGreen,
          ),
          if (saveToLibrary)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: CheckboxListTile(
                title: const Text('Share with community', style: TextStyle(fontSize: 13, color: Colors.grey)),
                value: shareGlobally,
                onChanged: (v) => setState(() => shareGlobally = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: Palette.forestGreen,
              ),
            ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Text('Estimated Calories', style: TextStyle(color: Colors.grey)),
                const Spacer(),
                Text('$calories kcal',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Palette.forestGreen,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: Palette.forestGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Log to ${widget.mealName?.name ?? 'Today'}'),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _row(String label, TextEditingController controller, {bool isText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isText ? TextInputType.text : TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: isText ? 'Required' : '0',
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
