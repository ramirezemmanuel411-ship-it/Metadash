import 'package:flutter/material.dart';
import 'package:metadash/core/providers/user_state.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:metadash/data/models/data_inputs_settings.dart';
import 'package:provider/provider.dart';

class WorkoutSettingsScreen extends StatefulWidget {
  const WorkoutSettingsScreen({super.key});

  @override
  State<WorkoutSettingsScreen> createState() => _WorkoutSettingsScreenState();
}

class _WorkoutSettingsScreenState extends State<WorkoutSettingsScreen> {
  bool _isLoading = true;
  DataInputsSettings? _settings;
  bool _useTrackedWorkoutCalories = true;
  String _workoutAccuracy = 'Balanced';
  bool _includeStrengthInExpenditure = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final resolved =
        (await userState.db.getDataInputsSettings(user.id!)) ??
        DataInputsSettings.defaults(user.id!);
    await userState.db.createOrUpdateDataInputsSettings(resolved);

    setState(() {
      _settings = resolved;
      _useTrackedWorkoutCalories = resolved.useTrackedWorkoutCalories;
      _workoutAccuracy = resolved.workoutAccuracy;
      _includeStrengthInExpenditure = resolved.includeStrengthInExpenditure;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    final current = _settings ?? DataInputsSettings.defaults(user.id!);
    final next = current.copyWith(
      useTrackedWorkoutCalories: _useTrackedWorkoutCalories,
      workoutAccuracy: _workoutAccuracy,
      includeStrengthInExpenditure: _includeStrengthInExpenditure,
    );
    _settings = next;
    await userState.db.createOrUpdateDataInputsSettings(next);
    await userState.refreshDataInputsSettings();
  }

  Future<void> _selectWorkoutAccuracy() async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _SingleSelectScreen(
          title: 'Workout Accuracy',
          selected: _workoutAccuracy,
          options: {
            'Balanced': 'Good default for most workouts.',
            'Conservative': 'Counts fewer workout calories.',
            'Generous': 'Counts more workout calories.',
          },
        ),
      ),
    );

    if (selected != null) {
      setState(() => _workoutAccuracy = selected);
      await _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        title: const Text('Workout Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  title: const Text('Use Tracked Workout Calories'),
                  value: _useTrackedWorkoutCalories,
                  onChanged: (value) {
                    setState(() => _useTrackedWorkoutCalories = value);
                    _saveSettings();
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Workout Accuracy'),
                  subtitle: Text(_workoutAccuracy),
                  onTap: _selectWorkoutAccuracy,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Include Strength in Expenditure'),
                  value: _includeStrengthInExpenditure,
                  onChanged: (value) {
                    setState(() => _includeStrengthInExpenditure = value);
                    _saveSettings();
                  },
                ),
              ],
            ),
    );
  }
}

class _SingleSelectScreen extends StatelessWidget {
  final String title;
  final Map<String, String> options;
  final String selected;

  const _SingleSelectScreen({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            children: options.entries.map((entry) {
              return Column(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context, entry.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.colors.textMuted.withValues(
                                      alpha: 0.85,
                                    ),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context, entry.key),
                            child: Icon(
                              selected == entry.key
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selected == entry.key
                                  ? context.colors.accent
                                  : context.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (entry.key != options.keys.last) const _SectionDivider(),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: context.colors.textMuted.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: context.colors.textMuted.withValues(alpha: 0.06),
    );
  }
}

// Removed unused helper widgets `_ValueRow` and `_ToggleRow`.
