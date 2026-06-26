import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/user_state.dart';
import '../../models/data_inputs_settings.dart';
import '../../shared/palette.dart';
import '../../services/health_service.dart';

class CreateUserFlow extends StatefulWidget {
  final UserState userState;
  final String? initialEmail;
  final String? initialName;

  const CreateUserFlow({
    super.key,
    required this.userState,
    this.initialEmail,
    this.initialName,
  });

  @override
  State<CreateUserFlow> createState() => _CreateUserFlowState();
}

class _CreateUserFlowState extends State<CreateUserFlow> {
  final PageController _pageController = PageController();
  final ExpansibleController _activityController = ExpansibleController();
  int _currentPage = 0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _weightController = TextEditingController(text: '180');
  final _heightFeetController = TextEditingController(text: '5');
  final _heightInchesController = TextEditingController(text: '10');
  final _goalWeightController = TextEditingController();
  final _calorieGoalController = TextEditingController(text: '2200');
  final _stepsGoalController = TextEditingController(text: '10000');

  DateTime _selectedDob = DateTime.now().subtract(
    const Duration(days: 365 * 28),
  );
  String? _selectedGender;
  String _selectedActivityLevel = 'Moderately Active';
  String _weightGoal = ''; // 'lose', 'gain', or 'maintain'
  String _dietType = 'Balanced';

  // Page 4 variables
  double _weeklyRate = 1.0; // lbs per week (0-5, increments of 0.5)

  // Page 5 variables (health permissions)
  bool _healthPermissionsRequested = false;
  bool _healthPermissionsGranted = false;

  // Page 6 variable (wearable device)
  String _selectedWearableFamily = 'unknown';

  @override
  void initState() {
    super.initState();
    // Prefill from the signed-in account so the local profile's email matches
    // the auth account (used to re-link the profile on subsequent launches).
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
    }
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _goalWeightController.dispose();
    _calorieGoalController.dispose();
    _stepsGoalController.dispose();
    super.dispose();
  }

  int _calculateAgeFromDob(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    final hasHadBirthday =
        (now.month > dob.month) ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hasHadBirthday) age--;
    return age;
  }

  double _genderOffsetForCalculation() {
    switch (_selectedGender) {
      case 'Male':
        return 5.0;
      case 'Female':
        return -161.0;
      default:
        // Neutral midpoint when gender is not selected or set to Other.
        return -78.0;
    }
  }

  String _formatDob(DateTime dob) {
    const months = [
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
    return '${months[dob.month - 1]} ${dob.day}, ${dob.year}';
  }

  Future<void> _showDobPicker() async {
    _dismissKeyboard();
    var tempDob = _selectedDob;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedDob = DateTime(
                            tempDob.year,
                            tempDob.month,
                            tempDob.day,
                          );
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDob,
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime.now().subtract(
                    const Duration(days: 365 * 120),
                  ),
                  onDateTimeChanged: (value) {
                    tempDob = value;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showWeightPicker() async {
    _dismissKeyboard();
    const minWeight = 80;
    const maxWeight = 450;
    var tempWeight = int.tryParse(_weightController.text) ?? 180;
    tempWeight = tempWeight.clamp(minWeight, maxWeight);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final ctrl = FixedExtentScrollController(
          initialItem: tempWeight - minWeight,
        );
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Text(
                      'Current Weight',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ctx.colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _weightController.text = tempWeight.toString();
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: ctrl,
                  itemExtent: 36,
                  magnification: 1.08,
                  useMagnifier: true,
                  onSelectedItemChanged: (i) => tempWeight = minWeight + i,
                  children: List.generate(
                    maxWeight - minWeight + 1,
                    (i) => Center(child: Text('${minWeight + i} lbs')),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showHeightPicker() async {
    _dismissKeyboard();
    var tempFeet = int.tryParse(_heightFeetController.text) ?? 5;
    var tempInches = int.tryParse(_heightInchesController.text) ?? 10;
    tempFeet = tempFeet.clamp(3, 8);
    tempInches = tempInches.clamp(0, 11);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final feetCtrl = FixedExtentScrollController(initialItem: tempFeet - 3);
        final inchesCtrl = FixedExtentScrollController(initialItem: tempInches);
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Text(
                      'Height',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ctx.colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _heightFeetController.text = tempFeet.toString();
                          _heightInchesController.text = tempInches.toString();
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: feetCtrl,
                        itemExtent: 36,
                        magnification: 1.08,
                        useMagnifier: true,
                        onSelectedItemChanged: (i) => tempFeet = 3 + i,
                        children: List.generate(
                          6,
                          (i) => Center(child: Text('${3 + i} ft')),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: inchesCtrl,
                        itemExtent: 36,
                        magnification: 1.08,
                        useMagnifier: true,
                        onSelectedItemChanged: (i) => tempInches = i,
                        children: List.generate(
                          12,
                          (i) => Center(child: Text('$i in')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showGoalWeightPicker() async {
    _dismissKeyboard();
    const minWeight = 80;
    const maxWeight = 450;
    var tempWeight = int.tryParse(_goalWeightController.text) ?? 175;
    tempWeight = tempWeight.clamp(minWeight, maxWeight);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final controller = FixedExtentScrollController(
          initialItem: tempWeight - minWeight,
        );

        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Text(
                      'Select Goal Weight',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _goalWeightController.text = tempWeight.toString();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: controller,
                  itemExtent: 36,
                  magnification: 1.08,
                  useMagnifier: true,
                  onSelectedItemChanged: (index) {
                    tempWeight = minWeight + index;
                  },
                  children: List.generate(
                    maxWeight - minWeight + 1,
                    (index) => Center(child: Text('${minWeight + index} lbs')),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isPageValid() {
    switch (_currentPage) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            _emailController.text.trim().isNotEmpty &&
            _selectedGender != null;
      case 1:
        // Weight and Height have default values in the pickers,
        // but we should ensure controllers aren't empty if the user cleared them
        return _weightController.text.isNotEmpty &&
            _heightFeetController.text.isNotEmpty &&
            _heightInchesController.text.isNotEmpty;
      case 2:
        return _weightGoal.isNotEmpty;
      case 3:
        return _goalWeightController.text.isNotEmpty &&
            _selectedActivityLevel.isNotEmpty;
      case 4:
        return _calorieGoalController.text.isNotEmpty &&
            _stepsGoalController.text.isNotEmpty;
      case 5:
        return true; // Health permissions page is optional
      case 6:
        return true; // Wearable picker is optional
      default:
        return true;
    }
  }

  void _nextPage() {
    _dismissKeyboard();
    if (!_isPageValid()) return;
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createUser();
    }
  }

  void _previousPage() {
    _dismissKeyboard();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Calculate daily deficit/surplus needed
  double _calculateDailyDeficit() {
    return _weeklyRate * 3500 / 7; // 1 lb = 3500 cal
  }

  // Calculate estimated weeks to goal
  int _calculateWeeksToGoal() {
    final currentWeight = double.tryParse(_weightController.text) ?? 180;
    final goalWeight = double.tryParse(_goalWeightController.text) ?? 170;
    final weightDifference = (currentWeight - goalWeight).abs();

    if (_weeklyRate == 0) return 0;
    return (weightDifference / _weeklyRate).ceil();
  }

  // Calculate baseline calorie goal
  int _calculateBaselineCalorie() {
    final weight = double.tryParse(_weightController.text) ?? 180;
    final feet = int.tryParse(_heightFeetController.text) ?? 5;
    final inches = int.tryParse(_heightInchesController.text) ?? 10;
    final age = _calculateAgeFromDob(_selectedDob);

    final totalHeightInInches = (feet * 12) + inches.toDouble();
    final weightInKg = weight * 0.453592;
    final heightInCm = totalHeightInInches * 2.54;

    final genderOffset = _genderOffsetForCalculation();
    final bmr =
        (10 * weightInKg) + (6.25 * heightInCm) - (5 * age) + genderOffset;

    // Activity multipliers
    final activityMultiplier = _getActivityMultiplier(_selectedActivityLevel);
    final tdee = bmr * activityMultiplier;

    // Apply deficit or surplus
    final dailyDeficit = _calculateDailyDeficit();
    final direction = _weightGoal == 'lose' ? -1 : 1;

    final calculated = (tdee + (direction * dailyDeficit)).toInt();

    // Ensure we never return a dangerous or impossible calorie goal.
    // 1200 is generally considered the absolute floor for safe weight loss.
    return calculated.clamp(1200, 10000);
  }

  int _resolveCalorieGoal() {
    final parsed = int.tryParse(_calorieGoalController.text.trim());
    if (parsed != null && parsed > 0) return parsed;
    return _calculateBaselineCalorie();
  }

  Map<String, int> _calculateMacroTargets(int calories, String dietType) {
    double proteinPct;
    double carbsPct;
    double fatPct;

    switch (dietType) {
      case 'High Protein':
        proteinPct = 0.40;
        carbsPct = 0.35;
        fatPct = 0.25;
        break;
      case 'Low Carb':
        proteinPct = 0.35;
        carbsPct = 0.25;
        fatPct = 0.40;
        break;
      case 'Low Fat':
        proteinPct = 0.30;
        carbsPct = 0.50;
        fatPct = 0.20;
        break;
      case 'Mediterranean':
        proteinPct = 0.18;
        carbsPct = 0.50;
        fatPct = 0.32;
        break;
      case 'Ketogenic':
        proteinPct = 0.25;
        carbsPct = 0.05;
        fatPct = 0.70;
        break;
      case 'Plant-Based':
        proteinPct = 0.20;
        carbsPct = 0.55;
        fatPct = 0.25;
        break;
      case 'Balanced':
      default:
        proteinPct = 0.30;
        carbsPct = 0.40;
        fatPct = 0.30;
        break;
    }

    final proteinCalories = calories * proteinPct;
    final carbsCalories = calories * carbsPct;
    final fatCalories = calories * fatPct;

    final proteinG = (proteinCalories / 4).round();
    final carbsG = (carbsCalories / 4).round();
    final fatG = (fatCalories / 9).round();

    return {'protein': proteinG, 'carbs': carbsG, 'fat': fatG};
  }

  double _getActivityMultiplier(String activity) {
    switch (activity) {
      case 'Sedentary':
        return 1.2;
      case 'Lightly Active':
        return 1.375;
      case 'Moderately Active':
        return 1.55;
      case 'Very Active':
        return 1.725;
      default:
        return 1.55;
    }
  }

  void _createUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) return;
    if (_weightGoal.isEmpty) return;
    if (_selectedGender == null) return;

    // Capture platform before any async gap (used after awaits below).
    final platform = Theme.of(context).platform;

    try {
      // Guard: if this email already exists, log in instead of failing with UNIQUE constraint
      final existingUser = await widget.userState.db.getUserProfileByEmail(
        _emailController.text.trim(),
      );
      if (existingUser != null) {
        await widget.userState.loginUser(existingUser.id!);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      // Convert feet and inches to total inches
      final feet = int.tryParse(_heightFeetController.text) ?? 5;
      final inches = int.tryParse(_heightInchesController.text) ?? 10;
      final totalHeightInInches = (feet * 12) + inches.toDouble();

      // Get weight and age
      final weight = double.tryParse(_weightController.text) ?? 180;
      final age = _calculateAgeFromDob(_selectedDob);

      // Calculate BMR using Mifflin-St Jeor equation
      // Convert weight (lbs) to kg and height (inches) to cm
      final weightInKg = weight * 0.453592;
      final heightInCm = totalHeightInInches * 2.54;

      // BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age) + s
      // where s = +5 for males and -161 for females
      final genderOffset = _genderOffsetForCalculation();
      final bmr =
          (10 * weightInKg) + (6.25 * heightInCm) - (5 * age) + genderOffset;

      await widget.userState.createUser(
        name: _nameController.text,
        email: _emailController.text,
        weight: weight,
        height: totalHeightInInches,
        age: age,
        gender: _selectedGender!,
        dateOfBirth: _selectedDob,
        bmr: bmr,
        goalWeight: double.tryParse(_goalWeightController.text) ?? 175,
        dailyCaloricGoal: _resolveCalorieGoal(),
        activityLevel: _selectedActivityLevel,
        dailyStepsGoal: int.tryParse(_stepsGoalController.text) ?? 10000,
        macroTargets: _calculateMacroTargets(_resolveCalorieGoal(), _dietType),
      );
      // Save wearable device choice
      try {
        final user = widget.userState.currentUser;
        if (user != null) {
          final settings = DataInputsSettings.defaults(user.id!).copyWith(
            appleHealthConnected:
                _healthPermissionsGranted && platform == TargetPlatform.iOS,
            googleFitConnected:
                _healthPermissionsGranted && platform == TargetPlatform.android,
            wearableFamily: _selectedWearableFamily,
          );
          await widget.userState.db.createOrUpdateDataInputsSettings(settings);
        }
      } catch (_) {}
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {}
  }

  Widget _buildProgressBar() {
    return Container(
      color: context.colors.background,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 6,
          color: context.colors.surfaceVariant,
          child: Row(
            children: List.generate(7, (index) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  color: index <= _currentPage
                      ? context.colors.accent
                      : context.colors.surfaceVariant.withValues(alpha: 0),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: context.colors.background,
        boxShadow: [
          BoxShadow(
            color: context.colors.textMuted.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: context.colors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isPageValid()
                    ? context.colors.accent
                    : context.colors.surfaceVariant,
                foregroundColor: context.colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(_currentPage < 6 ? 'Next' : 'Create Account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.textMuted,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildPage1() {
    final colors = context.colors;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Text(
            'About You',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This helps us build your personal metabolic plan.',
            style: TextStyle(
              fontSize: 15,
              color: colors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // ── Full Name ─────────────────────────────────────────────
          _buildFieldLabel('Full Name'),
          const SizedBox(height: 8),
          _OnboardingTextField(
            controller: _nameController,
            hint: 'Your full name',
            keyboardType: TextInputType.name,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // ── Email ─────────────────────────────────────────────────
          _buildFieldLabel('Email Address'),
          const SizedBox(height: 8),
          _OnboardingTextField(
            controller: _emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // ── Date of Birth ─────────────────────────────────────────
          _buildFieldLabel('Date of Birth'),
          const SizedBox(height: 8),
          _OnboardingTapField(
            value:
                '${_formatDob(_selectedDob)}  ·  ${_calculateAgeFromDob(_selectedDob)} yrs old',
            icon: Icons.calendar_today_outlined,
            onTap: _showDobPicker,
          ),
          const SizedBox(height: 20),

          // ── Gender ───────────────────────────────────────────────
          _buildFieldLabel('Gender'),
          const SizedBox(height: 10),
          Row(
            children: ['Male', 'Female', 'Other'].asMap().entries.map((e) {
              final g = e.value;
              final isLast = e.key == 2;
              final selected = _selectedGender == g;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(right: isLast ? 0 : 10),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: selected ? colors.accent : colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? colors.accent : colors.divider,
                        width: selected ? 0 : 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        g,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? colors.onPrimary
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    final colors = context.colors;
    final weight = _weightController.text.isEmpty
        ? '\u2014'
        : _weightController.text;
    final feet = _heightFeetController.text.isEmpty
        ? '\u2014'
        : _heightFeetController.text;
    final inches = _heightInchesController.text.isEmpty
        ? '\u2014'
        : _heightInchesController.text;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Text(
            'Physical Stats',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Used to calculate your metabolic rate accurately.',
            style: TextStyle(
              fontSize: 15,
              color: colors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // ── Weight ────────────────────────────────────────────────
          _buildFieldLabel('Current Weight'),
          const SizedBox(height: 10),
          _StatInputCard(value: weight, unit: 'lbs', onTap: _showWeightPicker),
          const SizedBox(height: 20),

          // ── Height ────────────────────────────────────────────────
          _buildFieldLabel('Height'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showHeightPicker,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                children: [
                  // Feet column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FEET',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              feet,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: feet == '\u2014'
                                    ? colors.textMuted
                                    : colors.textPrimary,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'ft',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(height: 52, width: 1, color: colors.divider),
                  // Inches column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INCHES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                inches,
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: inches == '\u2014'
                                      ? colors.textMuted
                                      : colors.textPrimary,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'in',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textMuted, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Info note ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.accent, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'BMR is auto-calculated using the Mifflin-St\u202fJeor equation based on your stats.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weight Goal',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'What\'s your goal?',
            style: TextStyle(fontSize: 16, color: context.colors.textMuted),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.background.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.colors.divider),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: context.colors.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Choose the path that matches your current focus. You can adjust calories and macros afterward.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildGoalBox(
            label: 'Lose Weight',
            description:
                'Create a calorie deficit and trend downward steadily.',
            icon: Icons.trending_down,
            isSelected: _weightGoal == 'lose',
            onTap: () => setState(() => _weightGoal = 'lose'),
          ),
          const SizedBox(height: 16),
          _buildGoalBox(
            label: 'Maintain Weight',
            description: 'Hold your current weight while dialing in habits.',
            icon: Icons.balance,
            isSelected: _weightGoal == 'maintain',
            onTap: () => setState(() => _weightGoal = 'maintain'),
          ),
          const SizedBox(height: 16),
          _buildGoalBox(
            label: 'Gain Weight',
            description:
                'Add calories gradually to support muscle or mass gain.',
            icon: Icons.trending_up,
            isSelected: _weightGoal == 'gain',
            onTap: () => setState(() => _weightGoal = 'gain'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildGoalBox({
    required String label,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final selectedColor = context.colors.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedColor : context.colors.surfaceVariant,
            width: isSelected ? 2.4 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? selectedColor
                      : context.colors.surfaceVariant,
                ),
              ),
              child: Icon(icon, size: 34, color: selectedColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? selectedColor
                          : context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: context.colors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? selectedColor
                      : context.colors.surfaceVariant,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 18, color: selectedColor)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage4() {
    final dailyDeficit = _calculateDailyDeficit();
    final weeksToGoal = _calculateWeeksToGoal();
    final baselineCalorie = _calculateBaselineCalorie();
    final isAggressive = _weeklyRate > 2.0;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Goals',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Set your target and pace',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.background.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.colors.divider),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.track_changes_outlined,
                  color: context.colors.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _weightGoal == 'maintain'
                        ? 'We’ll set a steady maintenance target based on your current stats and activity level.'
                        : 'Pick a realistic target and pace. You can always refine these later from Macro Strategy.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildOnboardingSection(
            title: 'Target Weight',
            child: GestureDetector(
              onTap: _showGoalWeightPicker,
              child: AbsorbPointer(
                child: TextField(
                  controller: _goalWeightController,
                  decoration: const InputDecoration(
                    suffixText: 'lbs',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildOnboardingSection(
            title: 'Pace',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly ${_weightGoal == 'maintain' ? 'Target' : (_weightGoal == 'lose' ? 'Loss' : 'Gain')} Rate',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (_weightGoal == 'maintain')
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Maintain Current Weight',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your calorie target will balance with your activity',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Slider(
                        value: _weeklyRate,
                        min: 0,
                        max: 5,
                        divisions: 10, // 0.5 increments
                        label: '${_weeklyRate.toStringAsFixed(1)} lbs/week',
                        onChanged: (val) => setState(() => _weeklyRate = val),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_weeklyRate.toStringAsFixed(1)} lbs per week',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isAggressive)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.colors.cta.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.colors.cta.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Palette.nightAccentBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'We do not recommend rates above 2 lbs/week as this is very aggressive and may lead to health complications.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Palette.nightTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_weightGoal != 'maintain')
            Row(
              children: [
                Expanded(
                  child: _GoalSummaryCard(
                    title: _weightGoal == 'lose'
                        ? 'Daily Deficit'
                        : 'Daily Surplus',
                    value: '${dailyDeficit.toStringAsFixed(0)} cal',
                    accentColor: context.colors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GoalSummaryCard(
                    title: 'Timeline',
                    value: '~$weeksToGoal wks',
                    accentColor: context.colors.accent,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          _buildOnboardingSection(
            title: 'Activity Level',
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: context.colors.divider.withValues(alpha: 0),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.divider),
                ),
                child: ExpansionTile(
                  controller: _activityController,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  collapsedShape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  title: Text(
                    _selectedActivityLevel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        children: [
                          _buildActivityLevelOption(
                            'Sedentary',
                            '0–1 workouts/week or under 5k steps/day',
                          ),
                          const SizedBox(height: 8),
                          _buildActivityLevelOption(
                            'Lightly Active',
                            '1–2 workouts/week or 5k–8k steps/day',
                          ),
                          const SizedBox(height: 8),
                          _buildActivityLevelOption(
                            'Moderately Active',
                            '3–4 workouts/week or 8k–12k steps/day',
                          ),
                          const SizedBox(height: 8),
                          _buildActivityLevelOption(
                            'Very Active',
                            '5–6 workouts/week or 12k+ steps/day',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.colors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.accent.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_fire_department_outlined,
                        color: context.colors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Baseline Daily Calories',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$baselineCalorie calories',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: context.colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Based on your ${_selectedActivityLevel.toLowerCase()} activity level. Your daily target can still adjust later using HealthKit activity and macro strategy settings.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelOption(String title, String subtitle) {
    final bool isSelected = _selectedActivityLevel == title;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedActivityLevel = title);
        _activityController.collapse();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.background.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.colors.accent
                : context.colors.surfaceVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected
                          ? context.colors.accent
                          : context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? context.colors.accent.withValues(alpha: 0.8)
                          : context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: context.colors.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPage5() {
    final colors = context.colors;
    final baselineCalorie = _calculateBaselineCalorie();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_calorieGoalController.text != baselineCalorie.toString()) {
        setState(
          () => _calorieGoalController.text = baselineCalorie.toString(),
        );
      }
    });

    final calorieGoal = _resolveCalorieGoal();
    final macros = _calculateMacroTargets(calorieGoal, _dietType);

    const diets = [
      _DietOption(
        'Balanced',
        'Flexible, adaptable & sustainable',
        Icons.balance,
        30,
        40,
        30,
      ),
      _DietOption(
        'High Protein',
        'Maximize muscle retention & satiety',
        Icons.fitness_center_rounded,
        40,
        35,
        25,
      ),
      _DietOption(
        'Mediterranean',
        'Heart-healthy, anti-inflammatory',
        Icons.spa_outlined,
        18,
        50,
        32,
      ),
      _DietOption(
        'Ketogenic',
        'Very low-carb, fat adaptation',
        Icons.local_fire_department_rounded,
        25,
        5,
        70,
      ),
      _DietOption(
        'Low Carb',
        'Steady energy, reduced insulin spikes',
        Icons.trending_down_rounded,
        35,
        25,
        40,
      ),
      _DietOption(
        'Plant-Based',
        'Whole foods, fiber-rich, gut health',
        Icons.eco_rounded,
        20,
        55,
        25,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Text(
            'Calorie & Macros',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We estimated your daily target. Pick a diet style to match.',
            style: TextStyle(
              fontSize: 15,
              color: colors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // ── Calorie target card (tap to edit) ───────────────────────
          GestureDetector(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: colors.surface,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Calorie Target',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _OnboardingTextField(
                      controller: _calorieGoalController,
                      hint: baselineCalorie.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: colors.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILY TARGET',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$calorieGoal kcal',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: colors.accent,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(Icons.edit_outlined, size: 15, color: colors.accent),
                      const SizedBox(height: 2),
                      Text(
                        'tap to edit',
                        style: TextStyle(fontSize: 10, color: colors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Diet style ──────────────────────────────────────────────
          _buildFieldLabel('Diet Style'),
          const SizedBox(height: 12),
          for (int i = 0; i < diets.length; i += 2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildDietCard(diets[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < diets.length
                      ? _buildDietCard(diets[i + 1])
                      : const SizedBox(),
                ),
              ],
            ),
            if (i + 2 < diets.length) const SizedBox(height: 12),
          ],
          const SizedBox(height: 24),

          // ── Macro summary ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Estimated Macros',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _dietType,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MacroSummaryTile(
                        label: 'Protein',
                        grams: macros['protein'] ?? 0,
                        color: Palette.macroProtein,
                      ),
                    ),
                    Expanded(
                      child: _MacroSummaryTile(
                        label: 'Carbs',
                        grams: macros['carbs'] ?? 0,
                        color: Palette.macroCarbs,
                      ),
                    ),
                    Expanded(
                      child: _MacroSummaryTile(
                        label: 'Fat',
                        grams: macros['fat'] ?? 0,
                        color: Palette.macroFat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        Flexible(
                          flex: macros['protein'] ?? 1,
                          child: Container(color: Palette.macroProtein),
                        ),
                        Flexible(
                          flex: macros['carbs'] ?? 1,
                          child: Container(color: Palette.macroCarbs),
                        ),
                        Flexible(
                          flex: macros['fat'] ?? 1,
                          child: Container(color: Palette.macroFat),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on $calorieGoal cal/day',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietCard(_DietOption diet) {
    final colors = context.colors;
    final isSelected = _dietType == diet.id;

    return GestureDetector(
      onTap: () => setState(() => _dietType = diet.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  diet.icon,
                  size: 16,
                  color: isSelected ? colors.accent : colors.textMuted,
                ),
                const Spacer(),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: colors.accent,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              diet.id,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? colors.accent : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              diet.subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: colors.textMuted,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 3,
                child: Row(
                  children: [
                    Expanded(
                      flex: diet.protein,
                      child: Container(color: Palette.macroProtein),
                    ),
                    Expanded(
                      flex: diet.carbs,
                      child: Container(color: Palette.macroCarbs),
                    ),
                    Expanded(
                      flex: diet.fat,
                      child: Container(color: Palette.macroFat),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'P ${diet.protein}%  C ${diet.carbs}%  F ${diet.fat}%',
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? colors.accent.withValues(alpha: 0.8)
                    : colors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage7() {
    final colors = context.colors;

    const devices = [
      _WearableOption(
        'Apple Watch',
        'appleWatch',
        Icons.watch_rounded,
        Color(0xFF1C1C1E),
        0.82,
      ),
      _WearableOption(
        'Garmin',
        'garmin',
        Icons.gps_fixed_rounded,
        Color(0xFF006DC6),
        0.86,
      ),
      _WearableOption(
        'Fitbit / Sense',
        'fitbit',
        Icons.monitor_heart_rounded,
        Color(0xFF00B0B9),
        0.75,
      ),
      _WearableOption(
        'WHOOP',
        'whoop',
        Icons.bolt_rounded,
        Color(0xFF1A1A2E),
        0.78,
      ),
      _WearableOption(
        'Samsung Galaxy Watch',
        'samsungGalaxyWatch',
        Icons.watch_outlined,
        Color(0xFF1428A0),
        0.76,
      ),
      _WearableOption(
        'Polar',
        'polar',
        Icons.favorite_rounded,
        Color(0xFFD0021B),
        0.84,
      ),
      _WearableOption(
        'Oura Ring',
        'oura',
        Icons.circle_outlined,
        Color(0xFF2D2D2D),
        0.70,
      ),
      _WearableOption(
        'Pixel Watch',
        'pixelWatch',
        Icons.watch_rounded,
        Color(0xFF4285F4),
        0.76,
      ),
      _WearableOption(
        'None / Not sure',
        'unknown',
        Icons.device_unknown_rounded,
        null,
        0.75,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Wearable',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'MetaDash adjusts calorie accuracy based on your device. Every wearable overcounts — we correct for it.',
            style: TextStyle(
              fontSize: 15,
              color: colors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.divider),
            ),
            child: Column(
              children: devices.asMap().entries.map((e) {
                final isLast = e.key == devices.length - 1;
                final d = e.value;
                final isSelected = _selectedWearableFamily == d.familyKey;
                final deviceColor = d.color ?? colors.textMuted;

                return Column(
                  children: [
                    InkWell(
                      onTap: () =>
                          setState(() => _selectedWearableFamily = d.familyKey),
                      borderRadius: isLast
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(18),
                            )
                          : BorderRadius.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: deviceColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(d.icon, size: 18, color: deviceColor),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                d.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? colors.accent
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? colors.accent
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? colors.accent
                                      : colors.divider,
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 68,
                        endIndent: 16,
                        color: colors.divider,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You can always change this in Settings → Wearables.',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _requestHealthPermissions() async {
    try {
      setState(() => _healthPermissionsRequested = true);

      final granted = await HealthService().requestPermissions();

      if (mounted) {
        setState(() => _healthPermissionsGranted = granted);
      }

      // Persist the connection + default device family so the calibration
      // engine has a non-unknown multiplier from the very first sync.
      if (granted && mounted) {
        try {
          final userState = context.read<UserState>();
          final user = userState.currentUser;
          final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
          if (user != null) {
            final existing =
                await userState.db.getDataInputsSettings(user.id!) ??
                DataInputsSettings.defaults(user.id!);
            // Default to Apple Watch on iOS (most common), unknown on Android
            final defaultFamily = isIOS ? 'appleWatch' : 'unknown';
            final updated = existing.copyWith(
              appleHealthConnected: isIOS
                  ? true
                  : existing.appleHealthConnected,
              googleFitConnected: isIOS ? existing.googleFitConnected : true,
              // Only set if the user hasn't already chosen a device
              wearableFamily: existing.wearableFamily == 'unknown'
                  ? defaultFamily
                  : existing.wearableFamily,
            );
            await userState.db.createOrUpdateDataInputsSettings(updated);
          }
        } catch (_) {}
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error requesting health permissions: $e');
      if (mounted) {
        setState(() => _healthPermissionsGranted = false);
      }
    }
  }

  Widget _buildPage6() {
    final colors = context.colors;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Apple Health icon ───────────────────────────────────────
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF3B30),
                size: 54,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Health',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 36),

          // ── Copy ─────────────────────────────────────────────────
          Text(
            'Allow Access to Health',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isIOS
                ? 'Connect with Apple Health to automatically sync your steps, workouts, weight, sleep, and heart rate — so MetaDash can calculate your most accurate TDEE.'
                : 'Connect with Google Health to automatically sync your activity data — powering your personalized metabolic estimate.',
            style: TextStyle(
              fontSize: 15,
              color: colors.textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),

          // ── CTA / status ───────────────────────────────────────────
          if (!_healthPermissionsRequested) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestHealthPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isIOS
                      ? 'Connect to Apple Health'
                      : 'Connect to Google Health',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else if (_healthPermissionsGranted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF34C759).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF34C759),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isIOS
                              ? 'Apple Health Connected'
                              : 'Google Health Connected',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF34C759),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Health data will sync automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors.textMuted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Permission not granted. Enable it in Settings → Privacy & Security → Health.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _requestHealthPermissions,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF34C759),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF34C759)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: Text(
              'You can connect this later in Settings.',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: context.colors.background.withValues(alpha: 0),
        backgroundColor: context.colors.background,
        foregroundColor: context.colors.textPrimary,
        title: Text(
          'Step ${_currentPage + 1} of 7',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.colors.textMuted,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildPage4(),
                  _buildPage5(),
                  _buildPage6(),
                  _buildPage7(),
                ],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }
}

// ── Premium onboarding input widgets ─────────────────────────────────────────

class _OnboardingTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _OnboardingTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(fontSize: 16, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textMuted),
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
      ),
    );
  }
}

class _OnboardingTapField extends StatelessWidget {
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _OnboardingTapField({
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: TextStyle(fontSize: 16, color: colors.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _StatInputCard extends StatelessWidget {
  final String value;
  final String unit;
  final VoidCallback onTap;

  const _StatInputCard({
    required this.value,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEmpty = value == '—';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: isEmpty ? colors.textMuted : colors.textPrimary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 18,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Icon(Icons.edit_outlined, size: 18, color: colors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;

  const _GoalSummaryCard({
    required this.title,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Diet option data ─────────────────────────────────────────────────────────

class _DietOption {
  final String id;
  final String subtitle;
  final IconData icon;
  final int protein; // percentage
  final int carbs;
  final int fat;

  const _DietOption(
    this.id,
    this.subtitle,
    this.icon,
    this.protein,
    this.carbs,
    this.fat,
  );
}

// ── Macro summary tile ───────────────────────────────────────────────────────

class _MacroSummaryTile extends StatelessWidget {
  final String label;
  final int grams;
  final Color color;

  const _MacroSummaryTile({
    required this.label,
    required this.grams,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(
          '$grams g',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.colors.textMuted),
        ),
      ],
    );
  }
}

class _WearableOption {
  final String name;
  final String familyKey;
  final IconData icon;
  final Color? color;
  final double multiplier;
  const _WearableOption(
    this.name,
    this.familyKey,
    this.icon,
    this.color,
    this.multiplier,
  );
}
