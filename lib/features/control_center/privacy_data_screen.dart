import 'package:flutter/material.dart';
import '../../shared/palette.dart';

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool _analyticsEnabled = true;
  bool _crashReporting = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: const Text('Privacy & Data'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'You own your data. Control what MetaDash can read, store, and share.',
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          _PrvSectionLabel(label: 'HEALTH PERMISSIONS'),
          const SizedBox(height: 8),
          _PrvCard(
            children: [
              _PrvPermissionRow(
                icon: Icons.directions_walk_outlined,
                title: 'Steps',
                status: 'Allowed',
                allowed: true,
              ),
              _PrvDivider(),
              _PrvPermissionRow(
                icon: Icons.fitness_center_outlined,
                title: 'Workouts',
                status: 'Allowed',
                allowed: true,
              ),
              _PrvDivider(),
              _PrvPermissionRow(
                icon: Icons.restaurant_outlined,
                title: 'Nutrition',
                status: 'Allowed',
                allowed: true,
              ),
              _PrvDivider(),
              _PrvPermissionRow(
                icon: Icons.bedtime_outlined,
                title: 'Sleep',
                status: 'Allowed',
                allowed: true,
              ),
              _PrvDivider(),
              _PrvPermissionRow(
                icon: Icons.favorite_outline,
                title: 'Heart Rate',
                status: 'Not granted',
                allowed: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Manage permission grants in your device Settings → Health.',
              style: TextStyle(fontSize: 12, color: context.colors.textMuted),
            ),
          ),
          const SizedBox(height: 20),
          _PrvSectionLabel(label: 'ANALYTICS & DIAGNOSTICS'),
          const SizedBox(height: 8),
          _PrvCard(
            children: [
              _PrvSwitchRow(
                icon: Icons.bar_chart_outlined,
                title: 'Usage Analytics',
                subtitle: 'Anonymous usage patterns — helps us improve features',
                value: _analyticsEnabled,
                onChanged: (v) => setState(() => _analyticsEnabled = v),
              ),
              _PrvDivider(),
              _PrvSwitchRow(
                icon: Icons.bug_report_outlined,
                title: 'Crash Reporting',
                subtitle: 'Automatic crash logs to help diagnose app issues',
                value: _crashReporting,
                onChanged: (v) => setState(() => _crashReporting = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _PrvSectionLabel(label: 'YOUR DATA'),
          const SizedBox(height: 8),
          _PrvCard(
            children: [
              _PrvTapRow(
                icon: Icons.download_outlined,
                title: 'Export My Data',
                subtitle: 'Download a full archive of your MetaDash data',
                iconColor: context.colors.accent,
                onTap: () {},
              ),
              _PrvDivider(),
              _PrvTapRow(
                icon: Icons.policy_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read how we handle and protect your data',
                iconColor: context.colors.accent,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 28),
          _PrvSectionLabel(label: 'DANGER ZONE'),
          const SizedBox(height: 8),
          _PrvCard(
            children: [
              _PrvTapRow(
                icon: Icons.delete_outline,
                title: 'Delete All Data',
                subtitle: 'Permanently erase all your MetaDash logs and settings',
                iconColor: Colors.red,
                titleColor: Colors.red,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          'Delete All Data?',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          'This will permanently erase all logs, settings, and history. '
          'This action cannot be undone.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _PrvSectionLabel extends StatelessWidget {
  final String label;
  const _PrvSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: context.colors.textMuted,
        ),
      );
}

class _PrvCard extends StatelessWidget {
  final List<Widget> children;
  const _PrvCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colors.divider.withValues(alpha: 0.08),
          ),
        ),
        child: Column(children: children),
      );
}

class _PrvDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 52,
        color: context.colors.divider.withValues(alpha: 0.6),
      );
}

class _PrvPermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final bool allowed;

  const _PrvPermissionRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.allowed,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = allowed ? const Color(0xFF2E8B57) : Colors.orange;
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrvSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrvSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.colors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: context.colors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.colors.accent,
          ),
        ],
      ),
    );
  }
}

class _PrvTapRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color? titleColor;
  final VoidCallback onTap;

  const _PrvTapRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}
