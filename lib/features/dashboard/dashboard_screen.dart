import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../services/calorie_calculation_service.dart';
import '../../shared/date_utils.dart';
import 'dashboard_state.dart';
import 'horizontal_date_wheel_picker.dart';
import 'calorie_progress_ring.dart';
import 'macro_progress_bars.dart';

class DashboardScreen extends StatefulWidget {
  final DateTime selectedDay;
  final Function(int) onDayChanged;
  final VoidCallback? onOpenDiary;
  final int caloriesConsumed;
  final int caloriesGoal;
  final int proteinConsumed;
  final int carbsConsumed;
  final int fatConsumed;
  final int stepsTaken;
  final int stepsGoal;
  final UserState? userState;

  const DashboardScreen({
    super.key,
    required this.selectedDay,
    required this.onDayChanged,
    this.onOpenDiary,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.proteinConsumed,
    required this.carbsConsumed,
    required this.fatConsumed,
    required this.stepsTaken,
    required this.stepsGoal,
    this.userState,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<double> _weeklyDeficit = List<double>.filled(7, 0);
  List<double> _weeklyTDEE = List<double>.filled(7, 0);
  bool _loadingWeekly = false;
  late final DashboardState _dashboardState;
  DateTime? _lastNotifiedDate;

  @override
  void initState() {
    super.initState();
    _dashboardState = DashboardState(
      initialDate: widget.selectedDay,
      userState: widget.userState,
    );
    _lastNotifiedDate = _dashboardState.selectedDate;
    _dashboardState.addListener(_handleSelectedDateChanged);
    _loadWeeklyDeficit();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.selectedDay, widget.selectedDay)) {
      _dashboardState.setSelectedDateFromExternal(widget.selectedDay);
    }
    if (oldWidget.userState != widget.userState) {
      _loadWeeklyDeficit();
    }
  }

  @override
  void dispose() {
    _dashboardState.removeListener(_handleSelectedDateChanged);
    _dashboardState.dispose();
    super.dispose();
  }

  void _handleSelectedDateChanged() {
    final selectedDate = _dashboardState.selectedDate;
    if (_lastNotifiedDate != null && AppDateUtils.isSameDay(_lastNotifiedDate!, selectedDate)) {
      return;
    }
    final daysDiff = DateUtils.dateOnly(selectedDate)
        .difference(DateUtils.dateOnly(widget.selectedDay))
        .inDays;
    if (daysDiff != 0) {
      widget.onDayChanged(daysDiff);
    }
    _lastNotifiedDate = selectedDate;
    _loadWeeklyDeficit();
  }

  Future<void> _loadWeeklyDeficit() async {
    final userState = widget.userState;
    final user = userState?.currentUser;
    if (userState == null || user == null) {
      if (!mounted) return;
      setState(() {
        _weeklyDeficit = List<double>.filled(7, 0);
        _weeklyTDEE = List<double>.filled(7, 0);
      });
      return;
    }

    setState(() => _loadingWeekly = true);

    final endDate = DateUtils.dateOnly(_dashboardState.selectedDate);
    final startDate = endDate.subtract(const Duration(days: 6));
    final logs = await userState.db.getDailyLogsByUserAndDateRange(user.id!, startDate, endDate);

    final logByDate = <DateTime, dynamic>{
      for (final log in logs) DateUtils.dateOnly(log.date): log,
    };

    final deficitValues = <double>[];
    final tdeeValues = <double>[];
    for (var i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final log = logByDate[DateUtils.dateOnly(date)];
      if (log != null) {
        final metrics = CalorieCalculationService.calculateDayMetrics(user: user, log: log);
        deficitValues.add(metrics.dailyDeficitSurplus);
        tdeeValues.add(metrics.tdee);
      } else {
        deficitValues.add(0);
        tdeeValues.add(0);
      }
    }

    if (!mounted) return;
    setState(() {
      _weeklyDeficit = deficitValues;
      _weeklyTDEE = tdeeValues;
      _loadingWeekly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _dashboardState,
      child: Scaffold(
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
                Consumer<DashboardState>(
                  builder: (context, state, _) {
                    return HorizontalDateWheelPicker(
                      selectedDate: state.selectedDate,
                      onSelectedDateChanged: state.setSelectedDate,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Consumer<DashboardState>(
                  builder: (context, state, _) {
                    final data = state.selectedData;
                    return GestureDetector(
                      onTap: widget.onOpenDiary,
                      child: _CardSection(
                        title: 'Today\'s Summary',
                        child: _SummaryRow(
                          calories: data.caloriesConsumed,
                          goal: data.caloriesGoal,
                          protein: data.proteinConsumed,
                          carbs: data.carbsConsumed,
                          fat: data.fatConsumed,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Consumer<DashboardState>(
                  builder: (context, state, _) {
                    final data = state.selectedData;
                    return _CardSection(
                      title: 'Steps',
                      child: _StepsCard(
                        stepsTaken: data.stepsTaken,
                        stepsGoal: data.stepsGoal,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Consumer<DashboardState>(
                  builder: (context, state, _) {
                    return _CardSection(
                      title: 'Weekly Deficit',
                      child: _WeeklyDeficitChart(
                        dailyDeficit: _weeklyDeficit,
                        dailyTDEE: _weeklyTDEE,
                        endDate: state.selectedDate,
                        isLoading: _loadingWeekly,
                      ),
                    );
                  },
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
      ),
    );
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
    return SingleChildScrollView(
      child: Column(
        children: [
          CalorieProgressRing(
            consumed: calories,
            target: goal,
          ),
          const SizedBox(height: 24),
          MacroProgressBars(
            proteinConsumed: protein,
            proteinTarget: goal ~/ 8,
            carbsConsumed: carbs,
            carbsTarget: goal ~/ 2,
            fatConsumed: fat,
            fatTarget: goal ~/ 4,
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  final int stepsTaken;
  final int stepsGoal;

  const _StepsCard({required this.stepsTaken, required this.stepsGoal});

  @override
  Widget build(BuildContext context) {
    final progress = stepsGoal > 0 ? (stepsTaken / stepsGoal).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Icon(Icons.directions_walk, color: Palette.forestGreen, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$stepsTaken / $stepsGoal steps', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  color: Palette.forestGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyDeficitChart extends StatelessWidget {
  final List<double> dailyDeficit; // negative = deficit, positive = surplus
  final List<double> dailyTDEE; // TDEE for each day
  final DateTime endDate;
  final bool isLoading;

  const _WeeklyDeficitChart({
    required this.dailyDeficit,
    required this.dailyTDEE,
    required this.endDate,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final values = dailyDeficit.length == 7 ? dailyDeficit : List<double>.filled(7, 0);
    final tdeeValues = dailyTDEE.length == 7 ? dailyTDEE : List<double>.filled(7, 0);
    final maxAbs = values.map((v) => v.abs()).fold(0.0, (a, b) => math.max(a, b));
    final maxTDEE = tdeeValues.fold(0.0, (a, b) => math.max(a, b));
    final safeMax = math.max(maxAbs, maxTDEE);
    final safeMaxVal = safeMax == 0 ? 1.0 : safeMax;
    final startDate = DateUtils.dateOnly(endDate).subtract(const Duration(days: 6));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: Padding(
            padding: const EdgeInsets.only(left: 32, right: 8, top: 8, bottom: 24),
            child: CustomPaint(
              painter: _ComboChartPainter(
                deficitValues: values,
                tdeeValues: tdeeValues,
                maxValue: safeMaxVal,
                startDate: startDate,
              ),
              child: Container(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _LegendDot(color: Palette.forestGreen, label: 'Deficit'),
            const SizedBox(width: 12),
            _LegendDot(color: Colors.redAccent, label: 'Surplus'),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 2,
                  color: Colors.orange,
                ),
                const SizedBox(width: 6),
                const Text('Avg TDEE', style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ComboChartPainter extends CustomPainter {
  final List<double> deficitValues;
  final List<double> tdeeValues;
  final double maxValue;
  final DateTime startDate;

  _ComboChartPainter({
    required this.deficitValues,
    required this.tdeeValues,
    required this.maxValue,
    required this.startDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (deficitValues.isEmpty) return;

    final chartHeight = size.height * 0.85;
    final chartTop = 0.0;
    final chartBottom = chartHeight;
    final chartRight = size.width;
    const barWidth = 10.0;
    const spacing = 28.0;

    // Draw Y-axis labels
    const tickCount = 5;
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= tickCount; i++) {
      final factor = i / tickCount;
      final value = maxValue * (1 - factor);
      final y = chartTop + (chartHeight * factor);

      labelPaint.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: const TextStyle(fontSize: 8, color: Colors.black54),
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(-labelPaint.width - 4, y - labelPaint.height / 2),
      );

      // Draw horizontal grid line
      canvas.drawLine(
        Offset(0, y),
        Offset(chartRight, y),
        Paint()
          ..color = Colors.black12
          ..strokeWidth = 0.5,
      );
    }

    // Draw Y-axis
    canvas.drawLine(
      Offset(0, chartTop),
      Offset(0, chartBottom),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1,
    );

    // Draw center line
    canvas.drawLine(
      Offset(0, chartHeight / 2),
      Offset(chartRight, chartHeight / 2),
      Paint()
        ..color = Colors.black12
        ..strokeWidth = 1,
    );

    // Draw bars for deficit/surplus
    for (var i = 0; i < deficitValues.length; i++) {
      final value = deficitValues[i];
      final x = (spacing * i) + spacing / 2;

      if (value > 0) {
        // Surplus (red, top)
        final factor = (value / maxValue).clamp(0.0, 1.0);
        final barHeight = (chartHeight / 2) * factor;
        final rect = Rect.fromLTWH(
          x - barWidth / 2,
          (chartHeight / 2) - barHeight,
          barWidth,
          barHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = Colors.redAccent,
        );
      } else if (value < 0) {
        // Deficit (green, bottom)
        final factor = (value.abs() / maxValue).clamp(0.0, 1.0);
        final barHeight = (chartHeight / 2) * factor;
        final rect = Rect.fromLTWH(
          x - barWidth / 2,
          chartHeight / 2,
          barWidth,
          barHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = Palette.forestGreen,
        );
      }
    }

    // Draw dashed line for average TDEE
    final avgTDEE = tdeeValues.fold(0.0, (a, b) => a + b) / 7;
    final avgFactor = (avgTDEE / maxValue).clamp(0.0, 1.0);
    final lineY = chartTop + (chartHeight * 0.5) - (chartHeight * avgFactor * 0.5);

    _drawDashedLine(
      canvas,
      Offset(0, lineY),
      Offset(chartRight, lineY),
      dashWidth: 4,
      dashSpace: 2,
      color: Colors.orange,
      strokeWidth: 2,
    );

    // Draw weekday labels
    for (var i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final label = _weekdayLabel(date.weekday);
      final x = (spacing * i) + spacing / 2;

      labelPaint.text = TextSpan(
        text: label,
        style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w500),
      );
      labelPaint.layout();
      labelPaint.paint(
        canvas,
        Offset(x - labelPaint.width / 2, chartBottom + 6),
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end, {
    double dashWidth = 4,
    double dashSpace = 2,
    required Color color,
    double strokeWidth = 1,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final steps = (distance / (dashWidth + dashSpace)).ceil();

    for (int i = 0; i < steps; i++) {
      final t1 = (i * (dashWidth + dashSpace)) / distance;
      final t2 = ((i * (dashWidth + dashSpace)) + dashWidth) / distance;

      final p1 = Offset(
        start.dx + dx * t1,
        start.dy + dy * t1,
      );
      final p2 = Offset(
        start.dx + dx * t2.clamp(0, 1),
        start.dy + dy * t2.clamp(0, 1),
      );

      canvas.drawLine(p1, p2, paint);
    }
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'T';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'S';
    }
    return '';
  }

  @override
  bool shouldRepaint(_ComboChartPainter oldDelegate) =>
      oldDelegate.deficitValues != deficitValues || oldDelegate.tdeeValues != tdeeValues;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
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
