// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import '../../models/exercise_model.dart';

/// Vertical scrollable intensity selector for running
class IntensitySelector extends StatefulWidget {
  final ExerciseIntensity? selectedIntensity;
  final ValueChanged<ExerciseIntensity> onChanged;

  const IntensitySelector({
    super.key,
    this.selectedIntensity,
    required this.onChanged,
  });

  @override
  State<IntensitySelector> createState() => _IntensitySelectorState();
}

class _IntensitySelectorState extends State<IntensitySelector> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set Intensity',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListWheelScrollView(
            controller: _scrollController,
            itemExtent: 80,
            onSelectedItemChanged: (index) {
              widget.onChanged(ExerciseIntensity.values[index]);
            },
            children: ExerciseIntensity.values
                .map((intensity) => _buildIntensityOption(intensity))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildIntensityOption(ExerciseIntensity intensity) {
    final isSelected = intensity == widget.selectedIntensity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? context.colors.accent : context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: context.colors.accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              intensity.label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? context.colors.surface
                    : context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              intensity.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? context.colors.onPrimary
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
