import 'package:flutter/material.dart';
import '../../shared/palette.dart';

class InsightsReportingScreen extends StatefulWidget {
  const InsightsReportingScreen({super.key});

  @override
  State<InsightsReportingScreen> createState() => _InsightsReportingScreenState();
}

class _InsightsReportingScreenState extends State<InsightsReportingScreen> {
  String _primaryFocus = 'Daily View';

  void _restoreDefaults() {
    setState(() {
      _primaryFocus = 'Daily View';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text(
          'Dashboard Layout',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: Palette.forestGreen,
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionCard(
            title: 'Primary Focus',
            subtitle: 'Choose how your dashboard is structured.',
            child: Row(
              children: [
                Expanded(
                  child: _FocusOptionCard(
                    title: 'Daily View',
                    selected: _primaryFocus == 'Daily View',
                    onTap: () => setState(() => _primaryFocus = 'Daily View'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FocusOptionCard(
                    title: 'Weekly View',
                    selected: _primaryFocus == 'Weekly View',
                    onTap: () => setState(() => _primaryFocus = 'Weekly View'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _LayoutSection(
            title: 'General',
            buttonLabel: 'Edit Widgets',
            items: const [
              _WidgetItem(icon: Icons.today, name: 'Today\'s Summary'),
              _WidgetItem(icon: Icons.directions_walk, name: 'Steps'),
              _WidgetItem(icon: Icons.trending_down, name: 'Weekly Deficit'),
              _WidgetItem(icon: Icons.show_chart, name: 'Weight Trend'),
            ],
          ),
          const SizedBox(height: 16),
          _LayoutSection(
            title: 'Insights',
            buttonLabel: 'Edit Insights',
            items: const [
              _WidgetItem(icon: Icons.auto_graph, name: 'Metabolic Trend'),
              _WidgetItem(icon: Icons.bolt, name: 'Energy Balance'),
              _WidgetItem(icon: Icons.check_circle_outline, name: 'Consistency'),
              _WidgetItem(icon: Icons.local_fire_department, name: 'Metabolism / TDEE'),
            ],
          ),
          const SizedBox(height: 16),
          _LayoutSection(
            title: 'Nutrition',
            buttonLabel: 'Edit Nutrients',
            items: const [
              _WidgetItem(icon: Icons.restaurant, name: 'Calories', setting: 'Consumed'),
              _WidgetItem(icon: Icons.pie_chart, name: 'Macros Breakdown', setting: 'Consumed'),
              _WidgetItem(icon: Icons.water_drop, name: 'Water Intake'),
            ],
          ),
          const SizedBox(height: 16),
          _LayoutSection(
            title: 'Body Metrics',
            buttonLabel: 'Edit Body Metrics',
            items: const [
              _WidgetItem(icon: Icons.monitor_weight, name: 'Weight'),
              _WidgetItem(icon: Icons.straighten, name: 'Measurements'),
              _WidgetItem(icon: Icons.favorite, name: 'Resting Heart Rate'),
            ],
          ),
          const SizedBox(height: 16),
          _LayoutSection(
            title: 'Habits',
            buttonLabel: 'Edit Habits',
            items: const [
              _WidgetItem(icon: Icons.bedtime, name: 'Sleep'),
              _WidgetItem(icon: Icons.self_improvement, name: 'Mindfulness'),
              _WidgetItem(icon: Icons.directions_run, name: 'Workout Consistency'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _restoreDefaults,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Palette.lightStone,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Restore Default Layout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}

class _FocusOptionCard extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _FocusOptionCard({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? Palette.forestGreen.withValues(alpha: 0.12)
              : Palette.lightStone,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Palette.forestGreen : Colors.black.withValues(alpha: 0.08),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Palette.forestGreen : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _LayoutSection extends StatelessWidget {
  final String title;
  final String buttonLabel;
  final List<_WidgetItem> items;

  const _LayoutSection({
    required this.title,
    required this.buttonLabel,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      subtitle: 'Control what appears in this section.',
      child: Column(
        children: [
          ...items.map((item) => _WidgetRow(item: item)).toList(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: Palette.forestGreen,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetItem {
  final IconData icon;
  final String name;
  final String? setting;

  const _WidgetItem({
    required this.icon,
    required this.name,
    this.setting,
  });
}

class _WidgetRow extends StatelessWidget {
  final _WidgetItem item;

  const _WidgetRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Palette.forestGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: Palette.forestGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (item.setting != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.setting!,
                      style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.55)),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.drag_handle,
            color: Colors.black.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}
