import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../shared/palette.dart';
import '../food_search/food_search_screen.dart';
import '../food_search/models.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _selectedDay = DateTime.now();

  void _shiftDays(int delta) {
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: delta));
    });
  }

  String get _dayLabel {
    final now = DateTime.now();
    final diff = DateUtils.dateOnly(_selectedDay).difference(DateUtils.dateOnly(now)).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return '${_selectedDay.month}/${_selectedDay.day}/${_selectedDay.year}';
  }

  final Map<String, List<_MealItem>> _meals = {
    'Breakfast': const [
      _MealItem(name: 'Oats', calories: 150, macro: 'P 5g • C 27g • F 3g'),
      _MealItem(name: 'Greek Yogurt', calories: 100, macro: 'P 17g • C 6g • F 0g'),
    ],
    'Lunch': const [
      _MealItem(name: 'Chicken Breast', calories: 165, macro: 'P 31g • C 0g • F 3g'),
    ],
    'Dinner': const [
      _MealItem(name: 'Salmon', calories: 208, macro: 'P 22g • C 0g • F 13g'),
    ],
    'Snacks': const [
      _MealItem(name: 'Banana', calories: 105, macro: 'P 1g • C 27g • F 0g'),
    ],
  };

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _dateSelector(),
          ),

          // Top dashboard with weekday selector and nutrient rings
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formattedHeaderDate(),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          _WeekdayRow(selectedWeekday: DateTime.now().weekday),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Nutrient rings row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      _Ring(value: 0.6, label: 'Protein', number: 180, color: Colors.redAccent),
                      _Ring(value: 0.2, label: 'Fats', number: 60, color: Colors.orange),
                      _Ring(value: 0.25, label: 'Carbs', number: 200, color: Colors.teal),
                      _Ring(value: 0.8, label: 'Calories', number: 2200, color: Palette.forestGreen),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Workout and Steps progress bars
                  Column(
                    children: [
                      _ProgressBar(label: 'Workout', value: 0.65, icon: Icons.fitness_center),
                      const SizedBox(height: 8),
                      _ProgressBar(label: 'Steps', value: 0.45, icon: Icons.directions_walk),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.forestGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('RESULTS', style: TextStyle(fontSize: 12, color: Palette.warmNeutral)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Timeline area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
                children: [
                  // Hour rows
                  SingleChildScrollView(
                    child: Column(
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
                                  decoration: const BoxDecoration(),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {},
                                        child: const Icon(Icons.add, color: Palette.forestGreen),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),

                  // Meal pill overlay (example: Breakfast at 7 AM)
                  Positioned(
                    top: rowHeight * 7,
                    left: 80,
                    child: _MealPill(label: 'Breakfast'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _RadialFab(),
    );
  }

  Future<void> _addFoodForMeal(String mealLabel) async {
    // Map string label to MealName enum used by FoodSearchScreen
    MealName? meal;
    switch (mealLabel.toLowerCase()) {
      case 'breakfast':
        meal = MealName.breakfast;
        break;
      case 'lunch':
        meal = MealName.lunch;
        break;
      case 'dinner':
        meal = MealName.dinner;
        break;
      default:
        meal = null;
    }

    final result = await Navigator.of(context).push<FoodItem?>(
      MaterialPageRoute(builder: (_) => FoodSearchScreen(targetMeal: meal, returnOnSelect: true)),
    );

    if (result != null) {
      setState(() {
        final list = _meals.putIfAbsent(mealLabel, () => []);
        list.add(_MealItem(name: result.name, calories: result.calories, macro: result.macroLine));
      });
    }
  }

  Widget _dateSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftDays(-1),
            icon: const Icon(Icons.chevron_left),
            splashRadius: 20,
          ),
          Expanded(
            child: Center(
              child: Text(
                _dayLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _shiftDays(1),
            icon: const Icon(Icons.chevron_right),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final String title;
  final List<_MealItem> items;
  final VoidCallback? onAdd;

  const _MealCard({required this.title, required this.items, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final totalCalories = items.fold<int>(0, (sum, i) => sum + i.calories);

    return Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$totalCalories kcal', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _MealRow(item: items[i]),
                if (i != items.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1.0, thickness: 0.5),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final _MealItem item;

  const _MealRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(item.macro, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('${item.calories} kcal', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
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
            children: [
              _SmallCircle(icon: Icons.restaurant),
              const SizedBox(width: 6),
              _SmallCircle(icon: Icons.kitchen),
              const SizedBox(width: 6),
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

class _MiniFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MiniFab({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(color: Palette.forestGreen, shape: BoxShape.circle),
        child: Icon(icon, color: Palette.warmNeutral),
      ),
    );
  }
}

String _hourLabel(int hour) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  final suffix = hour < 12 ? 'AM' : 'PM';
  return '$h $suffix';
}

String _formattedHeaderDate() {
  final now = DateTime.now();
  return '${_weekdayFullName(now.weekday)}, ${_monthName(now.month)} ${now.day}';
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
  return names[m - 1];
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

class _RadialFab extends StatefulWidget {
  const _RadialFab();

  @override
  State<_RadialFab> createState() => _RadialFabState();
}

class _RadialFabState extends State<_RadialFab> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Semi-transparent overlay
        if (_isOpen)
          GestureDetector(
            onTap: _toggleMenu,
            child: Container(color: Colors.black26),
          ),
        // Radial menu buttons
        ..._buildRadialButtons(),
        // Center FAB
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _toggleMenu,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Palette.forestGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isOpen ? Icons.close : Icons.add,
                color: Palette.warmNeutral,
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRadialButtons() {
    const buttons = [
      (icon: Icons.search, label: 'Search', angle: -90.0),
      (icon: Icons.restaurant, label: 'Restaurant', angle: 0.0),
      (icon: Icons.fitness_center, label: 'Fitness', angle: 90.0),
      (icon: Icons.person, label: 'Profile', angle: 180.0),
    ];

    return buttons.map((btn) {
      final angle = btn.angle * (3.14159 / 180);
      final radius = 100.0;
      final x = radius * _animation.value * cos(angle);
      final y = radius * _animation.value * sin(angle);

      return Positioned(
        bottom: 28 + y,
        right: 28 + x,
        child: ScaleTransition(
          scale: _animation,
          child: GestureDetector(
            onTap: () {
              _toggleMenu();
              if (btn.label == 'Search') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FoodSearchScreen()),
                );
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Palette.forestGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(btn.icon, color: Palette.warmNeutral, size: 24),
            ),
          ),
        ),
      );
    }).toList();
  }
}

double cos(double radians) => math.cos(radians);
double sin(double radians) => math.sin(radians);

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
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: value, color: color, strokeWidth: 6, backgroundColor: Colors.grey.shade300),
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
