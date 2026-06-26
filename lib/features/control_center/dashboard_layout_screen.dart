import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metadash/providers/dashboard_layout_provider.dart';
import 'package:metadash/shared/palette.dart';
import 'package:provider/provider.dart';

class DashboardLayoutScreen extends StatefulWidget {
  const DashboardLayoutScreen({super.key});

  @override
  State<DashboardLayoutScreen> createState() => _DashboardLayoutScreenState();
}

class _DashboardLayoutScreenState extends State<DashboardLayoutScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _draftIds;
  late List<String> _originalIds;
  bool _editMode = false;

  bool get _isDirty {
    if (_draftIds.length != _originalIds.length) return true;
    for (var i = 0; i < _draftIds.length; i++) {
      if (_draftIds[i] != _originalIds[i]) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final provider = context.read<DashboardLayoutProvider>();
    _draftIds = List.from(provider.activeIds);
    _originalIds = List.from(provider.activeIds);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleWidget(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_draftIds.contains(id)) {
        _draftIds.remove(id);
      } else {
        _draftIds.add(id);
      }
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _draftIds.removeAt(oldIndex);
      _draftIds.insert(newIndex, item);
    });
  }

  Future<void> _attemptPop() async {
    if (!_isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _showSaveDialog();
  }

  void _showSaveDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          'Save Layout?',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Would you like to save your changes to the dashboard layout?',
          style: TextStyle(color: context.colors.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text(
              'Discard',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await context.read<DashboardLayoutProvider>().commit(_draftIds);
              if (mounted) Navigator.of(context).pop();
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: context.colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _draftIds.length;
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showSaveDialog();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.background,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          title: const Text('Dashboard Layout'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _attemptPop,
          ),
          actions: [
            if (_editMode)
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _editMode = false);
                },
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.accent,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            else
              TextButton(
                onPressed: _isDirty
                    ? () async {
                        await context.read<DashboardLayoutProvider>().commit(
                          _draftIds,
                        );
                        setState(() => _originalIds = List.from(_draftIds));
                      }
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.accent,
                ),
                child: Text(
                  _isDirty ? 'Save' : 'Saved',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _isDirty
                        ? context.colors.accent
                        : context.colors.textMuted,
                  ),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text(
                    '$activeCount widget${activeCount == 1 ? '' : 's'} active on your dashboard',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: context.colors.accent,
                  unselectedLabelColor: context.colors.textMuted,
                  indicatorColor: context.colors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'DASHBOARD'),
                    Tab(text: 'LIBRARY'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _ActiveTab(
              draftIds: _draftIds,
              editMode: _editMode,
              onReorder: _onReorder,
              onRemove: _toggleWidget,
              onEnterEditMode: () {
                HapticFeedback.mediumImpact();
                setState(() => _editMode = true);
              },
              onResetDefaults: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _draftIds = List.from(
                    DashboardLayoutProvider.kDefaultActiveIds,
                  );
                  _editMode = false;
                });
              },
            ),
            _LibraryTab(draftIds: _draftIds, onToggle: _toggleWidget),
          ],
        ),
      ),
    );
  }
}

class _ActiveTab extends StatelessWidget {
  final List<String> draftIds;
  final bool editMode;
  final ReorderCallback onReorder;
  final ValueChanged<String> onRemove;
  final VoidCallback onEnterEditMode;
  final VoidCallback onResetDefaults;

  const _ActiveTab({
    required this.draftIds,
    required this.editMode,
    required this.onReorder,
    required this.onRemove,
    required this.onEnterEditMode,
    required this.onResetDefaults,
  });

  @override
  Widget build(BuildContext context) {
    if (draftIds.isEmpty) return const _EmptyState();
    final provider = context.watch<DashboardLayoutProvider>();
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: editMode
              ? context.colors.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                editMode ? Icons.edit_outlined : Icons.touch_app_outlined,
                size: 14,
                color: context.colors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  editMode
                      ? 'Tap the red circle to remove  •  Hold & drag to reorder'
                      : 'Long-press any widget to enter edit mode',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: draftIds.length,
            onReorder: onReorder,
            buildDefaultDragHandles: false,
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: 10,
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
            itemBuilder: (context, index) {
              final id = draftIds[index];
              final info = DashboardLayoutProvider.catalog.firstWhere(
                (w) => w.id == id,
                orElse: () => DashWidgetInfo(
                  id: id,
                  name: id,
                  icon: Icons.widgets_outlined,
                  description: '',
                  category: DashWidgetCategory.performance,
                ),
              );
              return _DashboardMirrorCard(
                key: ValueKey(id),
                info: info,
                index: index,
                editMode: editMode,
                onLongPress: onEnterEditMode,
                onRemove: () => onRemove(id),
                size: provider.sizeOf(id),
                onToggleSize: () => provider.setSize(
                  id,
                  provider.sizeOf(id) == DashWidgetSize.compact
                      ? DashWidgetSize.full
                      : DashWidgetSize.compact,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onResetDefaults,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textPrimary,
                backgroundColor: context.colors.surfaceVariant,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: context.divider),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Restore Defaults',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardMirrorCard extends StatelessWidget {
  final DashWidgetInfo info;
  final int index;
  final bool editMode;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;
  final DashWidgetSize size;
  final VoidCallback onToggleSize;

  const _DashboardMirrorCard({
    super.key,
    required this.info,
    required this.index,
    required this.editMode,
    required this.onLongPress,
    required this.onRemove,
    required this.size,
    required this.onToggleSize,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = info.category.color;
    return GestureDetector(
      onLongPress: editMode ? null : onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: editMode
                ? catColor.withValues(alpha: 0.25)
                : context.colors.divider.withValues(alpha: 0.08),
            width: editMode ? 1.5 : 1,
          ),
          boxShadow: editMode
              ? [
                  BoxShadow(
                    color: catColor.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              child: Row(
                children: [
                  if (editMode)
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.remove,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(info.icon, size: 16, color: catColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          info.category.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: catColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggleSize,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: size == DashWidgetSize.compact
                            ? catColor.withValues(alpha: 0.12)
                            : context.colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: size == DashWidgetSize.compact
                              ? catColor.withValues(alpha: 0.4)
                              : context.colors.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            size == DashWidgetSize.compact
                                ? Icons.crop_square_rounded
                                : Icons.crop_landscape_rounded,
                            size: 11,
                            color: size == DashWidgetSize.compact
                                ? catColor
                                : context.colors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            size == DashWidgetSize.compact ? 'Square' : 'Full',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: size == DashWidgetSize.compact
                                  ? catColor
                                  : context.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (editMode)
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: context.colors.textMuted,
                          size: 22,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.drag_handle_rounded,
                      color: context.colors.divider,
                      size: 18,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _WidgetPreview(info: info),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetPreview extends StatelessWidget {
  final DashWidgetInfo info;
  const _WidgetPreview({required this.info});

  @override
  Widget build(BuildContext context) {
    switch (info.id) {
      case 'calorie_balance':
      case 'calories':
        return _CaloriePreview();
      case 'macros':
        return _MacrosPreview();
      case 'water_intake':
        return _WaterPreview();
      case 'steps':
        return _StepsPreview();
      case 'weekly_deficit':
        return _WeeklyDeficitPreview();
      case 'sleep_score':
        return _SleepScorePreview();
      case 'workout_performance':
        return _WorkoutPreview();
      case 'weight':
      case 'weight_trend':
        return _WeightPreview();
      case 'today_summary':
        return _TodaySummaryPreview();
      case 'tdee':
        return _TDEEPreview();
      case 'goal_pace':
        return _GoalPacePreview();
      case 'metabolic_trend':
        return _MetabolicTrendPreview();
      case 'active_calories':
        return _ActiveCaloriesPreview();
      case 'resting_hr':
        return _RestingHRPreview();
      case 'body_composition':
        return _BodyCompositionPreview();
      case 'meal_timing':
        return _MealTimingPreview();
      case 'fiber':
        return _FiberPreview();
      case 'measurements':
        return _MeasurementsPreview();
      case 'recovery_index':
        return _RecoveryPreview();
      case 'stress_level':
        return _StressPreview();
      case 'mindfulness':
        return _MindfulnessPreview();
      case 'workout_consistency':
        return _WorkoutConsistencyPreview();
      case 'movement_streak':
        return _MovementStreakPreview();
      default:
        return _GenericPreview(info: info);
    }
  }
}

class _CaloriePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const consumed = 1240;
    const goal = 2100;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: consumed / goal,
                  strokeWidth: 6,
                  backgroundColor: context.colors.accent.withValues(
                    alpha: 0.12,
                  ),
                  valueColor: AlwaysStoppedAnimation(context.colors.accent),
                ),
                Text(
                  '$consumed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Consumed',
                style: TextStyle(fontSize: 10, color: context.colors.textMuted),
              ),
              Text(
                '$consumed kcal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                'of $goal kcal goal',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacrosPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          _MiniBar(label: 'P', value: 0.72, color: Color(0xFF4C7FA8)),
          SizedBox(height: 6),
          _MiniBar(label: 'C', value: 0.55, color: Color(0xFF2E8B57)),
          SizedBox(height: 6),
          _MiniBar(label: 'F', value: 0.40, color: Color(0xFFEF8C2E)),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 10,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaterPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop, color: Color(0xFF0EA5E9), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '5 / 8 glasses',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.625,
                    minHeight: 5,
                    backgroundColor: Color(0x1A0EA5E9),
                    valueColor: AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_walk, color: Color(0xFFEF8C2E), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '6,240 / 10,000 steps',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.624,
                    minHeight: 5,
                    backgroundColor: Color(0x1AEF8C2E),
                    valueColor: AlwaysStoppedAnimation(Color(0xFFEF8C2E)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyDeficitPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const bars = [0.6, 0.8, 0.3, 0.9, 0.5, 0.7, 0.4];
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars
            .map(
              (h) => Container(
                width: 14,
                height: 50 * h,
                decoration: BoxDecoration(
                  color: context.colors.accent.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SleepScorePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.82,
                  strokeWidth: 5,
                  backgroundColor: Color(0x1A0EA5E9),
                  valueColor: AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
                ),
                Icon(Icons.bedtime, size: 18, color: Color(0xFF0EA5E9)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sleep Score',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
              Text(
                '82 / 100',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const Text(
                '7h 24m  -  Good',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0EA5E9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEF8C2E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fitness_center,
              size: 20,
              color: Color(0xFFEF8C2E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last: Upper Body',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  '45 min  -  6 exercises  -  320 kcal',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monitor_weight_outlined,
            color: Color(0xFF8B5CF6),
            size: 26,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '185.4 lbs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const Text(
                'down 0.6 lbs this week',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2E8B57),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodaySummaryPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          _MiniStat(
            label: 'Calories',
            value: '1,240',
            icon: Icons.bolt,
            color: Color(0xFF4C7FA8),
          ),
          SizedBox(width: 8),
          _MiniStat(
            label: 'Steps',
            value: '6,240',
            icon: Icons.directions_walk,
            color: Color(0xFFEF8C2E),
          ),
          SizedBox(width: 8),
          _MiniStat(
            label: 'Sleep',
            value: '7h 24m',
            icon: Icons.bedtime,
            color: Color(0xFF0EA5E9),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenericPreview extends StatelessWidget {
  final DashWidgetInfo info;
  const _GenericPreview({required this.info});

  @override
  Widget build(BuildContext context) {
    final color = info.category.color;
    final seed = math.Random(info.id.hashCode).nextDouble();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(info.icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.4 + seed * 0.5,
                    minHeight: 4,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(
                      color.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── New preview widgets ───────────────────────────────────────────────────────

class _TDEEPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4C7FA8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 22,
              color: Color(0xFF4C7FA8),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2,480 kcal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                'Est. daily energy expenditure',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalPacePreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E8B57).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'On Target',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E8B57),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '−0.9 lb/wk',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.9,
              minHeight: 6,
              backgroundColor: Color(0x1A2E8B57),
              valueColor: AlwaysStoppedAnimation(Color(0xFF2E8B57)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetabolicTrendPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const bars = [0.88, 0.91, 0.85, 0.93, 0.89, 0.95, 1.0];
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2,320 avg kcal/day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars
                  .map(
                    (h) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Container(
                          height: 30 * h,
                          decoration: BoxDecoration(
                            color: h == 1.0
                                ? const Color(0xFF4C7FA8)
                                : const Color(
                                    0xFF4C7FA8,
                                  ).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCaloriesPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEF8C2E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.whatshot_rounded,
              size: 22,
              color: Color(0xFFEF8C2E),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '342 kcal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                'Strength · 48 min',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestingHRPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF4C7FA8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 22,
              color: Color(0xFF4C7FA8),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '62 bpm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const Text(
                'Normal',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4C7FA8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BodyCompositionPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.accessibility_new_outlined,
              size: 22,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '23.4 BMI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const Text(
                'Normal weight',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E8B57),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MealTimingPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_sunny_outlined,
                size: 13,
                color: Color(0xFF2E8B57),
              ),
              const SizedBox(width: 6),
              Text(
                'First meal',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
              const Spacer(),
              Text(
                '8:24 AM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.nightlight_outlined,
                size: 13,
                color: Color(0xFF2E8B57),
              ),
              const SizedBox(width: 6),
              Text(
                'Last meal',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
              const Spacer(),
              Text(
                '7:18 PM',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_outlined,
                size: 13,
                color: Color(0xFF2E8B57),
              ),
              const SizedBox(width: 6),
              Text(
                'Eating window',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
              const Spacer(),
              const Text(
                '10h 54m',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E8B57),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FiberPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.grass_outlined, color: Color(0xFF2E8B57), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '18 / 25g fiber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.72,
                    minHeight: 5,
                    backgroundColor: Color(0x1A2E8B57),
                    valueColor: AlwaysStoppedAnimation(Color(0xFF2E8B57)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementsPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const _MeasureStat(label: 'Waist', value: '32"'),
          Container(width: 1, height: 32, color: context.colors.divider),
          const _MeasureStat(label: 'Hips', value: '38"'),
          Container(width: 1, height: 32, color: context.colors.divider),
          const _MeasureStat(label: 'Chest', value: '40"'),
        ],
      ),
    );
  }
}

class _MeasureStat extends StatelessWidget {
  final String label;
  final String value;
  const _MeasureStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.colors.textMuted),
        ),
      ],
    );
  }
}

class _RecoveryPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.76,
                  strokeWidth: 5,
                  backgroundColor: Color(0x1A0EA5E9),
                  valueColor: AlwaysStoppedAnimation(Color(0xFF0EA5E9)),
                ),
                Text(
                  '76',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recovery Score',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
              Text(
                '76 / 100',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const Text(
                'Ready',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E8B57),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StressPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.self_improvement_outlined,
            color: Color(0xFF8B5CF6),
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stress Level',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                    ),
                    const Text(
                      'Low',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E8B57),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.25,
                    minHeight: 5,
                    backgroundColor: Color(0x1A8B5CF6),
                    valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MindfulnessPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.spa_outlined, color: Color(0xFF0EA5E9), size: 26),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '12-day streak',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                'Mindfulness practice',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutConsistencyPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const active = [true, true, false, true, true, false, true];
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          return Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: active[i]
                      ? const Color(0xFFEF8C2E).withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active[i]
                        ? const Color(0xFFEF8C2E)
                        : context.colors.divider,
                    width: active[i] ? 1.5 : 1,
                  ),
                ),
                child: Icon(
                  active[i] ? Icons.check_rounded : Icons.remove,
                  size: 12,
                  color: active[i]
                      ? const Color(0xFFEF8C2E)
                      : context.colors.textMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                labels[i],
                style: TextStyle(fontSize: 9, color: context.colors.textMuted),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _MovementStreakPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEF8C2E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              size: 22,
              color: Color(0xFFEF8C2E),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: '12 ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF8C2E),
                        height: 1.0,
                      ),
                    ),
                    TextSpan(
                      text: 'days',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFEF8C2E),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Active streak',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 56,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No active widgets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open the Library tab and tap + to add widgets to your dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  final List<String> draftIds;
  final ValueChanged<String> onToggle;
  const _LibraryTab({required this.draftIds, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const categories = DashWidgetCategory.values;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final widgets = DashboardLayoutProvider.catalog
            .where((w) => w.category == cat)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryHeader(category: cat),
            _LibraryCategoryCard(
              widgets: widgets,
              draftIds: draftIds,
              onToggle: onToggle,
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final DashWidgetCategory category;
  const _CategoryHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(category.icon, size: 15, color: category.color),
          ),
          const SizedBox(width: 8),
          Text(
            category.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCategoryCard extends StatelessWidget {
  final List<DashWidgetInfo> widgets;
  final List<String> draftIds;
  final ValueChanged<String> onToggle;

  const _LibraryCategoryCard({
    required this.widgets,
    required this.draftIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.divider.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: List.generate(widgets.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Divider(
              height: 1,
              indent: 68,
              color: context.colors.divider.withValues(alpha: 0.6),
            );
          }
          final w = widgets[i ~/ 2];
          return _LibraryWidgetRow(
            info: w,
            active: draftIds.contains(w.id),
            onTap: () => onToggle(w.id),
          );
        }),
      ),
    );
  }
}

class _LibraryWidgetRow extends StatelessWidget {
  final DashWidgetInfo info;
  final bool active;
  final VoidCallback onTap;
  const _LibraryWidgetRow({
    required this.info,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = info.category.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(info.icon, size: 19, color: catColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    info.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: active
                    ? catColor.withValues(alpha: 0.15)
                    : context.colors.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? catColor : context.colors.divider,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Icon(
                active ? Icons.check : Icons.add,
                size: 15,
                color: active ? catColor : context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
