// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/food_model.dart';
import '../../models/diary_entry_food.dart';
import '../../providers/food_plate_provider.dart';
import '../../providers/user_state.dart';
import '../../shared/palette.dart';
import '../../shared/widgets/serving_picker.dart';

class FoodDetailScreen extends StatefulWidget {
  final FoodModel food;
  final String? mealName;
  final UserState? userState;
  final DateTime? targetTimestamp;
  final DiaryEntryFood? editingEntry;
  final VoidCallback? onSaved;

  const FoodDetailScreen({
    super.key,
    required this.food,
    this.mealName,
    this.userState,
    this.targetTimestamp,
    this.editingEntry,
    this.onSaved,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  double _quantity = 1.0;
  int _servingIdx = 0;
  String _servingLabel = '';

  FoodModel get food => widget.food;

  List<({String label, double? grams})> get _servings {
    // Appends "(Xg)" to a label if it doesn't already mention grams.
    String withG(String lbl, double? g) {
      if (g == null || g <= 0) return lbl;
      final alreadyHasG = RegExp(
        r'\d+\s*g[\)\s]|\d+\s*g$',
        caseSensitive: false,
      ).hasMatch(lbl);
      if (alreadyHasG) return lbl;
      final gStr = g == g.truncateToDouble()
          ? g.truncate().toString()
          : g.toStringAsFixed(1);
      return '$lbl ($gStr g)';
    }

    final def = food.servingSize > 0
        ? '${_fmtD(food.servingSize)} ${food.servingUnit}'
        : food.servingUnit.isNotEmpty
        ? '1 ${food.servingUnit}'
        : '1 serving';
    final list = <({String label, double? grams})>[
      (
        label: withG(def, food.servingWeightGrams),
        grams: food.servingWeightGrams,
      ),
    ];
    for (final opt in food.servingOptions) {
      if (opt.label == null && opt.unit == null) continue;
      final lbl =
          opt.label ??
          '${opt.quantity != null ? _fmtD(opt.quantity!) : ""} ${opt.unit ?? ""}'
              .trim();
      list.add((label: withG(lbl, opt.weightGrams), grams: opt.weightGrams));
    }
    final hasGrams =
        food.servingWeightGrams != null && food.servingWeightGrams! > 0;
    final already100g = list.any(
      (o) =>
          o.label.toLowerCase().contains('100g') ||
          o.label.toLowerCase().contains('100 g'),
    );
    if (hasGrams && !already100g) {
      list.add((label: '100 g', grams: 100.0));
    }
    return list;
  }

  double get _servingMultiplier {
    final s = _servings;
    if (_servingIdx == 0 || _servingIdx >= s.length) return 1.0;
    final selG = s[_servingIdx].grams;
    final defG = s[0].grams;
    if (selG != null && selG > 0 && defG != null && defG > 0) {
      return selG / defG;
    }
    return 1.0;
  }

  double get _m => _quantity * _servingMultiplier;
  double get _kcal => food.calories * _m;
  double get _protein => food.protein * _m;
  double get _carbs => food.carbs * _m;
  double get _fat => food.fat * _m;

  String _fmtD(double v) => v == v.truncateToDouble()
      ? v.truncate().toString()
      : v.toStringAsFixed(1);

  String _fmtG(double v, {String unit = 'g'}) {
    final s = v >= 10 ? v.round().toString() : v.toStringAsFixed(1);
    return '$s$unit';
  }

  // ── Energy Impact state ────────────────────────────────────────────────────
  int _todayKcal = 0;
  int _calGoal = 2000;
  bool _loadingImpact = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTodayData());
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingEntry != null;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz,
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
            onSelected: (v) => _handleOverflow(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'favorite', child: Text('Favourite')),
              PopupMenuItem(value: 'custom', child: Text('Create Custom Food')),
              PopupMenuItem(value: 'delete', child: Text('Delete Food')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // 1 — Header: name + brand + calorie + colored macro row
                _FoodHeader(
                  food: food,
                  kcal: _kcal,
                  protein: _protein,
                  carbs: _carbs,
                  fat: _fat,
                  fmtG: _fmtG,
                ),
                const SizedBox(height: 12),
                // 2 — Quantity (primary interaction)
                ServingPicker(
                  servings: _servings,
                  isLiquid:
                      food.servingVolumeMl != null && food.servingVolumeMl! > 0,
                  baseCalories: food.calories.toDouble(),
                  onChanged: (qty, idx, label) => setState(() {
                    _quantity = qty;
                    _servingIdx = idx;
                    _servingLabel = label;
                  }),
                ),
                const SizedBox(height: 12),
                // 3 — Energy Impact
                _EnergyImpact(
                  todayKcal: _todayKcal,
                  calGoal: _calGoal,
                  deltaKcal: _kcal.round(),
                  loading: _loadingImpact,
                ),
                const SizedBox(height: 12),
                // 4 — Nutrition Card (macros + full facts)
                _NutritionCard(
                  food: food,
                  kcal: _kcal,
                  protein: _protein,
                  carbs: _carbs,
                  fat: _fat,
                  m: _m,
                  fmtG: _fmtG,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // 5 — Action buttons
          _ActionArea(
            kcal: _kcal,
            isEditing: isEditing,
            onAddToTray: () => _addToPlate(context),
            onLogNow: () => isEditing ? _saveEdit(context) : _logNow(context),
          ),
        ],
      ),
    );
  }

  void _addToPlate(BuildContext context) {
    final plate = context.read<FoodPlateProvider>();
    plate.add(
      FoodPlateItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_${food.id}',
        name: food.displayTitle,
        calories: _kcal.round(),
        proteinG: _protein.round(),
        carbsG: _carbs.round(),
        fatG: _fat.round(),
        source: 'search',
        serving: _servingLabel.isNotEmpty
            ? _servingLabel
            : _quantity == 1.0
            ? _servings[_servingIdx].label
            : '${_fmtD(_quantity)} × ${_servings[_servingIdx].label}',
        baseCalories: food.calories.toDouble(),
        baseProtein: food.protein,
        baseCarbs: food.carbs,
        baseFat: food.fat,
        baseGrams: food.servingWeightGrams,
      ),
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _saveEdit(BuildContext context) async {
    final entry = widget.editingEntry!;
    final userState = widget.userState ?? context.read<UserState>();
    final user = userState.currentUser;
    if (user == null) return;
    final updated = DiaryEntryFood(
      id: entry.id,
      userId: entry.userId,
      timestamp: entry.timestamp,
      name: food.displayTitle,
      calories: _kcal.round(),
      proteinG: _protein.round(),
      carbsG: _carbs.round(),
      fatG: _fat.round(),
      source: entry.source,
      serving: _servingLabel.isNotEmpty ? _servingLabel : entry.serving,
    );
    await userState.db.deleteFoodEntry(entry.id);
    await userState.db.addFoodEntry(updated);
    widget.onSaved?.call();
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _loadTodayData() async {
    final us = widget.userState ?? context.read<UserState>();
    final user = us.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingImpact = false);
      return;
    }
    final today = DateTime.now();
    final maps = await us.db.getFoodEntriesForDay(user.id!, today);
    int total = 0;
    for (final m in maps) {
      total += (m['calories'] as int?) ?? 0;
    }
    if (mounted) {
      setState(() {
        _todayKcal = total;
        _calGoal = user.dailyCaloricGoal;
        _loadingImpact = false;
      });
    }
  }

  Future<void> _logNow(BuildContext context) async {
    final us = widget.userState ?? context.read<UserState>();
    final user = us.currentUser;
    if (user == null) return;
    final entry = DiaryEntryFood(
      id: '${DateTime.now().millisecondsSinceEpoch}_${food.id}',
      userId: user.id!,
      timestamp: widget.targetTimestamp ?? DateTime.now(),
      name: food.displayTitle,
      calories: _kcal.round(),
      proteinG: _protein.round(),
      carbsG: _carbs.round(),
      fatG: _fat.round(),
      source: 'search',
      serving: _servingLabel.isNotEmpty
          ? _servingLabel
          : _quantity == 1.0
          ? _servings[_servingIdx].label
          : '${_fmtD(_quantity)} × ${_servings[_servingIdx].label}',
    );
    await us.db.addFoodEntry(entry);
    widget.onSaved?.call();
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  void _handleOverflow(BuildContext context, String action) {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Food Header — name, brand, live macro summary
// ─────────────────────────────────────────────────────────────────────────────

class _FoodHeader extends StatelessWidget {
  final FoodModel food;
  final double kcal, protein, carbs, fat;
  final String Function(double, {String unit}) fmtG;

  const _FoodHeader({
    required this.food,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fmtG,
  });

  @override
  Widget build(BuildContext context) {
    final title = food.displayTitle;
    final rawBrand = food.displayBrand;
    final brand =
        (rawBrand.isNotEmpty &&
            rawBrand.toLowerCase() != 'generic' &&
            rawBrand.toLowerCase() != title.toLowerCase())
        ? rawBrand
        : null;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + brand
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          if (brand != null && brand.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              brand,
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          // Large calorie display
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: colors.accent,
                size: 24,
              ),
              const SizedBox(width: 4),
              Text(
                kcal.round().toString(),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 5),
                child: Text(
                  'kcal',
                  style: TextStyle(fontSize: 15, color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Colored macro row with vertical dividers
          IntrinsicHeight(
            child: Row(
              children: [
                _HeaderMacroTile(
                  value: fmtG(protein),
                  label: 'Protein',
                  color: Palette.macroProtein,
                ),
                _VertDivider(color: colors.divider),
                _HeaderMacroTile(
                  value: fmtG(carbs),
                  label: 'Carbs',
                  color: Palette.macroCarbs,
                ),
                _VertDivider(color: colors.divider),
                _HeaderMacroTile(
                  value: fmtG(fat),
                  label: 'Fat',
                  color: Palette.macroFat,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Macro Breakdown Card
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Nutrition Card — macro breakdown + expandable nutrition facts
// ─────────────────────────────────────────────────────────────────────────────

class _NutritionCard extends StatefulWidget {
  final FoodModel food;
  final double kcal, protein, carbs, fat, m;
  final String Function(double, {String unit}) fmtG;

  const _NutritionCard({
    required this.food,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.m,
    required this.fmtG,
  });

  @override
  State<_NutritionCard> createState() => _NutritionCardState();
}

class _NutritionCardState extends State<_NutritionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final protein = widget.protein;
    final carbs = widget.carbs;
    final fat = widget.fat;
    final total = protein * 4 + carbs * 4 + fat * 9;
    final pPct = total > 0 ? protein * 4 / total * 100 : 0.0;
    final cPct = total > 0 ? carbs * 4 / total * 100 : 0.0;
    final fPct = total > 0 ? fat * 9 / total * 100 : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: title + expand toggle ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                const Text(
                  'Macros',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Nutrition Facts',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: colors.accent,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // ── Macro rows ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _MacroProgressRow(
                  color: Palette.macroProtein,
                  name: 'Protein',
                  value: widget.fmtG(protein),
                  pct: pPct,
                ),
                Divider(height: 1, thickness: 0.5, color: colors.divider),
                _MacroProgressRow(
                  color: Palette.macroCarbs,
                  name: 'Carbohydrates',
                  value: widget.fmtG(carbs),
                  pct: cPct,
                ),
                Divider(height: 1, thickness: 0.5, color: colors.divider),
                _MacroProgressRow(
                  color: Palette.macroFat,
                  name: 'Fat',
                  value: widget.fmtG(fat),
                  pct: fPct,
                ),
              ],
            ),
          ),
          // ── Expandable nutrition facts ───────────────────────────────────
          if (_expanded) ...[
            Divider(
              height: 1,
              thickness: 0.5,
              color: colors.divider,
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _NutritionFactsContent(
                food: widget.food,
                m: widget.m,
                fmtG: widget.fmtG,
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _HeaderMacroTile extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeaderMacroTile({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MacroProgressRow extends StatelessWidget {
  final Color color;
  final String name, value;
  final double pct;
  const _MacroProgressRow({
    required this.color,
    required this.name,
    required this.value,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 17),
              Text(
                '${pct.round()}%',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 17),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  final Color color;
  const _VertDivider({required this.color});
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.5, height: 36, color: color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Energy Impact
// ─────────────────────────────────────────────────────────────────────────────

class _EnergyImpact extends StatelessWidget {
  final int todayKcal;
  final int calGoal;
  final int deltaKcal;
  final bool loading;

  const _EnergyImpact({
    required this.todayKcal,
    required this.calGoal,
    required this.deltaKcal,
    required this.loading,
  });

  String _signed(int v) => v >= 0 ? '+$v kcal' : '$v kcal';

  String _fmtLb(double v) {
    final abs = v.abs();
    final s = abs < 0.005 ? '< 0.01' : abs.toStringAsFixed(2);
    return v < 0 ? '-$s lb' : '+$s lb';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (loading) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final todayAfter = todayKcal + deltaKcal;
    final balanceBefore = todayKcal - calGoal;
    final balanceAfter = todayAfter - calGoal;
    final fatBefore = balanceBefore / 3500.0;
    final fatAfter = balanceAfter / 3500.0;

    final balanceLabel = balanceAfter <= 0
        ? 'Deficit of ${balanceAfter.abs().round()} kcal'
        : 'Surplus of ${balanceAfter.abs().round()} kcal';

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENERGY IMPACT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          _ImpactRow(
            label: 'Calories Today',
            before: '$todayKcal',
            after: '$todayAfter',
            delta: _signed(deltaKcal),
          ),
          Divider(height: 1, thickness: 0.5, color: colors.divider),
          _ImpactRow(
            label: "Today's Balance",
            before: '${balanceBefore >= 0 ? '+' : ''}$balanceBefore',
            after: '${balanceAfter >= 0 ? '+' : ''}$balanceAfter',
            delta: balanceLabel,
          ),
          Divider(height: 1, thickness: 0.5, color: colors.divider),
          _ImpactRow(
            label: 'Est. Fat Change',
            before: _fmtLb(fatBefore),
            after: _fmtLb(fatAfter),
            delta: 'Today only',
          ),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final String label, before, after, delta;
  const _ImpactRow({
    required this.label,
    required this.before,
    required this.after,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  '$before → $after',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            delta,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nutrient helper (top-level so _NutritionFacts can use it)
// ─────────────────────────────────────────────────────────────────────────────

double? _nv(
  FoodModel food,
  double m, {
  required int usdaId,
  required String offKey,
}) {
  final raw = food.rawJson;
  if (raw == null) return null;
  final list = raw['foodNutrients'] as List?;
  if (list != null) {
    for (final n in list) {
      final id = n['nutrientId'];
      if (id == usdaId || id?.toString() == '$usdaId') {
        var v = (n['value'] ?? n['amount'] as num?)?.toDouble();
        if (v == null) continue;
        if (food.nutritionBasis == 'per100g' ||
            food.nutritionBasis == 'per_100g') {
          v = v * (food.servingWeightGrams ?? 100) / 100;
        }
        return v * m;
      }
    }
  }
  final nm = raw['nutriments'] as Map?;
  if (nm != null) {
    var v = (nm['${offKey}_serving'] ?? nm['${offKey}_100g'] as num?)
        ?.toDouble();
    if (v != null) {
      if (nm['${offKey}_serving'] == null) {
        v = v * (food.servingWeightGrams ?? 100) / 100;
      }
      return v * m;
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Nutrition Facts
// ─────────────────────────────────────────────────────────────────────────────

class _NutritionFactsContent extends StatefulWidget {
  final FoodModel food;
  final double m;
  final String Function(double, {String unit}) fmtG;

  const _NutritionFactsContent({
    required this.food,
    required this.m,
    required this.fmtG,
  });

  @override
  State<_NutritionFactsContent> createState() => _NutritionFactsContentState();
}

class _NutritionFactsContentState extends State<_NutritionFactsContent> {
  int _tab = 0;

  static const _tabs = ['Macros', 'Vitamins', 'Minerals', 'Other'];

  FoodModel get food => widget.food;
  double get m => widget.m;
  String Function(double, {String unit}) get fmtG => widget.fmtG;

  double? _n(int usdaId, String offKey) =>
      _nv(food, m, usdaId: usdaId, offKey: offKey);
  String _v(double? val, {String unit = 'g'}) =>
      val != null ? fmtG(val, unit: unit) : '\u2014';

  @override
  Widget build(BuildContext context) {
    // ── Macros ────────────────────────────────────────────────────────────────
    final protein = food.protein * m;
    final carbs = food.carbs * m;
    final fat = food.fat * m;

    // ── Carb subs ─────────────────────────────────────────────────────────────
    final fiber = _n(1079, 'fiber');
    final insolFiber = _n(1084, 'insoluble-fiber');
    final solFiber = _n(1082, 'soluble-fiber');
    final sugars = _n(2000, 'sugars');
    final addedSugars = _n(1235, 'added-sugars');
    final sugarAlcohols = _n(1086, 'sugar-alcohols');
    final starch = _n(1009, 'starch');
    final netCarbs = fiber != null
        ? (carbs - fiber).clamp(0, double.infinity) as double
        : null;

    // ── Fat subs ──────────────────────────────────────────────────────────────
    final satFat = _n(1258, 'saturated-fat');
    final transFat = _n(1257, 'trans-fat');
    final monoFat = _n(1292, 'monounsaturated-fat');
    final polyFat = _n(1293, 'polyunsaturated-fat');
    final omega3 = _n(1404, 'omega-3');
    final omega6 = _n(1269, 'linoleic-acid');
    final cholesterol = _n(1253, 'cholesterol');

    // ── Amino acids ───────────────────────────────────────────────────────────
    final tryptophan = _n(1210, 'tryptophan');
    final threonine = _n(1211, 'threonine');
    final isoleucine = _n(1212, 'isoleucine');
    final leucine = _n(1213, 'leucine');
    final lysine = _n(1214, 'lysine');
    final methionine = _n(1215, 'methionine');
    final cystine = _n(1216, 'cystine');
    final phenylalanine = _n(1217, 'phenylalanine');
    final tyrosine = _n(1218, 'tyrosine');
    final valine = _n(1219, 'valine');
    final histidine = _n(1220, 'histidine');

    // ── Vitamins ──────────────────────────────────────────────────────────────
    final vitA = _n(1106, 'vitamin-a');
    final vitC = _n(1162, 'vitamin-c');
    final vitD = _n(1114, 'vitamin-d');
    final vitE = _n(1109, 'vitamin-e');
    final vitK = _n(1185, 'vitamin-k');
    final thiamine = _n(1165, 'thiamin');
    final riboflavin = _n(1166, 'riboflavin');
    final niacin = _n(1167, 'niacin');
    final b5 = _n(1170, 'pantothenic-acid');
    final b6 = _n(1175, 'vitamin-b6');
    final biotin = _n(1176, 'biotin');
    final folate = _n(1177, 'folate');
    final b12 = _n(1178, 'vitamin-b12');
    final choline = _n(1180, 'choline');

    // ── Minerals ──────────────────────────────────────────────────────────────
    final calcium = _n(1087, 'calcium');
    final chloride = _n(1088, 'chloride');
    final iron = _n(1089, 'iron');
    final magnesium = _n(1090, 'magnesium');
    final phosphorus = _n(1091, 'phosphorus');
    final potassium = _n(1092, 'potassium');
    final sodium = _n(1093, 'sodium');
    final zinc = _n(1095, 'zinc');
    final chromium = _n(1096, 'chromium');
    final copper = _n(1098, 'copper');
    final fluoride = _n(1099, 'fluoride');
    final iodine = _n(1100, 'iodine');
    final manganese = _n(1101, 'manganese');
    final molybdenum = _n(1102, 'molybdenum');
    final selenium = _n(1103, 'selenium');

    // ── Other ─────────────────────────────────────────────────────────────────

    final water = _n(1051, 'water');
    final caffeine = _n(1057, 'caffeine');
    final alcohol = _n(1018, 'alcohol');

    const teal = Palette.macroProtein; // protein — matches diary ring
    const amber = Palette.macroCarbs; // carbs   — matches diary ring
    const red = Palette.macroFat; // fat     — matches diary ring

    // ── Tab content ───────────────────────────────────────────────────────────
    final tabContent = <int, Widget>{
      // Macros tab: macro headers + sub-rows, no collapse needed
      0: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MacroSection(label: 'Protein', value: _v(protein), color: teal),
          _NRow(label: 'Tryptophan', value: _v(tryptophan)),
          _NRow(label: 'Threonine', value: _v(threonine)),
          _NRow(label: 'Isoleucine', value: _v(isoleucine)),
          _NRow(label: 'Leucine', value: _v(leucine)),
          _NRow(label: 'Lysine', value: _v(lysine)),
          _NRow(label: 'Methionine', value: _v(methionine)),
          _NRow(label: 'Cystine', value: _v(cystine)),
          _NRow(label: 'Phenylalanine', value: _v(phenylalanine)),
          _NRow(label: 'Tyrosine', value: _v(tyrosine)),
          _NRow(label: 'Valine', value: _v(valine)),
          _NRow(label: 'Histidine', value: _v(histidine)),
          const SizedBox(height: 8),
          _MacroSection(label: 'Carbohydrates', value: _v(carbs), color: amber),
          if (netCarbs != null) _NRow(label: 'Net Carbs', value: _v(netCarbs)),
          _NRow(label: 'Dietary Fiber', value: _v(fiber)),
          _NRow(label: '  Soluble Fiber', value: _v(solFiber)),
          _NRow(label: '  Insoluble Fiber', value: _v(insolFiber)),
          _NRow(label: 'Total Sugars', value: _v(sugars)),
          _NRow(label: '  Added Sugars', value: _v(addedSugars)),
          _NRow(label: '  Sugar Alcohols', value: _v(sugarAlcohols)),
          _NRow(label: 'Starch', value: _v(starch)),
          const SizedBox(height: 8),
          _MacroSection(label: 'Total Fat', value: _v(fat), color: red),
          _NRow(label: 'Saturated Fat', value: _v(satFat)),
          _NRow(label: 'Trans Fat', value: _v(transFat)),
          _NRow(label: 'Monounsaturated', value: _v(monoFat)),
          _NRow(label: 'Polyunsaturated', value: _v(polyFat)),
          _NRow(label: '  Omega-3', value: _v(omega3)),
          _NRow(label: '  Omega-6', value: _v(omega6)),
          _NRow(
            label: 'Cholesterol',
            value: _v(cholesterol, unit: 'mg'),
          ),
        ],
      ),

      // Vitamins tab
      1: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NRow(
            label: 'Vitamin A',
            value: _v(vitA, unit: 'mcg'),
          ),
          _NRow(
            label: 'Vitamin C',
            value: _v(vitC, unit: 'mg'),
          ),
          _NRow(
            label: 'Vitamin D',
            value: _v(vitD, unit: 'mcg'),
          ),
          _NRow(
            label: 'Vitamin E',
            value: _v(vitE, unit: 'mg'),
          ),
          _NRow(
            label: 'Vitamin K',
            value: _v(vitK, unit: 'mcg'),
          ),
          _NRow(
            label: 'B1 · Thiamine',
            value: _v(thiamine, unit: 'mg'),
          ),
          _NRow(
            label: 'B2 · Riboflavin',
            value: _v(riboflavin, unit: 'mg'),
          ),
          _NRow(
            label: 'B3 · Niacin',
            value: _v(niacin, unit: 'mg'),
          ),
          _NRow(
            label: 'B5 · Pantothenic Acid',
            value: _v(b5, unit: 'mg'),
          ),
          _NRow(
            label: 'B6 · Pyridoxine',
            value: _v(b6, unit: 'mg'),
          ),
          _NRow(
            label: 'B7 · Biotin',
            value: _v(biotin, unit: 'mcg'),
          ),
          _NRow(
            label: 'B9 · Folate',
            value: _v(folate, unit: 'mcg'),
          ),
          _NRow(
            label: 'B12 · Cobalamin',
            value: _v(b12, unit: 'mcg'),
          ),
          _NRow(
            label: 'Choline',
            value: _v(choline, unit: 'mg'),
          ),
        ],
      ),

      // Minerals tab
      2: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NRow(
            label: 'Calcium',
            value: _v(calcium, unit: 'mg'),
          ),
          _NRow(
            label: 'Iron',
            value: _v(iron, unit: 'mg'),
          ),
          _NRow(
            label: 'Potassium',
            value: _v(potassium, unit: 'mg'),
          ),
          _NRow(
            label: 'Sodium',
            value: _v(sodium, unit: 'mg'),
          ),
          _NRow(
            label: 'Chloride',
            value: _v(chloride, unit: 'mg'),
          ),
          _NRow(
            label: 'Magnesium',
            value: _v(magnesium, unit: 'mg'),
          ),
          _NRow(
            label: 'Phosphorus',
            value: _v(phosphorus, unit: 'mg'),
          ),
          _NRow(
            label: 'Zinc',
            value: _v(zinc, unit: 'mg'),
          ),
          _NRow(
            label: 'Copper',
            value: _v(copper, unit: 'mg'),
          ),
          _NRow(
            label: 'Manganese',
            value: _v(manganese, unit: 'mg'),
          ),
          _NRow(
            label: 'Selenium',
            value: _v(selenium, unit: 'mcg'),
          ),
          _NRow(
            label: 'Iodine',
            value: _v(iodine, unit: 'mcg'),
          ),
          _NRow(
            label: 'Chromium',
            value: _v(chromium, unit: 'mcg'),
          ),
          _NRow(
            label: 'Molybdenum',
            value: _v(molybdenum, unit: 'mcg'),
          ),
          _NRow(
            label: 'Fluoride',
            value: _v(fluoride, unit: 'mcg'),
          ),
        ],
      ),

      // Other tab
      3: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NRow(label: 'Water', value: _v(water)),
          _NRow(
            label: 'Caffeine',
            value: _v(caffeine, unit: 'mg'),
          ),
          _NRow(label: 'Alcohol', value: _v(alcohol)),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tab chips ─────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final active = _tab == i;
              return Padding(
                padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? context.colors.accent
                          : context.colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _tabs[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : context.colors.accent,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 14),
        Divider(height: 1, thickness: 0.5, color: context.colors.divider),
        const SizedBox(height: 6),

        // ── Animated content ──────────────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(_tab), child: tabContent[_tab]!),
        ),
      ],
    );
  }
}

// Macro section header row inside the Macros tab
class _MacroSection extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroSection({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NRow extends StatelessWidget {
  final String label, value;
  const _NRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Area
// ─────────────────────────────────────────────────────────────────────────────

class _ActionArea extends StatelessWidget {
  final double kcal;
  final bool isEditing;
  final VoidCallback onAddToTray;
  final VoidCallback onLogNow;

  const _ActionArea({
    required this.kcal,
    required this.isEditing,
    required this.onAddToTray,
    required this.onLogNow,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kcalStr = '${kcal.round()} kcal';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: isEditing
          ? SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onLogNow,
                child: Text(
                  'Save Changes · $kcalStr',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onAddToTray,
                    child: Text(
                      'Add to Food Tray · $kcalStr',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accent,
                      side: BorderSide(color: colors.accent, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onLogNow,
                    child: const Text(
                      'Log Food Now',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
