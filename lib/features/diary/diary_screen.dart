import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:metadash/core/providers/user_state.dart';
import 'package:metadash/core/services/calorie_calculation_service.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:metadash/data/models/daily_log.dart';
import 'package:metadash/data/models/data_inputs_settings.dart';
import 'package:metadash/data/models/diary_entry_food.dart';
import 'package:metadash/data/models/food_model.dart';
import 'package:metadash/data/models/metabolic_settings.dart';
import 'package:metadash/data/models/user_profile.dart';
import 'package:metadash/features/food_search/food_detail_screen.dart';
import 'package:metadash/features/food_search/food_search_screen.dart';

class DiaryScreen extends StatefulWidget {
  final DateTime selectedDay;
  final Function(int)? onDayChanged;
  final VoidCallback? onEntriesChanged;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbsConsumed;
  final int carbsGoal;
  final int fatConsumed;
  final int fatGoal;
  final int stepsTaken;
  final int stepsGoal;
  final int workoutCalories;
  final UserState? userState;

  const DiaryScreen({
    super.key,
    required this.selectedDay,
    this.onDayChanged,
    this.onEntriesChanged,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbsConsumed,
    required this.carbsGoal,
    required this.fatConsumed,
    required this.fatGoal,
    required this.stepsTaken,
    required this.stepsGoal,
    required this.workoutCalories,
    this.userState,
  });

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  bool _showResults = false;
  int _currentMacroPage = 0;
  List<DiaryEntryFood> _foodEntries = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadFoodEntries());
  }

  @override
  void didUpdateWidget(DiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) {
      unawaited(_loadFoodEntries());
    }
  }

  Future<void> _loadFoodEntries() async {
    if (widget.userState?.currentUser == null) return;

    final entries = await widget.userState!.db.getFoodEntriesForDay(
      widget.userState!.currentUser!.id!,
      widget.selectedDay,
    );

    setState(() {
      _foodEntries = entries.map((map) => DiaryEntryFood.fromMap(map)).toList();
    });

    // Notify parent that entries changed so macros can be updated
    widget.onEntriesChanged?.call();
  }

  DateTime _timestampForHour(int hour) {
    return DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
      hour,
    );
  }

  void _openAddFoodSearch({int? targetHour}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          autofocusSearch: true,
          userState: widget.userState,
          targetTimestamp: targetHour == null
              ? null
              : _timestampForHour(targetHour),
        ),
      ),
    );
    // Reload entries when returning from search
    unawaited(_loadFoodEntries());
  }

  void _openBarcodeScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          userState: widget.userState,
          initialTab: FoodSearchTab.barcode,
        ),
      ),
    );
  }

  Future<void> _addEntryFromTemplate(
    DiaryEntryFood entry, {
    DateTime? timestamp,
  }) async {
    final user = widget.userState?.currentUser;
    if (user == null) return;

    final newEntry = entry.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.id!,
      timestamp: timestamp ?? entry.timestamp,
    );

    await widget.userState!.db.addFoodEntry(newEntry);
    unawaited(_loadFoodEntries());
  }

  Future<void> _editEntry(DiaryEntryFood entry) async {
    final food = FoodModel(
      id: entry.id,
      name: entry.name,
      servingSize: 1,
      servingUnit: entry.serving ?? 'serving',
      calories: entry.calories,
      protein: entry.proteinG.toDouble(),
      carbs: entry.carbsG.toDouble(),
      fat: entry.fatG.toDouble(),
      source: entry.source,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen(
          food: food,
          userState: widget.userState,
          targetTimestamp: entry.timestamp,
          editingEntry: entry,
          onSaved: _loadFoodEntries,
        ),
      ),
    );
  }

  Future<void> _showEntryMoveMenu(
    BuildContext ctx,
    DiaryEntryFood entry,
  ) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntryMoveSheet(
        entry: entry,
        currentDay: widget.selectedDay,
        onMove: (newTimestamp) async {
          final user = widget.userState?.currentUser;
          if (user == null) return;
          final moved = entry.copyWith(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            timestamp: newTimestamp,
          );
          await widget.userState!.db.deleteFoodEntry(entry.id);
          await widget.userState!.db.addFoodEntry(moved);
          unawaited(_loadFoodEntries());
        },
        onCopy: (newTimestamp) async {
          await _addEntryFromTemplate(entry, timestamp: newTimestamp);
        },
      ),
    );
  }

  String get _formattedHeaderDate {
    return '${_weekdayFullName(widget.selectedDay.weekday)}, ${_monthName(widget.selectedDay.month)} ${widget.selectedDay.day}';
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: context.colors.cta,
              onPrimary: context.colors.onPrimary,
              surface: Theme.of(context).colorScheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && widget.onDayChanged != null) {
      final daysDiff = DateUtils.dateOnly(
        pickedDate,
      ).difference(DateUtils.dateOnly(widget.selectedDay)).inDays;
      widget.onDayChanged!(daysDiff);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        title: const Text(
          'Diary',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Container(
                  color: context.colors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showDatePicker(context),
                                        child: Text(
                                          _formattedHeaderDate,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _WeekdayRow(
                                        selectedWeekday:
                                            widget.selectedDay.weekday,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 185,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Show workout as a simple calories readout (no per-workout calorie goal)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.fitness_center,
                                            color: context.colors.accent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Workout',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              '${widget.workoutCalories} cal',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      _ProgressBar(
                                        label: 'Steps',
                                        value: widget.stepsGoal > 0
                                            ? (widget.stepsTaken /
                                                      widget.stepsGoal)
                                                  .clamp(0.0, 1.0)
                                            : 0,
                                        icon: Icons.directions_walk,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 100,
                              child: GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _currentMacroPage =
                                        _currentMacroPage == 0 ? 1 : 0,
                                  );
                                },
                                child: IndexedStack(
                                  index: _currentMacroPage,
                                  children: [
                                    // Page 1: Consumed macros
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _Ring(
                                                value: widget.proteinGoal > 0
                                                    ? widget.proteinConsumed /
                                                          widget.proteinGoal
                                                    : 0,
                                                label: 'Protein',
                                                number: widget.proteinConsumed,
                                                color: Palette.macroProtein,
                                              ),
                                              const SizedBox(width: 0),
                                              _Ring(
                                                value: widget.fatGoal > 0
                                                    ? widget.fatConsumed /
                                                          widget.fatGoal
                                                    : 0,
                                                label: 'Fats',
                                                number: widget.fatConsumed,
                                                color: Palette.macroFat,
                                              ),
                                              const SizedBox(width: 0),
                                              _Ring(
                                                value: widget.carbsGoal > 0
                                                    ? widget.carbsConsumed /
                                                          widget.carbsGoal
                                                    : 0,
                                                label: 'Carbs',
                                                number: widget.carbsConsumed,
                                                color: Palette.macroCarbs,
                                              ),
                                            ],
                                          ),
                                        ),
                                        _Ring(
                                          value: widget.caloriesGoal > 0
                                              ? widget.caloriesConsumed /
                                                    widget.caloriesGoal
                                              : 0,
                                          label: 'Calories',
                                          number: widget.caloriesConsumed,
                                          color: context.colors.accent,
                                        ),
                                      ],
                                    ),
                                    // Page 2: Remaining macros
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _Ring(
                                                value: widget.proteinGoal > 0
                                                    ? ((widget.proteinGoal -
                                                                  widget
                                                                      .proteinConsumed) /
                                                              widget
                                                                  .proteinGoal)
                                                          .clamp(0.0, 1.0)
                                                    : 0,
                                                startFraction:
                                                    widget.proteinGoal > 0
                                                    ? (widget.proteinConsumed /
                                                              widget
                                                                  .proteinGoal)
                                                          .clamp(0.0, 1.0)
                                                    : 0,
                                                label: 'Protein',
                                                number:
                                                    (widget.proteinGoal -
                                                            widget
                                                                .proteinConsumed)
                                                        .clamp(
                                                          0,
                                                          widget.proteinGoal,
                                                        ),
                                                color: Palette.macroProtein,
                                              ),
                                              const SizedBox(width: 0),
                                              _Ring(
                                                value: widget.fatGoal > 0
                                                    ? ((widget.fatGoal -
                                                                  widget
                                                                      .fatConsumed) /
                                                              widget.fatGoal)
                                                          .clamp(0.0, 1.0)
                                                    : 0,
                                                startFraction:
                                                    widget.fatGoal > 0
                                                    ? (widget.fatConsumed /
                                                              widget.fatGoal)
                                                          .clamp(0.0, 1.0)
                                                    : 0,
                                                label: 'Fats',
                                                number:
                                                    (widget.fatGoal -
                                                            widget.fatConsumed)
                                                        .clamp(
                                                          0,
                                                          widget.fatGoal,
                                                        ),
                                                color: Palette.macroFat,
                                              ),
                                              const SizedBox(width: 0),
                                              _Ring(
                                                value: widget.carbsGoal > 0
                                                    ? ((widget.carbsGoal -
                                                                  widget
                                                                      .carbsConsumed) /
                                                              widget.carbsGoal)
                                                          .clamp(0.0, 1.0)
                                                    : 0,
                                                startFraction:
                                                    widget.carbsGoal > 0
                                                    ? (widget.carbsConsumed /
                                                              widget.carbsGoal)
                                                          .clamp(0.0, 1.0)
                                                    : 0,
                                                label: 'Carbs',
                                                number:
                                                    (widget.carbsGoal -
                                                            widget
                                                                .carbsConsumed)
                                                        .clamp(
                                                          0,
                                                          widget.carbsGoal,
                                                        ),
                                                color: Palette.macroCarbs,
                                              ),
                                            ],
                                          ),
                                        ),
                                        _Ring(
                                          value: widget.caloriesGoal > 0
                                              ? ((widget.caloriesGoal -
                                                            widget
                                                                .caloriesConsumed) /
                                                        widget.caloriesGoal)
                                                    .clamp(0.0, 1.0)
                                              : 0,
                                          startFraction: widget.caloriesGoal > 0
                                              ? (widget.caloriesConsumed /
                                                        widget.caloriesGoal)
                                                    .clamp(0.0, 1.0)
                                              : 0,
                                          label: 'Calories',
                                          number:
                                              (widget.caloriesGoal -
                                                      widget.caloriesConsumed)
                                                  .clamp(
                                                    0,
                                                    widget.caloriesGoal,
                                                  ),
                                          color: context.colors.accent,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => setState(() => _showResults = true),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.accent.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: context.colors.accent.withValues(
                                      alpha: 0.22,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.show_chart_rounded,
                                      size: 16,
                                      color: context.colors.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Current Metabolic Estimate',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: context.colors.accent,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: context.colors.accent.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edge-to-edge search bar
                      GestureDetector(
                        onTap: _openAddFoodSearch,
                        child: Container(
                          color: context.colors.inputFill,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: context.colors.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Search foods...',
                                  style: TextStyle(
                                    color: context.colors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _openBarcodeScanner,
                                child: Icon(
                                  Icons.qr_code_scanner,
                                  color: context.colors.accent,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _MealSections(
                    foodEntries: _foodEntries,
                    onAdd: _openAddFoodSearch,
                    onDelete: (entry) async {
                      await widget.userState!.db.deleteFoodEntry(entry.id);
                      unawaited(_loadFoodEntries());
                    },
                    onEdit: _editEntry,
                    onLongPress: (entry) => _showEntryMoveMenu(context, entry),
                  ),
                ),
              ],
            ),
          ),
          // Results modal overlay
          if (_showResults &&
              widget.userState != null &&
              widget.userState!.currentUser != null)
            FutureBuilder<DailyLog?>(
              future: widget.userState!.db.getDailyLogByUserAndDate(
                widget.userState!.currentUser!.id!,
                widget.selectedDay,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                final log =
                    snapshot.data ??
                    DailyLog(
                      userId: widget.userState!.currentUser!.id!,
                      date: widget.selectedDay,
                      caloriesConsumed: widget.caloriesConsumed,
                      stepsCount: widget.stepsTaken,
                      workoutCalories: widget.workoutCalories > 0
                          ? widget.workoutCalories
                          : null,
                      waterIntake: 0,
                      workoutActivities: const [],
                      protein: widget.proteinConsumed,
                      carbs: widget.carbsConsumed,
                      fat: widget.fatConsumed,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                return _ResultsModal(
                  onDismiss: () => setState(() => _showResults = false),
                  user: widget.userState!.currentUser!,
                  log: log,
                  settings: widget.userState!.metabolicSettings,
                  inputs: widget.userState!.dataInputsSettings,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final int selectedWeekday; // 1..7
  const _WeekdayRow({required this.selectedWeekday});

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final idx = i + 1;
        final selected = idx == selectedWeekday;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labels[i],
                style: TextStyle(
                  color: selected
                      ? context.colors.accent
                      : context.colors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: selected ? context.colors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Ring extends StatelessWidget {
  final double value; // 0..1 — fraction to draw
  final String label;
  final int number;
  final Color color;

  /// Fraction (0..1) where the arc should start on the circle.
  /// 0 = 12 o'clock. Pass the consumed fraction here for remaining rings so
  /// the arc begins exactly where the consumed arc ends.
  final double startFraction;

  const _Ring({
    required this.value,
    required this.label,
    required this.number,
    required this.color,
    this.startFraction = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = context.colors.surfaceVariant;
    return SizedBox(
      width: 75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(60, 60),
                  painter: _RingArcPainter(
                    value: value,
                    startFraction: startFraction,
                    color: color,
                    backgroundColor: bgColor,
                  ),
                ),
                Text(
                  '$number',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RingArcPainter extends CustomPainter {
  final double value;
  final double startFraction;
  final Color color;
  final Color backgroundColor;

  const _RingArcPainter({
    required this.value,
    required this.startFraction,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 8.0;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (value <= 0) return;

    final startAngle =
        -math.pi / 2 + 2 * math.pi * startFraction.clamp(0.0, 1.0);
    final sweepAngle = 2 * math.pi * value.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingArcPainter old) =>
      old.value != value ||
      old.startFraction != startFraction ||
      old.color != color ||
      old.backgroundColor != backgroundColor;
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final IconData icon;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.colors.accent, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.textMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: context.colors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(context.colors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

// _StatTile removed — calories ring is used instead.

String _weekdayFullName(int w) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[(w - 1) % 7];
}

String _monthName(int m) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[(m - 1) % 12];
}

class _ResultsModal extends StatefulWidget {
  final VoidCallback onDismiss;
  final UserProfile user;
  final DailyLog log;
  final MetabolicSettings settings;
  final DataInputsSettings? inputs;

  const _ResultsModal({
    required this.onDismiss,
    required this.user,
    required this.log,
    required this.settings,
    this.inputs,
  });

  @override
  State<_ResultsModal> createState() => _ResultsModalState();
}

class _ResultsModalState extends State<_ResultsModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate values from real data using CalorieCalculationService
    final metrics = CalorieCalculationService.calculateDayMetrics(
      user: widget.user,
      log: widget.log,
      settings: widget.settings,
      inputs: widget.inputs,
    );

    final tdee = metrics.tdee;
    final netCalories = metrics.dailyDeficitSurplus;
    final fatChangeLb =
        netCalories / 3500.0; // Convert calorie deficit to fat pounds
    final metabolismTrend = netCalories < -500
        ? 'down'
        : netCalories > 500
        ? 'up'
        : 'flat';

    return Stack(
      children: [
        // Transparent backdrop (tap to dismiss)
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              _animationController.reverse().then((_) => widget.onDismiss());
            },
            child: Container(
              color: context.colors.background.withValues(alpha: 0),
            ),
          ),
        ),
        // Raised card
        Align(
          alignment: const Alignment(0, -0.75),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  color: context.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.textMuted.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 18,
                          color: context.colors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Metabolic Estimate',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Row 1: Daily Energy Expenditure
                    _ResultsRow(
                      label: 'Est. TDEE:',
                      value: '${tdee.round()} kcal',
                    ),
                    const SizedBox(height: 12),
                    // Row 2: Net Calories
                    _NetCaloriesRow(netCalories: netCalories.round()),
                    const SizedBox(height: 12),
                    // Row 3: Estimated Fat Change
                    _ResultsRow(
                      label: 'Est. Fat Change:',
                      value:
                          '${fatChangeLb < 0
                              ? '−'
                              : fatChangeLb > 0
                              ? '+'
                              : ''}${fatChangeLb.abs().toStringAsFixed(2)} lb',
                    ),
                    const SizedBox(height: 12),
                    // Row 4: Metabolism Trend
                    _MetabolismTrendRow(trend: metabolismTrend),
                    const SizedBox(height: 16),
                    // OK Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _animationController.reverse().then(
                            (_) => widget.onDismiss(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.surfaceVariant,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'OK',
                          style: TextStyle(
                            color: context.colors.cta,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultsRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _NetCaloriesRow extends StatelessWidget {
  final int netCalories;

  const _NetCaloriesRow({required this.netCalories});

  @override
  Widget build(BuildContext context) {
    String label;
    String value;
    Color valueColor = context.colors.textPrimary;

    if (netCalories.abs() <= 100) {
      label = 'Maintenance:';
      value = '${netCalories.abs()} kcal';
    } else if (netCalories < 0) {
      label = 'Calorie Deficit:';
      value = '(${netCalories.abs()}) kcal';
      valueColor = context.colors.textPrimary;
    } else {
      label = 'Calorie Surplus:';
      value = '$netCalories kcal';
      valueColor = context.colors.textPrimary;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ── Meal Sections ────────────────────────────────────────────────────────────

typedef _EntryCallback = void Function(DiaryEntryFood entry);

enum _Meal { breakfast, lunch, dinner, snack }

extension _MealInfo on _Meal {
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

  bool containsHour(int h) {
    switch (this) {
      case _Meal.breakfast:
        return h >= 5 && h <= 10;
      case _Meal.lunch:
        return h >= 11 && h <= 15;
      case _Meal.dinner:
        return h >= 16 && h <= 20;
      case _Meal.snack:
        return true;
    }
  }

  /// Determine which meal bucket an hour belongs to.
  static _Meal fromHour(int h) {
    for (final m in _Meal.values) {
      if (m.containsHour(h)) return m;
    }
    return _Meal.snack;
  }
}

class _MealSections extends StatelessWidget {
  final List<DiaryEntryFood> foodEntries;
  final void Function({int? targetHour}) onAdd;
  final _EntryCallback onDelete;
  final _EntryCallback onEdit;
  final _EntryCallback onLongPress;

  const _MealSections({
    required this.foodEntries,
    required this.onAdd,
    required this.onDelete,
    required this.onEdit,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final buckets = <_Meal, List<DiaryEntryFood>>{
      for (final m in _Meal.values) m: [],
    };
    for (final e in foodEntries) {
      buckets[_MealInfo.fromHour(e.timestamp.hour)]!.add(e);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
      children: _Meal.values
          .map(
            (meal) => _MealSection(
              meal: meal,
              entries: buckets[meal]!,
              onAdd: () => onAdd(),
              onDelete: onDelete,
              onEdit: onEdit,
              onLongPress: onLongPress,
            ),
          )
          .toList(),
    );
  }
}

class _MealSection extends StatelessWidget {
  final _Meal meal;
  final List<DiaryEntryFood> entries;
  final VoidCallback onAdd;
  final _EntryCallback onDelete;
  final _EntryCallback onEdit;
  final _EntryCallback onLongPress;

  const _MealSection({
    required this.meal,
    required this.entries,
    required this.onAdd,
    required this.onDelete,
    required this.onEdit,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final totalCal = entries.fold(0, (s, e) => s + e.calories);
    final totalP = entries.fold(0, (s, e) => s + e.proteinG);
    final totalC = entries.fold(0, (s, e) => s + e.carbsG);
    final totalF = entries.fold(0, (s, e) => s + e.fatG);
    final hasFood = entries.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (hasFood)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$totalCal kcal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'P $totalP · C $totalC · F $totalF',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Food rows
            if (!hasFood)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'No foods logged',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textMuted,
                  ),
                ),
              )
            else
              Column(
                children: entries
                    .map(
                      (entry) => _FoodEntryCard(
                        entry: entry,
                        onDelete: () => onDelete(entry),
                        onEdit: () => onEdit(entry),
                        onLongPress: () => onLongPress(entry),
                      ),
                    )
                    .toList(),
              ),
            // Divider + Add Food
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: context.colors.divider.withValues(alpha: 0.5),
            ),
            InkWell(
              onTap: onAdd,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 16, color: context.colors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Add Food',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodEntryCard extends StatelessWidget {
  final DiaryEntryFood entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onLongPress;

  const _FoodEntryCard({
    required this.entry,
    required this.onDelete,
    required this.onEdit,
    required this.onLongPress,
  });

  Color _sourceColor(String source) {
    switch (source) {
      case 'barcode':
        return const Color(0xFF2E8B57);
      case 'ai_camera':
      case 'ai_chat':
        return const Color(0xFF8B5CF6);
      case 'manual':
        return const Color(0xFFEF8C2E);
      default:
        return const Color(0xFF4C7FA8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final src = entry.source;
    final srcColor = _sourceColor(src);
    final cal = entry.calories;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Slidable(
        key: ValueKey(entry.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.38,
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: const Color(0xFF4C7FA8),
              foregroundColor: Colors.white,
              icon: Icons.edit_outlined,
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: const Color(0xFFE05252),
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'Delete',
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Left accent dot
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: srcColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Name + serving
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Builder(
                      builder: (context) {
                        // Serving: strip quantity prefix like "2.0 × "
                        final serving = (entry.serving ?? '')
                            .trim()
                            .replaceFirst(RegExp(r'^[\d.]+ × '), '');
                        final macros =
                            'P ${entry.proteinG}g · C ${entry.carbsG}g · F ${entry.fatG}g';
                        // serving first, macros second — mirrors search tile order
                        final subtitle = serving.isNotEmpty
                            ? '$serving  ·  $macros'
                            : macros;
                        return Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Calories right
              Text(
                '$cal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetabolismTrendRow extends StatelessWidget {
  final String trend;

  const _MetabolismTrendRow({required this.trend});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (trend) {
      case 'up':
        icon = Icons.arrow_upward;
        color = context.colors.accent;
        break;
      case 'down':
        icon = Icons.arrow_downward;
        color = context.colors.accent;
        break;
      default:
        icon = Icons.remove;
        color = context.colors.textMuted;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Metabolism:',
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Icon(icon, size: 16, color: color),
      ],
    );
  }
}
// ── Entry Move / Copy Sheet ───────────────────────────────────────────────────

class _EntryMoveSheet extends StatefulWidget {
  final DiaryEntryFood entry;
  final DateTime currentDay;
  final void Function(DateTime) onMove;
  final void Function(DateTime) onCopy;

  const _EntryMoveSheet({
    required this.entry,
    required this.currentDay,
    required this.onMove,
    required this.onCopy,
  });

  @override
  State<_EntryMoveSheet> createState() => _EntryMoveSheetState();
}

class _EntryMoveSheetState extends State<_EntryMoveSheet> {
  // Left column: meal (0=Breakfast,1=Lunch,2=Dinner,3=Snack)
  // Right column: date (0=Today,1=Tomorrow,2=+2days …)
  int _mealIndex = 0;
  int _dateIndex = 0;

  // Date entries: index 0 = today, 1 = tomorrow, 2..N = next days
  static const int _totalDays = 14;

  late FixedExtentScrollController _mealCtrl;
  late FixedExtentScrollController _dateCtrl;

  static const _meals = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
  // Representative hours for each meal index
  static const _mealHours = [7, 12, 18, 21];

  @override
  void initState() {
    super.initState();
    // Pre-select meal based on current time
    final h = TimeOfDay.now().hour;
    if (h >= 5 && h <= 10) {
      _mealIndex = 0; // Breakfast
    } else if (h >= 11 && h <= 15) {
      _mealIndex = 1; // Lunch
    } else if (h >= 16 && h <= 20) {
      _mealIndex = 2; // Dinner
    } else {
      _mealIndex = 3; // Snack
    }

    _mealCtrl = FixedExtentScrollController(initialItem: _mealIndex);
    _dateCtrl = FixedExtentScrollController(initialItem: _dateIndex);
  }

  @override
  void dispose() {
    _mealCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  String _dateLabel(int i) {
    if (i == 0) return 'Today';
    if (i == 1) return 'Tomorrow';
    final d = widget.currentDay.add(Duration(days: i));
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mn = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${wd[d.weekday - 1]}, ${mn[d.month - 1]} ${d.day}';
  }

  DateTime _buildTimestamp() {
    final base = widget.currentDay.add(Duration(days: _dateIndex));
    final date = DateUtils.dateOnly(base);
    return DateTime(date.year, date.month, date.day, _mealHours[_mealIndex]);
  }

  Widget _col({
    required FixedExtentScrollController ctrl,
    required int count,
    required String Function(int) label,
    required int selected,
    required void Function(int) onChange,
    double width = 160,
  }) {
    return SizedBox(
      width: width,
      height: 220,
      child: CupertinoPicker(
        scrollController: ctrl,
        itemExtent: 46,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: onChange,
        children: List.generate(count, (i) {
          final sel = i == selected;
          return Center(
            child: Text(
              label(i),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sel ? 20 : 17,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                color: sel ? null : null, // color handled by opacity below
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    void confirm(bool isMove) {
      final ts = _buildTimestamp();
      Navigator.of(context).pop();
      if (isMove) {
        widget.onMove(ts);
      } else {
        widget.onCopy(ts);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Entry name
            Text(
              widget.entry.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              '${widget.entry.calories} kcal  ·  '
              'P ${widget.entry.proteinG}g  ·  '
              'C ${widget.entry.carbsG}g  ·  '
              'F ${widget.entry.fatG}g',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 16),
            // Wheel area
            Stack(
              alignment: Alignment.center,
              children: [
                // Subtle selection highlight — very light pill
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Row(
                  children: [
                    // Meal column
                    Expanded(
                      child: _col(
                        ctrl: _mealCtrl,
                        count: _meals.length,
                        label: (i) => _meals[i],
                        selected: _mealIndex,
                        onChange: (i) => setState(() => _mealIndex = i),
                      ),
                    ),
                    // Date column
                    Expanded(
                      child: _col(
                        ctrl: _dateCtrl,
                        count: _totalDays,
                        label: _dateLabel,
                        selected: _dateIndex,
                        onChange: (i) => setState(() => _dateIndex = i),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Move button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => confirm(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.cta,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Move to Date and Time',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Copy button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => confirm(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceVariant,
                  foregroundColor: colors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Copy to Date and Time',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Cancel
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, color: colors.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
