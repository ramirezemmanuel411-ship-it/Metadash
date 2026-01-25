import 'package:flutter/material.dart';
import 'shared/palette.dart';
import 'shared/widgets/radial_menu.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/diary/diary_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _pageController = PageController(initialPage: 0);
  int _index = 0;
  DateTime _selectedDay = DateTime.now();

  // Shared nutrition data
  int _caloriesConsumed = 1800;
  final int _caloriesGoal = 2200;
  int _proteinConsumed = 120;
  final int _proteinGoal = 150;
  int _carbsConsumed = 180;
  final int _carbsGoal = 250;
  int _fatConsumed = 60;
  final int _fatGoal = 73;

  void _shiftDays(int delta) {
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: delta));
    });
  }

  void _onTapNav(int i) {
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                DashboardScreen(
                  selectedDay: _selectedDay,
                  onDayChanged: _shiftDays,
                  caloriesConsumed: _caloriesConsumed,
                  caloriesGoal: _caloriesGoal,
                  proteinConsumed: _proteinConsumed,
                  carbsConsumed: _carbsConsumed,
                  fatConsumed: _fatConsumed,
                ),
                DiaryScreen(
                  selectedDay: _selectedDay,
                  onDayChanged: _shiftDays,
                  caloriesConsumed: _caloriesConsumed,
                  caloriesGoal: _caloriesGoal,
                  proteinConsumed: _proteinConsumed,
                  proteinGoal: _proteinGoal,
                  carbsConsumed: _carbsConsumed,
                  carbsGoal: _carbsGoal,
                  fatConsumed: _fatConsumed,
                  fatGoal: _fatGoal,
                ),
              ],
            ),
          ),
          // Persistent FAB menu across all screens
          const RadialMenu(),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DotIndicator(
                    isActive: _index == 0,
                    onTap: () => _onTapNav(0),
                  ),
                  const SizedBox(width: 8),
                  _DotIndicator(
                    isActive: _index == 1,
                    onTap: () => _onTapNav(1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _DotIndicator({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isActive ? 8 : 6,
        height: isActive ? 8 : 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Palette.forestGreen : Colors.grey.shade400,
        ),
      ),
    );
  }
}
