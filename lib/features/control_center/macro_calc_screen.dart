import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';
import '../../models/data_inputs_settings.dart';

class MacroCalcScreen extends StatefulWidget {
  const MacroCalcScreen({super.key});

  @override
  State<MacroCalcScreen> createState() => _MacroCalcScreenState();
}

class _MacroCalcScreenState extends State<MacroCalcScreen> {
  bool _isLoading = true;
  DataInputsSettings? _settings;
  String _macroCalcMode = 'Standard (4/4/9)';
  bool _showFiber = true;
  bool _showSugar = false;

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
      _macroCalcMode = resolved.macroCalcMode;
      _showFiber = resolved.showFiber;
      _showSugar = resolved.showSugar;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    final current = _settings ?? DataInputsSettings.defaults(user.id!);
    final next = current.copyWith(
      macroCalcMode: _macroCalcMode,
      showFiber: _showFiber,
      showSugar: _showSugar,
    );
    _settings = next;
    await userState.db.createOrUpdateDataInputsSettings(next);
  }

  Future<void> _selectCalcMode() async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _SingleSelectScreen(
          title: 'Macro Calculations',
          selected: _macroCalcMode,
          options: {
            'Standard (4/4/9)': 'Recommended for most foods.',
            'Label Mode': 'Uses label rounding behavior.',
          },
        ),
      ),
    );

    if (selected != null) {
      setState(() => _macroCalcMode = selected);
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
        title: const Text('Macro Calculations'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Control how calories are calculated from macros.',
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
                title: 'Calculation Mode',
                value: _macroCalcMode,
                onTap: _selectCalcMode,
              ),
              const _SectionDivider(),
              _ToggleRow(
                title: 'Show Fiber',
                value: _showFiber,
                onChanged: (value) async {
                  setState(() => _showFiber = value);
                  await _saveSettings();
                },
              ),
              const _SectionDivider(),
              _ToggleRow(
                title: 'Show Sugar',
                value: _showSugar,
                onChanged: (value) async {
                  setState(() => _showSugar = value);
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
