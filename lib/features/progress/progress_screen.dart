import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:metadash/core/providers/user_state.dart';
import 'package:metadash/core/services/calorie_calculation_service.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:metadash/data/models/daily_log.dart';
import 'package:metadash/features/progress/scale_change_summary_card.dart';
import 'package:provider/provider.dart';

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dash = 4.0;
  const gap = 4.0;
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final dist = math.sqrt(dx * dx + dy * dy);
  if (dist == 0) return;
  final steps = (dist / (dash + gap)).floor();
  final stepX = dx / dist * (dash + gap);
  final stepY = dy / dist * (dash + gap);
  for (int i = 0; i <= steps; i++) {
    final x1 = start.dx + stepX * i;
    final y1 = start.dy + stepY * i;
    final x2 = x1 + dx / dist * dash;
    final y2 = y1 + dy / dist * dash;
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
  }
}

class DataPoint {
  final String id;
  final DateTime date;
  final double value;
  DataPoint({required this.id, required this.date, required this.value});
}

class WeightEntry {
  final String id;
  final DateTime date;
  final double weight;
  WeightEntry({required this.id, required this.date, required this.weight});
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<WeightEntry> _weightEntries = [];
  double _totalFatChange = 0;
  String _bodyStatus = '';
  bool _bodyStatusLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeightData();
    _loadFatSummary();
  }

  Future<void> _loadWeightData() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) {
      setState(() => _weightEntries = []);
      return;
    }
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 90));
    final logs = await userState.db.getDailyLogsByUserAndDateRange(
      user.id!,
      startDate,
      now,
    );
    final weightEntries = logs
        .where((log) => log.weight != null && log.weight! > 0)
        .map(
          (log) => WeightEntry(
            id: 'weight_${log.id ?? log.date.millisecondsSinceEpoch}',
            date: log.date,
            weight: log.weight!,
          ),
        )
        .toList();
    weightEntries.sort((a, b) => a.date.compareTo(b.date));
    if (mounted) setState(() => _weightEntries = weightEntries);
  }

  Future<void> _loadFatSummary() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) {
      if (mounted) setState(() => _bodyStatusLoading = false);
      return;
    }
    try {
      final now = DateTime.now();
      final logs = await userState.db.getDailyLogsByUserAndDateRange(
        user.id!,
        now.subtract(const Duration(days: 90)),
        now,
      );
      if (!mounted) return;
      double total = 0;
      double sumDeficit = 0;
      int count = 0;
      for (final log in logs) {
        final metrics = CalorieCalculationService.calculateDayMetrics(
          user: user,
          log: log,
          settings: userState.metabolicSettings,
          inputs: userState.dataInputsSettings,
        );
        total += metrics.dailyDeficitSurplus / 3500.0;
        sumDeficit += metrics.dailyDeficitSurplus;
        count++;
      }
      final avgDeficit = count > 0 ? sumDeficit / count : 0.0;
      final status = avgDeficit < -100
          ? 'On Track'
          : avgDeficit > 100
          ? 'Surplus'
          : 'Maintenance';
      setState(() {
        _totalFatChange = total;
        _bodyStatus = status;
        _bodyStatusLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _bodyStatusLoading = false);
    }
  }

  Future<void> _addOrUpdateWeight(
    DateTime date,
    double weight, {
    String? id,
  }) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    var log = await userState.db.getDailyLogByUserAndDate(
      user.id!,
      normalizedDate,
    );
    if (log != null) {
      log = log.copyWith(weight: weight);
      await userState.db.updateDailyLog(log);
    } else {
      final now = DateTime.now();
      final newLog = DailyLog(
        userId: user.id!,
        date: normalizedDate,
        caloriesConsumed: 0,
        stepsCount: 0,
        waterIntake: 0.0,
        workoutActivities: [],
        protein: 0,
        carbs: 0,
        fat: 0,
        weight: weight,
        createdAt: now,
        updatedAt: now,
      );
      await userState.db.createDailyLog(newLog);
    }
    await _loadWeightData();
  }

  Future<void> _deleteWeight(String id) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;
    final entry = _weightEntries.firstWhere((e) => e.id == id);
    final normalizedDate = DateTime(
      entry.date.year,
      entry.date.month,
      entry.date.day,
    );
    final log = await userState.db.getDailyLogByUserAndDate(
      user.id!,
      normalizedDate,
    );
    if (log != null) {
      final updatedLog = log.copyWith();
      await userState.db.updateDailyLog(updatedLog);
      await _loadWeightData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentWeight = _weightEntries.isNotEmpty
        ? _weightEntries.last.weight
        : null;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        title: const Text(
          'Progress',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: context.colors.textSecondary,
              size: 22,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: context.colors.textSecondary,
              size: 22,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1 — Body Status
            _BodyStatusCard(
              currentWeight: currentWeight,
              fatChange: _totalFatChange,
              status: _bodyStatus,
              loading: _bodyStatusLoading,
            ),
            const SizedBox(height: 12),
            // 2 — Estimated Fat Change
            _FatChangeSection(),
            const SizedBox(height: 12),
            // 3 — Metabolism / TDEE
            _TDEETrendSection(),
            const SizedBox(height: 12),
            // 4 — Weight
            _WeightSection(
              entries: _weightEntries,
              onAddWeight: (date, weight) => _addOrUpdateWeight(date, weight),
              onDeleteWeight: _deleteWeight,
              onEditWeight: (id, date, weight) =>
                  _addOrUpdateWeight(date, weight, id: id),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fat Change Section ───────────────────────────────────────────────────────

class _FatChangeSection extends StatefulWidget {
  @override
  State<_FatChangeSection> createState() => _FatChangeSectionState();
}

class _FatChangeSectionState extends State<_FatChangeSection> {
  int? _selectedIndex;
  String _filterType = 'ALL';
  List<DataPoint> _allData = [];
  bool _isLoading = true;
  double _fat7d = 0;
  double _fat30d = 0;
  double _avgDeficit = 0;
  double _avgIntake = 0;
  double _avgTdee = 0;
  DateTime? _sinceDate;

  @override
  void initState() {
    super.initState();
    _loadFatChangeData();
  }

  Future<void> _loadFatChangeData() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _allData = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final settings = userState.metabolicSettings;
      final now = DateTime.now();
      final logs = await userState.db.getDailyLogsByUserAndDateRange(
        user.id!,
        now.subtract(const Duration(days: 90)),
        now,
      );
      final dataPoints = <DataPoint>[];
      double cumulativeFatChange = 0.0;
      double sumDeficit = 0, sumIntake = 0, sumTdee = 0;
      int count = 0;
      for (final log in logs) {
        final metrics = CalorieCalculationService.calculateDayMetrics(
          user: user,
          log: log,
          settings: settings,
          inputs: userState.dataInputsSettings,
        );
        cumulativeFatChange += metrics.dailyDeficitSurplus / 3500.0;
        sumDeficit += metrics.dailyDeficitSurplus;
        sumIntake += metrics.caloriesConsumed;
        sumTdee += metrics.tdee;
        count++;
        dataPoints.add(
          DataPoint(
            id: 'fat_${log.date.millisecondsSinceEpoch}',
            date: log.date,
            value: cumulativeFatChange,
          ),
        );
      }
      dataPoints.sort((a, b) => a.date.compareTo(b.date));

      double fat7d = 0, fat30d = 0;
      if (dataPoints.isNotEmpty) {
        final cutoff7 = now.subtract(const Duration(days: 7));
        final cutoff30 = now.subtract(const Duration(days: 30));
        final current = dataPoints.last.value;
        double val7ago = dataPoints.first.value;
        double val30ago = dataPoints.first.value;
        for (final p in dataPoints) {
          if (!p.date.isAfter(cutoff7)) val7ago = p.value;
          if (!p.date.isAfter(cutoff30)) val30ago = p.value;
        }
        fat7d = current - val7ago;
        fat30d = current - val30ago;
      }

      if (mounted) {
        setState(() {
          _allData = dataPoints;
          _isLoading = false;
          _fat7d = fat7d;
          _fat30d = fat30d;
          _avgDeficit = count > 0 ? sumDeficit / count : 0;
          _avgIntake = count > 0 ? sumIntake / count : 0;
          _avgTdee = count > 0 ? sumTdee / count : 0;
          _sinceDate = dataPoints.isNotEmpty ? dataPoints.first.date : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allData = [];
          _isLoading = false;
        });
      }
    }
  }

  List<DataPoint> _filterData(List<DataPoint> data, String filter) {
    final now = DateTime.now();
    DateTime cutoff;
    switch (filter) {
      case '1D':
        cutoff = now.subtract(const Duration(days: 1));
        break;
      case '1W':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case '1M':
        cutoff = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3M':
        cutoff = DateTime(now.year, now.month - 3, now.day);
        break;
      case '1Y':
        cutoff = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'YTD':
        cutoff = DateTime(now.year);
        break;
      default:
        return data;
    }
    return data.where((p) => p.date.isAfter(cutoff)).toList();
  }

  int _tickCount(String f) {
    switch (f) {
      case '1D':
        return 2;
      case '1W':
        return 4;
      case '1M':
        return 5;
      case '3M':
        return 6;
      case '1Y':
        return 6;
      case 'YTD':
        return 6;
      default:
        return 5;
    }
  }

  String _fmtShortDate(DateTime d) {
    const months = [
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
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_isLoading) {
      return const _ProgressEmptyCard(
        icon: Icons.hourglass_empty_rounded,
        message: 'MetaDash is building your metabolic profile.',
      );
    }
    final filteredData = _filterData(_allData, _filterType);
    if (filteredData.isEmpty) {
      return const _ProgressEmptyCard(
        icon: Icons.trending_down_rounded,
        message:
            'Track food and activity for 3 days to begin estimating fat change.',
      );
    }

    final totalDisplay = _allData.isNotEmpty ? _allData.last.value : 0.0;
    final valueColor = totalDisplay <= 0 ? colors.accent : colors.cta;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with icon ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  color: colors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Fat Change',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Your body composition trend',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _FilterPill(
                filterType: _filterType,
                onChanged: (f) => setState(() {
                  _filterType = f;
                  _selectedIndex = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Value (left) + Chart (right) ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${totalDisplay > 0 ? '+' : ''}${totalDisplay.toStringAsFixed(1)} lb',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1,
                        color: valueColor,
                      ),
                    ),
                    if (_sinceDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Since ${_fmtShortDate(_sinceDate!)}',
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _MiniStatCard(
                      value:
                          '${_fat7d > 0 ? '+' : ''}${_fat7d.toStringAsFixed(1)} lb',
                      label: 'Last 7 days',
                      valueColor: _fat7d <= 0 ? colors.accent : colors.cta,
                    ),
                    const SizedBox(height: 6),
                    _MiniStatCard(
                      value:
                          '${_fat30d > 0 ? '+' : ''}${_fat30d.toStringAsFixed(1)} lb',
                      label: 'Last 30 days',
                      valueColor: _fat30d <= 0 ? colors.accent : colors.cta,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 190,
                  child: _InteractiveChart(
                    data: filteredData,
                    color: colors.accent.withValues(alpha: 0.85),
                    selectedIndex: _selectedIndex,
                    onIndexChanged: (i) => setState(() => _selectedIndex = i),
                    showDecimals: true,
                    yAxisInterval: 0.25,
                    rightPadding: 8.0,
                    tickCount: _tickCount(_filterType),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 0.5, color: colors.divider),
          const SizedBox(height: 12),
          // ── What's driving this ───────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 14,
                color: colors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                "What's driving this",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DriverMetric(
                  label: 'Avg Deficit',
                  value: '${_avgDeficit.round()} kcal/day',
                ),
              ),
              Expanded(
                child: _DriverMetric(
                  label: 'Avg Intake',
                  value: '${_avgIntake.round()} kcal/day',
                ),
              ),
              Expanded(
                child: _DriverMetric(
                  label: 'Avg TDEE',
                  value: '${_avgTdee.round()} kcal/day',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── TDEE Trend Section ───────────────────────────────────────────────────────

class _TDEETrendSection extends StatefulWidget {
  @override
  State<_TDEETrendSection> createState() => _TDEETrendSectionState();
}

class _TDEETrendSectionState extends State<_TDEETrendSection> {
  int? _selectedIndex;
  String _filterType = 'ALL';
  List<DataPoint> _allData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTDEEData();
  }

  Future<void> _loadTDEEData() async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _allData = [];
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final settings = userState.metabolicSettings;
      final now = DateTime.now();
      final logs = await userState.db.getDailyLogsByUserAndDateRange(
        user.id!,
        now.subtract(const Duration(days: 90)),
        now,
      );
      final dataPoints = <DataPoint>[];
      for (final log in logs) {
        final metrics = CalorieCalculationService.calculateDayMetrics(
          user: user,
          log: log,
          settings: settings,
          inputs: userState.dataInputsSettings,
        );
        dataPoints.add(
          DataPoint(
            id: 'tdee_${log.date.millisecondsSinceEpoch}',
            date: log.date,
            value: metrics.tdee,
          ),
        );
      }
      dataPoints.sort((a, b) => a.date.compareTo(b.date));
      if (mounted) {
        setState(() {
          _allData = dataPoints;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allData = [];
          _isLoading = false;
        });
      }
    }
  }

  List<DataPoint> _filterData(List<DataPoint> data, String filter) {
    final now = DateTime.now();
    DateTime cutoff;
    switch (filter) {
      case '1D':
        cutoff = now.subtract(const Duration(days: 1));
        break;
      case '1W':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case '1M':
        cutoff = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3M':
        cutoff = DateTime(now.year, now.month - 3, now.day);
        break;
      case '1Y':
        cutoff = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'YTD':
        cutoff = DateTime(now.year);
        break;
      default:
        return data;
    }
    return data.where((p) => p.date.isAfter(cutoff)).toList();
  }

  int _tickCount(String f) {
    switch (f) {
      case '1D':
        return 2;
      case '1W':
        return 4;
      case '1M':
        return 5;
      case '3M':
        return 6;
      case '1Y':
        return 6;
      case 'YTD':
        return 6;
      default:
        return 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_isLoading) {
      return const _ProgressEmptyCard(
        icon: Icons.hourglass_empty_rounded,
        message: 'MetaDash is building your metabolic profile.',
      );
    }
    final filteredData = _filterData(_allData, _filterType);
    if (filteredData.isEmpty) {
      return const _ProgressEmptyCard(
        icon: Icons.bolt_rounded,
        message: 'MetaDash is building your metabolic profile.',
      );
    }

    final currentTDEE = _allData.isNotEmpty ? _allData.last.value : 0.0;
    final first = filteredData.isNotEmpty ? filteredData.first.value : 0.0;
    final last = filteredData.isNotEmpty ? filteredData.last.value : 0.0;
    final diff = last - first;
    final trendLabel = diff > 50
        ? 'Rising ↗'
        : diff < -50
        ? 'Falling ↘'
        : 'Stable →';
    final trendColor = diff > 50
        ? colors.accent
        : diff < -50
        ? colors.cta
        : colors.textSecondary;

    final now = DateTime.now();
    final last30 = _allData
        .where((p) => p.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();
    final avg30 = last30.isNotEmpty
        ? last30.fold(0.0, (s, p) => s + p.value) / last30.length
        : currentTDEE;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with icon ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: colors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Metabolism (TDEE)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Your daily energy expenditure trend',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _FilterPill(
                filterType: _filterType,
                onChanged: (f) => setState(() {
                  _filterType = f;
                  _selectedIndex = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Value (left) + Chart (right) ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currentTDEE.round()} kcal',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Current TDEE',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${avg30.round()} kcal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '30-Day Average',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      trendLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: trendColor,
                      ),
                    ),
                    Text(
                      'Trend',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 175,
                  child: _InteractiveChart(
                    data: filteredData,
                    color: colors.accent.withValues(alpha: 0.8),
                    selectedIndex: _selectedIndex,
                    onIndexChanged: (i) => setState(() => _selectedIndex = i),
                    yAxisInterval: 200.0,
                    rightPadding: 8.0,
                    abbreviateLabels: true,
                    tickCount: _tickCount(_filterType),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Weight Section ───────────────────────────────────────────────────────────

class _WeightSection extends StatefulWidget {
  final List<WeightEntry> entries;
  final Function(DateTime, double) onAddWeight;
  final Function(String) onDeleteWeight;
  final Function(String, DateTime, double) onEditWeight;

  const _WeightSection({
    required this.entries,
    required this.onAddWeight,
    required this.onDeleteWeight,
    required this.onEditWeight,
  });

  @override
  State<_WeightSection> createState() => _WeightSectionState();
}

class _WeightSectionState extends State<_WeightSection> {
  int? _selectedIndex;
  String _filterType = 'ALL';

  List<WeightEntry> _filterEntries(List<WeightEntry> entries, String filter) {
    final now = DateTime.now();
    DateTime cutoff;
    switch (filter) {
      case '1D':
        cutoff = now.subtract(const Duration(days: 1));
        break;
      case '1W':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case '1M':
        cutoff = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3M':
        cutoff = DateTime(now.year, now.month - 3, now.day);
        break;
      case '1Y':
        cutoff = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'YTD':
        cutoff = DateTime(now.year);
        break;
      default:
        return entries;
    }
    return entries.where((e) => e.date.isAfter(cutoff)).toList();
  }

  List<DataPoint> _getScaleData() => _filterEntries(
    widget.entries,
    _filterType,
  ).map((e) => DataPoint(id: e.id, date: e.date, value: e.weight)).toList();

  List<DataPoint> _getTrendData() {
    final filtered = _filterEntries(widget.entries, _filterType);
    if (filtered.isEmpty) return [];
    final last21 = filtered.length > 21
        ? filtered.sublist(filtered.length - 21)
        : filtered;
    const alpha = 0.4;
    double ema = last21.first.weight;
    final points = <DataPoint>[
      DataPoint(id: 'trend_0', date: last21.first.date, value: ema),
    ];
    for (int i = 1; i < last21.length; i++) {
      ema = alpha * last21[i].weight + (1 - alpha) * ema;
      points.add(DataPoint(id: 'trend_$i', date: last21[i].date, value: ema));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final scaleData = _getScaleData();
    final trendData = _getTrendData();

    int tickCountForFilter(String f) {
      switch (f) {
        case '1D':
          return 2;
        case '1W':
          return 4;
        case '1M':
          return 5;
        case '3M':
          return 6;
        case '1Y':
          return 6;
        case 'YTD':
          return 6;
        default:
          return 5;
      }
    }

    final chartTickCount = tickCountForFilter(_filterType);

    final weightChartCard = Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.textMuted.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.monitor_weight_outlined,
                  color: Colors.deepPurple.shade200,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Scale vs. trend vs. estimated fat change',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _FilterPill(
                filterType: _filterType,
                onChanged: (f) => setState(() {
                  _filterType = f;
                  _selectedIndex = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _WeightChart(
              scaleData: scaleData,
              trendData: trendData,
              selectedIndex: _selectedIndex,
              onIndexChanged: (i) => setState(() => _selectedIndex = i),
              tickCount: chartTickCount,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(
                color: context.colors.textPrimary.withValues(alpha: 0.85),
                label:
                    'Scale Weight${scaleData.isNotEmpty ? '  ${scaleData.last.value.toStringAsFixed(1)} lb' : ''}',
              ),
              const SizedBox(height: 6),
              _LegendItem(
                color: context.colors.accent,
                label:
                    'Trend Weight${trendData.isNotEmpty ? '  ${trendData.last.value.toStringAsFixed(1)} lb' : ''}',
                isDot: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          ScaleChangeSummaryCard<WeightEntry>(
            items: widget.entries,
            dateSelector: (e) => e.date,
            valueSelector: (e) => e.weight,
            filter: _filterType,
            label: 'Weight Summary',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: Colors.deepPurple.shade200,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weight fluctuates daily.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Focus on the trend and estimated fat change.',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Learn More',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple.shade200,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Colors.deepPurple.shade200,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    final entriesCard = Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.textMuted.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._filterEntries(widget.entries, _filterType).reversed.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _WeightEntryRow(
                entry: entry,
                onDelete: () => widget.onDeleteWeight(entry.id),
                onEdit: () => _showAddWeightSheet(context, entry: entry),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddWeightSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Weight'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
                foregroundColor: context.colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [weightChartCard, const SizedBox(height: 12), entriesCard],
    );
  }

  void _showAddWeightSheet(BuildContext context, {WeightEntry? entry}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddWeightSheet(
        entry: entry,
        onSave: (date, weight) {
          if (entry != null) {
            widget.onEditWeight(entry.id, date, weight);
          } else {
            widget.onAddWeight(date, weight);
          }
        },
        onDelete: entry != null ? () => widget.onDeleteWeight(entry.id) : null,
      ),
    );
  }
}

// ─── Body Status Card ─────────────────────────────────────────────────────────

class _BodyStatusCard extends StatelessWidget {
  final double? currentWeight;
  final double fatChange;
  final String status;
  final bool loading;

  const _BodyStatusCard({
    required this.currentWeight,
    required this.fatChange,
    required this.status,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (loading) {
      return Container(
        height: 68,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final fatColor = fatChange <= 0 ? colors.accent : colors.cta;
    final statusColor = status == 'On Track'
        ? colors.accent
        : status == 'Surplus'
        ? colors.cta
        : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BODY STATUS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentWeight != null
                          ? '${currentWeight!.toStringAsFixed(1)} lb'
                          : '—',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Current Weight',
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 0.5, height: 48, color: colors.divider),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${fatChange > 0 ? '+' : ''}${fatChange.toStringAsFixed(1)} lb',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: fatColor,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Estimated Fat Change',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 10,
                            color: colors.textMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(width: 0.5, height: 48, color: colors.divider),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              status == 'On Track'
                                  ? Icons.check_circle_rounded
                                  : status == 'Surplus'
                                  ? Icons.arrow_upward_rounded
                                  : Icons.remove_rounded,
                              size: 11,
                              color: statusColor,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                status.isEmpty ? '—' : status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status == 'On Track'
                            ? "You're within\nplan range"
                            : status == 'Surplus'
                            ? 'Above maintenance\nrange'
                            : 'Near maintenance\nrange',
                        style: TextStyle(fontSize: 10, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Progress shared helpers ──────────────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: colors.textMuted)),
        ],
      ),
    );
  }
}

class _DriverMetric extends StatelessWidget {
  final String label, value;
  const _DriverMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: colors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String filterType;
  final void Function(String) onChanged;
  const _FilterPill({required this.filterType, required this.onChanged});

  static const _labelMap = <String, String>{
    'ALL': 'All Time',
    '1Y': '1 Year',
    'YTD': 'YTD',
    '3M': '3 Months',
    '1M': '1 Month',
    '1W': '1 Week',
    '1D': '1 Day',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final displayLabel = _labelMap[filterType] ?? filterType;
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => ['ALL', '1Y', 'YTD', '3M', '1M', '1W']
          .map(
            (k) => PopupMenuItem(
              value: k,
              child: Text(
                _labelMap[k] ?? k,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: colors.divider),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressEmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _ProgressEmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Interactive Chart ────────────────────────────────────────────────────────

class _InteractiveChart extends StatefulWidget {
  final List<DataPoint> data;
  final Color color;
  final int? selectedIndex;
  final Function(int?) onIndexChanged;
  final bool showDecimals;
  final double? yAxisInterval;
  final double rightPadding;
  final int tickCount;
  final bool abbreviateLabels;

  const _InteractiveChart({
    required this.data,
    required this.color,
    required this.selectedIndex,
    required this.onIndexChanged,
    this.showDecimals = false,
    this.yAxisInterval,
    this.rightPadding = 32.0,
    this.tickCount = 5,
    this.abbreviateLabels = false,
  });

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  int? _hoverIndex;
  double? _cachedYMin;
  double? _cachedYMax;

  @override
  void initState() {
    super.initState();
    _recomputeBounds();
  }

  @override
  void didUpdateWidget(covariant _InteractiveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldMin = oldWidget.data.isNotEmpty
        ? oldWidget.data.map((p) => p.value).reduce(math.min)
        : null;
    final oldMax = oldWidget.data.isNotEmpty
        ? oldWidget.data.map((p) => p.value).reduce(math.max)
        : null;
    final newMin = widget.data.isNotEmpty
        ? widget.data.map((p) => p.value).reduce(math.min)
        : null;
    final newMax = widget.data.isNotEmpty
        ? widget.data.map((p) => p.value).reduce(math.max)
        : null;
    const eps = 1e-6;
    if (oldMin == null ||
        newMin == null ||
        (oldMin - newMin).abs() > eps ||
        oldMax == null ||
        newMax == null ||
        (oldMax - newMax).abs() > eps) {
      _recomputeBounds();
    }
  }

  void _recomputeBounds() {
    final data = widget.data;
    if (data.isEmpty) {
      _cachedYMin = null;
      _cachedYMax = null;
      return;
    }
    final minValue = data.map((p) => p.value).reduce(math.min);
    final maxValue = data.map((p) => p.value).reduce(math.max);
    double yMin, yMax;
    if (widget.yAxisInterval != null && widget.yAxisInterval! > 0) {
      final iv = widget.yAxisInterval!;
      yMin = (minValue / iv).floor() * iv;
      yMax = (maxValue / iv).ceil() * iv;
      if (yMax - yMin < iv) yMax = yMin + iv;
    } else {
      final pad = (maxValue - minValue) * 0.1;
      yMin = minValue - pad;
      yMax = maxValue + pad;
      if (yMin == yMax) {
        yMin -= 1;
        yMax += 1;
      }
    }
    _cachedYMin = yMin;
    _cachedYMax = yMax;
  }

  int? _computeIndex(Offset position, double width) {
    if (widget.data.isEmpty) return null;
    const leftPad = 6.0, rightPad = 32.0;
    final plotWidth = width - leftPad - rightPad;
    if (plotWidth <= 0) return 0;
    final clampedX = (position.dx - leftPad).clamp(0.0, plotWidth);
    final fraction = widget.data.length > 1 ? clampedX / plotWidth : 0.0;
    return (fraction * (widget.data.length - 1)).round().clamp(
      0,
      widget.data.length - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (d) => setState(
            () => _hoverIndex = _computeIndex(
              d.localPosition,
              constraints.maxWidth,
            ),
          ),
          onPanUpdate: (d) => setState(
            () => _hoverIndex = _computeIndex(
              d.localPosition,
              constraints.maxWidth,
            ),
          ),
          onTapUp: (_) {
            if (_hoverIndex != null) widget.onIndexChanged(_hoverIndex);
          },
          onPanEnd: (_) {
            if (_hoverIndex != null) widget.onIndexChanged(_hoverIndex);
          },
          child: CustomPaint(
            painter: _ChartPainter(
              data: widget.data,
              color: widget.color,
              selectedIndex: _hoverIndex ?? widget.selectedIndex,
              fixedYMin: _cachedYMin,
              fixedYMax: _cachedYMax,
              showDecimals: widget.showDecimals,
              yAxisInterval: widget.yAxisInterval,
              rightPadding: widget.rightPadding,
              tickCount: widget.tickCount,
              abbreviateLabels: widget.abbreviateLabels,
              // theme-driven drawing colors
              labelColor: context.colors.textSecondary,
              gridLineColor: context.colors.divider,
              tooltipTextColor: context.colors.background,
              tooltipBgColor: context.colors.textPrimary,
            ),
            child: Container(),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<DataPoint> data;
  final Color color;
  final Color labelColor;
  final Color gridLineColor;
  final Color tooltipTextColor;
  final Color tooltipBgColor;
  final int? selectedIndex;
  final double? fixedYMin;
  final double? fixedYMax;
  final bool showDecimals;
  final double? yAxisInterval;
  final double rightPadding;
  final int tickCount;
  final bool abbreviateLabels;

  _ChartPainter({
    required this.data,
    required this.color,
    this.selectedIndex,
    this.fixedYMin,
    this.fixedYMax,
    this.showDecimals = false,
    this.yAxisInterval,
    this.rightPadding = 32.0,
    this.tickCount = 5,
    this.abbreviateLabels = false,
    required this.labelColor,
    required this.gridLineColor,
    required this.tooltipTextColor,
    required this.tooltipBgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final labelStyle = TextStyle(color: labelColor, fontSize: 9);
    const leftPad = 6.0, bottomPad = 18.0, topPad = 6.0;
    final plotWidth = size.width - leftPad - rightPadding;
    final plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    double yMin, yMax;
    if (fixedYMin != null && fixedYMax != null) {
      yMin = fixedYMin!;
      yMax = fixedYMax!;
    } else {
      final minV = data.map((p) => p.value).reduce(math.min);
      final maxV = data.map((p) => p.value).reduce(math.max);
      if (yAxisInterval != null && yAxisInterval! > 0) {
        final iv = yAxisInterval!;
        yMin = (minV / iv).floor() * iv;
        yMax = (maxV / iv).ceil() * iv;
        if (yMax - yMin < iv) yMax = yMin + iv;
      } else {
        final pad = (maxV - minV) * 0.1;
        yMin = minV - pad;
        yMax = maxV + pad;
        if (yMin == yMax) {
          yMin -= 1;
          yMax += 1;
        }
      }
    }

    final gridPaint = Paint()
      ..color = gridLineColor.withValues(alpha: 0.12)
      ..strokeWidth = 0.5;
    final ticks = tickCount > 1 ? tickCount : 5;
    for (int i = 0; i <= ticks; i++) {
      _drawDashedLine(
        canvas,
        Offset(leftPad, topPad + plotHeight * i / ticks),
        Offset(leftPad + plotWidth, topPad + plotHeight * i / ticks),
        gridPaint,
      );
    }
    for (int i = 0; i <= 5; i++) {
      _drawDashedLine(
        canvas,
        Offset(leftPad + plotWidth * i / 5, topPad),
        Offset(leftPad + plotWidth * i / 5, topPad + plotHeight),
        gridPaint,
      );
    }

    if (yAxisInterval != null && yAxisInterval! > 0) {
      final iv = yAxisInterval!;
      final steps = ((yMax - yMin) / iv).round();
      final usedIv = steps > 8 ? iv * (steps / 8).ceil() : iv;
      var lv = yMin;
      while (lv <= yMax + 0.0001) {
        final y =
            topPad + plotHeight - ((lv - yMin) / (yMax - yMin) * plotHeight);
        final text = abbreviateLabels
            ? _formatWithCommas(lv, showDecimals)
            : (showDecimals ? lv.toStringAsFixed(1) : lv.toStringAsFixed(0));
        final tp = TextPainter(
          text: TextSpan(text: text, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height / 2));
        lv += usedIv;
      }
    } else {
      for (int i = 0; i <= ticks; i++) {
        final y = topPad + plotHeight * i / ticks;
        final value = yMax - (yMax - yMin) * (i / ticks);
        final text = abbreviateLabels
            ? _formatWithCommas(value, showDecimals)
            : (showDecimals
                  ? value.toStringAsFixed(1)
                  : value.toStringAsFixed(0));
        final tp = TextPainter(
          text: TextSpan(text: text, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height));
      }
    }

    final xAxisY = topPad + plotHeight;
    for (int i = 0; i <= 5; i++) {
      final frac = data.length == 1 ? 0.0 : i / 5;
      final idx = (frac * (data.length - 1)).round();
      final x = leftPad + plotWidth * frac;
      final tp = TextPainter(
        text: TextSpan(text: _formatDate(data[idx].date), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, xAxisY + 2));
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(leftPad, topPad, plotWidth, plotHeight));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + plotWidth * i / (data.length - 1);
      final y =
          topPad +
          plotHeight -
          ((data[i].value - yMin) / (yMax - yMin) * plotHeight);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    if (selectedIndex != null && selectedIndex! < data.length) {
      final x = leftPad + plotWidth * selectedIndex! / (data.length - 1);
      final y =
          topPad +
          plotHeight -
          ((data[selectedIndex!].value - yMin) / (yMax - yMin) * plotHeight);
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + plotHeight),
        Paint()
          ..color = gridLineColor.withValues(alpha: 0.8)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      final tooltipText =
          '${_formatDate(data[selectedIndex!].date)}\n${showDecimals ? data[selectedIndex!].value.toStringAsFixed(1) : data[selectedIndex!].value.toStringAsFixed(0)}';
      final tp = TextPainter(
        text: TextSpan(
          text: tooltipText,
          style: TextStyle(color: tooltipTextColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final tx = (x + 50 > leftPad + plotWidth) ? x - tp.width - 10 : x + 10;
      final ty = (y - 30).clamp(0.0, size.height - tp.height - 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(tx - 4, ty - 4, tp.width + 8, tp.height + 8),
          const Radius.circular(6),
        ),
        Paint()..color = tooltipBgColor.withValues(alpha: 0.95),
      );
      tp.paint(canvas, Offset(tx, ty));
    }
    canvas.restore();
  }

  String _formatWithCommas(double v, bool dec) {
    final neg = v < 0;
    final text = dec ? v.abs().toStringAsFixed(1) : v.abs().toStringAsFixed(0);
    final parts = text.split('.');
    final buf = StringBuffer();
    for (int i = 0; i < parts[0].length; i++) {
      final pos = parts[0].length - i;
      buf.write(parts[0][i]);
      if (pos > 1 && pos % 3 == 1) buf.write(',');
    }
    var result = buf.toString();
    if (parts.length > 1) result = '$result.${parts[1]}';
    return neg ? '-$result' : result;
  }

  String _formatDate(DateTime date) {
    const m = [
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
    return '${m[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.selectedIndex != selectedIndex;
}

// ─── Weight Chart ─────────────────────────────────────────────────────────────

class _WeightChart extends StatefulWidget {
  final List<DataPoint> scaleData;
  final List<DataPoint> trendData;
  final int? selectedIndex;
  final Function(int?) onIndexChanged;
  final int tickCount;

  const _WeightChart({
    required this.scaleData,
    required this.trendData,
    required this.selectedIndex,
    required this.onIndexChanged,
    this.tickCount = 5,
  });

  @override
  State<_WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<_WeightChart> {
  int? _hoverIndex;
  double? _cachedYMin;
  double? _cachedYMax;

  @override
  void initState() {
    super.initState();
    _recomputeBounds();
  }

  @override
  void didUpdateWidget(covariant _WeightChart old) {
    super.didUpdateWidget(old);
    if (!identical(widget.scaleData, old.scaleData) ||
        !identical(widget.trendData, old.trendData)) {
      _recomputeBounds();
    }
  }

  void _recomputeBounds() {
    final allValues = [
      ...widget.scaleData.map((p) => p.value),
      ...widget.trendData.map((p) => p.value),
    ];
    if (allValues.isEmpty) {
      _cachedYMin = null;
      _cachedYMax = null;
      return;
    }
    final minValue = allValues.reduce(math.min);
    final maxValue = allValues.reduce(math.max);
    final desiredTicks = widget.tickCount > 0 ? widget.tickCount : 5;
    double interval = (maxValue - minValue) / desiredTicks;
    double niceInterval(double v) {
      if (v <= 0) return 1.0;
      final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
      final norm = v / mag;
      return (norm < 1.5
              ? 1.0
              : norm < 3
              ? 2.5
              : norm < 7
              ? 5.0
              : 10.0) *
          mag;
    }

    interval = niceInterval(interval);
    var yMin = (minValue / interval).floor() * interval;
    var yMax = (maxValue / interval).ceil() * interval;
    if (yMax - yMin < interval) yMax = yMin + interval;
    yMin = yMin.clamp(30, 400);
    yMax = yMax.clamp(yMin + interval, 500);
    _cachedYMin = yMin;
    _cachedYMax = yMax;
  }

  int? _computeIndex(Offset position, double width) {
    if (widget.scaleData.isEmpty) return null;
    const leftPad = 6.0, rightPad = 32.0;
    final plotWidth = width - leftPad - rightPad;
    if (plotWidth <= 0) return 0;
    final clampedX = (position.dx - leftPad).clamp(0.0, plotWidth);
    final fraction = widget.scaleData.length > 1 ? clampedX / plotWidth : 0.0;
    return (fraction * (widget.scaleData.length - 1)).round().clamp(
      0,
      widget.scaleData.length - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (d) => setState(
            () => _hoverIndex = _computeIndex(
              d.localPosition,
              constraints.maxWidth,
            ),
          ),
          onPanUpdate: (d) => setState(
            () => _hoverIndex = _computeIndex(
              d.localPosition,
              constraints.maxWidth,
            ),
          ),
          onTapUp: (_) {
            if (_hoverIndex != null) widget.onIndexChanged(_hoverIndex);
          },
          onPanEnd: (_) {
            if (_hoverIndex != null) widget.onIndexChanged(_hoverIndex);
          },
          child: CustomPaint(
            painter: _WeightChartPainter(
              scaleData: widget.scaleData,
              trendData: widget.trendData,
              selectedIndex: _hoverIndex ?? widget.selectedIndex,
              fixedYMin: _cachedYMin,
              fixedYMax: _cachedYMax,
              tickCount: widget.tickCount,
              // theme-driven colors
              labelColor: context.colors.textSecondary,
              gridColor: context.colors.divider.withValues(alpha: 0.5),
              scaleColor: context.colors.cta.withValues(alpha: 0.9),
              trendColor: context.colors.accent.withValues(alpha: 0.7),
              axisColor: context.colors.textMuted,
              centerLineColor: context.colors.divider,
              tooltipTextColor: context.colors.background,
              tooltipBgColor: context.colors.textPrimary,
              selectedLineColor: context.colors.textMuted.withValues(
                alpha: 0.6,
              ),
              selectedCircleColor: context.colors.cta,
            ),
            child: Container(),
          ),
        );
      },
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<DataPoint> scaleData;
  final List<DataPoint> trendData;
  final int? selectedIndex;
  final double? fixedYMin;
  final double? fixedYMax;
  final int tickCount;

  // theme-driven colors
  final Color labelColor;
  final Color gridColor;
  final Color scaleColor;
  final Color trendColor;
  final Color axisColor;
  final Color centerLineColor;
  final Color tooltipTextColor;
  final Color tooltipBgColor;
  final Color selectedLineColor;
  final Color selectedCircleColor;

  _WeightChartPainter({
    required this.scaleData,
    required this.trendData,
    this.selectedIndex,
    this.fixedYMin,
    this.fixedYMax,
    this.tickCount = 5,
    required this.labelColor,
    required this.gridColor,
    required this.scaleColor,
    required this.trendColor,
    required this.axisColor,
    required this.centerLineColor,
    required this.tooltipTextColor,
    required this.tooltipBgColor,
    required this.selectedLineColor,
    required this.selectedCircleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scaleData.isEmpty) return;
    final labelStyle = TextStyle(color: labelColor, fontSize: 9);
    final effectiveTicks = tickCount > 1 ? tickCount : 5;
    const leftPad = 6.0, rightPad = 32.0, bottomPad = 18.0, topPad = 6.0;
    final plotWidth = size.width - leftPad - rightPad;
    final plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final allValues = [
      ...scaleData.map((p) => p.value),
      ...trendData.map((p) => p.value),
    ];
    if (allValues.isEmpty) return;

    double yMin, yMax, interval;
    if (fixedYMin != null && fixedYMax != null) {
      yMin = fixedYMin!;
      yMax = fixedYMax!;
      interval = (yMax - yMin) / effectiveTicks;
    } else {
      final minV = allValues.reduce(math.min);
      final maxV = allValues.reduce(math.max);
      interval = (maxV - minV) / effectiveTicks;
      double niceInterval(double v) {
        if (v <= 0) return 1.0;
        final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
        final norm = v / mag;
        return (norm < 1.5
                ? 1.0
                : norm < 3
                ? 2.5
                : norm < 7
                ? 5.0
                : 10.0) *
            mag;
      }

      interval = niceInterval(interval);
      yMin = (minV / interval).floor() * interval;
      yMax = (maxV / interval).ceil() * interval;
      if (yMax - yMin < interval) yMax = yMin + interval;
      yMin = yMin.clamp(30, 400);
      yMax = yMax.clamp(yMin + interval, 500);
    }

    final steps = ((yMax - yMin) / interval).round();
    final usedIv = steps > 8 ? interval * (steps / 8).ceil() : interval;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    var gv = yMin;
    while (gv <= yMax + 0.0001) {
      final y =
          topPad + plotHeight - ((gv - yMin) / (yMax - yMin) * plotHeight);
      _drawDashedLine(
        canvas,
        Offset(leftPad, y),
        Offset(leftPad + plotWidth, y),
        gridPaint,
      );
      gv += usedIv;
    }
    for (int i = 0; i <= 5; i++) {
      _drawDashedLine(
        canvas,
        Offset(leftPad + plotWidth * i / 5, topPad),
        Offset(leftPad + plotWidth * i / 5, topPad + plotHeight),
        gridPaint,
      );
    }

    var lv = yMin;
    while (lv <= yMax + 0.0001) {
      final y =
          topPad + plotHeight - ((lv - yMin) / (yMax - yMin) * plotHeight);
      final tp = TextPainter(
        text: TextSpan(text: lv.toStringAsFixed(0), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height / 2));
      lv += usedIv;
    }

    final xAxisY = topPad + plotHeight;
    for (int i = 0; i <= 5; i++) {
      final frac = scaleData.length == 1 ? 0.0 : i / 5;
      final idx = (frac * (scaleData.length - 1)).round();
      final x = leftPad + plotWidth * frac;
      final tp = TextPainter(
        text: TextSpan(
          text: _formatDate(scaleData[idx].date),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, xAxisY + 2));
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(leftPad, topPad, plotWidth, plotHeight));
    final scalePaint = Paint()
      ..color = scaleColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final scalePath = Path();
    for (int i = 0; i < scaleData.length; i++) {
      final x = scaleData.length > 1
          ? leftPad + plotWidth * i / (scaleData.length - 1)
          : leftPad + plotWidth / 2;
      final y =
          topPad +
          plotHeight -
          ((scaleData[i].value - yMin) / (yMax - yMin) * plotHeight);
      i == 0 ? scalePath.moveTo(x, y) : scalePath.lineTo(x, y);
      if (!x.isNaN && !y.isNaN) {
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()..color = scaleColor.withValues(alpha: 0.9),
        );
      }
    }
    canvas.drawPath(scalePath, scalePaint);

    final trendPaint = Paint()
      ..color = trendColor
      ..style = PaintingStyle.fill;
    for (final point in trendData) {
      final si = scaleData.indexWhere(
        (p) =>
            p.date.year == point.date.year &&
            p.date.month == point.date.month &&
            p.date.day == point.date.day,
      );
      if (si >= 0) {
        final x = scaleData.length > 1
            ? leftPad + plotWidth * si / (scaleData.length - 1)
            : leftPad + plotWidth / 2;
        final y =
            topPad +
            plotHeight -
            ((point.value - yMin) / (yMax - yMin) * plotHeight);
        if (!x.isNaN && !y.isNaN) {
          canvas.drawCircle(Offset(x, y), 5, trendPaint);
        }
      }
    }

    if (selectedIndex != null && selectedIndex! < scaleData.length) {
      final x = leftPad + plotWidth * selectedIndex! / (scaleData.length - 1);
      final y =
          topPad +
          plotHeight -
          ((scaleData[selectedIndex!].value - yMin) /
              (yMax - yMin) *
              plotHeight);
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + plotHeight),
        Paint()
          ..color = selectedLineColor
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = selectedCircleColor);
      final tooltipText =
          '${_formatDate(scaleData[selectedIndex!].date)}\n${scaleData[selectedIndex!].value.toStringAsFixed(1)} lb';
      final tp = TextPainter(
        text: TextSpan(
          text: tooltipText,
          style: TextStyle(color: tooltipTextColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final tx = (x + 50 > leftPad + plotWidth) ? x - tp.width - 10 : x + 10;
      final ty = (y - 30).clamp(topPad, topPad + plotHeight - tp.height - 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(tx - 4, ty - 4, tp.width + 8, tp.height + 8),
          const Radius.circular(6),
        ),
        Paint()..color = tooltipBgColor,
      );
      tp.paint(canvas, Offset(tx, ty));
    }
    canvas.restore();
  }

  String _formatDate(DateTime date) {
    const m = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${m[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      old.selectedIndex != selectedIndex;
}

// ─── Legend Item ──────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDot;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        isDot
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
            : Container(width: 20, height: 3, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

// ─── Weight Entry Row ─────────────────────────────────────────────────────────

class _WeightEntryRow extends StatelessWidget {
  final WeightEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _WeightEntryRow({
    required this.entry,
    required this.onDelete,
    required this.onEdit,
  });

  String _formatDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: context.colors.cta,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.delete, color: context.colors.onPrimary),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.colors.divider, width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(entry.date),
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                '${entry.weight.toStringAsFixed(1)} lb',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add/Edit Weight Sheet ────────────────────────────────────────────────────

class _AddWeightSheet extends StatefulWidget {
  final WeightEntry? entry;
  final Function(DateTime, double) onSave;
  final VoidCallback? onDelete;

  const _AddWeightSheet({this.entry, required this.onSave, this.onDelete});

  @override
  State<_AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends State<_AddWeightSheet> {
  late DateTime _selectedDate;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.entry?.date ?? DateTime.now();
    _weightController = TextEditingController(
      text: widget.entry?.weight.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.entry != null ? 'Edit Weight' : 'Add Weight',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: Theme.of(context).colorScheme.primary,
                        onPrimary: Theme.of(context).colorScheme.onPrimary,
                        surface: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: context.colors.accent),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Weight (lb)',
                filled: true,
                fillColor: context.colors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.onDelete != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onDelete!();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.cta,
                        side: BorderSide(color: context.colors.cta),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final weight = double.tryParse(_weightController.text);
                      if (weight != null && weight > 0) {
                        widget.onSave(_selectedDate, weight);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.accent,
                      foregroundColor: context.colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const m = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${m[date.month - 1]} ${date.day}, ${date.year}';
  }
}
