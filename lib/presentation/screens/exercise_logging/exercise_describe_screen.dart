// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/exercise_model.dart';
import '../../../data/repositories/exercise_repository.dart';
import '../../../providers/user_state.dart';
import '../../../services/ai_service.dart';

/// Screen for describing an exercise in text (AI-ready)
class ExerciseDescribeScreen extends StatefulWidget {
  const ExerciseDescribeScreen({super.key});

  @override
  State<ExerciseDescribeScreen> createState() => _ExerciseDescribeScreenState();
}

class _ExerciseDescribeScreenState extends State<ExerciseDescribeScreen> {
  final TextEditingController _controller = TextEditingController();
  final AiService _aiService = AiService();
  bool _isParsingWithAi = false;

  bool get _hasContent => _controller.text.trim().isNotEmpty;

  void _fillWithAIExample() {
    // Fill with example text to demonstrate AI parsing
    setState(() {
      _controller.text = 'HIIT for 20 mins, 5/10 intensity - alternating sprints and walking recovery';
    });
  }

  void _onAddExercise() async {
    if (!_hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your workout')),
      );
      return;
    }

    setState(() => _isParsingWithAi = true);

    try {
      Exercise exercise;
      
      // Try AI parsing if API key is configured
      if (_aiService.hasAnyKey) {
        try {
          final parsed = await _aiService.parseExerciseDescription(_controller.text.trim());
          
          // Create exercise from AI-parsed data
          final exerciseType = _mapExerciseType(parsed['type'] ?? 'run');
          final intensity = _mapIntensity(parsed['intensity'] ?? 'medium');
          final duration = parsed['duration_minutes'] ?? 30;
          
          if (exerciseType == ExerciseType.run && intensity != null) {
            // Create run exercise with parsed values
            exercise = Exercise.run(
              intensity: intensity,
              durationMinutes: duration,
            );
          } else {
            // Create described exercise (fallback)
            exercise = Exercise.described(
              description: _controller.text.trim(),
            );
          }
          
          if (!mounted) return;
          
          // Show AI confidence if available
          final confidence = parsed['confidence'] ?? 0.8;
          if (confidence < 0.7) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('AI estimate (${(confidence * 100).toInt()}% confident). You can edit if needed.'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (aiError) {
          print('AI parsing failed: $aiError');
          // Fallback to basic exercise
          exercise = Exercise.described(description: _controller.text.trim());
        }
      } else {
        // No AI key, use basic description
        exercise = Exercise.described(description: _controller.text.trim());
      }

      final userState = context.read<UserState>();
      final repo = ExerciseRepository(userState: userState);
      await repo.saveExercise(exercise);

      if (!mounted) return;
      setState(() => _isParsingWithAi = false);
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout logged'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isParsingWithAi = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  ExerciseType _mapExerciseType(String type) {
    switch (type.toLowerCase()) {
      case 'run':
      case 'running':
      case 'jogging':
        return ExerciseType.run;
      case 'weightlifting':
      case 'weight':
      case 'lifting':
        return ExerciseType.weightLifting;
      case 'manual':
        return ExerciseType.manual;
      default:
        return ExerciseType.described;
    }
  }

  ExerciseIntensity? _mapIntensity(String intensity) {
    switch (intensity.toLowerCase()) {
      case 'light':
      case 'low':
      case 'easy':
        return ExerciseIntensity.low;
      case 'medium':
      case 'moderate':
        return ExerciseIntensity.medium;
      case 'high':
      case 'intense':
      case 'hard':
        return ExerciseIntensity.high;
      default:
        return ExerciseIntensity.medium;
    }
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
        title: const Text('Describe Exercise'),
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
                  TextField(
                    controller: _controller,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Describe workout time, intensity, etc.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // AI helper button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Example:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'HIIT for 20 mins, 5/10 intensity',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // AI button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _fillWithAIExample,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[100],
                        foregroundColor: Colors.amber[900],
                      ),
                      child: const Text('✨ Created by AI'),
                    ),
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
                onPressed: (_hasContent && !_isParsingWithAi) ? _onAddExercise : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isParsingWithAi
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Analyzing with AI...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Add Exercise',
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
