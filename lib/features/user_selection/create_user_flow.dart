import 'package:flutter/material.dart';
import '../../providers/user_state.dart';
import '../../shared/palette.dart';

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

const _activityLevelItems = [
  DropdownMenuItem(value: 'Sedentary', child: Text('Sedentary')),
  DropdownMenuItem(value: 'Lightly Active', child: Text('Lightly Active')),
  DropdownMenuItem(value: 'Moderately Active', child: Text('Moderately Active')),
  DropdownMenuItem(value: 'Very Active', child: Text('Very Active')),
];

class _CreateUserFlowState extends State<CreateUserFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _ageController = TextEditingController();
  final _goalWeightController = TextEditingController();
  final _calorieGoalController = TextEditingController(text: '2200');
  final _stepsGoalController = TextEditingController(text: '10000');

  final DateTime _selectedDob = DateTime.now();
  String _selectedGender = 'Male';
  String _selectedActivityLevel = 'Moderately Active';
  String _weightGoal = ''; // 'lose', 'gain', or 'maintain'
  
  // Page 4 variables
  double _weeklyRate = 1.0; // lbs per week (0-5, increments of 0.5)

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _ageController.dispose();
    _goalWeightController.dispose();
    _calorieGoalController.dispose();
    _stepsGoalController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createUser();
    }
  }

  void _previousPage() {
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
    final age = int.tryParse(_ageController.text) ?? 28;
    
    final totalHeightInInches = (feet * 12) + inches.toDouble();
    final weightInKg = weight * 0.453592;
    final heightInCm = totalHeightInInches * 2.54;
    
    final genderOffset = _selectedGender == 'Male' ? 5.0 : -161.0;
    final bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * age) + genderOffset;
    
    // Activity multipliers
    final activityMultiplier = _getActivityMultiplier(_selectedActivityLevel);
    final tdee = bmr * activityMultiplier;
    
    // Apply deficit or surplus
    final dailyDeficit = _calculateDailyDeficit();
    final direction = _weightGoal == 'lose' ? -1 : 1;
    
    return (tdee + (direction * dailyDeficit)).toInt();
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

    try {
      // Convert feet and inches to total inches
      final feet = int.tryParse(_heightFeetController.text) ?? 5;
      final inches = int.tryParse(_heightInchesController.text) ?? 10;
      final totalHeightInInches = (feet * 12) + inches.toDouble();

      // Get weight and age
      final weight = double.tryParse(_weightController.text) ?? 180;
      final age = int.tryParse(_ageController.text) ?? 28;

      // Calculate BMR using Mifflin-St Jeor equation
      // Convert weight (lbs) to kg and height (inches) to cm
      final weightInKg = weight * 0.453592;
      final heightInCm = totalHeightInInches * 2.54;

      // BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age) + s
      // where s = +5 for males and -161 for females
      final genderOffset = _selectedGender == 'Male' ? 5.0 : -161.0;
      final bmr = (10 * weightInKg) + (6.25 * heightInCm) - (5 * age) + genderOffset;

      await widget.userState.createUser(
        name: _nameController.text,
        email: _emailController.text,
        weight: weight,
        height: totalHeightInInches,
        age: age,
        gender: _selectedGender,
        dateOfBirth: _selectedDob,
        bmr: bmr,
        goalWeight: double.tryParse(_goalWeightController.text) ?? 175,
        dailyCaloricGoal: int.tryParse(_calorieGoalController.text) ?? 2200,
        activityLevel: _selectedActivityLevel,
        dailyStepsGoal: int.tryParse(_stepsGoalController.text) ?? 10000,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating user: $e')),
        );
      }
    }
  }

  Widget _buildProgressBar() {
    return Container(
      height: 6,
      color: Colors.grey[200],
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: Container(
              color: index <= _currentPage ? Palette.forestGreen : Colors.transparent,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_currentPage < 4 ? 'Next' : 'Create Account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
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
            decoration: const InputDecoration(
              hintText: 'John Doe',
              labelText: 'Full Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              hintText: 'john@example.com',
              labelText: 'Email *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '28',
              labelText: 'Age',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            items: _genderDropdownItems,
            onChanged: (val) => setState(() => _selectedGender = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return SingleChildScrollView(
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
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '180',
              labelText: 'Current Weight (lbs)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Height',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightFeetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '5',
                    labelText: 'Feet',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _heightInchesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '10',
                    labelText: 'Inches',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Palette.forestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Palette.forestGreen.withValues(alpha: 0.3)),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Weight Goal',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'What\'s your goal?',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 50),
          // Lose Weight Box
          _buildGoalBox(
            label: 'Lose Weight',
            icon: Icons.trending_down,
            iconColor: const Color(0xFFE74C3C),
            isSelected: _weightGoal == 'lose',
            onTap: () => setState(() => _weightGoal = 'lose'),
          ),
          const SizedBox(height: 20),
          // Maintain Weight Box
          _buildGoalBox(
            label: 'Maintain Weight',
            icon: Icons.balance,
            iconColor: const Color(0xFF3498DB),
            isSelected: _weightGoal == 'maintain',
            onTap: () => setState(() => _weightGoal = 'maintain'),
          ),
          const SizedBox(height: 20),
          // Gain Weight Box
          _buildGoalBox(
            label: 'Gain Weight',
            icon: Icons.trending_up,
            iconColor: const Color(0xFF27AE60),
            isSelected: _weightGoal == 'gain',
            onTap: () => setState(() => _weightGoal = 'gain'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalBox({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isSelected ? iconColor.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? iconColor : Colors.grey[300]!,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: iconColor,
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isSelected ? iconColor : Colors.black87,
              ),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Your Goals',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Set your target and pace',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          // Goal Weight
          TextField(
            controller: _goalWeightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '175',
              labelText: 'Goal Weight (lbs)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 30),
          // Weekly Rate Slider
          Text(
            'Weekly ${_weightGoal == 'maintain' ? 'Target' : (_weightGoal == 'lose' ? 'Loss' : 'Gain')} Rate',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your calorie target will balance with your activity',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          else
            Column(
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
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (isAggressive)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE74C3C).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Color(0xFFE74C3C), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'We do not recommend rates above 2 lbs/week as this is very aggressive and may lead to health complications.',
                            style: TextStyle(fontSize: 12, color: Colors.red[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          // Display calculations
          if (_weightGoal != 'maintain')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Palette.forestGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Palette.forestGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily ${_weightGoal == 'lose' ? 'Deficit' : 'Surplus'} Needed',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dailyDeficit.toStringAsFixed(0)} calories/day',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Estimated Timeline',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '~$weeksToGoal weeks to reach your goal',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // Activity Level
          DropdownButtonFormField<String>(
            initialValue: _selectedActivityLevel,
            decoration: const InputDecoration(
              labelText: 'Activity Level',
              border: OutlineInputBorder(),
            ),
            items: _activityLevelItems,
            onChanged: (val) => setState(() => _selectedActivityLevel = val!),
          ),
          const SizedBox(height: 24),
          // Baseline Calorie Goal
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Baseline Daily Calorie Goal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue[900]),
                ),
                const SizedBox(height: 8),
                Text(
                  '$baselineCalorie calories',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3498DB)),
                ),
                const SizedBox(height: 12),
                Text(
                  'Based on your ${_selectedActivityLevel.toLowerCase()} activity level. Your actual daily target will adjust based on your real activity from HealthKit.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
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
        backgroundColor: Palette.forestGreen,
        foregroundColor: Colors.white,
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
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
              ],
            ),
          ),
          // Navigation buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }
}
