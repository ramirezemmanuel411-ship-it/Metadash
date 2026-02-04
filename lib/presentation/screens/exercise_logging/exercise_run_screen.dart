import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/exercise_model.dart';
import '../../../data/repositories/exercise_repository.dart';
import '../../../providers/user_state.dart';
import '../../widgets/intensity_selector.dart';
import '../../widgets/duration_selector.dart';

/// Screen for logging a run exercise
class ExerciseRunScreen extends StatefulWidget {
  const ExerciseRunScreen({super.key});

  @override
  State<ExerciseRunScreen> createState() => _ExerciseRunScreenState();
}

class _ExerciseRunScreenState extends State<ExerciseRunScreen> {
  ExerciseIntensity? _selectedIntensity;
  int? _selectedDuration;

  bool get _isValid => _selectedIntensity != null && _selectedDuration != null && _selectedDuration! > 0;

  void _onContinue() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select intensity and duration')),
      );
      return;
    }

    try {
      final exercise = Exercise.run(
        intensity: _selectedIntensity!,
        durationMinutes: _selectedDuration!,
      );

      final userState = context.read<UserState>();
      final repo = ExerciseRepository(userState: userState);
      await repo.saveExercise(exercise);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_selectedDuration min run logged'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run'),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IntensitySelector(
                    selectedIntensity: _selectedIntensity,
                    onChanged: (intensity) {
                      setState(() => _selectedIntensity = intensity);
                    },
                  ),
                  const SizedBox(height: 40),
                  DurationSelector(
                    selectedDuration: _selectedDuration,
                    onChanged: (duration) {
                      setState(() => _selectedDuration = duration);
                    },
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
                onPressed: _isValid ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Continue',
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
}
