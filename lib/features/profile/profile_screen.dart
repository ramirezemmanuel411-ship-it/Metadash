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
              // Profile Photo
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
              
              // Name
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              
              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Weight',
                      value: user.weight.toStringAsFixed(0),
                      unit: 'lbs',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Height',
                      value: '${(user.height / 12).toStringAsFixed(0)}\'${(user.height % 12).toStringAsFixed(0)}"',
                      unit: '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Age',
                      value: user.age.toString(),
                      unit: 'years',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'BMR',
                      value: user.bmr.toStringAsFixed(0),
                      unit: 'kcal',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Settings Section
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
                onTap: () {
                  // Navigate to settings screen
                },
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
              
              // Logout Button
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Palette.forestGreen,
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
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
        subtitle: value.isNotEmpty ? Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ) : null,
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.black38,
        ),
        onTap: onTap,
      ),
    );
  }
}
