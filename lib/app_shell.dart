import 'package:flutter/material.dart';
import 'shared/palette.dart';
import 'shared/widgets/floating_action_hub.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/diary/diary_screen.dart';
import 'features/food/ai_chat_screen.dart';
import 'features/food_search/food_search_screen.dart';
import 'features/control_center/control_center_screen.dart';
import 'features/progress/progress_screen.dart';
import 'presentation/screens/exercise_logging/exercise_main_screen.dart';
import 'providers/user_state.dart';
import 'models/data_inputs_settings.dart';
import 'services/health_service.dart';
import 'services/calorie_calculation_service.dart';

class AppShell extends StatefulWidget {
  final UserState userState;
  const AppShell({super.key, required this.userState});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
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
  int _workoutCalories = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    widget.userState.addListener(_handleUserStateChange);
    
    // Start automatic sync on app open (async, non-blocking)
    Future.delayed(const Duration(milliseconds: 500), _syncHealthDataInBackground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.userState.removeListener(_handleUserStateChange);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sync again whenever the app is opened/resumed
      _syncHealthDataInBackground();
    }
  }

  void _handleUserStateChange() {
    if (!mounted) return;
    if (widget.userState.currentUser == null) return;
    _loadDailyData();
  }

  /// Automatically sync health data from HealthKit/Google Fit
  /// Runs silently in the background
  Future<void> _syncHealthDataInBackground() async {
    try {
      final user = widget.userState.currentUser;
      if (user == null) return;

      try {
        // Check if user has given health permissions
        final hasPermissions = await HealthService().hasPermissions();
        if (!hasPermissions) return;
      } catch (e) {
        // If health service fails to check permissions, skip sync
        print('Could not check health permissions: $e');
        return;
      }

      try {
        // Sync last 7 days INCLUDING today
        final now = DateTime.now();
        final start = now.subtract(const Duration(days: 6));
        final end = now; // Include today by using current time, not midnight

        await widget.userState.db.syncHealthDataForDateRange(user.id!, start, end);

        // Reload UI with new data
        if (mounted) {
          _loadDailyData();
        }
      } catch (e) {
        // If sync fails, still let app continue
        print('Health data sync failed: $e');
      }
    } catch (e) {
      // Catch all - don't let anything crash the app
      print('Background health sync error (non-blocking): $e');
    }
  }

  Future<void> _loadDailyData() async {
    final user = widget.userState.currentUser;
    if (user == null) return;

    final settings = await widget.userState.db.getDataInputsSettings(user.id!) ??
      DataInputsSettings.defaults(user.id!).copyWith(stepGoal: user.dailyStepsGoal);
    await widget.userState.db.createOrUpdateDataInputsSettings(settings);

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
      _stepsGoal = settings.stepGoal;
      _caloriesGoal = user.dailyCaloricGoal;
      _proteinGoal = user.macroTargets?['protein'] ?? 150;
      _carbsGoal = user.macroTargets?['carbs'] ?? 250;
      _fatGoal = user.macroTargets?['fat'] ?? 73;

      if (log != null) {
        final metrics = CalorieCalculationService.calculateDayMetrics(
          user: user,
          log: log,
          settings: widget.userState.metabolicSettings,
          inputs: widget.userState.dataInputsSettings,
        );
        _caloriesConsumed = log.caloriesConsumed + foodCalories;
        _proteinConsumed = log.protein + foodProtein;
        _carbsConsumed = log.carbs + foodCarbs;
        _fatConsumed = log.fat + foodFat;
        _stepsTaken = log.stepsCount;
        _workoutCalories = metrics.workoutCalories.round();
      } else {
        _caloriesConsumed = foodCalories;
        _proteinConsumed = foodProtein;
        _carbsConsumed = foodCarbs;
        _fatConsumed = foodFat;
        _stepsTaken = 0;
        _workoutCalories = 0;
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

  void _openAddFood() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          userState: widget.userState,
          targetTimestamp: _selectedDay,
          autofocusSearch: true,
        ),
      ),
    ).then((_) => _loadDailyData());
  }

  void _openAddWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExerciseMainScreen(),
      ),
    ).then((_) => _loadDailyData());
  }

  void _openAddWeight() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProgressScreen(),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ControlCenterScreen(),
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
                  workoutCalories: _workoutCalories,
                  userState: widget.userState,
                ),
              ],
            ),
          ),
          // Floating action hub with radial menu
          FloatingActionHub(
            onAddFood: _openAddFood,
            onOpenAI: _openAiAssistant,
            onAddWorkout: _openAddWorkout,
            onAddWeight: _openAddWeight,
            onSettings: _openSettings,
            fabColor: Palette.forestGreen,
            backgroundColor: Palette.warmNeutral,
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
