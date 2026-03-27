import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_state.dart';
import '../../shared/palette.dart';

class CalorieMacroGoalsScreen extends StatefulWidget {
  const CalorieMacroGoalsScreen({super.key});

  @override
  State<CalorieMacroGoalsScreen> createState() => _CalorieMacroGoalsScreenState();
}

class _CalorieMacroGoalsScreenState extends State<CalorieMacroGoalsScreen> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  bool _manualEntry = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserState>().currentUser;
      if (user == null) return;
      _caloriesController.text = user.dailyCaloricGoal.toString();
      _proteinController.text = (user.macroTargets?['protein'] ?? 0).toString();
      _carbsController.text = (user.macroTargets?['carbs'] ?? 0).toString();
      _fatController.text = (user.macroTargets?['fat'] ?? 0).toString();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userState = context.read<UserState>();
    final user = userState.currentUser;
    if (user == null) return;

    final calories = int.tryParse(_caloriesController.text.trim());
    final protein = int.tryParse(_proteinController.text.trim());
    final carbs = int.tryParse(_carbsController.text.trim());
    final fat = int.tryParse(_fatController.text.trim());

    if (_manualEntry) {
      if (calories == null || calories <= 0) {
        _showSnack('Enter a valid calorie goal.');
        return;
      }
      if (protein == null || carbs == null || fat == null) {
        _showSnack('Enter valid macro targets.');
        return;
      }
    }

    if (calories != null && protein != null && carbs != null && fat != null) {
      await userState.updateCurrentUser(
        user.copyWith(
          dailyCaloricGoal: calories,
          macroTargets: {
            'protein': protein,
            'carbs': carbs,
            'fat': fat,
          },
        ),
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Macro Strategy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose how you want MetaDash to set your targets.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Palette.lightStone,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Auto Calculate'),
                    selected: !_manualEntry,
                    onSelected: (_) => setState(() => _manualEntry = false),
                    selectedColor: Palette.forestGreen.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: !_manualEntry ? Palette.forestGreen : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Manual Entry'),
                    selected: _manualEntry,
                    onSelected: (_) => setState(() => _manualEntry = true),
                    selectedColor: Palette.forestGreen.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _manualEntry ? Palette.forestGreen : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_manualEntry)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'Auto Calculate uses your onboarding targets and recent activity to update goals automatically.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
          if (_manualEntry)
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
                    'Manual Entry',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Daily Calorie Goal',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _proteinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Protein (g)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _carbsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Carbs (g)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _fatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Fat (g)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.forestGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Save Goals',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
