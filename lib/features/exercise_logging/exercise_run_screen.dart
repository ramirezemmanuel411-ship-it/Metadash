// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:metadash/core/providers/user_state.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:metadash/core/shared/widgets/duration_selector.dart';
import 'package:metadash/data/models/exercise_model.dart';
import 'package:metadash/data/models/hr_zones.dart';
import 'package:metadash/data/repositories/exercise_repository.dart';
import 'package:provider/provider.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _CardioOption {
  final String name;
  final IconData icon;
  const _CardioOption(this.name, this.icon);
}

class _CardioCategory {
  final String label;
  final IconData icon;
  final List<_CardioOption> options;
  const _CardioCategory(this.label, this.icon, this.options);
}

const _cardioCategories = [
  _CardioCategory('Running', Icons.directions_run, [
    _CardioOption('Running', Icons.directions_run),
    _CardioOption('Jogging', Icons.directions_run),
    _CardioOption('Sprinting', Icons.speed),
    _CardioOption('Trail Running', Icons.terrain),
    _CardioOption('Treadmill', Icons.directions_run),
  ]),
  _CardioCategory('Cycling', Icons.directions_bike, [
    _CardioOption('Cycling', Icons.directions_bike),
    _CardioOption('Indoor Cycling', Icons.pedal_bike),
    _CardioOption('Mountain Biking', Icons.terrain),
    _CardioOption('Road Biking', Icons.directions_bike),
  ]),
  _CardioCategory('Water', Icons.pool, [
    _CardioOption('Swimming', Icons.pool),
    _CardioOption('Rowing', Icons.rowing),
    _CardioOption('Indoor Rowing', Icons.sports),
    _CardioOption('Kayaking', Icons.kayaking),
    _CardioOption('Paddleboarding', Icons.directions_boat),
  ]),
  _CardioCategory('Machine', Icons.loop, [
    _CardioOption('Elliptical', Icons.loop),
    _CardioOption('Stair Climber', Icons.stairs),
    _CardioOption('Jump Rope', Icons.sports_gymnastics),
    _CardioOption('Rowing Machine', Icons.sports),
    _CardioOption('Ski Erg', Icons.downhill_skiing),
  ]),
  _CardioCategory('Outdoor', Icons.landscape, [
    _CardioOption('Walking', Icons.directions_walk),
    _CardioOption('Hiking', Icons.terrain),
    _CardioOption('Nordic Walking', Icons.directions_walk),
    _CardioOption('Stair Climbing', Icons.stairs),
    _CardioOption('Power Walking', Icons.directions_walk),
  ]),
];

const _cardioAccent = Color(0xFFFF6B35);

// ── Screen ────────────────────────────────────────────────────────────────────

class ExerciseRunScreen extends StatefulWidget {
  const ExerciseRunScreen({super.key});

  @override
  State<ExerciseRunScreen> createState() => _ExerciseRunScreenState();
}

class _ExerciseRunScreenState extends State<ExerciseRunScreen> {
  WorkoutIntensity? _intensity;
  int? _duration;
  _CardioOption? _activity;
  int? _heartRate;
  HrZones _zones = HrZones.defaults();
  final _hrCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    final userState = context.read<UserState>();
    final profile = userState.currentUser;
    if (profile == null) return;
    final userId = profile.id;
    if (userId == null) return;
    // Try to pull today's resting HR from the most recent daily log
    int restingHr = 60; // sensible default
    try {
      final log = await userState.db.getDailyLogByUserAndDate(
        userId,
        DateTime.now(),
      );
      if (log?.restingHeartRate != null && log!.restingHeartRate! > 30) {
        restingHr = log.restingHeartRate!;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _zones = HrZones.compute(age: profile.age, restingHr: restingHr);
    });
  }

  @override
  void dispose() {
    _hrCtrl.dispose();
    super.dispose();
  }

  WorkoutIntensity? _zoneFromBpm(int bpm) {
    final idx = _zones.intensityIndexFor(bpm);
    if (idx == null) return null;
    return WorkoutIntensity.values[idx];
  }

  bool get _isValid =>
      _intensity != null && _duration != null && _duration! > 0;

  Future<void> _openActivitySheet() async {
    final result = await showModalBottomSheet<_CardioOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CardioSheet(),
    );
    if (result != null) setState(() => _activity = result);
  }

  Future<void> _onLog() async {
    if (!_isValid) return;
    try {
      final exercise = Exercise.weightLifting(
        workoutIntensity: _intensity!,
        durationMinutes: _duration!,
        workoutType: _activity?.name,
        avgHeartRate: _heartRate,
      );
      final userState = context.read<UserState>();
      final repo = ExerciseRepository(userState: userState);
      await repo.saveExercise(exercise);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cardio'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                const _StepLabel(
                  number: '1',
                  title: 'Activity',
                  accent: _cardioAccent,
                ),
                const SizedBox(height: 10),
                _ActivityPickerCard(
                  activity: _activity,
                  onTap: _openActivitySheet,
                ),
                const SizedBox(height: 28),
                const _StepLabel(
                  number: '2',
                  title: 'Intensity',
                  accent: _cardioAccent,
                ),
                const SizedBox(height: 10),
                _HeartRateStep(
                  controller: _hrCtrl,
                  heartRate: _heartRate,
                  zones: _zones,
                  accent: _cardioAccent,
                  onChanged: (bpm) {
                    setState(() {
                      _heartRate = bpm;
                      final suggested = bpm != null ? _zoneFromBpm(bpm) : null;
                      if (suggested != null) _intensity = suggested;
                    });
                  },
                ),
                const SizedBox(height: 12),
                ...WorkoutIntensity.values.map(
                  (i) => _IntensityOption(
                    intensity: i,
                    selected: _intensity == i,
                    accent: _cardioAccent,
                    zones: _zones,
                    onTap: () => setState(() => _intensity = i),
                  ),
                ),
                const SizedBox(height: 28),
                const _StepLabel(
                  number: '3',
                  title: 'Duration',
                  accent: _cardioAccent,
                ),
                const SizedBox(height: 10),
                DurationSelector(
                  selectedDuration: _duration,
                  quickSelectOptions: const [20, 30, 45, 60, 90],
                  onChanged: (d) => setState(() => _duration = d),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          _LogButton(
            label: _activity != null ? 'Log ${_activity!.name}' : 'Log Cardio',
            enabled: _isValid,
            onPressed: _onLog,
            accent: _cardioAccent,
          ),
        ],
      ),
    );
  }
}

// ── Heart Rate Step ───────────────────────────────────────────────────────────

class _HeartRateStep extends StatelessWidget {
  final TextEditingController controller;
  final int? heartRate;
  final HrZones zones;
  final Color accent;
  final ValueChanged<int?> onChanged;

  const _HeartRateStep({
    required this.controller,
    required this.heartRate,
    required this.zones,
    required this.accent,
    required this.onChanged,
  });

  static const _zoneColors = [
    Color(0xFF64B5F6), // Z1 blue
    Color(0xFF81C784), // Z2 green
    Color(0xFFFFB74D), // Z3 amber
    Color(0xFFFF7043), // Z4 orange
    Color(0xFFE53935), // Z5 red
  ];

  @override
  Widget build(BuildContext context) {
    final zoneNum = heartRate != null ? zones.zoneFor(heartRate!) : null;
    final zoneColor = zoneNum != null ? _zoneColors[zoneNum - 1] : null;
    final zoneLabel = zoneNum != null ? zones.labelFor(zoneNum) : null;
    final zoneRange = zoneNum != null ? zones.rangeFor(zoneNum) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: heartRate != null ? accent : context.colors.divider,
              width: heartRate != null ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                color: heartRate != null
                    ? Colors.redAccent
                    : context.colors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter HR to auto-set intensity',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: context.colors.textMuted,
                    ),
                    border: InputBorder.none,
                    suffixText: heartRate != null ? 'bpm' : '',
                    suffixStyle: TextStyle(
                      fontSize: 13,
                      color: context.colors.textMuted,
                    ),
                  ),
                  onChanged: (v) => onChanged(int.tryParse(v.trim())),
                ),
              ),
              if (heartRate != null)
                GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged(null);
                  },
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: context.colors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (zoneColor != null) ...[
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: zoneColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: zoneColor.withValues(alpha: 0.4)),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: zoneColor),
                Text(
                  zoneLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: zoneColor,
                  ),
                ),
                Text(
                  '· $zoneRange',
                  style: TextStyle(
                    fontSize: 12,
                    color: zoneColor.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '· intensity auto-set',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Zones based on your age & resting HR (max ${zones.maxHr} bpm)',
            style: TextStyle(fontSize: 11, color: context.colors.textMuted),
          ),
        ],
      ],
    );
  }
}

// ── Step label ────────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  final String number;
  final String title;
  final Color accent;
  const _StepLabel({
    required this.number,
    required this.title,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Activity picker card ──────────────────────────────────────────────────────

class _ActivityPickerCard extends StatelessWidget {
  final _CardioOption? activity;
  final VoidCallback onTap;
  const _ActivityPickerCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final has = activity != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: has
              ? _cardioAccent.withValues(alpha: 0.08)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: has ? _cardioAccent : context.colors.divider,
            width: has ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: has ? _cardioAccent : context.colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                has ? activity!.icon : Icons.add_rounded,
                color: has ? Colors.white : context.colors.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    has ? activity!.name : 'Choose Activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: has
                          ? context.colors.textPrimary
                          : context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    has
                        ? 'Tap to change'
                        : 'Optional · improves calorie accuracy',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: has ? _cardioAccent : context.colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Intensity option ──────────────────────────────────────────────────────────

class _IntensityOption extends StatelessWidget {
  final WorkoutIntensity intensity;
  final bool selected;
  final Color accent;
  final HrZones zones;
  final VoidCallback onTap;
  const _IntensityOption({
    required this.intensity,
    required this.selected,
    required this.accent,
    required this.zones,
    required this.onTap,
  });

  String _hrRange() {
    switch (intensity) {
      case WorkoutIntensity.light:
        return '< ${zones.z3Lo} bpm';
      case WorkoutIntensity.moderate:
        return '${zones.z3Lo}–${zones.z4Lo - 1} bpm';
      case WorkoutIntensity.intense:
        return '${zones.z4Lo}+ bpm';
    }
  }

  int get _flames => intensity.index + 1;

  Color get _flameColor {
    switch (intensity) {
      case WorkoutIntensity.light:
        return const Color(0xFF64B5F6);
      case WorkoutIntensity.moderate:
        return const Color(0xFFFF9800);
      case WorkoutIntensity.intense:
        return const Color(0xFFE53935);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? _flameColor.withValues(alpha: 0.08)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _flameColor : context.colors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Row(
              children: List.generate(3, (i) {
                final lit = i < _flames;
                return Icon(
                  Icons.local_fire_department_rounded,
                  size: 20,
                  color: lit
                      ? (selected
                            ? _flameColor
                            : _flameColor.withValues(alpha: 0.55))
                      : context.colors.surfaceVariant,
                );
              }),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intensity.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? _flameColor
                          : context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${intensity.description} · ${_hrRange()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
              child: Icon(
                Icons.check_circle_rounded,
                color: _flameColor,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Log button ────────────────────────────────────────────────────────────────

class _LogButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final Color accent;
  const _LogButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: accent,
              disabledBackgroundColor: context.colors.surfaceVariant.withValues(
                alpha: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: enabled ? 2 : 0,
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cardio Bottom Sheet ───────────────────────────────────────────────────────

class _CardioSheet extends StatefulWidget {
  const _CardioSheet();

  @override
  State<_CardioSheet> createState() => _CardioSheetState();
}

class _CardioSheetState extends State<_CardioSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _cardioCategories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_CardioOption> get _searchResults {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _cardioCategories
        .expand((c) => c.options)
        .where((o) => o.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.88, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Choose Activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search activities…',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: context.colors.textMuted,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: context.colors.textMuted,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 18,
                                color: context.colors.textMuted,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (!isSearching)
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _cardioAccent,
                  unselectedLabelColor: context.colors.textSecondary,
                  indicatorColor: _cardioAccent,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: _cardioCategories
                      .map(
                        (c) => Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c.icon, size: 14),
                              const SizedBox(width: 5),
                              Text(c.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  dividerColor: Colors.transparent,
                ),
              const SizedBox(height: 6),
              Expanded(
                child: isSearching
                    ? _CardioGrid(
                        options: _searchResults,
                        scrollController: scrollController,
                        onSelect: (opt) => Navigator.pop(context, opt),
                        emptyMessage: 'No activities found',
                      )
                    : TabBarView(
                        controller: _tabs,
                        children: _cardioCategories
                            .map(
                              (cat) => _CardioGrid(
                                options: cat.options,
                                scrollController: scrollController,
                                onSelect: (opt) => Navigator.pop(context, opt),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Cardio grid ───────────────────────────────────────────────────────────────

class _CardioGrid extends StatelessWidget {
  final List<_CardioOption> options;
  final ScrollController scrollController;
  final ValueChanged<_CardioOption> onSelect;
  final String? emptyMessage;

  const _CardioGrid({
    required this.options,
    required this.scrollController,
    required this.onSelect,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty && emptyMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: context.colors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              emptyMessage!,
              style: TextStyle(
                fontSize: 15,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.95,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: options.length,
      itemBuilder: (context, i) =>
          _CardioTile(option: options[i], onTap: () => onSelect(options[i])),
    );
  }
}

class _CardioTile extends StatelessWidget {
  final _CardioOption option;
  final VoidCallback onTap;
  const _CardioTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: _cardioAccent.withValues(alpha: 0.12),
        highlightColor: _cardioAccent.withValues(alpha: 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _cardioAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(option.icon, color: _cardioAccent, size: 22),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                option.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
