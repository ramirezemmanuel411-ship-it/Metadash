import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metadash/models/user_profile.dart';
import 'package:metadash/providers/user_state.dart';
import 'package:metadash/services/auth_service.dart';
import 'package:metadash/shared/palette.dart';
import 'package:provider/provider.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static const _danger = Color(0xFFB3261E);

  Future<void> _signOut(BuildContext context) async {
    final userState = context.read<UserState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "You'll need to sign in again to access your dashboard.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService().signOut();
    userState.logout();
    // The auth-state stream in AuthGate now routes back to the sign-in screen.
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _monthAbbr(int month) => _months[(month - 1).clamp(0, 11)];

  void _editField(
    BuildContext context,
    UserState userState,
    UserProfile user, {
    required String title,
    required String currentValue,
    required String Function(String) save,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    final controller = TextEditingController(text: currentValue);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: context.colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: keyboardType,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: hint ?? 'Enter $title',
                hintStyle: TextStyle(color: context.colors.textMuted),
                filled: true,
                fillColor: context.colors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final trimmed = controller.text.trim();
                  if (trimmed.isEmpty) return;
                  final errorMsg = save(trimmed);
                  Navigator.of(context).pop();
                  if (errorMsg.isNotEmpty) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(errorMsg)));
                  }
                },
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editHeight(
    BuildContext context,
    UserState userState,
    UserProfile user,
  ) {
    final feetCtrl = TextEditingController(
      text: '${(user.height ~/ 12).toInt()}',
    );
    final inchCtrl = TextEditingController(
      text: '${(user.height % 12).round()}',
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: context.colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Height',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: feetCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: context.colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Feet',
                      hintStyle: TextStyle(color: context.colors.textMuted),
                      filled: true,
                      fillColor: context.colors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixText: 'ft',
                      suffixStyle: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: inchCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(color: context.colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Inches',
                      hintStyle: TextStyle(color: context.colors.textMuted),
                      filled: true,
                      fillColor: context.colors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixText: 'in',
                      suffixStyle: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final feet = int.tryParse(feetCtrl.text.trim()) ?? 0;
                  final inches = int.tryParse(inchCtrl.text.trim()) ?? 0;
                  final totalInches = (feet * 12 + inches).toDouble();
                  if (totalInches <= 0) return;
                  Navigator.of(context).pop();
                  await userState.updateCurrentUser(
                    user.copyWith(height: totalInches),
                  );
                },
                child: const Text(
                  'Save',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();
    final user = userState.currentUser;
    final heightIn = user?.height.round() ?? 0;
    final heightStr = heightIn > 0
        ? "${heightIn ~/ 12}'${heightIn % 12}\""
        : '—';
    final dob = user?.dateOfBirth;
    final dobStr = dob != null
        ? '${_monthAbbr(dob.month)} ${dob.day}, ${dob.year}'
        : '—';
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Profile Banner ───────────────────────────────────────────────
          _AccCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: context.colors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 32,
                          color: context.colors.accent,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: context.colors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colors.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '—',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? '—',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E8B57,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Starter Plan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E8B57),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _AccSectionLabel(label: 'PROFILE'),
          const SizedBox(height: 8),
          _AccCard(
            child: Column(
              children: [
                _AccRow(
                  icon: Icons.badge_outlined,
                  title: 'Display Name',
                  value: user?.name ?? '—',
                  onTap: user == null
                      ? () {}
                      : () => _editField(
                          context,
                          userState,
                          user,
                          title: 'Display Name',
                          currentValue: user.name,
                          save: (v) {
                            userState.updateCurrentUser(user.copyWith(name: v));
                            return '';
                          },
                        ),
                ),
                _AccDivider(),
                _AccRow(
                  icon: Icons.flag_outlined,
                  title: 'Primary Goal',
                  value: user?.activityLevel ?? '—',
                  onTap: () {},
                ),
                _AccDivider(),
                _AccRow(
                  icon: Icons.cake_outlined,
                  title: 'Date of Birth',
                  value: dobStr,
                  onTap: () {},
                ),
                _AccDivider(),
                _AccRow(
                  icon: Icons.height_outlined,
                  title: 'Height',
                  value: heightStr,
                  onTap: user == null
                      ? () {}
                      : () => _editHeight(context, userState, user),
                ),
                _AccDivider(),
                _AccRow(
                  icon: Icons.monitor_weight_outlined,
                  title: 'Current Weight',
                  value: user != null
                      ? '${user.weight.toStringAsFixed(1)} lbs'
                      : '—',
                  onTap: user == null
                      ? () {}
                      : () => _editField(
                          context,
                          userState,
                          user,
                          title: 'Current Weight',
                          currentValue: user.weight.toStringAsFixed(1),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          hint: 'Weight in lbs',
                          save: (v) {
                            final val = double.tryParse(v);
                            if (val == null || val <= 0) {
                              return 'Enter a valid weight';
                            }
                            userState.updateCurrentUser(
                              user.copyWith(weight: val),
                            );
                            return '';
                          },
                        ),
                ),
                _AccDivider(),
                _AccRow(
                  icon: Icons.directions_walk_outlined,
                  title: 'Daily Steps Goal',
                  value: user != null
                      ? '${user.dailyStepsGoal.toString()} steps'
                      : '—',
                  onTap: user == null
                      ? () {}
                      : () => _editField(
                          context,
                          userState,
                          user,
                          title: 'Daily Steps Goal',
                          currentValue: user.dailyStepsGoal.toString(),
                          keyboardType: TextInputType.number,
                          hint: 'Steps per day',
                          save: (v) {
                            final val = int.tryParse(v);
                            if (val == null || val <= 0) {
                              return 'Enter a valid number';
                            }
                            userState.updateCurrentUser(
                              user.copyWith(dailyStepsGoal: val),
                            );
                            return '';
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _AccSectionLabel(label: 'CREDENTIALS'),
          const SizedBox(height: 8),
          _AccCard(
            child: Column(
              children: [
                _AccRow(
                  icon: Icons.email_outlined,
                  title: 'Email Address',
                  value: user?.email ?? '—',
                  onTap: user == null
                      ? () {}
                      : () => _editField(
                          context,
                          userState,
                          user,
                          title: 'Email Address',
                          currentValue: user.email,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'your@email.com',
                          save: (v) {
                            if (!v.contains('@')) return 'Enter a valid email';
                            userState.updateCurrentUser(
                              user.copyWith(email: v),
                            );
                            return '';
                          },
                        ),
                ),
                _AccDivider(),
                _AccRow(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  value: '••••••••',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _AccSectionLabel(label: 'LINKED SERVICES'),
          const SizedBox(height: 8),
          _AccCard(
            child: Column(
              children: [
                const _AccServiceRow(
                  icon: Icons.favorite_border,
                  title: 'Apple Health',
                  connected: true,
                ),
                _AccDivider(),
                const _AccServiceRow(
                  icon: Icons.fitness_center_outlined,
                  title: 'Google Fit',
                  connected: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _AccCard(
            child: InkWell(
              onTap: () => _signOut(context),
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AccSectionLabel extends StatelessWidget {
  final String label;
  const _AccSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: context.colors.textMuted,
      ),
    );
  }
}

class _AccCard extends StatelessWidget {
  final Widget child;
  const _AccCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.divider.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _AccDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 52,
      color: context.colors.divider.withValues(alpha: 0.6),
    );
  }
}

class _AccRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _AccRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.colors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccServiceRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool connected;

  const _AccServiceRow({
    required this.icon,
    required this.title,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: connected
                  ? const Color(0xFF2E8B57).withValues(alpha: 0.12)
                  : context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              connected ? 'Connected' : 'Connect',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: connected
                    ? const Color(0xFF2E8B57)
                    : context.colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
