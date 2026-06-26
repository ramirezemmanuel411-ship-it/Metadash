// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:metadash/data/repositories/exercise_repository.dart';
import 'package:metadash/models/exercise_model.dart';
import 'package:metadash/models/hr_zones.dart';
import 'package:metadash/presentation/widgets/duration_selector.dart';
import 'package:metadash/providers/user_state.dart';
import 'package:metadash/services/database_service.dart';
import 'package:metadash/shared/palette.dart';
import 'package:provider/provider.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _WorkoutCategory {
  final String label;
  final IconData icon;
  final List<_WorkoutOption> options;
  const _WorkoutCategory(this.label, this.icon, this.options);
}

class _WorkoutOption {
  final String name;
  final IconData icon;
  const _WorkoutOption(this.name, this.icon);
}

const _categories = [
  _WorkoutCategory('Strength & HIIT', Icons.fitness_center, [
    _WorkoutOption('Strength Training', Icons.fitness_center),
    _WorkoutOption('HIIT', Icons.bolt),
    _WorkoutOption('Circuit Training', Icons.repeat),
    _WorkoutOption('CrossFit', Icons.flag),
    _WorkoutOption('Functional Training', Icons.self_improvement),
  ]),
  _WorkoutCategory('Mind & Body', Icons.self_improvement, [
    _WorkoutOption('Yoga', Icons.self_improvement),
    _WorkoutOption('Pilates', Icons.accessibility_new),
    _WorkoutOption('Stretching', Icons.airline_seat_flat),
    _WorkoutOption('Tai Chi', Icons.blur_circular),
    _WorkoutOption('Barre', Icons.music_note),
  ]),
  _WorkoutCategory('Dance', Icons.music_note, [
    _WorkoutOption('Dance', Icons.music_note),
    _WorkoutOption('Zumba', Icons.headphones),
    _WorkoutOption('Ballet', Icons.directions_walk),
    _WorkoutOption('Hip Hop', Icons.headphones),
    _WorkoutOption('Salsa', Icons.music_note),
  ]),
  _WorkoutCategory('Combat', Icons.sports_mma, [
    _WorkoutOption('Boxing', Icons.sports_mma),
    _WorkoutOption('Kickboxing', Icons.sports_kabaddi),
    _WorkoutOption('Martial Arts', Icons.sports_martial_arts),
    _WorkoutOption('Jiu-Jitsu', Icons.sports_martial_arts),
    _WorkoutOption('Muay Thai', Icons.sports_mma),
  ]),
  _WorkoutCategory('Sports', Icons.sports_basketball, [
    _WorkoutOption('Basketball', Icons.sports_basketball),
    _WorkoutOption('Soccer', Icons.sports_soccer),
    _WorkoutOption('Tennis', Icons.sports_tennis),
    _WorkoutOption('Volleyball', Icons.sports_volleyball),
    _WorkoutOption('Golf', Icons.sports_golf),
  ]),
  _WorkoutCategory('Outdoor & Water', Icons.landscape, [
    _WorkoutOption('Rock Climbing', Icons.terrain),
    _WorkoutOption('Skiing', Icons.downhill_skiing),
    _WorkoutOption('Snowboarding', Icons.snowboarding),
    _WorkoutOption('Surfing', Icons.surfing),
    _WorkoutOption('Kayaking', Icons.kayaking),
    _WorkoutOption('Paddleboarding', Icons.directions_boat),
  ]),
];

const _accent = Color(0xFF4C7FA8);

// ── Main Screen ───────────────────────────────────────────────────────────────

class ExerciseWeightLiftingScreen extends StatefulWidget {
  const ExerciseWeightLiftingScreen({super.key});

  @override
  State<ExerciseWeightLiftingScreen> createState() =>
      _ExerciseWeightLiftingScreenState();
}

class _ExerciseWeightLiftingScreenState
    extends State<ExerciseWeightLiftingScreen> {
  WorkoutIntensity? _intensity;
  int? _duration;
  _WorkoutOption? _activity;
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
    final user = userState.currentUser;
    final age = user?.age ?? 30;
    int rhr = 65;
    try {
      final db = DatabaseService();
      final today = DateTime.now();
      final log = await db.getDailyLogByUserAndDate(
        user?.id ?? 0,
        DateTime(today.year, today.month, today.day),
      );
      if (log?.restingHeartRate != null) rhr = log!.restingHeartRate!;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _zones = HrZones.compute(age: age, restingHr: rhr));
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
    final result = await showModalBottomSheet<_WorkoutOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ActivitySheet(),
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
        title: const Text('Workouts & Sports'),
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
                // Step 1 ── Activity
                const _StepLabel(number: '1', title: 'Activity'),
                const SizedBox(height: 10),
                _ActivityPickerCard(
                  activity: _activity,
                  onTap: _openActivitySheet,
                ),
                const SizedBox(height: 28),

                // Step 2 ── Intensity
                const _StepLabel(number: '2', title: 'Intensity'),
                const SizedBox(height: 10),
                _HeartRateStep(
                  controller: _hrCtrl,
                  heartRate: _heartRate,
                  zones: _zones,
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
                    zones: _zones,
                    onTap: () => setState(() => _intensity = i),
                  ),
                ),
                const SizedBox(height: 28),

                // Step 3 ── Duration
                const _StepLabel(number: '3', title: 'Duration'),
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
          _LogButton(activity: _activity, enabled: _isValid, onPressed: _onLog),
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
  final ValueChanged<int?> onChanged;

  const _HeartRateStep({
    required this.controller,
    required this.heartRate,
    required this.zones,
    required this.onChanged,
  });

  static const _zoneColors = [
    Color(0xFF64B5F6),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFFF7043),
    Color(0xFFE53935),
  ];

  ({String label, String range, Color color}) _zoneInfo(int bpm) {
    final z = zones.zoneFor(bpm);
    return (
      label: zones.labelFor(z),
      range: zones.rangeFor(z),
      color: _zoneColors[z - 1],
    );
  }

  @override
  Widget build(BuildContext context) {
    final zone = heartRate != null ? _zoneInfo(heartRate!) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: heartRate != null ? _accent : context.colors.divider,
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
                  onChanged: (v) {
                    final parsed = int.tryParse(v.trim());
                    onChanged(parsed);
                  },
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
        if (zone != null) ...[
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: zone.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: zone.color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: zone.color),
                const SizedBox(width: 6),
                Text(
                  zone.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: zone.color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '· ${zone.range}',
                  style: TextStyle(
                    fontSize: 12,
                    color: zone.color.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 8),
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
          const SizedBox(height: 6),
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
  const _StepLabel({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: _accent,
            shape: BoxShape.circle,
          ),
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
  final _WorkoutOption? activity;
  final VoidCallback onTap;
  const _ActivityPickerCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasActivity = activity != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: hasActivity
              ? _accent.withValues(alpha: 0.08)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasActivity ? _accent : context.colors.divider,
            width: hasActivity ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasActivity ? _accent : context.colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasActivity ? activity!.icon : Icons.add_rounded,
                color: hasActivity ? Colors.white : context.colors.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasActivity ? activity!.name : 'Choose Activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasActivity
                          ? context.colors.textPrimary
                          : context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasActivity
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
              color: hasActivity ? _accent : context.colors.textMuted,
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
  final HrZones zones;
  final VoidCallback onTap;
  const _IntensityOption({
    required this.intensity,
    required this.selected,
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
  final _WorkoutOption? activity;
  final bool enabled;
  final VoidCallback onPressed;
  const _LogButton({
    required this.activity,
    required this.enabled,
    required this.onPressed,
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
              backgroundColor: _accent,
              disabledBackgroundColor: context.colors.surfaceVariant.withValues(
                alpha: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: enabled ? 2 : 0,
            ),
            child: Text(
              activity != null ? 'Log ${activity!.name}' : 'Log Workout',
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

// ── Activity Bottom Sheet ─────────────────────────────────────────────────────

class _ActivitySheet extends StatefulWidget {
  const _ActivitySheet();

  @override
  State<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<_ActivitySheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_WorkoutOption> get _searchResults {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    return _categories
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
              // Drag handle
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

              // Header row
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

              // Search bar
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

              // Category tabs (hidden while searching)
              if (!isSearching)
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _accent,
                  unselectedLabelColor: context.colors.textSecondary,
                  indicatorColor: _accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: _categories
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

              // Grid content
              Expanded(
                child: isSearching
                    ? _ActivityGrid(
                        options: _searchResults,
                        scrollController: scrollController,
                        onSelect: (opt) => Navigator.pop(context, opt),
                        emptyMessage: 'No activities found',
                      )
                    : TabBarView(
                        controller: _tabs,
                        children: _categories
                            .map(
                              (cat) => _ActivityGrid(
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

// ── Activity grid ─────────────────────────────────────────────────────────────

class _ActivityGrid extends StatelessWidget {
  final List<_WorkoutOption> options;
  final ScrollController scrollController;
  final ValueChanged<_WorkoutOption> onSelect;
  final String? emptyMessage;

  const _ActivityGrid({
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
          _ActivityTile(option: options[i], onTap: () => onSelect(options[i])),
    );
  }
}

// ── Activity tile ─────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final _WorkoutOption option;
  final VoidCallback onTap;
  const _ActivityTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: _accent.withValues(alpha: 0.12),
        highlightColor: _accent.withValues(alpha: 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(option.icon, color: _accent, size: 22),
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
