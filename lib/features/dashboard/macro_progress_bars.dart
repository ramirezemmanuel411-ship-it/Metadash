// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class MacroProgressBars extends StatelessWidget {
  final int proteinConsumed;
  final int proteinTarget;
  final int carbsConsumed;
  final int carbsTarget;
  final int fatConsumed;
  final int fatTarget;

  const MacroProgressBars({
    super.key,
    required this.proteinConsumed,
    required this.proteinTarget,
    required this.carbsConsumed,
    required this.carbsTarget,
    required this.fatConsumed,
    required this.fatTarget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bars row with labels centered on bars
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _MacroBar(
                label: 'Protein',
                consumed: proteinConsumed,
                target: proteinTarget,
                color: Colors.orange,
              ),
            ),
            Expanded(
              child: _MacroBar(
                label: 'Carbs',
                consumed: carbsConsumed,
                target: carbsTarget,
                color: Colors.blue,
              ),
            ),
            Expanded(
              child: _MacroBar(
                label: 'Fat',
                consumed: fatConsumed,
                target: fatTarget,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final int consumed;
  final int target;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final exceeded = consumed > target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            color: exceeded ? color.withOpacity(0.7) : color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$consumed / $target g',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: exceeded ? Colors.amber.shade600 : Colors.grey,
          ),
        ),
      ],
    );
  }
}
