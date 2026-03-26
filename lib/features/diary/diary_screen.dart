import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/diary_entry_food.dart';
import '../../models/user_profile.dart';
import '../../models/daily_log.dart';
import '../../models/metabolic_settings.dart';
import '../../models/data_inputs_settings.dart';
import '../../services/calorie_calculation_service.dart';
import '../food_search/food_search_screen.dart';
import '../food_search/models.dart';

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
    _loadFoodEntries();
  }

  @override
  void didUpdateWidget(DiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) {
      _loadFoodEntries();
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
      0,
      0,
    );
  }

  void _openAddFoodSearch({int? targetHour}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          returnOnSelect: false,
          autofocusSearch: true,
          userState: widget.userState,
          targetTimestamp:
              targetHour == null ? null : _timestampForHour(targetHour),
        ),
      ),
    );
    // Reload entries when returning from search
    _loadFoodEntries();
  }

  void _openBarcodeScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          returnOnSelect: false,
          userState: widget.userState,
          initialTab: FoodSearchTab.barcode,
        ),
      ),
    );
  }

  String _servingText(DiaryEntryFood entry) {
    final direct = entry.serving?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final assumptions = entry.assumptions ?? const [];
    for (final assumption in assumptions) {
      final trimmed = assumption.trim();
      if (trimmed.isEmpty) continue;
      if (RegExp(r'\d').hasMatch(trimmed)) {
        return trimmed;
      }
    }

    return 'Not specified';
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
    _loadFoodEntries();
  }

  Future<void> _editEntry(DiaryEntryFood entry) async {
    final selected = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          returnOnSelect: true,
          autofocusSearch: true,
          userState: widget.userState,
        ),
      ),
    );

    if (selected == null || widget.userState?.currentUser == null) return;

    final replacement = DiaryEntryFood(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: widget.userState!.currentUser!.id!,
      timestamp: entry.timestamp,
      name: selected.name,
      calories: selected.calories,
      proteinG: selected.protein.toInt(),
      carbsG: selected.carbs.toInt(),
      fatG: selected.fat.toInt(),
      source: 'search',
      serving: entry.serving,
    );

    await widget.userState!.db.deleteFoodEntry(entry.id);
    await widget.userState!.db.addFoodEntry(replacement);
    _loadFoodEntries();
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
              primary: Palette.forestGreen,
              onPrimary: Palette.warmNeutral,
              surface: Palette.lightStone,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && widget.onDayChanged != null) {
      final daysDiff = DateUtils.dateOnly(pickedDate).difference(DateUtils.dateOnly(widget.selectedDay)).inDays;
      widget.onDayChanged!(daysDiff);
    }
  }

  @override
  Widget build(BuildContext context) {
    const rowHeight = 72.0;

    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        title: const Text('Diary'),
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Palette.lightStone,
                    borderRadius: BorderRadius.circular(0),
                  ),
                  padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _showDatePicker(context),
                                child: Text(
                                  _formattedHeaderDate,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _WeekdayRow(selectedWeekday: widget.selectedDay.weekday),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 185,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show workout as a simple calories readout (no per-workout calorie goal)
                              Row(
                                children: [
                                  Icon(Icons.fitness_center, color: Palette.forestGreen, size: 18),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text('Workout', style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text('${widget.workoutCalories} cal', style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _ProgressBar(
                                label: 'Steps',
                                value: widget.stepsGoal > 0 ? (widget.stepsTaken / widget.stepsGoal).clamp(0.0, 1.0) : 0,
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
                          setState(() => _currentMacroPage = _currentMacroPage == 0 ? 1 : 0);
                        },
                        child: IndexedStack(
                          index: _currentMacroPage,
                          children: [
                            // Page 1: Consumed macros
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _Ring(value: widget.proteinGoal > 0 ? widget.proteinConsumed / widget.proteinGoal : 0, label: 'Protein', number: widget.proteinConsumed, color: Colors.redAccent),
                                      const SizedBox(width: 0),
                                      _Ring(value: widget.fatGoal > 0 ? widget.fatConsumed / widget.fatGoal : 0, label: 'Fats', number: widget.fatConsumed, color: Colors.orange),
                                      const SizedBox(width: 0),
                                      _Ring(value: widget.carbsGoal > 0 ? widget.carbsConsumed / widget.carbsGoal : 0, label: 'Carbs', number: widget.carbsConsumed, color: Colors.teal),
                                    ],
                                  ),
                                ),
                                _Ring(value: widget.caloriesGoal > 0 ? widget.caloriesConsumed / widget.caloriesGoal : 0, label: 'Calories', number: widget.caloriesConsumed, color: Palette.forestGreen),
                              ],
                            ),
                            // Page 2: Remaining macros
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _Ring(
                                        value: widget.proteinGoal > 0 ? ((widget.proteinGoal - widget.proteinConsumed) / widget.proteinGoal).clamp(0.0, 1.0) : 0,
                                        label: 'Protein',
                                        number: (widget.proteinGoal - widget.proteinConsumed).clamp(0, widget.proteinGoal),
                                        color: Colors.redAccent,
                                      ),
                                      const SizedBox(width: 0),
                                      _Ring(
                                        value: widget.fatGoal > 0 ? ((widget.fatGoal - widget.fatConsumed) / widget.fatGoal).clamp(0.0, 1.0) : 0,
                                        label: 'Fats',
                                        number: (widget.fatGoal - widget.fatConsumed).clamp(0, widget.fatGoal),
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 0),
                                      _Ring(
                                        value: widget.carbsGoal > 0 ? ((widget.carbsGoal - widget.carbsConsumed) / widget.carbsGoal).clamp(0.0, 1.0) : 0,
                                        label: 'Carbs',
                                        number: (widget.carbsGoal - widget.carbsConsumed).clamp(0, widget.carbsGoal),
                                        color: Colors.teal,
                                      ),
                                    ],
                                  ),
                                ),
                                _Ring(
                                  value: widget.caloriesGoal > 0 ? ((widget.caloriesGoal - widget.caloriesConsumed) / widget.caloriesGoal).clamp(0.0, 1.0) : 0,
                                  label: 'Calories',
                                  number: (widget.caloriesGoal - widget.caloriesConsumed).clamp(0, widget.caloriesGoal),
                                  color: Palette.forestGreen,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => setState(() => _showResults = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.forestGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('RESULTS', style: TextStyle(fontSize: 12, color: Palette.warmNeutral)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 0),
            // Search bar with barcode icon
            GestureDetector(
                onTap: _openAddFoodSearch,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Search foods...',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _openBarcodeScanner,
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: Palette.forestGreen,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 0),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(24, (index) {
                          final label = _hourLabel(index);
                          // Find food entries for this hour
                          final entriesForHour = _foodEntries.where((entry) {
                            return entry.timestamp.hour == index;
                          }).toList();
                          
                          return SizedBox(
                            height: rowHeight,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 64,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(label, style: const TextStyle(color: Colors.grey)),
                                  ),
                                ),
                                const VerticalDivider(width: 1, thickness: 0.5, color: Colors.grey),
                                Expanded(
                                  child: entriesForHour.isEmpty
                                      ? GestureDetector(
                                          onTap: () => _openAddFoodSearch(
                                            targetHour: index,
                                          ),
                                          child: Container(
                                            alignment: Alignment.centerLeft,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            child: const Icon(Icons.add, color: Palette.forestGreen),
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          itemCount: entriesForHour.length,
                                          itemBuilder: (context, entryIndex) {
                                            final entry = entriesForHour[entryIndex];
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Slidable(
                                                key: ValueKey(entry.id),
                                                startActionPane: ActionPane(
                                                  motion: const ScrollMotion(),
                                                  extentRatio: 0.28,
                                                  children: [
                                                    SlidableAction(
                                                      onPressed: (_) => _addEntryFromTemplate(
                                                        entry,
                                                        timestamp: DateTime.now(),
                                                      ),
                                                      backgroundColor: Palette.forestGreen,
                                                      foregroundColor: Colors.white,
                                                      icon: Icons.add_circle_outline,
                                                      label: 'Add Again',
                                                    ),
                                                  ],
                                                ),
                                                endActionPane: ActionPane(
                                                  motion: const ScrollMotion(),
                                                  extentRatio: 0.75,
                                                  children: [
                                                    SlidableAction(
                                                      onPressed: (_) async {
                                                        await widget.userState!.db.deleteFoodEntry(entry.id);
                                                        _loadFoodEntries();
                                                      },
                                                      backgroundColor: Colors.redAccent,
                                                      foregroundColor: Colors.white,
                                                      icon: Icons.delete_outline,
                                                      label: 'Delete',
                                                    ),
                                                    SlidableAction(
                                                      onPressed: (_) => _editEntry(entry),
                                                      backgroundColor: Palette.lightStone,
                                                      foregroundColor: Colors.black87,
                                                      icon: Icons.edit_outlined,
                                                      label: 'Edit',
                                                    ),
                                                    SlidableAction(
                                                      onPressed: (_) => _addEntryFromTemplate(entry),
                                                      backgroundColor: Palette.lightStone,
                                                      foregroundColor: Colors.black87,
                                                      icon: Icons.copy_outlined,
                                                      label: 'Duplicate',
                                                    ),
                                                  ],
                                                ),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Palette.lightStone,
                                                    borderRadius: BorderRadius.circular(15),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.08),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 3),
                                                      ),
                                                    ],
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        entry.name,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.black87,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'P ${entry.proteinG}g • C ${entry.carbsG}g • F ${entry.fatG}g • ${entry.calories} kcal',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.black.withValues(alpha: 0.5),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Serving: ${_servingText(entry)}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.black.withValues(alpha: 0.45),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          );
                        }),
                ),
              ),
            ),
          ],
        ),
      ),
      // Results modal overlay
      if (_showResults && widget.userState != null && widget.userState!.currentUser != null)
        FutureBuilder(
          future: widget.userState!.db.getDailyLogByUserAndDate(
            widget.userState!.currentUser!.id!,
            widget.selectedDay,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return Container(); // Don't show modal if no log data
            }
            return _ResultsModal(
              onDismiss: () => setState(() => _showResults = false),
              user: widget.userState!.currentUser!,
              log: snapshot.data!,
              settings: widget.userState!.metabolicSettings,
              inputs: widget.userState!.dataInputsSettings,
            );
          },
        ),
    ],
  ),
    floatingActionButton: null,
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
              Text(labels[i], style: TextStyle(color: selected ? Palette.forestGreen : Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: selected ? Palette.forestGreen : Colors.transparent,
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
  final double value; // 0..1
  final String label;
  final int number;
  final Color color;

  const _Ring({required this.value, required this.label, required this.number, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 75,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(value: value, color: color, strokeWidth: 8, backgroundColor: Colors.grey.shade300),
                ),
                Text('$number', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final IconData icon;

  const _ProgressBar({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Palette.forestGreen, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(Palette.forestGreen),
            ),
          ),
        ),
      ],
    );
  }
}

// _StatTile removed — calories ring is used instead.

String _hourLabel(int hour) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'AM' : 'PM';
  return '$h $suffix';
}

String _weekdayFullName(int w) {
  const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return names[(w - 1) % 7];
}

String _monthName(int m) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
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

class _ResultsModalState extends State<_ResultsModal> with SingleTickerProviderStateMixin {
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
    final fatChangeLb = netCalories / 3500.0; // Convert calorie deficit to fat pounds
    final metabolismTrend = netCalories < -500 ? 'down' : netCalories > 500 ? 'up' : 'flat';

    return Stack(
      children: [
        // Transparent backdrop (tap to dismiss)
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              _animationController.reverse().then((_) => widget.onDismiss());
            },
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        // Raised card
        Align(
          alignment: Alignment(0, -0.75),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  color: Palette.lightStone,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
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
                    Text(
                      'Results',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Row 1: Daily Energy Expenditure
                    _ResultsRow(
                      label: 'Daily Energy Expendeture:',
                      value: '${tdee.round()} kcal',
                    ),
                    const SizedBox(height: 12),
                    // Row 2: Net Calories
                    _NetCaloriesRow(netCalories: netCalories.round()),
                    const SizedBox(height: 12),
                    // Row 3: Estimated Fat Change
                    _ResultsRow(
                      label: 'Est. Fat Change:',
                      value: '${fatChangeLb < 0 ? '−' : fatChangeLb > 0 ? '+' : ''}${fatChangeLb.abs().toStringAsFixed(2)} lb',
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
                          _animationController.reverse().then((_) => widget.onDismiss());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'OK',
                          style: TextStyle(
                            color: Palette.forestGreen,
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
          style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
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
    Color valueColor = Colors.black;

    if (netCalories.abs() <= 100) {
      label = 'Maintenance:';
      value = '${netCalories.abs()} kcal';
    } else if (netCalories < 0) {
      label = 'Calorie Deficit:';
      value = '(${netCalories.abs()}) kcal';
      valueColor = Colors.black;
    } else {
      label = 'Calorie Surplus:';
      value = '$netCalories kcal';
      valueColor = Colors.black;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
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
        color = Colors.green.shade600;
        break;
      case 'down':
        icon = Icons.arrow_downward;
        color = Colors.green.shade600;
        break;
      default:
        icon = Icons.remove;
        color = Colors.grey;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Metabolism:',
          style: TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold),
        ),
        Icon(icon, size: 16, color: color),
      ],
    );
  }
}