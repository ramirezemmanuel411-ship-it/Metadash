import 'package:flutter/material.dart';
import '../../shared/palette.dart';
import 'metabolic_engine_screen.dart';
import 'goal_strategy_screen.dart';
import 'data_inputs_screen.dart';
import 'dashboard_layout_screen.dart';
import 'interface_workflow_screen.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';
import 'privacy_data_screen.dart';
import 'subscription_screen.dart';
import 'appearance_selector.dart';

class ControlCenterScreen extends StatelessWidget {
  const ControlCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Control Center'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            const AppearanceSelector(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                'SYSTEM',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            _ControlRow(
              icon: Icons.psychology_outlined,
              title: 'Metabolic Engine',
              subtitle: 'Configure energy and fat modeling.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MetabolicEngineScreen()),
              ),
            ),
            _buildDivider(),
            _ControlRow(
              icon: Icons.flag_outlined,
              title: 'Goal Strategy',
              subtitle: 'Configure goal behavior and progress logic.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoalStrategyScreen()),
              ),
            ),
            _buildDivider(),
            _ControlRow(
              icon: Icons.input_outlined,
              title: 'Data & Inputs',
              subtitle: 'Manage modeling inputs and wearable data.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataInputsScreen()),
              ),
            ),
            _buildDivider(),
            _ControlRow(
              icon: Icons.bar_chart_outlined,
              title: 'Dashboard Layout',
              subtitle: 'Control dashboards and modeling visibility.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardLayoutScreen()),
              ),
            ),
            _buildDivider(),
            _ControlRow(
              icon: Icons.tune_outlined,
              title: 'Interface & Workflow',
              subtitle: 'Customize layout and logging behavior.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InterfaceWorkflowScreen()),
              ),
            ),
            const SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                'PERSONAL',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.4),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            _ControlRow(
              icon: Icons.person_outline,
              title: 'Account',
              subtitle: 'Manage profile information and credentials.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              ),
            ),
            _buildDivider(),
            _ControlRow(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Configure reminders and system alerts.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            _buildDivider(),
            _ControlRow(
              icon: Icons.lock_outline,
              title: 'Privacy & Data',
              subtitle: 'Manage permissions and data controls.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyDataScreen()),
              ),
            ),
            _buildDivider(),
            _ControlRow(
              icon: Icons.credit_card_outlined,
              title: 'Subscription',
              subtitle: 'Manage plan and billing details.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 18),
      height: 1,
      color: Colors.black.withOpacity(0.05),
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
            color: _isPressed ? Palette.lightStone : Palette.warmNeutral,
            borderRadius: BorderRadius.circular(10),
          ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              widget.icon,
              size: 26,
              color: Colors.black.withOpacity(0.75),
              weight: 300,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
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
                      color: Colors.black.withOpacity(0.5),
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
              color: Colors.black.withOpacity(0.25),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
