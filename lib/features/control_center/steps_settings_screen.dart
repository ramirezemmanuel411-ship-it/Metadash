import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/data_inputs_settings.dart';

class StepsSettingsScreen extends StatefulWidget {
  const StepsSettingsScreen({super.key});

  @override
  State<StepsSettingsScreen> createState() => _StepsSettingsScreenState();
}

class _StepsSettingsScreenState extends State<StepsSettingsScreen> {
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

    final resolved = (await userState.db.getDataInputsSettings(user.id!)) ??
        DataInputsSettings.defaults(user.id!);
    await userState.db.createOrUpdateDataInputsSettings(resolved);

    setState(() {
      _settings = resolved;
      _stepGoal = resolved.stepGoal;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    final current = _settings ?? DataInputsSettings.defaults(user.id!);
    final next = current.copyWith(stepGoal: _stepGoal);
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
        title: const Text('Steps'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Set your daily step goal.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            children: [
              _ValueRow(
                title: 'Step Goal',
                value: _stepGoal.toString(),
                onTap: _editStepGoal,
              ),
            ],
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

