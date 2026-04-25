import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../providers/user_state.dart';
import '../../shared/palette.dart';
import '../../services/health_service.dart';

class CreateUserFlow extends StatefulWidget {
  final UserState userState;

  const CreateUserFlow({super.key, required this.userState});

  @override
  State<CreateUserFlow> createState() => _CreateUserFlowState();
}

const _genderDropdownItems = [
  DropdownMenuItem(value: 'Male', child: Text('Male')),
  DropdownMenuItem(value: 'Female', child: Text('Female')),
  DropdownMenuItem(value: 'Other', child: Text('Other')),
];

class _CreateUserFlowState extends State<CreateUserFlow> {
  final PageController _pageController = PageController();
  final ExpansionTileController _activityController = ExpansionTileController();
  int _currentPage = 0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
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
      backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
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
                    const Text(
                      'Select Weight',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _weightController.text = tempWeight.toString();
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

  Future<void> _showGoalWeightPicker() async {
    _dismissKeyboard();
    const minWeight = 80;
    const maxWeight = 450;
    var tempWeight = int.tryParse(_goalWeightController.text) ?? 175;
    tempWeight = tempWeight.clamp(minWeight, maxWeight);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
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
                    const Text(
                      'Select Goal Weight',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
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

  Future<void> _showHeightPicker() async {
    _dismissKeyboard();
    const minFeet = 3;
    const maxFeet = 8;
    const minInches = 0;
    const maxInches = 11;

    var tempFeet = int.tryParse(_heightFeetController.text) ?? 5;
    var tempInches = int.tryParse(_heightInchesController.text) ?? 10;
    tempFeet = tempFeet.clamp(minFeet, maxFeet);
    tempInches = tempInches.clamp(minInches, maxInches);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final feetController = FixedExtentScrollController(
          initialItem: tempFeet - minFeet,
        );
        final inchController = FixedExtentScrollController(
          initialItem: tempInches,
        );

        return SizedBox(
          height: 340,
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
                          _heightFeetController.text = tempFeet.toString();
                          _heightInchesController.text = tempInches.toString();
                        });
                        Navigator.pop(context);
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
                        scrollController: feetController,
                        itemExtent: 36,
                        magnification: 1.08,
                        useMagnifier: true,
                        onSelectedItemChanged: (index) {
                          tempFeet = minFeet + index;
                        },
                        children: List.generate(
                          maxFeet - minFeet + 1,
                          (index) =>
                              Center(child: Text('${minFeet + index} ft')),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: inchController,
                        itemExtent: 36,
                        magnification: 1.08,
                        useMagnifier: true,
                        onSelectedItemChanged: (index) {
                          tempInches = index;
                        },
                        children: List.generate(
                          maxInches - minInches + 1,
                          (index) => Center(child: Text('$index in')),
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
      default:
        return true;
    }
  }

  void _nextPage() {
    _dismissKeyboard();
    if (!_isPageValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required information'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_currentPage < 5) {
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
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_weightGoal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a weight goal')),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a gender')));
      return;
    }

    try {
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
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating user: $e')));
      }
    }
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 6,
          color: Colors.grey[200],
          child: Row(
            children: List.generate(6, (index) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  color: index <= _currentPage
                      ? Palette.forestGreen
                      : Colors.transparent,
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
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                  foregroundColor: Palette.forestGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[350]!),
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
                    ? Palette.forestGreen
                    : Colors.grey[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(_currentPage < 5 ? 'Next' : 'Create Account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s start with the basics',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'John Doe',
              labelText: 'Full Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'john@example.com',
              labelText: 'Email *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            readOnly: true,
            onTap: _showDobPicker,
            decoration: InputDecoration(
              labelText: 'Date of Birth',
              border: const OutlineInputBorder(),
              hintText:
                  '${_formatDob(_selectedDob)} (${_calculateAgeFromDob(_selectedDob)} yrs)',
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Select gender'),
            items: _genderDropdownItems,
            onChanged: (val) => setState(() => _selectedGender = val),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Physical Stats',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your current state',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          TextField(
            readOnly: true,
            onTap: _showWeightPicker,
            decoration: InputDecoration(
              hintText: '${int.tryParse(_weightController.text) ?? 180} lbs',
              labelText: 'Current Weight (lbs)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            readOnly: true,
            onTap: _showHeightPicker,
            decoration: InputDecoration(
              labelText: 'Height',
              hintText:
                  '${int.tryParse(_heightFeetController.text) ?? 5} ft ${int.tryParse(_heightInchesController.text) ?? 10} in',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Palette.forestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Palette.forestGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Palette.forestGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'BMR will be calculated automatically using the Mifflin-St Jeor equation',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Choose the path that matches your current focus. You can adjust calories and macros afterward.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey[700],
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
    const selectedColor = Palette.forestGreen;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey[300]!,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? selectedColor : Colors.grey[300]!,
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
                      color: isSelected ? selectedColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey[700],
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
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? selectedColor : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 18, color: selectedColor)
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
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.track_changes_outlined, color: Palette.forestGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _weightGoal == 'maintain'
                        ? 'We’ll set a steady maintenance target based on your current stats and activity level.'
                        : 'Pick a realistic target and pace. You can always refine these later from Macro Strategy.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey[700],
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
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Maintain Current Weight',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your calorie target will balance with your activity',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
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
                            color: const Color(0xFFFFEAEE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFFE74C3C,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Color(0xFFE74C3C),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'We do not recommend rates above 2 lbs/week as this is very aggressive and may lead to health complications.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[900],
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
                    accentColor: Palette.forestGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GoalSummaryCard(
                    title: 'Timeline',
                    value: '~$weeksToGoal wks',
                    accentColor: const Color(0xFF3498DB),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          _buildOnboardingSection(
            title: 'Activity Level',
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF3498DB).withValues(alpha: 0.22),
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
                        color: const Color(0xFF3498DB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_outlined,
                        color: Color(0xFF3498DB),
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
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$baselineCalorie calories',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3498DB),
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
                    color: Colors.grey[700],
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Palette.vibrantAction : Colors.grey[300]!,
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Palette.vibrantAction : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Palette.vibrantAction.withValues(alpha: 0.8) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Palette.vibrantAction,
                size: 20,
              ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
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
    final baselineCalorie = _calculateBaselineCalorie();
    
    // Always sync the calorie goal if it hasn't been manually adjusted or if we want to default to baseline
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_calorieGoalController.text != baselineCalorie.toString()) {
        setState(() {
          _calorieGoalController.text = baselineCalorie.toString();
        });
      }
    });

    final calorieGoal = _resolveCalorieGoal();
    final macros = _calculateMacroTargets(calorieGoal, _dietType);

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Calorie & Macro Goals',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a diet style and review your recommended targets.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _calorieGoalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Daily Calorie Goal',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const Text(
            'Diet Preference',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['Balanced', 'High Protein', 'Low Carb', 'Low Fat'].map((
              option,
            ) {
              final selected = option == _dietType;
              return ChoiceChip(
                label: Text(option),
                selected: selected,
                onSelected: (_) => setState(() => _dietType = option),
                selectedColor: Palette.forestGreen.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected ? Palette.forestGreen : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selected
                        ? Palette.forestGreen
                        : Colors.grey.shade300,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Palette.lightStone,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommended Macro Targets',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MacroTargetTile(
                      label: 'Protein',
                      value: '${macros['protein']} g',
                    ),
                    _MacroTargetTile(
                      label: 'Carbs',
                      value: '${macros['carbs']} g',
                    ),
                    _MacroTargetTile(label: 'Fat', value: '${macros['fat']} g'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on $calorieGoal calories/day.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
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
    } catch (e) {
      // ignore: avoid_print
      print('Error requesting health permissions: $e');
      if (mounted) {
        setState(() => _healthPermissionsGranted = false);
      }
    }
  }

  Widget _buildPage6() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Health Data Access',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect HealthKit to track your activity',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),

          // Health icon
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Palette.forestGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.favorite,
                  size: 60,
                  color: Palette.forestGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue, width: 1),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MetaDash needs access to:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 12),
                Text('• Steps & Distance'),
                Text('• Active Energy (Calories)'),
                Text('• Workout Data'),
                SizedBox(height: 12),
                Text(
                  'This data is used to calculate your daily TDEE and adjust your calorie goal.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Permission button
          if (!_healthPermissionsRequested)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestHealthPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.forestGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Grant Health Access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_healthPermissionsGranted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Access Granted!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Your health data will sync automatically',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Access Denied',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'You can enable this later in Health app settings',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Skip button for denied
          if (_healthPermissionsRequested && !_healthPermissionsGranted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _requestHealthPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.forestGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.lightStone,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Palette.forestGreen,
        foregroundColor: Colors.white,
        title: const Text('Create Account'),
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
            // Progress indicator
            _buildProgressBar(),
            // Page content
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
                ],
              ),
            ),
            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }
}

class _MacroTargetTile extends StatelessWidget {
  final String label;
  final String value;

  const _MacroTargetTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Palette.forestGreen,
          ),
        ),
      ],
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
              color: Colors.grey[700],
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
