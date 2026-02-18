import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../shared/palette.dart';
import '../../shared/user_settings.dart';
// scale change helper is used by the summary card; imported in the card file
import 'scale_change_summary_card.dart';
// removed mini_summary_card.dart uses; ScaleChangeSummaryCard is now generic

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

// Data models
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
  
  
  @override
  void initState() {
    super.initState();
    _initializeMockWeightData();
  }

  void _initializeMockWeightData() {
    // Placeholder data; replace with real weight data from database.
    // Will connect to UserState.db.getWeightByUserId() in future enhancement.
    final now = DateTime.now();
    _weightEntries = List.generate(15, (i) {
      return WeightEntry(
        id: 'weight_$i',
        date: now.subtract(Duration(days: 14 - i)),
        weight: 185.0 - (i * 0.3) + (math.Random().nextDouble() * 0.6 - 0.3),
      );
    });
  }

  void _addOrUpdateWeight(DateTime date, double weight, {String? id}) {
    setState(() {
      // Remove any existing entry for the same day
      final dayStart = DateTime(date.year, date.month, date.day);
      _weightEntries.removeWhere((e) => DateTime(e.date.year, e.date.month, e.date.day).isAtSameMomentAs(dayStart));

      // Add new entry
      _weightEntries.add(WeightEntry(
        id: id ?? 'weight_${DateTime.now().millisecondsSinceEpoch}',
        date: date,
        weight: weight,
      ));

      // Sort by date ascending
      _weightEntries.sort((a, b) => a.date.compareTo(b.date));
    });
  }

  void _deleteWeight(String id) {
    setState(() {
      _weightEntries.removeWhere((e) => e.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentWeight = _weightEntries.isNotEmpty ? _weightEntries.last.weight : null;
    final initialWeight = _weightEntries.isNotEmpty ? _weightEntries.first.weight : null;
    final goalWeight = UserSettings.goalWeight.value;
    double? progressPct;
    if (goalWeight != null && currentWeight != null && initialWeight != null) {
      final denom = (initialWeight - goalWeight);
      if (denom == 0) {
        progressPct = 1.0;
      } else {
        progressPct = ((initialWeight - currentWeight) / denom).clamp(0.0, 1.0);
      }
    }
    return Scaffold(
      backgroundColor: Palette.warmNeutral,
      appBar: AppBar(
        backgroundColor: Palette.warmNeutral,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Progress',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Goal/Current weight summary box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Palette.lightStone,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Weight', style: TextStyle(fontSize: 14, color: Colors.black54)),
                          const SizedBox(height: 6),
                          Text(
                            currentWeight != null ? '${currentWeight.toStringAsFixed(1)} lb' : '--',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Goal', style: TextStyle(fontSize: 14, color: Colors.black54)),
                          const SizedBox(height: 6),
                          ValueListenableBuilder<double?>(
                            valueListenable: UserSettings.goalWeight,
                            builder: (context, goal, _) => Text(
                              goal != null ? '${goal.toStringAsFixed(1)} lb' : 'Not set',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<double?>(
                    valueListenable: UserSettings.goalWeight,
                    builder: (context, goal, _) {
                      final displayPct = progressPct ?? 0.0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: displayPct,
                            color: Palette.forestGreen,
                            backgroundColor: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(displayPct * 100).toStringAsFixed(0)}% toward goal',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            _FatChangeSection(),
            const SizedBox(height: 16),
            _TDEETrendSection(),
            const SizedBox(height: 16),
            // (removed duplicate summary card; per-chart summaries are shown under each chart)
            const SizedBox(height: 16),
            _WeightSection(
              entries: _weightEntries,
              onAddWeight: (date, weight) => _addOrUpdateWeight(date, weight),
              onDeleteWeight: _deleteWeight,
              onEditWeight: (id, date, weight) => _addOrUpdateWeight(date, weight, id: id),
            ),
          ],
        ),
      ),
    );
  }
}

// Fat Change Section
class _FatChangeSection extends StatefulWidget {
  @override
  State<_FatChangeSection> createState() => _FatChangeSectionState();
}

class _FatChangeSectionState extends State<_FatChangeSection> {
  int? _selectedIndex;
  String _filterType = 'ALL';
  late final List<DataPoint> _allData;

  List<DataPoint> _generateFatChangeData() {
    // Placeholder data; replace with real fat change from daily_log deficit/surplus.
    // Planned mapping: daily_logs.map((log) => log.calorieDeficit / 3500).
    final now = DateTime.now();
    return List.generate(30, (i) {
      final date = now.subtract(Duration(days: 29 - i));
      final value = -5.0 + (i * -0.03) + (math.Random().nextDouble() * 0.3 - 0.15);
      return DataPoint(id: 'fat_$i', date: date, value: value);
    });
  }

  @override
  void initState() {
    super.initState();
    _allData = _generateFatChangeData();
  }

  List<DataPoint> _filterData(List<DataPoint> data, String filter) {
    final now = DateTime.now();
    DateTime cutoffDate;
    switch (filter) {
      case '1D':
        cutoffDate = now.subtract(const Duration(days: 1));
        break;
      case '1W':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case '1M':
        cutoffDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3M':
        cutoffDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case '1Y':
        cutoffDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'YTD':
        cutoffDate = DateTime(now.year, 1, 1);
        break;
      default:
        return data;
    }
    return data.where((p) => p.date.isAfter(cutoffDate)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _allData;
    final filteredData = _filterData(data, _filterType);
    final last7Days = filteredData.length >= 7 ? filteredData.sublist(filteredData.length - 7) : filteredData;
    final last7Sum = last7Days.isNotEmpty ? last7Days.fold(0.0, (sum, p) => sum + p.value) / last7Days.length : 0.0;
    
        return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartCard(
          title: 'Fat Change',
          subtitle: 'Estimated fat change over time',
          data: filteredData,
          color: Colors.blue.withValues(alpha: 0.8),
          selectedIndex: _selectedIndex,
          onIndexChanged: (index) {
            // parent received index
            setState(() => _selectedIndex = index);
          },
          summaryText: 'Last 7 days: ${last7Sum.toStringAsFixed(1)} lb',
          showDecimals: true,
          yAxisInterval: 0.25,
          filterType: _filterType,
          onFilterChanged: (filter) => setState(() => _filterType = filter),
          attachedSummary: ScaleChangeSummaryCard<DataPoint>(
            items: filteredData,
            dateSelector: (p) => p.date,
            valueSelector: (p) => p.value,
            filter: _filterType,
            label: 'Fat Change Summary',
          ),
        ),
      ],
    );
  }
}

// TDEE Trend Section
class _TDEETrendSection extends StatefulWidget {
  @override
  State<_TDEETrendSection> createState() => _TDEETrendSectionState();
}

class _TDEETrendSectionState extends State<_TDEETrendSection> {
  int? _selectedIndex;
  String _filterType = 'ALL';
  
  List<DataPoint> _generateTDEEData() {
    // Placeholder data; replace with real TDEE from daily_log calories + activity.
    // Will be replaced with actual TDEE calculations per day.
    final now = DateTime.now();
    return List.generate(30, (i) {
      final date = now.subtract(Duration(days: 29 - i));
      final value = 2600.0 + (i * 1.5) + (math.Random().nextDouble() * 80 - 40);
      return DataPoint(id: 'tdee_$i', date: date, value: value);
    });
  }

  late final List<DataPoint> _allData;

  @override
  void initState() {
    super.initState();
    _allData = _generateTDEEData();
  }

  List<DataPoint> _filterData(List<DataPoint> data, String filter) {
    final now = DateTime.now();
    DateTime cutoffDate;
    switch (filter) {
      case '1D':
        cutoffDate = now.subtract(const Duration(days: 1));
        break;
      case '1W':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case '1M':
        cutoffDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3M':
        cutoffDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case '1Y':
        cutoffDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'YTD':
        cutoffDate = DateTime(now.year, 1, 1);
        break;
      default:
        return data;
    }
    return data.where((p) => p.date.isAfter(cutoffDate)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _allData;
    final filteredData = _filterData(data, _filterType);
    final first = filteredData.isNotEmpty ? filteredData.first.value : 0.0;
    final last = filteredData.isNotEmpty ? filteredData.last.value : 0.0;
    final diff = last - first;
    final symbol = diff > 5 ? '↑' : (diff < -5 ? '↓' : '—');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartCard(
          title: 'Daily Energy Expenditure',
          subtitle: 'Daily energy expenditure',
          data: filteredData,
          color: Colors.green.withValues(alpha: 0.8),
          selectedIndex: _selectedIndex,
          onIndexChanged: (index) {
            // parent received index
            setState(() => _selectedIndex = index);
          },
          summaryText: 'Trend: $symbol',
          showDecimals: false,
          // Use a smaller interval for TDEE so the Y-axis is more informative
          yAxisInterval: 50.0,
          rightPadding: 50.0,
          abbreviateLabels: true,
          filterType: _filterType,
          onFilterChanged: (filter) => setState(() => _filterType = filter),
            attachedSummary: ScaleChangeSummaryCard<DataPoint>(
            items: filteredData,
            dateSelector: (p) => p.date,
            valueSelector: (p) => p.value,
            filter: _filterType,
              label: 'Daily Energy Expenditure Summary',
              unit: 'Kcal',
          ),
        ),
      ],
    );
  }
}

// Weight Section with chart and log
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
    DateTime cutoffDate;
    switch (filter) {
      case '1D':
        cutoffDate = now.subtract(const Duration(days: 1));
        break;
      case '1W':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case '1M':
        cutoffDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3M':
        cutoffDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case '1Y':
        cutoffDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case 'YTD':
        cutoffDate = DateTime(now.year, 1, 1);
        break;
      default:
        return entries;
    }
    return entries.where((e) => e.date.isAfter(cutoffDate)).toList();
  }

  List<DataPoint> _getScaleData() {
    final filteredEntries = _filterEntries(widget.entries, _filterType);
    return filteredEntries.map((e) => DataPoint(
      id: e.id,
      date: e.date,
      value: e.weight,
    )).toList();
  }

  List<DataPoint> _getTrendData() {
    final filteredEntries = _filterEntries(widget.entries, _filterType);
    if (filteredEntries.isEmpty) return [];
    
    final last21Days = filteredEntries.length > 21 
        ? filteredEntries.sublist(filteredEntries.length - 21)
        : filteredEntries;
    
    if (last21Days.isEmpty) return [];
    
    final alpha = 0.4;
    double ema = last21Days.first.weight;
    final trendPoints = <DataPoint>[
      DataPoint(id: 'trend_0', date: last21Days.first.date, value: ema)
    ];
    
    for (int i = 1; i < last21Days.length; i++) {
      ema = alpha * last21Days[i].weight + (1 - alpha) * ema;
      trendPoints.add(DataPoint(
        id: 'trend_$i',
        date: last21Days[i].date,
        value: ema,
      ));
    }
    
    return trendPoints;
  }

  double? _get7DayAverage() {
    final filteredEntries = _filterEntries(widget.entries, _filterType);
    if (filteredEntries.isEmpty) return null;
    
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final last7Days = filteredEntries.where((e) => 
      endOfToday.difference(e.date).inDays < 7
    ).toList();
    
    if (last7Days.isEmpty) return null;
    
    return last7Days.fold(0.0, (sum, e) => sum + e.weight) / last7Days.length;
  }

  @override
  Widget build(BuildContext context) {
    final scaleData = _getScaleData();
    final trendData = _getTrendData();
    final avg7 = _get7DayAverage();

    // Map filter type to tick count for Y-axis (shorter ranges -> fewer ticks)
    int tickCountForFilter(String f) {
      switch (f) {
        case '1D': return 2;
        case '1W': return 4;
        case '1M': return 5;
        case '3M': return 6;
        case '1Y': return 6;
        case 'YTD': return 6;
        default: return 5;
      }
    }
    final chartTickCount = tickCountForFilter(_filterType);

    // Main weight chart card (contains chart, legend, and scale-change summary)
    final weightChartCard = Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Weight',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scale weight',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (filter) => setState(() => _filterType = filter),
                itemBuilder: (context) => ['1D', '1W', '1M', '3M', '1Y', 'YTD', 'ALL']
                    .map((label) => PopupMenuItem(
                          value: label,
                          child: Text(label, style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Palette.forestGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _filterType,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Palette.warmNeutral,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Palette.warmNeutral, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Chart
          SizedBox(
            height: 200,
            child: _WeightChart(
              scaleData: scaleData,
              trendData: trendData,
              selectedIndex: _selectedIndex,
              onIndexChanged: (index) => setState(() => _selectedIndex = index),
              tickCount: chartTickCount,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Legend
          Row(
            children: [
              _LegendItem(color: Colors.orange.withValues(alpha: 0.9), label: 'Scale'),
              const SizedBox(width: 16),
              _LegendItem(color: Colors.purple.withValues(alpha: 0.7), label: 'Trend', isDot: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '7 Day Average: ${avg7 != null ? avg7.toStringAsFixed(1) : '—'} lb',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // Scale change summary for weight
          ScaleChangeSummaryCard<WeightEntry>(
            items: widget.entries,
            dateSelector: (e) => e.date,
            valueSelector: (e) => e.weight,
            filter: _filterType,
            label: 'Weight Summary',
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    // Separate card for entries list + Add button
    final entriesCard = Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weight entries list
          ..._filterEntries(widget.entries, _filterType).reversed.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _WeightEntryRow(
              entry: entry,
              onDelete: () => widget.onDeleteWeight(entry.id),
              onEdit: () => _showAddWeightSheet(context, entry: entry),
            ),
          )),
          const SizedBox(height: 8),
          // Add Weight button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddWeightSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Weight'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.forestGreen,
                foregroundColor: Palette.warmNeutral,
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

    // Return a Column with the chart card followed by the entries card
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        weightChartCard,
        const SizedBox(height: 12),
        entriesCard,
      ],
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

// Chart Card widget for Fat Change and TDEE
class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<DataPoint> data;
  final Color color;
  final int? selectedIndex;
  final Function(int?) onIndexChanged;
  final String summaryText;
  final bool showDecimals;
  final double? yAxisInterval;
  final double rightPadding;
  final bool abbreviateLabels;
  final String? filterType;
  final Function(String)? onFilterChanged;
  final Widget? attachedSummary;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.data,
    required this.color,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.summaryText,
    this.showDecimals = false,
    this.yAxisInterval,
    this.rightPadding = 32.0,
    this.abbreviateLabels = false,
    this.filterType,
    this.onFilterChanged,
    this.attachedSummary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (filterType != null && onFilterChanged != null)
                PopupMenuButton<String>(
                  onSelected: onFilterChanged,
                  itemBuilder: (context) => ['1D', '1W', '1M', '3M', '1Y', 'YTD', 'ALL']
                      .map((label) => PopupMenuItem(
                            value: label,
                            child: Text(label, style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Palette.forestGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          filterType!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Palette.warmNeutral,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Palette.warmNeutral, size: 16),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: _InteractiveChart(
              data: data,
              color: color,
              selectedIndex: selectedIndex,
              onIndexChanged: onIndexChanged,
              showDecimals: showDecimals,
              yAxisInterval: yAxisInterval,
              rightPadding: rightPadding,
              // Determine tick count from filterType when available
              tickCount: filterType != null ? _tickCountForFilter(filterType!) : 5,
              abbreviateLabels: abbreviateLabels,
              // allow callers to optionally clamp Y bounds for stability
              minY: (title == 'TDEE') ? 1200.0 : (title == 'Fat Change' ? -10.0 : null),
              maxY: (title == 'TDEE') ? 4000.0 : (title == 'Fat Change' ? 10.0 : null),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summaryText,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          if (attachedSummary != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            attachedSummary!,
          ],
        ],
      ),
    );
  }

  int _tickCountForFilter(String f) {
    switch (f) {
      case '1D': return 2;
      case '1W': return 4;
      case '1M': return 5;
      case '3M': return 6;
      case '1Y': return 6;
      case 'YTD': return 6;
      default: return 5;
    }
  }
}

// Interactive Chart widget
class _InteractiveChart extends StatefulWidget {
  final List<DataPoint> data;
  final Color color;
  final int? selectedIndex;
  final Function(int?) onIndexChanged;
  final bool showDecimals;
  final double? yAxisInterval;
  final double rightPadding;
  final int tickCount;
  final double? minY;
  final double? maxY;
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
    this.minY,
    this.maxY,
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
    // Recompute only when the data's min/max change meaningfully (avoid identity-based churn)
    final oldMin = oldWidget.data.isNotEmpty ? oldWidget.data.map((p) => p.value).reduce(math.min) : null;
    final oldMax = oldWidget.data.isNotEmpty ? oldWidget.data.map((p) => p.value).reduce(math.max) : null;
    final newMin = widget.data.isNotEmpty ? widget.data.map((p) => p.value).reduce(math.min) : null;
    final newMax = widget.data.isNotEmpty ? widget.data.map((p) => p.value).reduce(math.max) : null;
    bool needs = false;
    const eps = 1e-6;
    if (oldMin == null || newMin == null) {
      needs = true;
    } else if ((oldMin - newMin).abs() > eps) {
      needs = true;
    }
    if (oldMax == null || newMax == null) {
      needs = true;
    } else if ((oldMax - newMax).abs() > eps) {
      needs = true;
    }
    if (needs) _recomputeBounds();
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
    // If explicit clamps provided, use them as base
    final clampMin = widget.minY;
    final clampMax = widget.maxY;
    if (widget.yAxisInterval != null && widget.yAxisInterval! > 0) {
      final interval = widget.yAxisInterval!;
      var yMin = (minValue / interval).floor() * interval;
      var yMax = (maxValue / interval).ceil() * interval;
      if (yMax - yMin < interval) yMax = yMin + interval;
      // apply clamps if provided (keep bounds inside the clamp range)
      if (clampMin != null) yMin = math.max(yMin, clampMin);
      if (clampMax != null) yMax = math.min(yMax, clampMax);
      // ensure a reasonable min span relative to data to avoid jitter
      final span = yMax - yMin;
      final minSpan = math.max(interval, (maxValue - minValue).abs() * 0.15);
      if (span < minSpan) {
        final mid = (yMax + yMin) / 2.0;
        yMin = mid - minSpan / 2.0;
        yMax = mid + minSpan / 2.0;
      }
      _cachedYMin = yMin;
      _cachedYMax = yMax;
    } else {
      final padding = (maxValue - minValue) * 0.1;
      var yMin = minValue - padding;
      var yMax = maxValue + padding;
      if (yMin == yMax) {
        yMin -= 1;
        yMax += 1;
      }
      // apply clamps if provided (keep bounds inside the clamp range)
      if (clampMin != null) yMin = math.max(yMin, clampMin);
      if (clampMax != null) yMax = math.min(yMax, clampMax);
      // enforce a minimum span so tiny variations don't rescale the chart while dragging
      final currentSpan = yMax - yMin;
      // pick an absolute minimum span based on magnitude
      double absoluteMin;
      final absMax = math.max(yMax.abs(), yMin.abs());
      if (absMax < 10) {
        absoluteMin = 1.0;
      } else if (absMax < 100) {
        absoluteMin = 5.0;
      } else if (absMax < 1000) {
        absoluteMin = 50.0;
      } else {
        absoluteMin = 100.0;
      }
      final minSpan = math.max(absoluteMin, (maxValue - minValue).abs() * 0.2);
      if (currentSpan < minSpan) {
        final mid = (yMax + yMin) / 2.0;
        yMin = mid - minSpan / 2.0;
        yMax = mid + minSpan / 2.0;
      }
      _cachedYMin = yMin;
      _cachedYMax = yMax;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            final idx = _computeIndex(details.localPosition, constraints.maxWidth);
            setState(() => _hoverIndex = idx);
          },
          onPanUpdate: (details) {
            final idx = _computeIndex(details.localPosition, constraints.maxWidth);
            setState(() => _hoverIndex = idx);
          },
          onTapUp: (_) {
            if (_hoverIndex != null) {
              widget.onIndexChanged(_hoverIndex);
            }
          },
          onPanEnd: (_) {
            if (_hoverIndex != null) {
              widget.onIndexChanged(_hoverIndex);
            }
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
            ),
            child: Container(),
          ),
        );
      },
    );
  }

  // Removed: previously unused helper _handleTouch is omitted; touch handled inline.

  int? _computeIndex(Offset position, double width) {
    if (widget.data.isEmpty) return null;
    const leftPad = 6.0;
    final plotWidth = width - leftPad - widget.rightPadding;
    if (plotWidth <= 0) return 0;
    final clampedX = (position.dx - leftPad).clamp(0.0, plotWidth);
    final fraction = widget.data.length > 1 ? clampedX / plotWidth : 0.0;
    final index = (fraction * (widget.data.length - 1)).round().clamp(0, widget.data.length - 1);
    return index;
  }
}

// Chart Painter
class _ChartPainter extends CustomPainter {
  final List<DataPoint> data;
  final Color color;
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Slightly smaller axis label font for readability
    final labelStyle = const TextStyle(color: Colors.black54, fontSize: 9);
    const leftPad = 6.0;
    const bottomPad = 18.0;
    const topPad = 6.0;

    final plotWidth = size.width - leftPad - rightPadding;
    final plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Calculate bounds (use fixed if provided to avoid rescaling during hover)
    double yMin, yMax;
    if (fixedYMin != null && fixedYMax != null) {
      yMin = fixedYMin!;
      yMax = fixedYMax!;
    } else {
      final minValue = data.map((p) => p.value).reduce(math.min);
      final maxValue = data.map((p) => p.value).reduce(math.max);
      // Calculate Y-axis bounds based on interval if specified
      if (yAxisInterval != null && yAxisInterval! > 0) {
        final interval = yAxisInterval!;
        yMin = (minValue / interval).floor() * interval;
        yMax = (maxValue / interval).ceil() * interval;
        if (yMax - yMin < interval) yMax = yMin + interval;
      } else {
        final padding = (maxValue - minValue) * 0.1;
        yMin = minValue - padding;
        yMax = maxValue + padding;
        if (yMin == yMax) {
          yMin -= 1;
          yMax += 1;
        }
      }
    }

    // Draw gridlines (dashed)
    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.5;

    // Draw horizontal gridlines at Y-axis label positions
    if (yAxisInterval != null && yAxisInterval! > 0) {
      final interval = yAxisInterval!;
      double gridStartValue = yMin;
      // Cap the number of Y labels to avoid overlapping text (max ~8)
      int steps = ((yMax - yMin) / interval).round();
      double usedInterval = interval;
      if (steps > 8) {
        final factor = (steps / 8).ceil();
        usedInterval = interval * factor;
        // snap bounds to the new interval
        yMin = (yMin / usedInterval).floor() * usedInterval;
        yMax = (yMax / usedInterval).ceil() * usedInterval;
      }
      while (gridStartValue <= yMax) {
        final normalizedY = (gridStartValue - yMin) / (yMax - yMin);
        final y = topPad + plotHeight - (normalizedY * plotHeight);
        _drawDashedLine(canvas, Offset(leftPad, y), Offset(leftPad + plotWidth, y), gridPaint);
        gridStartValue += usedInterval;
      }
    } else {
      final effectiveTicks = tickCount > 1 ? tickCount : 5;
      for (int i = 0; i <= effectiveTicks; i++) {
        final y = topPad + plotHeight * i / effectiveTicks;
        _drawDashedLine(canvas, Offset(leftPad, y), Offset(leftPad + plotWidth, y), gridPaint);
      }
    }

    // Vertical gridlines
    for (int i = 0; i <= 5; i++) {
      final x = leftPad + plotWidth * i / 5;
      _drawDashedLine(canvas, Offset(x, topPad), Offset(x, topPad + plotHeight), gridPaint);
    }

    // Axes removed for cleaner look
    final xAxisY = topPad + plotHeight;

    // Y-axis labels (right aligned)
    if (yAxisInterval != null && yAxisInterval! > 0) {
      final interval = yAxisInterval!;
      int steps = ((yMax - yMin) / interval).round();
      double usedInterval = interval;
      if (steps > 8) {
        final factor = (steps / 8).ceil();
        usedInterval = interval * factor;
      }
      double labelValue = yMin;
      while (labelValue <= yMax + 0.0001) {
        final normalizedY = (labelValue - yMin) / (yMax - yMin);
        final y = topPad + plotHeight - (normalizedY * plotHeight);
        final labelText = abbreviateLabels
          ? _formatWithCommas(labelValue, showDecimals)
          : (showDecimals ? labelValue.toStringAsFixed(1) : labelValue.toStringAsFixed(0));
        final tp = TextPainter(
          text: TextSpan(text: labelText, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height / 2));
        labelValue += usedInterval;
      }
    } else {
      final effectiveTicks = tickCount > 1 ? tickCount : 5;
      for (int i = 0; i <= effectiveTicks; i++) {
        final y = topPad + plotHeight * i / effectiveTicks;
        final value = yMax - (yMax - yMin) * (i / effectiveTicks);
        final labelText = abbreviateLabels
          ? _formatWithCommas(value, showDecimals)
          : (showDecimals ? value.toStringAsFixed(1) : value.toStringAsFixed(0));
        final tp = TextPainter(
          text: TextSpan(text: labelText, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height));
      }
    }

    // X-axis labels (month/day)
    const xTicks = 5;
    for (int i = 0; i <= xTicks; i++) {
      final frac = data.length == 1 ? 0.0 : i / xTicks;
      final idx = (frac * (data.length - 1)).round();
      final x = leftPad + plotWidth * frac;
      final tp = TextPainter(
        text: TextSpan(text: _formatDate(data[idx].date), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, xAxisY + 2));
    }

    // Clip to plot area to keep drawings inside axes
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(leftPad, topPad, plotWidth, plotHeight));

    // Draw line
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + plotWidth * i / (data.length - 1);
      final y = topPad + plotHeight - ((data[i].value - yMin) / (yMax - yMin) * plotHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Draw selection overlay
    if (selectedIndex != null && selectedIndex! < data.length) {
      final x = leftPad + plotWidth * selectedIndex! / (data.length - 1);
      final y = topPad + plotHeight - ((data[selectedIndex!].value - yMin) / (yMax - yMin) * plotHeight);

      // Vertical line
      final linePaint = Paint()
        ..color = Colors.black38
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(x, topPad), Offset(x, topPad + plotHeight), linePaint);

      // Dot
      canvas.drawCircle(Offset(x, y), 5, dotPaint);

      // Tooltip background
      final tooltipText = '${_formatDate(data[selectedIndex!].date)}\n${showDecimals ? data[selectedIndex!].value.toStringAsFixed(1) : data[selectedIndex!].value.toStringAsFixed(0)}';
      final textPainter = TextPainter(
        text: TextSpan(
          text: tooltipText,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final tooltipX = (x + 50 > size.width) ? x - textPainter.width - 10 : x + 10;
      final tooltipY = (y - 30).clamp(0.0, size.height - textPainter.height - 10);

      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX - 4, tooltipY - 4, textPainter.width + 8, textPainter.height + 8),
        const Radius.circular(6),
      );

      canvas.drawRRect(tooltipRect, Paint()..color = Colors.black87);
      textPainter.paint(canvas, Offset(tooltipX, tooltipY));
    }

    canvas.restore();
  }

  String _formatWithCommas(double v, bool showDecimals) {
    final negative = v < 0;
    final absVal = v.abs();
    final text = showDecimals ? absVal.toStringAsFixed(1) : absVal.toStringAsFixed(0);
    final parts = text.split('.');
    var intPart = parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final pos = intPart.length - i;
      buffer.write(intPart[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write(',');
    }
    var result = buffer.toString();
    if (parts.length > 1) result = '$result.${parts[1]}';
    return negative ? '-$result' : result;
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex;
}

// Weight Chart with scale line and trend dots
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
  void didUpdateWidget(covariant _WeightChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.scaleData, oldWidget.scaleData) || !identical(widget.trendData, oldWidget.trendData)) {
      _recomputeBounds();
    }
  }

  void _recomputeBounds() {
    final allValues = [...widget.scaleData.map((p) => p.value), ...widget.trendData.map((p) => p.value)];
    if (allValues.isEmpty) {
      _cachedYMin = null;
      _cachedYMax = null;
      return;
    }
    final minValue = allValues.reduce(math.min);
    final maxValue = allValues.reduce(math.max);
    final rawRange = maxValue - minValue;
    final desiredTicks = widget.tickCount > 0 ? widget.tickCount : 5;
    double interval = rawRange / (desiredTicks > 0 ? desiredTicks : 5);
    double niceInterval(double v) {
      if (v <= 0) return 1.0;
      final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
      final norm = v / mag;
      double niceNorm;
      if (norm < 1.5) {
        niceNorm = 1.0;
      } else if (norm < 3) {
        niceNorm = 2.5;
      } else if (norm < 7) {
        niceNorm = 5.0;
      } else {
        niceNorm = 10.0;
      }
      return niceNorm * mag;
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            // Show transient hover on tap down but don't commit selection yet.
            final idx = _computeIndex(details.localPosition, constraints.maxWidth);
            setState(() => _hoverIndex = idx);
          },
          onPanUpdate: (details) {
            final idx = _computeIndex(details.localPosition, constraints.maxWidth);
            setState(() => _hoverIndex = idx);
          },
          onTapUp: (_) {
            // Commit selection on tap release and keep hover state so visuals remain identical.
            if (_hoverIndex != null) widget.onIndexChanged(_hoverIndex);
          },
          onPanEnd: (_) {
            // Commit selection on pan end and keep hover so the overlay doesn't jump.
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
            ),
            child: Container(),
          ),
        );
      },
    );
  }

  // Removed: previously unused helper _handleTouch for weight chart; touch handled inline.

  int? _computeIndex(Offset position, double width) {
    if (widget.scaleData.isEmpty) return null;
    const leftPad = 6.0;
    const rightPad = 32.0;
    final plotWidth = width - leftPad - rightPad;
    if (plotWidth <= 0) return 0;
    final clampedX = (position.dx - leftPad).clamp(0.0, plotWidth);
    final fraction = widget.scaleData.length > 1 ? clampedX / plotWidth : 0.0;
    final index = (fraction * (widget.scaleData.length - 1)).round().clamp(0, widget.scaleData.length - 1);
    return index;
  }
}

// Weight Chart Painter
class _WeightChartPainter extends CustomPainter {
  final List<DataPoint> scaleData;
  final List<DataPoint> trendData;
  final int? selectedIndex;
  final double? fixedYMin;
  final double? fixedYMax;
  final int tickCount;

  _WeightChartPainter({
    required this.scaleData,
    required this.trendData,
    this.selectedIndex,
    this.fixedYMin,
    this.fixedYMax,
    this.tickCount = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scaleData.isEmpty) return;

    // Make Y-axis label font slightly smaller
    final labelStyle = const TextStyle(color: Colors.black54, fontSize: 9);
    final effectiveTickCount = tickCount > 1 ? tickCount : 5;
    const leftPad = 6.0;
    const rightPad = 32.0;
    const bottomPad = 18.0;
    const topPad = 6.0;

    final plotWidth = size.width - leftPad - rightPad;
    final plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    // Calculate bounds (use fixed values when provided to prevent rescaling during hover)
    final allValues = [...scaleData.map((p) => p.value), ...trendData.map((p) => p.value)];
    if (allValues.isEmpty) return;
    double yMin, yMax, interval;
    if (fixedYMin != null && fixedYMax != null) {
      yMin = fixedYMin!;
      yMax = fixedYMax!;
      interval = (yMax - yMin) / (effectiveTickCount > 0 ? effectiveTickCount : 5);
    } else {
      final minValue = allValues.reduce(math.min);
      final maxValue = allValues.reduce(math.max);
      final rawRange = maxValue - minValue;
      final desiredTicks = effectiveTickCount;
      interval = rawRange / (desiredTicks > 0 ? desiredTicks : 5);

      // Round interval to a "nice" value (0.1, 0.25, 0.5, 1, 2.5, 5, 10, ...)
      double niceInterval(double v) {
        if (v <= 0) return 1.0;
        final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
        final norm = v / mag;
        double niceNorm;
        if (norm < 1.5) {
          niceNorm = 1.0;
        } else if (norm < 3) {
          niceNorm = 2.5;
        } else if (norm < 7) {
          niceNorm = 5.0;
        } else {
          niceNorm = 10.0;
        }
        return niceNorm * mag;
      }

      interval = niceInterval(interval);

      yMin = (minValue / interval).floor() * interval;
      yMax = (maxValue / interval).ceil() * interval;

      // Ensure at least one interval between min and max
      if (yMax - yMin < interval) {
        yMax = yMin + interval;
      }

      // Clamp to reasonable weight ranges
      yMin = yMin.clamp(30, 400);
      yMax = yMax.clamp(yMin + interval, 500);
    }

    // Draw gridlines (dashed) - Draw horizontal gridlines at Y-axis label positions
    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.5;

    // Limit number of Y-axis lines/labels to avoid overlap
    int steps = ((yMax - yMin) / interval).round();
    double usedInterval = interval;
    if (steps > 8) {
      final factor = (steps / 8).ceil();
      usedInterval = interval * factor;
      yMin = (yMin / usedInterval).floor() * usedInterval;
      yMax = (yMax / usedInterval).ceil() * usedInterval;
    }

    double gridValue = yMin;
    while (gridValue <= yMax + 0.0001) {
      final normalizedY = (gridValue - yMin) / (yMax - yMin);
      final y = topPad + plotHeight - (normalizedY * plotHeight);
      _drawDashedLine(canvas, Offset(leftPad, y), Offset(leftPad + plotWidth, y), gridPaint);
      gridValue += usedInterval;
    }
    
    // Vertical gridlines
    for (int i = 0; i <= 5; i++) {
      final x = leftPad + plotWidth * i / 5;
      _drawDashedLine(canvas, Offset(x, topPad), Offset(x, topPad + plotHeight), gridPaint);
    }

    // Axes removed for cleaner look
    final xAxisY = topPad + plotHeight;

    // Y-axis labels (right aligned) - at each interval
    double labelValue = yMin;
    while (labelValue <= yMax + 0.0001) {
      final normalizedY = (labelValue - yMin) / (yMax - yMin);
      final y = topPad + plotHeight - (normalizedY * plotHeight);
      final tp = TextPainter(
        text: TextSpan(text: labelValue.toStringAsFixed(0), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height / 2));
      labelValue += usedInterval;
    }

    // X-axis labels
    const xTicks = 5;
    for (int i = 0; i <= xTicks; i++) {
      final frac = scaleData.length == 1 ? 0.0 : i / xTicks;
      final idx = (frac * (scaleData.length - 1)).round();
      final x = leftPad + plotWidth * frac;
      final tp = TextPainter(
        text: TextSpan(text: _formatDate(scaleData[idx].date), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, xAxisY + 2));
    }

    // Clip to plot area
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(leftPad, topPad, plotWidth, plotHeight));

    // Draw scale line
    final scalePaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final scalePath = Path();
    for (int i = 0; i < scaleData.length; i++) {
      final x = scaleData.length > 1 
          ? leftPad + plotWidth * i / (scaleData.length - 1)
          : leftPad + plotWidth / 2;
      final y = topPad + plotHeight - ((scaleData[i].value - yMin) / (yMax - yMin) * plotHeight);

      if (i == 0) {
        scalePath.moveTo(x, y);
      } else {
        scalePath.lineTo(x, y);
      }

      // Draw point markers
      if (!x.isNaN && !y.isNaN) {
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.orange.withValues(alpha: 0.9));
      }
    }
    canvas.drawPath(scalePath, scalePaint);

    // Draw trend dots
    final trendPaint = Paint()
      ..color = Colors.purple.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    for (final point in trendData) {
      final scaleIndex = scaleData.indexWhere((p) => 
        p.date.year == point.date.year && 
        p.date.month == point.date.month && 
        p.date.day == point.date.day
      );
      
      if (scaleIndex >= 0) {
        final x = scaleData.length > 1 
            ? leftPad + plotWidth * scaleIndex / (scaleData.length - 1)
            : leftPad + plotWidth / 2;
        final y = topPad + plotHeight - ((point.value - yMin) / (yMax - yMin) * plotHeight);
        if (!x.isNaN && !y.isNaN) {
          canvas.drawCircle(Offset(x, y), 5, trendPaint);
        }
      }
    }

    // Draw selection overlay
    if (selectedIndex != null && selectedIndex! < scaleData.length) {
      final x = leftPad + plotWidth * selectedIndex! / (scaleData.length - 1);
      final y = topPad + plotHeight - ((scaleData[selectedIndex!].value - yMin) / (yMax - yMin) * plotHeight);

      // Vertical line
      final linePaint = Paint()
        ..color = Colors.black38
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(x, topPad), Offset(x, topPad + plotHeight), linePaint);

      // Dot
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = Colors.orange);

      // Tooltip
      final tooltipText = '${_formatDate(scaleData[selectedIndex!].date)}\n${scaleData[selectedIndex!].value.toStringAsFixed(1)} lb';
      final textPainter = TextPainter(
        text: TextSpan(
          text: tooltipText,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final tooltipX = (x + 50 > leftPad + plotWidth) ? x - textPainter.width - 10 : x + 10;
      final tooltipY = (y - 30).clamp(topPad, topPad + plotHeight - textPainter.height - 10);

      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX - 4, tooltipY - 4, textPainter.width + 8, textPainter.height + 8),
        const Radius.circular(6),
      );

      canvas.drawRRect(tooltipRect, Paint()..color = Colors.black87);
      textPainter.paint(canvas, Offset(tooltipX, tooltipY));
    }

    canvas.restore();
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  bool shouldRepaint(_WeightChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex;
}

// Legend Item
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDot;

  const _LegendItem({required this.color, required this.label, this.isDot = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDot)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          )
        else
          Container(
            width: 20,
            height: 3,
            color: color,
          ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

// Weight Entry Row
class _WeightEntryRow extends StatelessWidget {
  final WeightEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _WeightEntryRow({
    required this.entry,
    required this.onDelete,
    required this.onEdit,
  });

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
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.black12, width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(entry.date),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              Text(
                '${entry.weight.toStringAsFixed(1)} lb',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// Add/Edit Weight Sheet
class _AddWeightSheet extends StatefulWidget {
  final WeightEntry? entry;
  final Function(DateTime, double) onSave;
  final VoidCallback? onDelete;

  const _AddWeightSheet({
    this.entry,
    required this.onSave,
    this.onDelete,
  });

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
      decoration: const BoxDecoration(
        color: Palette.warmNeutral,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            
            // Date picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Palette.forestGreen,
                          onPrimary: Palette.warmNeutral,
                          surface: Palette.lightStone,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Palette.lightStone,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Palette.forestGreen),
                    const SizedBox(width: 12),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Weight input
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Weight (lb)',
                filled: true,
                fillColor: Palette.lightStone,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                if (widget.onDelete != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onDelete!();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                if (widget.onDelete != null) const SizedBox(width: 12),
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
                      backgroundColor: Palette.forestGreen,
                      foregroundColor: Palette.warmNeutral,
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
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
