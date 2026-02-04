import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/exercise_model.dart';
import '../../../data/repositories/exercise_repository.dart';
import '../../../providers/user_state.dart';

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
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter calories burned')),
      );
      return;
    }

    try {
      final exercise = Exercise.manual(caloriesBurned: _calories);

      final userState = context.read<UserState>();
      final repo = ExerciseRepository(userState: userState);
      await repo.saveExercise(exercise);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_calories calories logged'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        _controller.text = _controller.text.substring(0, _controller.text.length - 1);
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
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                                Colors.orange.withOpacity(0.1),
                                Colors.red.withOpacity(0.1),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.orange,
                              width: 3,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              size: 64,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _calories.toString(),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Text(
                              'calories',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
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
                      color: Colors.grey[100],
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
                        color: Colors.red[100],
                        textColor: Colors.red,
                        onTap: _backspace,
                      ),
                      _buildKeypadButton(
                        '0',
                        onTap: () => _addDigit('0'),
                      ),
                      _buildKeypadButton(
                        'C',
                        color: Colors.grey[300],
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
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
          color: color ?? Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor ?? Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
