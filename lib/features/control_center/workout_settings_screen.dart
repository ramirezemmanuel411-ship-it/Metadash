import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/data_inputs_settings.dart';

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

    final resolved = (await userState.db.getDataInputsSettings(user.id!)) ??
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
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Workouts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Control how logged workouts affect expenditure.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            children: [
              _ToggleRow(
                title: 'Use Tracked Workout Calories',
                subtitle: 'Uses Apple Watch / device estimates when available.',
                value: _useTrackedWorkoutCalories,
                onChanged: (value) async {
                  setState(() => _useTrackedWorkoutCalories = value);
                  await _saveSettings();
                },
              ),
              const _SectionDivider(),
              _ValueRow(
                title: 'Workout Accuracy',
                value: _workoutAccuracy,
                onTap: _selectWorkoutAccuracy,
              ),
              const _SectionDivider(),
              _ToggleRow(
                title: 'Include Strength Training in Expenditure',
                subtitle: 'If off, strength sessions are logged but not used in calorie burn.',
                value: _includeStrengthInExpenditure,
                onChanged: (value) async {
                  setState(() => _includeStrengthInExpenditure = value);
                  await _saveSettings();
                },
              ),
            ],
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
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black.withOpacity(0.55),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: entry.key,
                            groupValue: selected,
                            activeColor: Palette.forestGreen,
                            onChanged: (_) => Navigator.pop(context, entry.key),
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
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
      color: Colors.black.withOpacity(0.06),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _ValueRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withOpacity(0.55),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.black.withOpacity(0.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Palette.forestGreen,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.55),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
