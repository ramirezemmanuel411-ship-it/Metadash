// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:metadash/shared/palette.dart';

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
        Row(
          children: [
            Expanded(
              child: _MacroBar(
                label: 'Protein',
                consumed: proteinConsumed,
                target: proteinTarget,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroBar(
                label: 'Carbs',
                consumed: carbsConsumed,
                target: carbsTarget,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MacroBar(
                label: 'Fat',
                consumed: fatConsumed,
                target: fatTarget,
                color: Colors.orange,
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
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: context.colors.surfaceVariant,
            color: exceeded ? context.colors.cta : color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$consumed / $target g',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: exceeded ? context.colors.cta : context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
