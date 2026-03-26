import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/data_inputs_settings.dart';
import 'wearables_connections_screen.dart';
import 'food_sources_screen.dart';
import 'macro_calc_screen.dart';
import 'reset_data_inputs_screen.dart';

class DataInputsScreen extends StatefulWidget {
  const DataInputsScreen({super.key});

  @override
  State<DataInputsScreen> createState() => _DataInputsScreenState();
}

class _DataInputsScreenState extends State<DataInputsScreen> {
  bool _isLoading = true;
  DataInputsSettings? _settings;
  int _stepGoal = 8000;

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

    final defaults = DataInputsSettings.defaults(user.id!).copyWith(
      stepGoal: user.dailyStepsGoal,
    );
    final resolved = (await userState.db.getDataInputsSettings(user.id!)) ?? defaults;
    await userState.db.createOrUpdateDataInputsSettings(resolved);

    setState(() {
      _settings = resolved;
      _stepGoal = resolved.stepGoal;
      _isLoading = false;
    });
  }

  Future<void> _saveStepGoal(int value) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;
    final current = _settings ?? DataInputsSettings.defaults(user.id!);
    final next = current.copyWith(stepGoal: value);
    _settings = next;
    await userState.db.createOrUpdateDataInputsSettings(next);
  }

  Future<void> _editStepGoal() async {
    final controller = TextEditingController(text: _stepGoal.toString());
    final updated = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Step Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter a number'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(context, value);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (updated != null && updated > 0) {
      setState(() => _stepGoal = updated);
      await _saveStepGoal(updated);
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
        title: const Text('Data & Inputs'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
          Text(
            'Manage wearable data, step logic, and nutrition sources.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('CONNECTIONS'),
          _SectionCard(
            children: [
              _DataInputRow(
                icon: Icons.watch_outlined,
                title: 'Wearables & Health Data',
                subtitle: 'Connect Apple Health / Google Fit and choose what to import.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WearablesConnectionsScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('ACTIVITY INPUTS'),
          _SectionCard(
            children: [
              _DataInputRow(
                icon: Icons.directions_walk_outlined,
                title: 'Steps',
                subtitle: null,
                trailing: _stepGoal.toString(),
                onTap: _editStepGoal,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('NUTRITION INPUTS'),
          _SectionCard(
            children: [
              _DataInputRow(
                icon: Icons.restaurant_outlined,
                title: 'Food Database',
                subtitle: 'Choose where food data comes from when you search.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FoodSourcesScreen(),
                  ),
                ),
              ),
              const _SectionDivider(),
              _DataInputRow(
                icon: Icons.calculate_outlined,
                title: 'Macro Calculations',
                subtitle: 'Control how calories are calculated from macros.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MacroCalcScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ResetDataInputsScreen(),
                ),
              ),
              child: const Text('Reset Data & Inputs'),
            ),
          ),
          const SizedBox(height: 12),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Colors.black.withOpacity(0.4),
          letterSpacing: 0.8,
        ),
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

class _DataInputRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  const _DataInputRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: Colors.black.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withOpacity(0.55),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
            ],
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
