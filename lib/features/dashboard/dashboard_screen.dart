import 'package:flutter/material.dart';
import '../../shared/palette.dart';

class DashboardScreen extends StatelessWidget {
  final DateTime selectedDay;
  final Function(int) onDayChanged;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int carbsConsumed;
  final int fatConsumed;

  const DashboardScreen({
    super.key,
    required this.selectedDay,
    required this.onDayChanged,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.carbsConsumed,
    required this.fatConsumed,
  });

  Future<void> _showDatePicker(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDay,
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

    if (pickedDate != null) {
      final daysDiff = DateUtils.dateOnly(pickedDate).difference(DateUtils.dateOnly(selectedDay)).inDays;
      onDayChanged(daysDiff);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Palette.lightStone,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => onDayChanged(-1),
                      icon: const Icon(Icons.chevron_left),
                      splashRadius: 20,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showDatePicker(context),
                        child: Center(
                          child: Text(
                            _dayLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onDayChanged(1),
                      icon: const Icon(Icons.chevron_right),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CardSection(
                title: 'Today\'s Summary',
                child: _SummaryRow(
                  calories: caloriesConsumed,
                  goal: caloriesGoal,
                  protein: proteinConsumed,
                  carbs: carbsConsumed,
                  fat: fatConsumed,
                ),
              ),
              const SizedBox(height: 12),
              const _CardSection(
                title: 'Weekly Trend',
                child: _TrendPlaceholder(),
              ),
              const SizedBox(height: 12),
              const _CardSection(
                title: 'Quick Actions',
                child: _QuickActionsRow(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _dayLabel {
    final now = DateTime.now();
    final diff = DateUtils.dateOnly(selectedDay).difference(DateUtils.dateOnly(now)).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return '${selectedDay.month}/${selectedDay.day}/${selectedDay.year}';
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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

class _SummaryRow extends StatelessWidget {
  final int calories;
  final int goal;
  final int protein;
  final int carbs;
  final int fat;

  const _SummaryRow({
    required this.calories,
    required this.goal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = goal - calories;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Calories', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                Text('$calories / $goal kcal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('Remaining: $remaining kcal', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('P $protein g', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('C $carbs g', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('F $fat g', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _TrendPlaceholder extends StatelessWidget {
  const _TrendPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
           color: Color.fromRGBO(255, 255, 255, 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        alignment: Alignment.center,
        child: const Text('Chart Placeholder'),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _ActionChip(icon: Icons.add, label: 'Add Food'),
        _ActionChip(icon: Icons.fitness_center, label: 'Add Workout'),
        _ActionChip(icon: Icons.local_drink, label: 'Log Water'),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: false,
      onSelected: (_) {},
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selectedColor: Palette.forestGreen,
      backgroundColor: Palette.lightStone,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}
