import 'package:flutter/material.dart';
import 'package:metadash/shared/palette.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _dailyCheckIn = true;
  String _checkInTime = '8:00 AM';
  bool _mealReminders = true;
  String _mealFrequency = 'Every 4 hrs';
  bool _milestoneAlerts = true;
  bool _weeklyDigest = true;
  String _digestDay = 'Sunday';
  bool _streakWarnings = true;
  bool _goalPaceAlerts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text(
            'Configure reminders that keep you on track without noise.',
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          const _NotifSectionLabel(label: 'DAILY CHECK-IN'),
          const SizedBox(height: 8),
          _NotifCard(
            children: [
              _NotifSwitchRow(
                icon: Icons.alarm_outlined,
                title: 'Check-In Reminder',
                subtitle: 'A daily nudge to review your dashboard and log data',
                value: _dailyCheckIn,
                onChanged: (v) => setState(() => _dailyCheckIn = v),
              ),
              if (_dailyCheckIn) ...[
                _NotifDivider(),
                _NotifTapRow(
                  icon: Icons.schedule_outlined,
                  title: 'Reminder Time',
                  value: _checkInTime,
                  onTap: () => _pickTime(context, (t) => _checkInTime = t),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          const _NotifSectionLabel(label: 'MEAL LOGGING'),
          const SizedBox(height: 8),
          _NotifCard(
            children: [
              _NotifSwitchRow(
                icon: Icons.restaurant_outlined,
                title: 'Meal Logging Reminders',
                subtitle: 'Prompted to log meals so your data stays accurate',
                value: _mealReminders,
                onChanged: (v) => setState(() => _mealReminders = v),
              ),
              if (_mealReminders) ...[
                _NotifDivider(),
                _NotifTapRow(
                  icon: Icons.repeat_outlined,
                  title: 'Reminder Frequency',
                  value: _mealFrequency,
                  onTap: () => _showPicker(
                    context,
                    title: 'Reminder Frequency',
                    options: [
                      'Every 2 hrs',
                      'Every 3 hrs',
                      'Every 4 hrs',
                      'Every 5 hrs',
                    ],
                    selected: _mealFrequency,
                    onSelected: (v) => setState(() => _mealFrequency = v),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          const _NotifSectionLabel(label: 'PROGRESS & GOALS'),
          const SizedBox(height: 8),
          _NotifCard(
            children: [
              _NotifSwitchRow(
                icon: Icons.emoji_events_outlined,
                title: 'Milestone Alerts',
                subtitle:
                    'Notified when you hit weight, streak, or goal targets',
                value: _milestoneAlerts,
                onChanged: (v) => setState(() => _milestoneAlerts = v),
              ),
              _NotifDivider(),
              _NotifSwitchRow(
                icon: Icons.flag_outlined,
                title: 'Goal Pace Alerts',
                subtitle:
                    'Warnings when your pace drifts off your target timeline',
                value: _goalPaceAlerts,
                onChanged: (v) => setState(() => _goalPaceAlerts = v),
              ),
              _NotifDivider(),
              _NotifSwitchRow(
                icon: Icons.local_fire_department_outlined,
                title: 'Streak Warnings',
                subtitle: 'Alerted before a logging streak is about to break',
                value: _streakWarnings,
                onChanged: (v) => setState(() => _streakWarnings = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _NotifSectionLabel(label: 'WEEKLY SUMMARY'),
          const SizedBox(height: 8),
          _NotifCard(
            children: [
              _NotifSwitchRow(
                icon: Icons.summarize_outlined,
                title: 'Weekly Digest',
                subtitle: 'A structured end-of-week performance report',
                value: _weeklyDigest,
                onChanged: (v) => setState(() => _weeklyDigest = v),
              ),
              if (_weeklyDigest) ...[
                _NotifDivider(),
                _NotifTapRow(
                  icon: Icons.calendar_today_outlined,
                  title: 'Delivery Day',
                  value: _digestDay,
                  onTap: () => _showPicker(
                    context,
                    title: 'Delivery Day',
                    options: ['Monday', 'Sunday', 'Saturday'],
                    selected: _digestDay,
                    onSelected: (v) => setState(() => _digestDay = v),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    void Function(String) onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => onPicked(picked.format(context)));
    }
  }

  void _showPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
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
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...options.map(
              (o) => ListTile(
                title: Text(o),
                trailing: selected == o
                    ? Icon(Icons.check, color: context.colors.accent)
                    : null,
                onTap: () {
                  onSelected(o);
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

class _NotifSectionLabel extends StatelessWidget {
  final String label;
  const _NotifSectionLabel({required this.label});

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

class _NotifCard extends StatelessWidget {
  final List<Widget> children;
  const _NotifCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.colors.divider.withValues(alpha: 0.08)),
    ),
    child: Column(children: children),
  );
}

class _NotifDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 52,
    color: context.colors.divider.withValues(alpha: 0.6),
  );
}

class _NotifSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifSwitchRow({
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

class _NotifTapRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _NotifTapRow({
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
              style: TextStyle(
                fontSize: 13,
                color: context.colors.accent,
                fontWeight: FontWeight.w600,
              ),
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
