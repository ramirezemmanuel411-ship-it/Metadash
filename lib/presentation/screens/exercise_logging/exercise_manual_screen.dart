// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/exercise_repository.dart';
import '../../../models/exercise_model.dart';
import '../../../providers/user_state.dart';
import '../../../shared/palette.dart';

/// Screen for manually entering calories burned
class ExerciseManualScreen extends StatefulWidget {
  const ExerciseManualScreen({super.key});

  @override
  State<ExerciseManualScreen> createState() => _ExerciseManualScreenState();
}

class _ExerciseManualScreenState extends State<ExerciseManualScreen> {
  final TextEditingController _controller = TextEditingController();
  int _calories = 0;

  bool get _isValid => _calories > 0;

  void _onAdd() async {
    if (!_isValid) return;

    try {
      final exercise = Exercise.manual(caloriesBurned: _calories);

      final userState = context.read<UserState>();
      final repo = ExerciseRepository(userState: userState);
      await repo.saveExercise(exercise);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {}
  }

  void _addDigit(String digit) {
    setState(() {
      _controller.text += digit;
      _calories = int.tryParse(_controller.text) ?? 0;
    });
  }

  void _backspace() {
    setState(() {
      if (_controller.text.isNotEmpty) {
        _controller.text = _controller.text.substring(
          0,
          _controller.text.length - 1,
        );
        _calories = int.tryParse(_controller.text) ?? 0;
      }
    });
  }

  void _clear() {
    setState(() {
      _controller.clear();
      _calories = 0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual'),
        elevation: 0,
        backgroundColor: context.colors.surface.withValues(alpha: 0),
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // Circular flame indicator
                  SizedBox(
                    height: 180,
                    width: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                context.colors.cta.withValues(alpha: 0.12),
                                Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.12),
                              ],
                            ),
                            border: Border.all(
                              color: context.colors.cta,
                              width: 3,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 64,
                              color: context.colors.cta,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _calories.toString(),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            Text(
                              'calories',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Input display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _controller.text.isEmpty ? '0' : _controller.text,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Number keypad
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map(
                        (digit) => _buildKeypadButton(
                          digit.toString(),
                          onTap: () => _addDigit(digit.toString()),
                        ),
                      ),
                      _buildKeypadButton(
                        'DEL',
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.12),
                        textColor: Theme.of(context).colorScheme.error,
                        onTap: _backspace,
                      ),
                      _buildKeypadButton('0', onTap: () => _addDigit('0')),
                      _buildKeypadButton(
                        'C',
                        color: context.colors.surfaceVariant,
                        onTap: _clear,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Fixed bottom button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid ? _onAdd : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: context.colors.cta,
                  disabledBackgroundColor: context.colors.surfaceVariant
                      .withValues(alpha: 0.5),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(
    String label, {
    Color? color,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor ?? context.colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
