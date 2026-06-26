import 'package:flutter/material.dart';
import 'package:metadash/features/control_center/account_screen.dart';
import 'package:metadash/features/control_center/appearance_selector_clean.dart';
import 'package:metadash/features/control_center/dashboard_layout_screen.dart';
import 'package:metadash/features/control_center/data_inputs_screen.dart';
import 'package:metadash/features/control_center/goal_strategy_screen.dart';
import 'package:metadash/features/control_center/interface_workflow_screen.dart';
import 'package:metadash/features/control_center/metabolic_engine_screen.dart';
import 'package:metadash/features/control_center/notifications_screen.dart';
import 'package:metadash/features/control_center/privacy_data_screen.dart';
import 'package:metadash/features/control_center/subscription_screen.dart';
import 'package:metadash/shared/palette.dart';

class ControlCenterScreen extends StatelessWidget {
  const ControlCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: const Text('Control Center')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            const AppearanceSelectorClean(),
            const SizedBox(height: 28),
            const _SectionLabel(label: 'SYSTEM'),
            const SizedBox(height: 10),
            _ControlCard(
              children: [
                _ControlRow(
                  icon: Icons.psychology_outlined,
                  title: 'Metabolic Engine',
                  subtitle: 'Configure energy and fat modeling.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MetabolicEngineScreen(),
                    ),
                  ),
                ),
                _CardDivider(),
                _ControlRow(
                  icon: Icons.flag_outlined,
                  title: 'Goal Strategy',
                  subtitle: 'Configure goal behavior and progress logic.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GoalStrategyScreen(),
                    ),
                  ),
                ),
                _CardDivider(),
                _ControlRow(
                  icon: Icons.input_outlined,
                  title: 'Data & Inputs',
                  subtitle: 'Manage modeling inputs and wearable data.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DataInputsScreen()),
                  ),
                ),
                _CardDivider(),
                _ControlRow(
                  icon: Icons.bar_chart_outlined,
                  title: 'Dashboard Layout',
                  subtitle: 'Control dashboards and modeling visibility.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DashboardLayoutScreen(),
                    ),
                  ),
                ),
                _CardDivider(),
                _ControlRow(
                  icon: Icons.tune_outlined,
                  title: 'Interface & Workflow',
                  subtitle: 'Customize layout and logging behavior.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InterfaceWorkflowScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionLabel(label: 'PERSONAL'),
            const SizedBox(height: 10),
            _ControlCard(
              children: [
                _ControlRow(
                  icon: Icons.person_outline,
                  title: 'Account',
                  subtitle: 'Manage profile information and credentials.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountScreen()),
                  ),
                ),
                _CardDivider(),
                _ControlRow(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Configure reminders and system alerts.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
                _CardDivider(),
                _ControlRow(
                  icon: Icons.lock_outline,
                  title: 'Privacy & Data',
                  subtitle: 'Manage permissions and data controls.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacyDataScreen(),
                    ),
                  ),
                ),
                _CardDivider(),
                _ControlRow(
                  icon: Icons.credit_card_outlined,
                  title: 'Subscription',
                  subtitle: 'Manage plan and billing details.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: context.colors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  final List<Widget> children;
  const _ControlCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: context.colors.textMuted.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 54,
      endIndent: 0,
      color: context.colors.divider,
    );
  }
}

class _ControlRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ControlRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_ControlRow> createState() => _ControlRowState();
}

class _ControlRowState extends State<_ControlRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _isPressed ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: _isPressed
                ? context.colors.surfaceVariant
                : context.colors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                widget.icon,
                size: 26,
                color: context.colors.textSecondary,
                weight: 300,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: context.colors.textSecondary,
                        height: 1.35,
                        letterSpacing: -0.05,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
