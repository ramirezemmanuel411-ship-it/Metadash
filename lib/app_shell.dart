import 'package:flutter/material.dart';
import 'shared/palette.dart';
import 'shared/widgets/radial_menu.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/diary/diary_screen.dart';
import 'providers/user_state.dart';

class AppShell extends StatefulWidget {
  final UserState userState;
  const AppShell({super.key, required this.userState});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _pageController = PageController(initialPage: 0);
  int _index = 0;
  DateTime _selectedDay = DateTime.now();

  // Shared nutrition data - loaded from database
  int _caloriesConsumed = 0;
  late int _caloriesGoal;
  int _proteinConsumed = 0;
  late int _proteinGoal;
  int _carbsConsumed = 0;
  late int _carbsGoal;
  int _fatConsumed = 0;
  late int _fatGoal;
  int _stepsTaken = 0;
  late int _stepsGoal;

  @override
  void initState() {
    super.initState();
    // Set defaults from user profile
    final user = widget.userState.currentUser;
    if (user != null) {
      _caloriesGoal = user.dailyCaloricGoal;
      _stepsGoal = user.dailyStepsGoal;
      _proteinGoal = user.macroTargets?['protein'] ?? 150;
      _carbsGoal = user.macroTargets?['carbs'] ?? 250;
      _fatGoal = user.macroTargets?['fat'] ?? 73;
    }
    _loadDailyData();
  }

  Future<void> _loadDailyData() async {
    final user = widget.userState.currentUser;
    if (user == null) return;

    final log = await widget.userState.db.getDailyLogByUserAndDate(user.id!, _selectedDay);
    
    setState(() {
      if (log != null) {
        _caloriesConsumed = log.caloriesConsumed;
        _proteinConsumed = log.protein;
        _carbsConsumed = log.carbs;
        _fatConsumed = log.fat;
        _stepsTaken = log.stepsCount;
      } else {
        _caloriesConsumed = 0;
        _proteinConsumed = 0;
        _carbsConsumed = 0;
        _fatConsumed = 0;
        _stepsTaken = 0;
      }
    });
  }

  void _shiftDays(int delta) {
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: delta));
    });
    _loadDailyData();
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

  void _logout() {
    widget.userState.logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
                  stepsTaken: _stepsTaken,
                  stepsGoal: _stepsGoal,
                  proteinConsumed: _proteinConsumed,
                  carbsConsumed: _carbsConsumed,
                  fatConsumed: _fatConsumed,
                  userState: widget.userState,
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
                  stepsTaken: _stepsTaken,
                  stepsGoal: _stepsGoal,
                  userState: widget.userState,
                ),
              ],
            ),
          ),
          // Persistent FAB menu across all screens
          RadialMenu(
            userState: widget.userState,
            onLogout: _logout,
          ),
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
