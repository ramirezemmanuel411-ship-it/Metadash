import 'package:flutter/material.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:metadash/features/control_center/calorie_macro_goals_screen.dart';
import 'package:metadash/features/control_center/reentry_mode_screen.dart';

class GoalStrategyScreen extends StatefulWidget {
  const GoalStrategyScreen({super.key});

  @override
  State<GoalStrategyScreen> createState() => _GoalStrategyScreenState();
}

class _GoalStrategyScreenState extends State<GoalStrategyScreen> {
  String _checkInFrequency = 'Weekly';
  String _progressInterpretation = 'Balanced';
  bool _autoAdjustTargets = true;
  String _plateauResponse = 'Adaptive';

  void _showFrequencyPicker() {
    _showSelectionBottomSheet(
      title: 'Check-In Frequency',
      options: ['Weekly', 'Biweekly', 'Monthly'],
      selectedValue: _checkInFrequency,
      onSelect: (value) {
        setState(() => _checkInFrequency = value);
        Navigator.pop(context);
      },
    );
  }

  void _showProgressInterpretationPicker() {
    _showSelectionBottomSheet(
      title: 'Progress Interpretation',
      options: ['Strict', 'Balanced', 'Flexible'],
      selectedValue: _progressInterpretation,
      onSelect: (value) {
        setState(() => _progressInterpretation = value);
        Navigator.pop(context);
      },
    );
  }

  void _showPlateauResponsePicker() {
    _showSelectionBottomSheet(
      title: 'Plateau Response',
      options: ['Conservative', 'Adaptive', 'Aggressive'],
      selectedValue: _plateauResponse,
      onSelect: (value) {
        setState(() => _plateauResponse = value);
        Navigator.pop(context);
      },
    );
  }

  void _showSelectionBottomSheet({
    required String title,
    required List<String> options,
    required String selectedValue,
    required Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ...options.map((option) {
                  final isSelected = option == selectedValue;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GestureDetector(
                      onTap: () => onSelect(option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.colors.accent.withValues(alpha: 0.1)
                              : context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: context.colors.accent,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? context.colors.accent
                                    : context.colors.textPrimary,
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: context.colors.accent,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: const Text('Goal Strategy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Define how MetaDash interprets progress and adjusts targets.',
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          // Section 1: Progress Evaluation
          _StrategySection(
            title: 'Progress Evaluation',
            children: [
              _StrategyRow(
                label: 'Check-In Frequency',
                value: _checkInFrequency,
                description:
                    'Determines how often MetaDash reviews your trends.',
                onTap: _showFrequencyPicker,
              ),
              _buildDivider(context),
              _StrategyRow(
                label: 'Progress Interpretation',
                value: _progressInterpretation,
                description:
                    'Controls how strictly MetaDash defines being "on track."',
                onTap: _showProgressInterpretationPicker,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Section 2: Target Adjustments
          _StrategySection(
            title: 'Target Adjustments',
            children: [
              _StrategyToggleRow(
                label: 'Auto-Adjust Targets',
                value: _autoAdjustTargets,
                description:
                    'Automatically updates calorie targets when trends shift.',
                onChanged: (newValue) {
                  setState(() => _autoAdjustTargets = newValue);
                },
              ),
              _buildDivider(context),
              _StrategyRow(
                label: 'Plateau Response',
                value: _plateauResponse,
                description:
                    'Defines how MetaDash responds when progress slows.',
                onTap: _showPlateauResponsePicker,
                showRecommendedBadge: _plateauResponse == 'Adaptive',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Section 3: Calorie & Macro Goals
          _StrategySection(
            title: 'Calorie & Macro Goals',
            children: [
              _StrategyNavigationRow(
                label: 'Macro Strategy',
                description: 'Set your daily calorie and macro goals manually.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CalorieMacroGoalsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Section 4: Lifestyle Handling
          _StrategySection(
            title: 'Lifestyle Handling',
            children: [
              _StrategyNavigationRow(
                label: 'Reentry Mode',
                description:
                    'Pause calorie tracking and resume smoothly after a break.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReentryModeScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StrategySection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StrategySection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: context.colors.textMuted.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StrategyRow extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  final VoidCallback onTap;
  final bool showRecommendedBadge;

  const _StrategyRow({
    required this.label,
    required this.value,
    required this.description,
    required this.onTap,
    this.showRecommendedBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: context.colors.surface.withValues(alpha: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showRecommendedBadge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.accent.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.colors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textMuted,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: context.colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StrategyToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final String description;
  final ValueChanged<bool> onChanged;

  const _StrategyToggleRow({
    required this.label,
    required this.value,
    required this.description,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface.withValues(alpha: 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textMuted,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: context.colors.accent,
              activeTrackColor: context.colors.accent.withValues(alpha: 0.3),
              inactiveThumbColor: context.colors.textMuted.withValues(
                alpha: 0.6,
              ),
              inactiveTrackColor: context.colors.divider,
            ),
          ),
        ],
      ),
    );
  }
}

class _StrategyNavigationRow extends StatelessWidget {
  final String label;
  final String description;
  final VoidCallback onTap;

  const _StrategyNavigationRow({
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: context.colors.surface.withValues(alpha: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textMuted,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right,
              color: context.colors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildDivider(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Divider(height: 1, thickness: 1, color: context.colors.divider),
  );
}
