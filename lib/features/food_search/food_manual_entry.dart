import 'package:flutter/material.dart';
import 'package:metadash/core/logging/app_logger.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a food name')));
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
          AppLogger.d('Failed to share food globally: $e');
        }
      }
    }

    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Added $name to your log')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: title + live calorie pill ───────────────────────
            Row(
              children: [
                Text(
                  'Quick Add',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: calories > 0
                        ? context.accent.withValues(alpha: 0.12)
                        : context.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    calories > 0 ? '$calories kcal' : '— kcal',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: calories > 0 ? context.accent : context.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Name / Brand fields ─────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _premiumRow(
                    context,
                    'Food Name',
                    nameCtrl,
                    icon: Icons.restaurant_outlined,
                    isText: true,
                    required: true,
                  ),
                  Divider(height: 1, indent: 46, color: context.divider),
                  _premiumRow(
                    context,
                    'Brand / Serving',
                    brandCtrl,
                    icon: Icons.label_outline_rounded,
                    isText: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Macro cards ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _macroCard(
                    context,
                    'Protein',
                    proteinCtrl,
                    Palette.macroProtein,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _macroCard(
                    context,
                    'Carbs',
                    carbsCtrl,
                    Palette.macroCarbs,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _macroCard(context, 'Fat', fatCtrl, Palette.macroFat),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Library options ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Save to My Library',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Access this food quickly in future logs',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                    value: saveToLibrary,
                    onChanged: (v) => setState(() => saveToLibrary = v),
                    activeThumbColor: context.accent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                  if (saveToLibrary) ...[
                    Divider(height: 1, indent: 16, color: context.divider),
                    SwitchListTile(
                      title: Text(
                        'Share with Community',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Help others discover this food',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textMuted,
                        ),
                      ),
                      value: shareGlobally,
                      onChanged: (v) => setState(() => shareGlobally = v),
                      activeThumbColor: context.accent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Log button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text('Log to ${widget.mealName?.name ?? 'Today'}'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.accent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroCard(
    BuildContext context,
    String label,
    TextEditingController ctrl,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: context.textMuted.withValues(alpha: 0.4),
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'g',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumRow(
    BuildContext context,
    String label,
    TextEditingController ctrl, {
    required IconData icon,
    bool isText = false,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              required ? '$label *' : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: isText ? TextInputType.text : TextInputType.number,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: required ? 'Required' : 'Optional',
                hintStyle: TextStyle(fontSize: 13, color: context.textMuted),
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
