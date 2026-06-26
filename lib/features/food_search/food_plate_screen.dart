// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:metadash/core/providers/food_plate_provider.dart';
import 'package:metadash/core/providers/user_state.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:provider/provider.dart';

/// Full-screen review and commit screen for staged Food Plate items.
class FoodPlateScreen extends StatefulWidget {
  final VoidCallback? onAdded;

  const FoodPlateScreen({super.key, this.onAdded});

  @override
  State<FoodPlateScreen> createState() => _FoodPlateScreenState();
}

enum _Meal { breakfast, lunch, dinner, snack }

extension _MealLabel on _Meal {
  String get label {
    switch (this) {
      case _Meal.breakfast:
        return 'Breakfast';
      case _Meal.lunch:
        return 'Lunch';
      case _Meal.dinner:
        return 'Dinner';
      case _Meal.snack:
        return 'Snack';
    }
  }

  IconData get icon {
    switch (this) {
      case _Meal.breakfast:
        return Icons.wb_sunny_outlined;
      case _Meal.lunch:
        return Icons.light_mode_outlined;
      case _Meal.dinner:
        return Icons.nights_stay_outlined;
      case _Meal.snack:
        return Icons.local_cafe_outlined;
    }
  }

  /// Representative hour used when building the diary timestamp.
  int get hour {
    switch (this) {
      case _Meal.breakfast:
        return 8;
      case _Meal.lunch:
        return 12;
      case _Meal.dinner:
        return 18;
      case _Meal.snack:
        return 21;
    }
  }
}

_Meal _mealFromHour(int hour) {
  if (hour >= 5 && hour <= 10) return _Meal.breakfast;
  if (hour >= 11 && hour <= 15) return _Meal.lunch;
  if (hour >= 16 && hour <= 20) return _Meal.dinner;
  return _Meal.snack;
}

class _FoodPlateScreenState extends State<FoodPlateScreen> {
  late _Meal _selectedMeal;
  int _todayKcal = 0;
  int _calGoal = 2000;
  bool _loadingImpact = true;

  @override
  void initState() {
    super.initState();
    _selectedMeal = _mealFromHour(DateTime.now().hour);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTodayData());
  }

  Future<void> _loadTodayData() async {
    final userState = context.read<UserState>();
    final user = userState.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingImpact = false);
      return;
    }
    final maps = await userState.db.getFoodEntriesForDay(
      user.id!,
      DateTime.now(),
    );
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

  Future<void> _commitToDay(BuildContext context) async {
    final plate = context.read<FoodPlateProvider>();
    final userState = context.read<UserState>();
    final user = userState.currentUser;

    if (user == null) return;

    final now = DateTime.now();
    final timestamp = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedMeal.hour,
    );

    try {
      for (final item in plate.items) {
        final entry = item.toDiaryEntry(userId: user.id!, timestamp: timestamp);
        await userState.db.addFoodEntry(entry);
      }

      plate.clear();

      if (!context.mounted) return;
      widget.onAdded?.call();
      Navigator.of(context).pop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final plate = context.watch<FoodPlateProvider>();
    final colors = context.colors;
    final items = plate.items;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Food Plate',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (items.isNotEmpty)
              Text(
                '${items.length} item${items.length == 1 ? '' : 's'} · ${plate.totalCalories} kcal',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: colors.surface,
                    title: Text(
                      'Clear plate?',
                      style: TextStyle(color: colors.textPrimary),
                    ),
                    content: Text(
                      'All ${items.length} staged item${items.length == 1 ? '' : 's'} will be removed.',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: colors.textMuted),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'Clear',
                          style: TextStyle(color: colors.accent),
                        ),
                      ),
                    ],
                  ),
                ).then((confirmed) {
                  if (confirmed == true && context.mounted) {
                    context.read<FoodPlateProvider>().clear();
                  }
                });
              },
              child: Text(
                'Clear',
                style: TextStyle(color: colors.textMuted, fontSize: 14),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Item list + insight cards ───────────────────────────────
          Expanded(
            child: items.isEmpty
                ? _EmptyState(colors: colors)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      ...items.asMap().entries.map((e) {
                        final i = e.key;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (i > 0)
                              Divider(height: 1, color: colors.divider),
                            _PlateItemTile(
                              key: ValueKey(items[i].id),
                              item: items[i],
                              colors: colors,
                              onDelete: () => context
                                  .read<FoodPlateProvider>()
                                  .remove(items[i].id),
                              onServingChanged: (qty, unit) =>
                                  context.read<FoodPlateProvider>().update(
                                    items[i].id,
                                    items[i].rescaled(qty, unit),
                                  ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 16),
                      _PlateNutrientsDropdown(plate: plate),
                    ],
                  ),
          ),

          if (items.isNotEmpty) ...[
            // ─── Totals row ──────────────────────────────────────────────
            _TotalsBar(plate: plate, colors: colors),

            // ─── Impact strip ─────────────────────────────────────────
            _PlateImpactStrip(
              todayKcal: _todayKcal,
              calGoal: _calGoal,
              plateKcal: plate.totalCalories,
              loading: _loadingImpact,
            ),

            // ─── Meal selector ───────────────────────────────────────────
            _MealSelector(
              selected: _selectedMeal,
              colors: colors,
              onChanged: (m) => setState(() => _selectedMeal = m),
            ),

            // ─── Add to Diary CTA ─────────────────────────────────────────
            _CommitButton(
              count: items.length,
              meal: _selectedMeal,
              colors: colors,
              onPressed: () => _commitToDay(context),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final MetaDashColors colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dinner_dining_outlined, size: 56, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Your plate is empty',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search for food and tap "Add to Plate"\nto stage it here before logging.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single item tile
// ─────────────────────────────────────────────────────────────────────────────

class _PlateItemTile extends StatefulWidget {
  final FoodPlateItem item;
  final MetaDashColors colors;
  final VoidCallback onDelete;
  final void Function(double qty, String unit) onServingChanged;

  const _PlateItemTile({
    super.key,
    required this.item,
    required this.colors,
    required this.onDelete,
    required this.onServingChanged,
  });

  @override
  State<_PlateItemTile> createState() => _PlateItemTileState();
}

class _PlateItemTileState extends State<_PlateItemTile> {
  String _qty = '1';
  String _unitStr = 'serving';

  // serving + the two most common weights first (left of the keypad divider),
  // then every other real measurement (right of the divider). Count-based words
  // like "piece"/"slice"/"item" aren't measurements — they're just servings, so
  // they're folded into the "serving" pill rather than listed separately.
  static const _commonUnits = [
    'serving',
    'g',
    'oz',
    'lb',
    'ml',
    'fl oz',
    'cup',
    'tbsp',
    'tsp',
  ];
  static const _unitDividerIndex = 3;

  static ({String num, String unit}) _parse(String serving) {
    final stripped = serving.trim().replaceFirst(
      RegExp(r'^\d+\.?\d*\s*[x×]\s*'),
      '',
    );
    final m = RegExp(r'^(\d*\.?\d+)\s*(.*)$').firstMatch(stripped);
    if (m != null) {
      return (num: m.group(1) ?? stripped, unit: m.group(2)?.trim() ?? '');
    }
    return (num: stripped, unit: '');
  }

  void _syncFromServing(String raw) {
    final parsed = _parse(raw);
    if (double.tryParse(parsed.num) != null) {
      _qty = parsed.num;
      _unitStr = _normalizeUnit(parsed.unit);
    } else {
      _unitStr = _normalizeUnit(raw);
      _qty = '1';
    }
  }

  /// Map a parsed serving unit onto one of [_commonUnits]. Count-based words
  /// ("piece", "slice", "item", …) and anything that isn't a real measurement
  /// collapse to "serving".
  static String _normalizeUnit(String u) {
    final lower = u.trim().toLowerCase();
    if (lower.isEmpty) return 'serving';
    return _commonUnits.contains(lower) ? lower : 'serving';
  }

  @override
  void initState() {
    super.initState();
    _syncFromServing(widget.item.serving ?? '');
  }

  @override
  void didUpdateWidget(_PlateItemTile old) {
    super.didUpdateWidget(old);
    if (old.item.serving != widget.item.serving) {
      setState(() => _syncFromServing(widget.item.serving ?? ''));
    }
  }

  void _commit(String qty, String unit) {
    final q = double.tryParse(qty.isEmpty || qty == '0' ? '1' : qty) ?? 1.0;
    widget.onServingChanged(q, unit);
  }

  void _openNumpad() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ServingNumpad(
        initialQty: _qty,
        initialUnit: _unitStr,
        units: _commonUnits,
        dividerIndex: _unitDividerIndex,
        baseGrams: widget.item.baseGrams,
        baseCalories: widget.item.baseCalories,
        colors: widget.colors,
        onConfirm: (qty, unit) {
          setState(() {
            _qty = qty;
            _unitStr = unit;
          });
          _commit(qty, unit);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle =
        '${widget.item.calories} kcal · P ${widget.item.proteinG}g · C ${widget.item.carbsG}g · F ${widget.item.fatG}g';

    return Dismissible(
      key: ValueKey(widget.item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withOpacity(0.15),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Source dot
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.colors.accent,
              ),
            ),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.colors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Serving pill — opens MacroFactor-style numpad sheet
            GestureDetector(
              onTap: _openNumpad,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: widget.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _qty,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _unitStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: widget.colors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            // Delete button
            const SizedBox(width: 2),
            GestureDetector(
              onTap: widget.onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: widget.colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MacroFactor-style serving numpad bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ServingNumpad extends StatefulWidget {
  final String initialQty;
  final String initialUnit;
  final List<String> units;
  final int dividerIndex;
  final double? baseGrams;
  final double baseCalories;
  final MetaDashColors colors;
  final void Function(String qty, String unit) onConfirm;

  const _ServingNumpad({
    required this.initialQty,
    required this.initialUnit,
    required this.units,
    required this.dividerIndex,
    this.baseGrams,
    this.baseCalories = 0,
    required this.colors,
    required this.onConfirm,
  });

  @override
  State<_ServingNumpad> createState() => _ServingNumpadState();
}

class _ServingNumpadState extends State<_ServingNumpad> {
  late String _qty;
  late String _unit;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty;
    _unit = widget.initialUnit;
  }

  double _gramsForUnit(String u) {
    final w = FoodPlateItem.unitGrams[u.toLowerCase()];
    if (w != null) return w;
    return widget.baseGrams ?? 0;
  }

  double get _qtyNum =>
      double.tryParse(_qty.isEmpty || _qty == '0' ? '1' : _qty) ?? 1;

  double? get _grams {
    final g = _gramsForUnit(_unit);
    return g > 0 ? _qtyNum * g : null;
  }

  double get _liveCal {
    final grams = _grams;
    final base = widget.baseGrams;
    if (grams != null && base != null && base > 0) {
      return widget.baseCalories * grams / base;
    }
    return widget.baseCalories * _qtyNum;
  }

  String _fmtGrams(double g) =>
      '${g >= 10 ? g.round().toString() : g.toStringAsFixed(1)} g';

  void _press(String key) {
    setState(() {
      if (key == '⌫') {
        _qty = _qty.length > 1 ? _qty.substring(0, _qty.length - 1) : '0';
      } else if (key == '.') {
        if (!_qty.contains('.')) _qty += '.';
      } else {
        if (_qty == '0') {
          _qty = key;
        } else if (_qty.length < 8) {
          _qty += key;
        }
      }
    });
  }

  Widget _key(
    String label, {
    bool isDone = false,
    bool isBack = false,
    bool isGray = false,
  }) {
    final c = widget.colors;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isDone
              ? () {
                  widget.onConfirm(
                    _qty == '0' || _qty.isEmpty ? '1' : _qty,
                    _unit,
                  );
                  Navigator.of(context).pop();
                }
              : label.isEmpty
              ? null
              : () => _press(label),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: isDone
                  ? c.accent
                  : isGray || isBack
                  ? c.surfaceVariant
                  : c.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isBack
                  ? Icon(
                      Icons.backspace_outlined,
                      size: 20,
                      color: c.textSecondary,
                    )
                  : label.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: isDone ? 15 : 22,
                        fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                        color: isDone ? c.onPrimary : c.textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Quantity + unit (left) and live calories + grams (right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _qty,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _unit,
                      style: TextStyle(fontSize: 18, color: c.accent),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_liveCal.round()} cal'
                    '${_grams != null ? '  ·  ${_fmtGrams(_grams!)}' : ''}',
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Horizontal unit chips
            SizedBox(
              height: 38,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (int i = 0; i < widget.units.length; i++) ...[
                      if (i == widget.dividerIndex)
                        Container(
                          width: 2,
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: c.accent,
                        ),
                      GestureDetector(
                        onTap: () => setState(() {
                          // Preserve the gram amount when switching units.
                          final og = _gramsForUnit(_unit);
                          final ng = _gramsForUnit(widget.units[i]);
                          final q = double.tryParse(_qty) ?? 1;
                          if (og > 0 && ng > 0 && q > 0) {
                            final newQ = q * og / ng;
                            _qty = newQ == newQ.truncateToDouble()
                                ? newQ.truncate().toString()
                                : newQ.toStringAsFixed(1);
                          }
                          _unit = widget.units[i];
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: widget.units[i] == _unit
                                ? c.accent
                                : c.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.units[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.units[i] == _unit
                                  ? c.onPrimary
                                  : c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Numpad grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      _key('1'),
                      _key('2'),
                      _key('3'),
                      _key('⌫', isBack: true),
                    ],
                  ),
                  Row(
                    children: [
                      _key('4'),
                      _key('5'),
                      _key('6'),
                      _key('', isGray: true),
                    ],
                  ),
                  Row(
                    children: [
                      _key('7'),
                      _key('8'),
                      _key('9'),
                      _key('', isGray: true),
                    ],
                  ),
                  Row(
                    children: [
                      _key('.'),
                      _key('0'),
                      _key('', isGray: true),
                      _key('Done', isDone: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Totals bar
// ─────────────────────────────────────────────────────────────────────────────

class _TotalsBar extends StatelessWidget {
  final FoodPlateProvider plate;
  final MetaDashColors colors;
  const _TotalsBar({required this.plate, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _MacroChip(
            label: 'Calories',
            value: '${plate.totalCalories}',
            unit: 'kcal',
            color: colors.accent,
          ),
          _MacroChip(
            label: 'Protein',
            value: '${plate.totalProtein}',
            unit: 'g',
            color: Palette.macroProtein,
          ),
          _MacroChip(
            label: 'Carbs',
            value: '${plate.totalCarbs}',
            unit: 'g',
            color: Palette.macroCarbs,
          ),
          _MacroChip(
            label: 'Fat',
            value: '${plate.totalFat}',
            unit: 'g',
            color: Palette.macroFat,
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _MacroChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colors.textMuted)),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meal selector — 4-chip row
// ─────────────────────────────────────────────────────────────────────────────

class _MealSelector extends StatelessWidget {
  final _Meal selected;
  final MetaDashColors colors;
  final ValueChanged<_Meal> onChanged;

  const _MealSelector({
    required this.selected,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        children: _Meal.values.map((meal) {
          final isActive = meal == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(meal),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? colors.accent.withOpacity(0.18)
                      : colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? colors.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      meal.icon,
                      size: 16,
                      color: isActive ? colors.accent : colors.textMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meal.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isActive ? colors.accent : colors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Commit CTA button
// ─────────────────────────────────────────────────────────────────────────────

class _CommitButton extends StatelessWidget {
  final int count;
  final _Meal meal;
  final MetaDashColors colors;
  final VoidCallback onPressed;

  const _CommitButton({
    required this.count,
    required this.meal,
    required this.colors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.cta,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            'Add $count item${count == 1 ? '' : 's'} to ${meal.label}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Compact impact strip — sits between macros bar and meal selector
// ───────────────────────────────────────────────────────────────────────────────

class _PlateImpactStrip extends StatelessWidget {
  final int todayKcal;
  final int calGoal;
  final int plateKcal;
  final bool loading;

  const _PlateImpactStrip({
    required this.todayKcal,
    required this.calGoal,
    required this.plateKcal,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Show a minimal placeholder while loading so layout doesn't jump
    if (loading) {
      return Container(
        height: 46,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.symmetric(
            horizontal: BorderSide(color: colors.divider, width: 0.5),
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.textMuted,
            ),
          ),
        ),
      );
    }

    final afterKcal = todayKcal + plateKcal;
    final balance = afterKcal - calGoal;
    final isDeficit = balance <= 0;
    final balanceColor = isDeficit ? colors.accent : const Color(0xFFE57373);
    final balanceLabel = isDeficit
        ? 'Deficit ${balance.abs()} kcal'
        : 'Over ${balance.abs()} kcal';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'After meal',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$todayKcal → $afterKcal kcal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 0.5, height: 28, color: colors.divider),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Today's balance",
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  balanceLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: balanceColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// Micronutrients dropdown card
// ───────────────────────────────────────────────────────────────────────────────

class _PlateNutrientsDropdown extends StatefulWidget {
  final FoodPlateProvider plate;
  const _PlateNutrientsDropdown({required this.plate});

  @override
  State<_PlateNutrientsDropdown> createState() =>
      _PlateNutrientsDropdownState();
}

class _PlateNutrientsDropdownState extends State<_PlateNutrientsDropdown> {
  bool _expanded = false;
  int _tab = 0;

  static const _tabs = ['Macros', 'Vitamins', 'Minerals', 'More'];

  // Each entry: (label, unit)
  static const _vitamins = [
    ('Vitamin A', 'mcg'),
    ('Vitamin C', 'mg'),
    ('Vitamin D', 'mcg'),
    ('Vitamin E', 'mg'),
    ('Vitamin K', 'mcg'),
    ('B1 · Thiamine', 'mg'),
    ('B2 · Riboflavin', 'mg'),
    ('B3 · Niacin', 'mg'),
    ('B5 · Pantothenic', 'mg'),
    ('B6 · Pyridoxine', 'mg'),
    ('B7 · Biotin', 'mcg'),
    ('B9 · Folate', 'mcg'),
    ('B12 · Cobalamin', 'mcg'),
    ('Choline', 'mg'),
  ];

  static const _minerals = [
    ('Calcium', 'mg'),
    ('Iron', 'mg'),
    ('Potassium', 'mg'),
    ('Sodium', 'mg'),
    ('Chloride', 'mg'),
    ('Magnesium', 'mg'),
    ('Phosphorus', 'mg'),
    ('Zinc', 'mg'),
    ('Copper', 'mg'),
    ('Manganese', 'mg'),
    ('Selenium', 'mcg'),
    ('Iodine', 'mcg'),
    ('Chromium', 'mcg'),
    ('Molybdenum', 'mcg'),
    ('Fluoride', 'mcg'),
  ];

  static const _more = [
    ('Dietary Fiber', 'g'),
    ('Total Sugars', 'g'),
    ('Added Sugars', 'g'),
    ('Net Carbs', 'g'),
    ('Cholesterol', 'mg'),
    ('Saturated Fat', 'g'),
    ('Trans Fat', 'g'),
    ('Water', 'g'),
    ('Caffeine', 'mg'),
    ('Alcohol', 'g'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header tap row ─────────────────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Text(
                    'MICRONUTRIENTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (!_expanded)
                    Text(
                      'See breakdown',
                      style: TextStyle(fontSize: 12, color: colors.accent),
                    ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Expandable body ──────────────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildBody(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(MetaDashColors colors) {
    if (_tab == 0) return _buildMacrosTab(colors);

    final rows = switch (_tab) {
      1 => _vitamins,
      2 => _minerals,
      _ => _more,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 0.5, color: colors.divider),
          const SizedBox(height: 12),
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
                            ? colors.accent
                            : colors.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : colors.accent,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: Column(
                children: rows
                    .map(
                      (r) => _MicroRow(
                        label: r.$1,
                        unit: r.$2,
                        value: null,
                        colors: colors,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _noteRow(colors),
        ],
      ),
    );
  }

  Widget _buildMacrosTab(MetaDashColors colors) {
    final plate = widget.plate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, thickness: 0.5, color: colors.divider),
          const SizedBox(height: 12),
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
                            ? colors.accent
                            : colors.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : colors.accent,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          // ── Protein ───────────────────────────────────────────────────────────────
          _MacroHeader(
            label: 'Protein',
            value: '${plate.totalProtein}g',
            color: Palette.macroProtein,
            colors: colors,
          ),
          _MicroRow(
            label: '  Tryptophan',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '  Threonine',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '  Isoleucine',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(label: '  Leucine', unit: 'g', value: null, colors: colors),
          _MicroRow(label: '  Lysine', unit: 'g', value: null, colors: colors),
          _MicroRow(
            label: '  Methionine',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '  Phenylalanine',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(label: '  Valine', unit: 'g', value: null, colors: colors),
          const SizedBox(height: 8),
          // ── Carbohydrates ───────────────────────────────────────────────────────
          _MacroHeader(
            label: 'Carbohydrates',
            value: '${plate.totalCarbs}g',
            color: Palette.macroCarbs,
            colors: colors,
          ),
          _MicroRow(
            label: '  Dietary Fiber',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '    Soluble',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '    Insoluble',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '  Total Sugars',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '    Added Sugars',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '  Net Carbs',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(label: '  Starch', unit: 'g', value: null, colors: colors),
          const SizedBox(height: 8),
          // ── Fat ───────────────────────────────────────────────────────────────────
          _MacroHeader(
            label: 'Total Fat',
            value: '${plate.totalFat}g',
            color: Palette.macroFat,
            colors: colors,
          ),
          _MicroRow(
            label: '  Saturated Fat',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '  Trans Fat',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '  Monounsaturated',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '  Polyunsaturated',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '    Omega-3',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '    Omega-6',
            unit: 'g',
            value: null,
            colors: colors,
          ),
          _MicroRow(
            label: '  Cholesterol',
            unit: 'mg',
            value: null,
            colors: colors,
          ),
          const SizedBox(height: 8),
          _noteRow(colors),
        ],
      ),
    );
  }

  Widget _noteRow(MetaDashColors colors) => Row(
    children: [
      Icon(Icons.info_outline_rounded, size: 12, color: colors.textMuted),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          'Sub-nutrient data available on individual food detail',
          style: TextStyle(fontSize: 11, color: colors.textMuted),
        ),
      ),
    ],
  );
}

class _MacroHeader extends StatelessWidget {
  final String label, value;
  final Color color;
  final MetaDashColors colors;
  const _MacroHeader({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroRow extends StatelessWidget {
  final String label, unit;
  final String? value;
  final MetaDashColors colors;
  const _MicroRow({
    required this.label,
    required this.unit,
    required this.value,
    required this.colors,
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
              style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
            ),
          ),
          Text(
            value ?? '—',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
              color: value != null ? colors.textPrimary : colors.textMuted,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 30,
            child: Text(
              value != null ? unit : '',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
