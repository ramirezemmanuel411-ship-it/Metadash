import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../providers/user_state.dart';
import '../../shared/palette.dart';
import 'create_user_flow.dart';

class UserSelectionScreen extends StatefulWidget {
  final UserState userState;
  const UserSelectionScreen({super.key, required this.userState});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  List<UserProfile> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load users asynchronously without blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    try {
      final loadedUsers = await widget.userState.getAllUsers();
      if (mounted) {
        setState(() {
          users = loadedUsers;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  void _selectUser(UserProfile user) async {
    await widget.userState.loginUser(user.id!);
    // Don't pop - let main.dart rebuild automatically
  }

  void _createNewUser() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateUserFlow(userState: widget.userState),
      ),
    );
    
    if (result == true && mounted) {
      // User was created, main.dart will rebuild automatically
      // Just reload the user list in case user wants to switch
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        elevation: 0,
        title: const Text(
          'Select User',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_outline, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No users found',
                                style: TextStyle(fontSize: 16, color: Colors.black54),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return _UserCard(
                              user: user,
                              onTap: () => _selectUser(user),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createNewUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.forestGreen,
                        foregroundColor: Palette.warmNeutral,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create New User',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onTap;

  const _UserCard({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Palette.forestGreen.withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.person, color: Palette.forestGreen),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        subtitle: Text(
          user.email,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black38),
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  final UserState userState;
  final VoidCallback onUserCreated;

  const _CreateUserDialog({
    required this.userState,
    required this.onUserCreated,
  });

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _ageController = TextEditingController();
  final _bmrController = TextEditingController();
  final _goalWeightController = TextEditingController();
  final _calorieGoalController = TextEditingController(text: '2200');
  final _stepsGoalController = TextEditingController(text: '10000');

  final DateTime _selectedDob = DateTime.now();
  String _selectedGender = 'Male';
  String _selectedActivityLevel = 'Moderately Active';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _ageController.dispose();
    _bmrController.dispose();
    _goalWeightController.dispose();
    _calorieGoalController.dispose();
    _stepsGoalController.dispose();
    super.dispose();
  }

  void _createUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      // Convert feet and inches to total inches
      final feet = int.tryParse(_heightFeetController.text) ?? 5;
      final inches = int.tryParse(_heightInchesController.text) ?? 10;
      final totalHeightInInches = (feet * 12) + inches.toDouble();
      
      await widget.userState.createUser(
        name: _nameController.text,
        email: _emailController.text,
        weight: double.tryParse(_weightController.text) ?? 180,
        height: totalHeightInInches,
        age: int.tryParse(_ageController.text) ?? 28,
        gender: _selectedGender,
        dateOfBirth: _selectedDob,
        bmr: double.tryParse(_bmrController.text) ?? 1800,
        goalWeight: double.tryParse(_goalWeightController.text) ?? 175,
        dailyCaloricGoal: int.tryParse(_calorieGoalController.text) ?? 2200,
        activityLevel: _selectedActivityLevel,
        dailyStepsGoal: int.tryParse(_stepsGoalController.text) ?? 10000,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUserCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating user: $e')),
        );
      }
    }
  }

  int _currentStep = 0;

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Basic Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'John Doe',
            labelText: 'Full Name *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            hintText: 'john@example.com',
            labelText: 'Email *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '28',
            labelText: 'Age',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          decoration: const InputDecoration(
            labelText: 'Gender',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (val) => setState(() => _selectedGender = val!),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Physical Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '180',
            labelText: 'Current Weight (lbs)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Height', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
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
            const SizedBox(width: 12),
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
        const SizedBox(height: 16),
        TextField(
          controller: _bmrController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '1800',
            labelText: 'BMR (Basal Metabolic Rate)',
            border: OutlineInputBorder(),
            helperText: 'Calories burned at rest',
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Goals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(
          controller: _goalWeightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '175',
            labelText: 'Goal Weight (lbs)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _calorieGoalController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '2200',
            labelText: 'Daily Calorie Goal',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _stepsGoalController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '10000',
            labelText: 'Daily Steps Goal',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedActivityLevel,
          decoration: const InputDecoration(
            labelText: 'Activity Level',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Sedentary', child: Text('Sedentary')),
            DropdownMenuItem(value: 'Lightly Active', child: Text('Lightly Active')),
            DropdownMenuItem(value: 'Moderately Active', child: Text('Moderately Active')),
            DropdownMenuItem(value: 'Very Active', child: Text('Very Active')),
          ],
          onChanged: (val) => setState(() => _selectedActivityLevel = val!),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [_buildStep1(), _buildStep2(), _buildStep3()];

    return AlertDialog(
      title: Column(
        children: [
          Text('Create New User (${_currentStep + 1}/3)'),
          const SizedBox(height: 12),
          Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: index <= _currentStep ? Colors.green : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: steps[_currentStep],
        ),
      ),
      actions: [
        if (_currentStep > 0)
          TextButton(
            onPressed: () => setState(() => _currentStep--),
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _createUser();
            }
          },
          child: Text(_currentStep < 2 ? 'Next' : 'Create'),
        ),
      ],
    );
  }
}
