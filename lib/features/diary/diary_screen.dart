import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import '../food_search/food_search_screen.dart';

class DiaryScreen extends StatefulWidget {
  final DateTime selectedDay;
  final Function(int)? onDayChanged;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int proteinGoal;
  final int carbsConsumed;
  final int carbsGoal;
  final int fatConsumed;
  final int fatGoal;

  const DiaryScreen({
    super.key,
    required this.selectedDay,
    this.onDayChanged,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.proteinGoal,
    required this.carbsConsumed,
    required this.carbsGoal,
    required this.fatConsumed,
    required this.fatGoal,
  });

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  bool _showResults = false;

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Palette.lightStone,
                  borderRadius: BorderRadius.circular(12),
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
                              _ProgressBar(label: 'Workout', value: 0.65, icon: Icons.fitness_center),
                              const SizedBox(height: 8),
                              _ProgressBar(label: 'Steps', value: 0.45, icon: Icons.directions_walk),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
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
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  child: Stack(
                    children: [
                      Column(
                        children: List.generate(24, (index) {
                          final label = _hourLabel(index);
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
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: const Icon(Icons.add, color: Palette.forestGreen),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ],
            ),
          ),
          // Results modal overlay
          if (_showResults)
            _ResultsModal(
              onDismiss: () => setState(() => _showResults = false),
            ),
        ],
      ),
      floatingActionButton: null,
    );
  }
}

class _MealItem {
  final String name;
  final int calories;
  final String macro;

  const _MealItem({required this.name, required this.calories, required this.macro});
}

class _MealPill extends StatelessWidget {
  final String label;

  const _MealPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Row(
            children: const [
              _SmallCircle(icon: Icons.restaurant),
              SizedBox(width: 6),
              _SmallCircle(icon: Icons.kitchen),
              SizedBox(width: 6),
              _SmallCircle(icon: Icons.search),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallCircle extends StatelessWidget {
  final IconData icon;

  const _SmallCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.forestGreen),
      child: Icon(icon, color: Palette.warmNeutral, size: 18),
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

  const _ResultsModal({required this.onDismiss});

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
    const tdee = 2850;
    const netCalories = -650;
    const fatChangeLb = -0.19;
    const metabolismTrend = 'up'; // 'up', 'flat', 'down'

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
                      color: Colors.black.withOpacity(0.15),
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
                      value: '$tdee kcal',
                    ),
                    const SizedBox(height: 12),
                    // Row 2: Net Calories
                    _NetCaloriesRow(netCalories: netCalories),
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