import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import '../../providers/user_state.dart';

class ProfileScreen extends StatefulWidget {
  final UserState userState;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.userState,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showInvalid(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userState.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Palette.warmNeutral,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: widget.onLogout,
                child: const Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Palette.lightStone,
                        border: Border.all(
                          color: Palette.forestGreen,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Palette.forestGreen,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Palette.forestGreen,
                          border: Border.all(
                            color: Palette.warmNeutral,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Palette.warmNeutral,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _EditableStatCard(
                      label: 'Weight',
                      value: user.weight.toStringAsFixed(0),
                      unit: 'lbs',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSave: (text) async {
                        final val = double.tryParse(text);
                        if (val == null || val <= 0) {
                          _showInvalid('Enter a valid weight');
                          return false;
                        }
                        await widget.userState.updateCurrentUser(user.copyWith(weight: val));
                        return true;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EditableHeightCard(
                      label: 'Height',
                      heightInInches: user.height,
                      onSave: (feet, inches) async {
                        if (feet <= 0 || inches < 0 || inches > 11) {
                          _showInvalid('Enter a valid height');
                          return false;
                        }
                        final total = (feet * 12) + inches;
                        await widget.userState.updateCurrentUser(user.copyWith(height: total.toDouble()));
                        return true;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _EditableStatCard(
                      label: 'Age',
                      value: user.age.toString(),
                      unit: 'years',
                      keyboardType: TextInputType.number,
                      onSave: (text) async {
                        final val = int.tryParse(text);
                        if (val == null || val <= 0) {
                          _showInvalid('Enter a valid age');
                          return false;
                        }
                        await widget.userState.updateCurrentUser(user.copyWith(age: val));
                        return true;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EditableStatCard(
                      label: 'BMR',
                      value: user.bmr.toStringAsFixed(0),
                      unit: 'kcal',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSave: (text) async {
                        final val = double.tryParse(text);
                        if (val == null || val <= 0) {
                          _showInvalid('Enter a valid BMR');
                          return false;
                        }
                        await widget.userState.updateCurrentUser(user.copyWith(bmr: val));
                        return true;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _SectionTitle('Account'),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.email,
                title: 'Email',
                value: user.email,
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.cake,
                title: 'Date of Birth',
                value: '${user.dateOfBirth.month}/${user.dateOfBirth.day}/${user.dateOfBirth.year}',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.wc,
                title: 'Gender',
                value: user.gender,
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.settings,
                title: 'Settings',
                value: '',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              _SectionTitle('Goals'),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.flag,
                title: 'Goal Weight',
                value: '${user.goalWeight.toStringAsFixed(0)} lbs',
                onTap: () async {
                  final controller = TextEditingController(text: user.goalWeight.toStringAsFixed(1));
                  final v = await showDialog<double?>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Set Goal Weight'),
                      content: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: 'e.g. 175.0'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            final val = double.tryParse(controller.text);
                            Navigator.of(context).pop(val);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (v != null) {
                    await widget.userState.updateCurrentUser(user.copyWith(goalWeight: v));
                  }
                },
              ),
              _SettingsTile(
                icon: Icons.local_fire_department,
                title: 'Daily Calorie Goal',
                value: '${user.dailyCaloricGoal} cal',
                onTap: () async {
                  final controller = TextEditingController(text: user.dailyCaloricGoal.toString());
                  final v = await showDialog<int?>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Set Daily Calorie Goal'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'e.g. 2200'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            final val = int.tryParse(controller.text);
                            Navigator.of(context).pop(val);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (v != null) {
                    await widget.userState.updateCurrentUser(user.copyWith(dailyCaloricGoal: v));
                  }
                },
              ),
              _SettingsTile(
                icon: Icons.track_changes,
                title: 'Activity Level',
                value: user.activityLevel,
                onTap: () async {
                  final selected = await showDialog<String?>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: const Text('Select Activity Level'),
                      children: [
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, 'Sedentary'),
                          child: const Text('Sedentary'),
                        ),
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, 'Lightly Active'),
                          child: const Text('Lightly Active'),
                        ),
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, 'Moderately Active'),
                          child: const Text('Moderately Active'),
                        ),
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, 'Very Active'),
                          child: const Text('Very Active'),
                        ),
                      ],
                    ),
                  );
                  if (selected != null) {
                    await widget.userState.updateCurrentUser(user.copyWith(activityLevel: selected));
                  }
                },
              ),
              const SizedBox(height: 24),
              _SectionTitle('Preferences'),
              const SizedBox(height: 12),
              _SettingsTile(
                icon: Icons.track_changes,
                title: 'Daily Steps Goal',
                value: '${user.dailyStepsGoal} steps',
                onTap: () async {
                  final controller = TextEditingController(text: user.dailyStepsGoal.toString());
                  final v = await showDialog<int?>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Set Daily Steps Goal'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'e.g. 10000'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            final val = int.tryParse(controller.text);
                            Navigator.of(context).pop(val);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (v != null) {
                    await widget.userState.updateCurrentUser(user.copyWith(dailyStepsGoal: v));
                  }
                },
              ),
              _SettingsTile(
                icon: Icons.scale,
                title: 'Units',
                value: 'Imperial',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.notifications,
                title: 'Notifications',
                value: 'Enabled',
                onTap: () {},
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onLogout,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableStatCard extends StatefulWidget {
  final String label;
  final String value;
  final String unit;
  final TextInputType keyboardType;
  final Future<bool> Function(String value) onSave;

  const _EditableStatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.keyboardType,
    required this.onSave,
  });

  @override
  State<_EditableStatCard> createState() => _EditableStatCardState();
}

class _EditableStatCardState extends State<_EditableStatCard> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _EditableStatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final ok = await widget.onSave(_controller.text.trim());
    if (!mounted) return;
    if (ok) {
      setState(() => _isEditing = false);
    }
  }

  void _startEdit() {
    setState(() => _isEditing = true);
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  void _cancelEdit() {
    setState(() {
      _controller.text = widget.value;
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: _isEditing ? _cancelEdit : _startEdit,
                child: Icon(
                  _isEditing ? Icons.close : Icons.edit,
                  size: 16,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isEditing)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _controller,
                    keyboardType: widget.keyboardType,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      border: UnderlineInputBorder(),
                    ),
                    onSubmitted: (_) => _handleSave(),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.unit,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _handleSave,
                  child: const Icon(Icons.check, size: 18, color: Palette.forestGreen),
                ),
              ],
            )
          else
            InkWell(
              onTap: _startEdit,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Palette.forestGreen,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (widget.unit.isNotEmpty)
                    Text(
                      widget.unit,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EditableHeightCard extends StatefulWidget {
  final String label;
  final double heightInInches;
  final Future<bool> Function(int feet, int inches) onSave;

  const _EditableHeightCard({
    required this.label,
    required this.heightInInches,
    required this.onSave,
  });

  @override
  State<_EditableHeightCard> createState() => _EditableHeightCardState();
}

class _EditableHeightCardState extends State<_EditableHeightCard> {
  late TextEditingController _feetController;
  late TextEditingController _inchesController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final feet = (widget.heightInInches / 12).floor();
    final inches = (widget.heightInInches % 12).round();
    _feetController = TextEditingController(text: feet.toString());
    _inchesController = TextEditingController(text: inches.toString());
  }

  @override
  void didUpdateWidget(covariant _EditableHeightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.heightInInches != widget.heightInInches) {
      final feet = (widget.heightInInches / 12).floor();
      final inches = (widget.heightInInches % 12).round();
      _feetController.text = feet.toString();
      _inchesController.text = inches.toString();
    }
  }

  @override
  void dispose() {
    _feetController.dispose();
    _inchesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final feet = int.tryParse(_feetController.text.trim()) ?? 0;
    final inches = int.tryParse(_inchesController.text.trim()) ?? -1;
    final ok = await widget.onSave(feet, inches);
    if (!mounted) return;
    if (ok) {
      setState(() => _isEditing = false);
    }
  }

  void _startEdit() {
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    final feet = (widget.heightInInches / 12).floor();
    final inches = (widget.heightInInches % 12).round();
    setState(() {
      _feetController.text = feet.toString();
      _inchesController.text = inches.toString();
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final feet = (widget.heightInInches / 12).floor();
    final inches = (widget.heightInInches % 12).round();
    final display = '$feet\'$inches"';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                onTap: _isEditing ? _cancelEdit : _startEdit,
                child: Icon(
                  _isEditing ? Icons.close : Icons.edit,
                  size: 16,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isEditing)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  child: TextField(
                    controller: _feetController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('\'', style: TextStyle(fontSize: 16, color: Colors.black54)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 40,
                  child: TextField(
                    controller: _inchesController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('"', style: TextStyle(fontSize: 16, color: Colors.black54)),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _handleSave,
                  child: const Icon(Icons.check, size: 18, color: Palette.forestGreen),
                ),
              ],
            )
          else
            InkWell(
              onTap: _startEdit,
              child: Text(
                display,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Palette.forestGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Palette.forestGreen.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Palette.forestGreen,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: value.isNotEmpty
            ? Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              )
            : null,
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.black38,
        ),
        onTap: onTap,
      ),
    );
  }
}
