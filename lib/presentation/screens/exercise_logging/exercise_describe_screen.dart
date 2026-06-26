import 'package:flutter/material.dart';
import 'package:metadash/core/logging/app_logger.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/exercise_repository.dart';
import '../../../models/exercise_model.dart';
import '../../../providers/user_state.dart';
import '../../../services/ai_service.dart';
import '../../../shared/palette.dart';

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
      _controller.text =
          'HIIT for 20 mins, 5/10 intensity - alternating sprints and walking recovery';
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
          final parsed = await _aiService.parseExerciseDescription(
            _controller.text.trim(),
          );

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
            exercise = Exercise.described(description: _controller.text.trim());
          }

          if (!mounted) return;

          // Show AI confidence if available
          final confidence = parsed['confidence'] ?? 0.8;
          if (confidence < 0.7) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'AI estimate (${(confidence * 100).toInt()}% confident). You can edit if needed.',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (aiError) {
          AppLogger.d('AI parsing failed: $aiError');
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
        SnackBar(
          content: const Text('Workout logged'),
          backgroundColor: context.colors.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isParsingWithAi = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        backgroundColor: context.colors.surface.withValues(alpha: 0),
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
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
                      color: context.colors.cta.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.colors.cta),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Example:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.colors.cta,
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
                        backgroundColor: context.colors.cta.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: context.colors.onPrimary,
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
                onPressed: (_hasContent && !_isParsingWithAi)
                    ? _onAddExercise
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: context.colors.accent,
                  disabledBackgroundColor: context.colors.surfaceVariant,
                ),
                child: _isParsingWithAi
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: context.colors.onPrimary,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
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
