import 'package:flutter/material.dart';
import 'shared/palette.dart';
import 'shared/widgets/radial_menu.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/diary/diary_screen.dart';
import 'features/food/ai_chat_screen.dart';
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
  bool _fabMenuOpen = false;

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
    
    // Also get food entries for the day
    final foodEntryMaps = await widget.userState.db.getFoodEntriesForDay(user.id!, _selectedDay);
    
    // Sum up calories and macros from food entries
    int foodCalories = 0;
    int foodProtein = 0;
    int foodCarbs = 0;
    int foodFat = 0;
    
    for (final map in foodEntryMaps) {
      foodCalories += (map['calories'] as int?) ?? 0;
      foodProtein += (map['proteinG'] as int?) ?? 0;
      foodCarbs += (map['carbsG'] as int?) ?? 0;
      foodFat += (map['fatG'] as int?) ?? 0;
    }
    
    setState(() {
      if (log != null) {
        _caloriesConsumed = log.caloriesConsumed + foodCalories;
        _proteinConsumed = log.protein + foodProtein;
        _carbsConsumed = log.carbs + foodCarbs;
        _fatConsumed = log.fat + foodFat;
        _stepsTaken = log.stepsCount;
      } else {
        _caloriesConsumed = foodCalories;
        _proteinConsumed = foodProtein;
        _carbsConsumed = foodCarbs;
        _fatConsumed = foodFat;
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

  void _openAiAssistant() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiChatScreen(
          userState: widget.userState,
          selectedDay: _selectedDay,
        ),
      ),
    );
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
                  onOpenDiary: () => _onTapNav(1),
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
                  onEntriesChanged: _loadDailyData,
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
            onOpenChanged: (isOpen) => setState(() => _fabMenuOpen = isOpen),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: 48 + 56 + 12 + (_fabMenuOpen ? 140 : 0),
            right: 32,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _fabMenuOpen ? 0.95 : 1,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: _fabMenuOpen ? 0.98 : 1,
                child: GestureDetector(
                  onTap: _openAiAssistant,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Palette.forestGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Palette.warmNeutral,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
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
