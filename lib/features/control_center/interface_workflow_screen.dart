import 'package:flutter/material.dart';
import '../../shared/palette.dart';

class InterfaceWorkflowScreen extends StatefulWidget {
  const InterfaceWorkflowScreen({super.key});

  @override
  State<InterfaceWorkflowScreen> createState() =>
      _InterfaceWorkflowScreenState();
}

class _InterfaceWorkflowScreenState extends State<InterfaceWorkflowScreen> {
  String _defaultTab = 'Dashboard';
  bool _compactMode = false;
  bool _swipeToLog = true;
  bool _doubleTapDuplicate = false;
  bool _logReminders = true;
  String _summaryTime = '9:00 AM';
  bool _hapticFeedback = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: const Text('Interface & Workflow'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Customize how MetaDash looks and behaves across your daily sessions.',
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          _IWSectionLabel(label: 'DISPLAY'),
          const SizedBox(height: 8),
          _IWCard(
            children: [
              _IWRowTap(
                icon: Icons.tab_outlined,
                title: 'Default Landing Tab',
                subtitle: 'Which screen opens on app launch',
                trailing: Text(
                  _defaultTab,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () => _showTabPicker(context),
              ),
              _IWDivider(),
              _IWRowSwitch(
                icon: Icons.view_compact_outlined,
                title: 'Compact Mode',
                subtitle: 'Tighter spacing — more data visible at a glance',
                value: _compactMode,
                onChanged: (v) => setState(() => _compactMode = v),
              ),
              _IWDivider(),
              _IWRowSwitch(
                icon: Icons.vibration,
                title: 'Haptic Feedback',
                subtitle:
                    'Subtle vibrations for interactions and confirmations',
                value: _hapticFeedback,
                onChanged: (v) => setState(() => _hapticFeedback = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _IWSectionLabel(label: 'QUICK LOG BEHAVIOR'),
          const SizedBox(height: 8),
          _IWCard(
            children: [
              _IWRowSwitch(
                icon: Icons.swipe_right_outlined,
                title: 'Swipe Right to Log',
                subtitle: 'Swipe a diary item to quickly re-log it',
                value: _swipeToLog,
                onChanged: (v) => setState(() => _swipeToLog = v),
              ),
              _IWDivider(),
              _IWRowSwitch(
                icon: Icons.touch_app_outlined,
                title: 'Double-Tap to Duplicate',
                subtitle: 'Double-tap a meal entry to instantly re-add it',
                value: _doubleTapDuplicate,
                onChanged: (v) => setState(() => _doubleTapDuplicate = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _IWSectionLabel(label: 'DAILY SUMMARY'),
          const SizedBox(height: 8),
          _IWCard(
            children: [
              _IWRowSwitch(
                icon: Icons.notifications_outlined,
                title: 'Logging Reminders',
                subtitle: 'Push prompts to log meals throughout the day',
                value: _logReminders,
                onChanged: (v) => setState(() => _logReminders = v),
              ),
              _IWDivider(),
              _IWRowTap(
                icon: Icons.schedule_outlined,
                title: 'Summary Refresh Time',
                subtitle: 'When your daily digest data resets',
                trailing: Text(
                  _summaryTime,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null && mounted) {
                    setState(() => _summaryTime = picked.format(context));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showTabPicker(BuildContext context) {
    final options = ['Dashboard', 'Diary', 'Progress', 'Workout'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Default Landing Tab',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...options.map(
              (o) => ListTile(
                title: Text(o),
                trailing: _defaultTab == o
                    ? Icon(Icons.check, color: context.colors.accent)
                    : null,
                onTap: () {
                  setState(() => _defaultTab = o);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _IWSectionLabel extends StatelessWidget {
  final String label;
  const _IWSectionLabel({required this.label});

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

class _IWCard extends StatelessWidget {
  final List<Widget> children;
  const _IWCard({required this.children});

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
      child: Column(children: children),
    );
  }
}

class _IWDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: context.colors.divider.withValues(alpha: 0.6),
    );
  }
}

class _IWRowSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _IWRowSwitch({
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

class _IWRowTap extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _IWRowTap({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
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
            trailing,
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
