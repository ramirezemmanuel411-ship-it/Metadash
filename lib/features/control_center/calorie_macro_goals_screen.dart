import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_state.dart';
import '../../shared/palette.dart';

class CalorieMacroGoalsScreen extends StatefulWidget {
  const CalorieMacroGoalsScreen({super.key});

  @override
  State<CalorieMacroGoalsScreen> createState() =>
      _CalorieMacroGoalsScreenState();
}

class _CalorieMacroGoalsScreenState extends State<CalorieMacroGoalsScreen> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  bool _manualEntry = false;

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

      _manualEntry = user.manualMacroEntry;
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
      // Create a copy of the user with the new values
      final updatedUser = user.copyWith(
        dailyCaloricGoal: calories,
        manualMacroEntry: _manualEntry,
        macroTargets: {'protein': protein, 'carbs': carbs, 'fat': fat},
      );

      // Force a UI update first by broadcasting the change
      await userState.updateCurrentUser(updatedUser);

      _showSnack('Goals saved successfully!');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: const Text('Macro Strategy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Choose how you want MetaDash to set your targets.',
            style: TextStyle(fontSize: 14, color: context.colors.textMuted),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Auto Calculate'),
                    selected: !_manualEntry,
                    onSelected: (_) => setState(() => _manualEntry = false),
                    selectedColor: context.colors.accent.withValues(
                      alpha: 0.15,
                    ),
                    labelStyle: TextStyle(
                      color: !_manualEntry
                          ? context.colors.accent
                          : context.colors.textPrimary,
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
                    selectedColor: context.colors.accent.withValues(
                      alpha: 0.15,
                    ),
                    labelStyle: TextStyle(
                      color: _manualEntry
                          ? context.colors.accent
                          : context.colors.textPrimary,
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
                color: context.colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.divider),
              ),
              child: Text(
                'Auto Calculate uses your onboarding targets and recent activity to update goals automatically.',
                style: TextStyle(fontSize: 13, color: context.colors.textMuted),
              ),
            ),
          if (_manualEntry)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Palette.lightStone,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.colors.divider.withValues(alpha: 0.08),
                ),
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
                backgroundColor: context.colors.cta,
                foregroundColor: context.colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Save Goals',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
