import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';

class MetabolicEngineScreen extends StatefulWidget {
  const MetabolicEngineScreen({super.key});

  @override
  State<MetabolicEngineScreen> createState() => _MetabolicEngineScreenState();
}

class _MetabolicEngineScreenState extends State<MetabolicEngineScreen> {
  late String _energyModel;
  late String _workoutAccuracy;

  @override
  void initState() {
    super.initState();
    final userState = Provider.of<UserState>(context, listen: false);
    final settings = userState.metabolicSettings;
    _energyModel = settings.energyModel;
    _workoutAccuracy = settings.workoutAccuracy;
  }

  void _updateSettings() {
    final userState = Provider.of<UserState>(context, listen: false);
    userState.updateMetabolicSettings(
      userState.metabolicSettings.copyWith(
        energyModel: _energyModel,
        workoutAccuracy: _workoutAccuracy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Metabolic Engine'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Configure energy and fat modeling.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _EngineSection(
            title: 'Energy Model',
            children: [
              _SelectableOption(
                title: 'Static',
                description: 'Uses a steady baseline with no adaptive adjustments.',
                isSelected: _energyModel == 'Static',
                onTap: () {
                  setState(() => _energyModel = 'Static');
                  _updateSettings();
                },
              ),
              _buildDivider(),
              _SelectableOption(
                title: 'Adaptive',
                description: 'Learns quickly from activity and outcomes to refine targets.',
                isSelected: _energyModel == 'Adaptive',
                onTap: () {
                  setState(() => _energyModel = 'Adaptive');
                  _updateSettings();
                },
              ),
              _buildDivider(),
              _SelectableOption(
                title: 'Hybrid (Recommended)',
                description: 'Balances your baseline metabolism with intelligent adjustments based on activity and progress.',
                isSelected: _energyModel == 'Hybrid (Recommended)',
                onTap: () {
                  setState(() => _energyModel = 'Hybrid (Recommended)');
                  _updateSettings();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _EngineSection(
            title: 'Workout Accuracy',
            children: [
              _SelectableOption(
                title: 'Strict',
                description: 'Applies the most conservative interpretation of workout calories.',
                isSelected: _workoutAccuracy == 'Strict',
                onTap: () {
                  setState(() => _workoutAccuracy = 'Strict');
                  _updateSettings();
                },
              ),
              _buildDivider(),
              _SelectableOption(
                title: 'Balanced',
                description: 'Uses a calibrated blend of caution and responsiveness.',
                isSelected: _workoutAccuracy == 'Balanced',
                onTap: () {
                  setState(() => _workoutAccuracy = 'Balanced');
                  _updateSettings();
                },
              ),
              _buildDivider(),
              _SelectableOption(
                title: 'Flexible',
                description: 'Leans into workout data for a more responsive estimate.',
                isSelected: _workoutAccuracy == 'Flexible',
                onTap: () {
                  setState(() => _workoutAccuracy = 'Flexible');
                  _updateSettings();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.black.withOpacity(0.05),
    );
  }
}

// SELECTABLE OPTION WIDGET
class _SelectableOption extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableOption({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.black.withOpacity(0.5),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Radio<bool>(
              value: true,
              groupValue: isSelected ? true : false,
              onChanged: (_) => onTap(),
              activeColor: Palette.forestGreen,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(
                horizontal: VisualDensity.minimumDensity,
                vertical: VisualDensity.minimumDensity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SECTION CARD WIDGET
class _EngineSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _EngineSection({
    required this.title,
    required this.children,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// NAVIGATION ROW
class _NavigationRow extends StatelessWidget {
  final String title;
  final String trailing;
  final VoidCallback onTap;

  const _NavigationRow({
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.black.withOpacity(0.25),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _FullWidthNavRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _FullWidthNavRow({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.black.withOpacity(0.25),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SelectionScreen extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;

  const _SelectionScreen({
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
          _EngineSection(
            title: title.toUpperCase(),
            children: options.map((option) {
              final isSelected = option == selected;
              return InkWell(
                onTap: () => Navigator.pop(context, option),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check,
                          color: Palette.forestGreen,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// TOGGLE ROW
class _ToggleRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
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
    );
  }
}

// DETAIL SCREEN PLACEHOLDER
class _DetailScreen extends StatelessWidget {
  final String title;

  const _DetailScreen({required this.title});

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Detail configuration for $title',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

class AdvancedEngineSettingsScreen extends StatefulWidget {
  const AdvancedEngineSettingsScreen({super.key});

  @override
  State<AdvancedEngineSettingsScreen> createState() => _AdvancedEngineSettingsScreenState();
}

class _AdvancedEngineSettingsScreenState extends State<AdvancedEngineSettingsScreen> {
  bool _conversionRuleEnabled = true;
  bool _confidenceBandsEnabled = false;
  bool _showTdeeLine = true;
  final String _stepInfluence = 'Moderate';
  final String _workoutMargin = '15%';
  final String _adaptiveSensitivity = 'Balanced';
  final String _fatDeltaMultiplier = '0.75';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Advanced Engine Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Fine-tune modeling behavior.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _EngineSection(
            title: 'ADVANCED SETTINGS',
            children: [
              _NavigationRow(
                title: 'Fat Delta Multiplier',
                trailing: _fatDeltaMultiplier,
                onTap: () => _navigateTo(context, 'Fat Delta Multiplier'),
              ),
              _buildDivider(),
              _ToggleRow(
                title: '3500 Conversion Rule',
                value: _conversionRuleEnabled,
                onChanged: (val) => setState(() => _conversionRuleEnabled = val),
              ),
              _buildDivider(),
              _NavigationRow(
                title: 'Step Influence Scaling',
                trailing: _stepInfluence,
                onTap: () => _navigateTo(context, 'Step Influence Scaling'),
              ),
              _buildDivider(),
              _NavigationRow(
                title: 'Workout Margin of Error',
                trailing: _workoutMargin,
                onTap: () => _navigateTo(context, 'Workout Margin of Error'),
              ),
              _buildDivider(),
              _ToggleRow(
                title: 'Confidence Bands',
                value: _confidenceBandsEnabled,
                onChanged: (val) => setState(() => _confidenceBandsEnabled = val),
              ),
              _buildDivider(),
              _ToggleRow(
                title: 'Show TDEE Line',
                value: _showTdeeLine,
                onChanged: (val) => setState(() => _showTdeeLine = val),
              ),
              _buildDivider(),
              _NavigationRow(
                title: 'Adaptive Sensitivity',
                trailing: _adaptiveSensitivity,
                onTap: () => _navigateTo(context, 'Adaptive Sensitivity'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.black.withOpacity(0.05),
    );
  }

  void _navigateTo(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DetailScreen(title: title),
      ),
    );
  }
}
