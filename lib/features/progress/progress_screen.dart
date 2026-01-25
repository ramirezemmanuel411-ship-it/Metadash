import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../shared/palette.dart';

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
      _weightEntries.removeWhere((e) => 
        DateTime(e.date.year, e.date.month, e.date.day).isAtSameMomentAs(dayStart));
      
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
            _FatChangeSection(),
            const SizedBox(height: 16),
            _TDEETrendSection(),
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
  
  List<DataPoint> _generateFatChangeData() {
    final now = DateTime.now();
    return List.generate(30, (i) {
      final date = now.subtract(Duration(days: 29 - i));
      final value = -5.0 + (i * -0.03) + (math.Random().nextDouble() * 0.3 - 0.15);
      return DataPoint(id: 'fat_$i', date: date, value: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _generateFatChangeData();
    final last7Days = data.sublist(data.length - 7);
    final last7Sum = last7Days.fold(0.0, (sum, p) => sum + p.value) / 7;
    
    return _ChartCard(
      title: 'Fat Change',
      subtitle: 'Estimated fat change over time',
      data: data,
      color: Colors.blue.withOpacity(0.8),
      selectedIndex: _selectedIndex,
      onIndexChanged: (index) => setState(() => _selectedIndex = index),
      summaryText: 'Last 7 days: ${last7Sum.toStringAsFixed(1)} lb',
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
  
  List<DataPoint> _generateTDEEData() {
    final now = DateTime.now();
    return List.generate(30, (i) {
      final date = now.subtract(Duration(days: 29 - i));
      final value = 2600.0 + (i * 1.5) + (math.Random().nextDouble() * 80 - 40);
      return DataPoint(id: 'tdee_$i', date: date, value: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _generateTDEEData();
    final first = data.first.value;
    final last = data.last.value;
    final diff = last - first;
    final symbol = diff > 5 ? '↑' : (diff < -5 ? '↓' : '—');
    
    return _ChartCard(
      title: 'TDEE Trend',
      subtitle: 'Daily burn trend',
      data: data,
      color: Colors.green.withOpacity(0.8),
      selectedIndex: _selectedIndex,
      onIndexChanged: (index) => setState(() => _selectedIndex = index),
      summaryText: 'Trend: $symbol',
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

  List<DataPoint> _getScaleData() {
    return widget.entries.map((e) => DataPoint(
      id: e.id,
      date: e.date,
      value: e.weight,
    )).toList();
  }

  List<DataPoint> _getTrendData() {
    if (widget.entries.isEmpty) return [];
    
    final last21Days = widget.entries.length > 21 
        ? widget.entries.sublist(widget.entries.length - 21)
        : widget.entries;
    
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
    if (widget.entries.isEmpty) return null;
    
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final last7Days = widget.entries.where((e) => 
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
    
    return Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weight',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scale weight',
            style: TextStyle(fontSize: 12, color: Colors.black54),
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
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Legend
          Row(
            children: [
              _LegendItem(color: Colors.orange.withOpacity(0.9), label: 'Scale'),
              const SizedBox(width: 16),
              _LegendItem(color: Colors.purple.withOpacity(0.7), label: 'Trend', isDot: true),
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
          
          // Weight entries list
          ...widget.entries.reversed.map((entry) => _WeightEntryRow(
            entry: entry,
            onDelete: () => widget.onDeleteWeight(entry.id),
            onEdit: () => _showAddWeightSheet(context, entry: entry),
          )),
          
          const SizedBox(height: 12),
          
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

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.data,
    required this.color,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.summaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.lightStone,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: _InteractiveChart(
              data: data,
              color: color,
              selectedIndex: selectedIndex,
              onIndexChanged: onIndexChanged,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            summaryText,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// Interactive Chart widget
class _InteractiveChart extends StatelessWidget {
  final List<DataPoint> data;
  final Color color;
  final int? selectedIndex;
  final Function(int?) onIndexChanged;

  const _InteractiveChart({
    required this.data,
    required this.color,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _handleTouch(details.localPosition),
      onPanUpdate: (details) => _handleTouch(details.localPosition),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 300), () => onIndexChanged(null)),
      onPanEnd: (_) => Future.delayed(const Duration(milliseconds: 300), () => onIndexChanged(null)),
      child: CustomPaint(
        painter: _ChartPainter(
          data: data,
          color: color,
          selectedIndex: selectedIndex,
        ),
        child: Container(),
      ),
    );
  }

  void _handleTouch(Offset position) {
    // Simple nearest point selection based on X position
    final index = (position.dx / 300 * data.length).round().clamp(0, data.length - 1);
    onIndexChanged(index);
  }
}

// Chart Painter
class _ChartPainter extends CustomPainter {
  final List<DataPoint> data;
  final Color color;
  final int? selectedIndex;

  _ChartPainter({required this.data, required this.color, this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const axisColor = Colors.black54;
    const labelStyle = TextStyle(color: Colors.black54, fontSize: 10);
    const tickCount = 5;
    const leftPad = 6.0;
    const rightPad = 32.0;
    const bottomPad = 18.0;
    const topPad = 6.0;

    final plotWidth = size.width - leftPad - rightPad;
    final plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Calculate bounds
    final minValue = data.map((p) => p.value).reduce(math.min);
    final maxValue = data.map((p) => p.value).reduce(math.max);
    final padding = (maxValue - minValue) * 0.1;
    final yMin = minValue - padding;
    final yMax = maxValue + padding;

    // Draw gridlines (dashed)
    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final y = topPad + plotHeight * i / 5;
      _drawDashedLine(canvas, Offset(leftPad, y), Offset(leftPad + plotWidth, y), gridPaint);
    }
    for (int i = 0; i <= 5; i++) {
      final x = leftPad + plotWidth * i / 5;
      _drawDashedLine(canvas, Offset(x, topPad), Offset(x, topPad + plotHeight), gridPaint);
    }

    // Axes (y-axis on right)
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final xAxisY = topPad + plotHeight;
    final yAxisX = leftPad + plotWidth;
    canvas.drawLine(Offset(leftPad, xAxisY), Offset(leftPad + plotWidth, xAxisY), axisPaint); // x-axis
    canvas.drawLine(Offset(yAxisX, topPad), Offset(yAxisX, topPad + plotHeight), axisPaint); // y-axis on right

    // Y-axis labels (right aligned)
    for (int i = 0; i <= tickCount; i++) {
      final y = topPad + plotHeight * i / tickCount;
      final value = yMax - (yMax - yMin) * (i / tickCount);
      final tp = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(1), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height));
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
      final tooltipText = '${_formatDate(data[selectedIndex!].date)}\n${data[selectedIndex!].value.toStringAsFixed(1)}';
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

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex;
}

// Weight Chart with scale line and trend dots
class _WeightChart extends StatelessWidget {
  final List<DataPoint> scaleData;
  final List<DataPoint> trendData;
  final int? selectedIndex;
  final Function(int?) onIndexChanged;

  const _WeightChart({
    required this.scaleData,
    required this.trendData,
    required this.selectedIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _handleTouch(details.localPosition),
      onPanUpdate: (details) => _handleTouch(details.localPosition),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 300), () => onIndexChanged(null)),
      onPanEnd: (_) => Future.delayed(const Duration(milliseconds: 300), () => onIndexChanged(null)),
      child: CustomPaint(
        painter: _WeightChartPainter(
          scaleData: scaleData,
          trendData: trendData,
          selectedIndex: selectedIndex,
        ),
        child: Container(),
      ),
    );
  }

  void _handleTouch(Offset position) {
    if (scaleData.isEmpty) return;
    final index = (position.dx / 300 * scaleData.length).round().clamp(0, scaleData.length - 1);
    onIndexChanged(index);
  }
}

// Weight Chart Painter
class _WeightChartPainter extends CustomPainter {
  final List<DataPoint> scaleData;
  final List<DataPoint> trendData;
  final int? selectedIndex;

  _WeightChartPainter({
    required this.scaleData,
    required this.trendData,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scaleData.isEmpty) return;

    const axisColor = Colors.black54;
    const labelStyle = TextStyle(color: Colors.black54, fontSize: 10);
    const tickCount = 5;
    const leftPad = 6.0;
    const rightPad = 32.0;
    const bottomPad = 18.0;
    const topPad = 6.0;

    final plotWidth = size.width - leftPad - rightPad;
    final plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    // Calculate bounds
    final allValues = [...scaleData.map((p) => p.value), ...trendData.map((p) => p.value)];
    final minValue = (allValues.reduce(math.min) - 5).clamp(50, 400);
    final maxValue = (allValues.reduce(math.max) + 5).clamp(50, 400);
    final yMin = minValue;
    final yMax = maxValue;

    // Draw gridlines (dashed)
    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final y = topPad + plotHeight * i / 5;
      _drawDashedLine(canvas, Offset(leftPad, y), Offset(leftPad + plotWidth, y), gridPaint);
    }
    for (int i = 0; i <= 5; i++) {
      final x = leftPad + plotWidth * i / 5;
      _drawDashedLine(canvas, Offset(x, topPad), Offset(x, topPad + plotHeight), gridPaint);
    }

    // Axes (y-axis on right)
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final xAxisY = topPad + plotHeight;
    final yAxisX = leftPad + plotWidth;
    canvas.drawLine(Offset(leftPad, xAxisY), Offset(leftPad + plotWidth, xAxisY), axisPaint);
    canvas.drawLine(Offset(yAxisX, topPad), Offset(yAxisX, topPad + plotHeight), axisPaint);

    // Y-axis labels (right aligned)
    for (int i = 0; i <= tickCount; i++) {
      final y = topPad + plotHeight * i / tickCount;
      final value = yMax - (yMax - yMin) * (i / tickCount);
      final tp = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(1), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 2, y - tp.height));
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
      ..color = Colors.orange.withOpacity(0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final scalePath = Path();
    for (int i = 0; i < scaleData.length; i++) {
      final x = leftPad + plotWidth * i / (scaleData.length - 1);
      final y = topPad + plotHeight - ((scaleData[i].value - yMin) / (yMax - yMin) * plotHeight);

      if (i == 0) {
        scalePath.moveTo(x, y);
      } else {
        scalePath.lineTo(x, y);
      }

      // Draw point markers
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.orange.withOpacity(0.9));
    }
    canvas.drawPath(scalePath, scalePaint);

    // Draw trend dots
    final trendPaint = Paint()
      ..color = Colors.purple.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    for (final point in trendData) {
      final scaleIndex = scaleData.indexWhere((p) => 
        p.date.year == point.date.year && 
        p.date.month == point.date.month && 
        p.date.day == point.date.day
      );
      
      if (scaleIndex >= 0) {
        final x = leftPad + plotWidth * scaleIndex / (scaleData.length - 1);
        final y = topPad + plotHeight - ((point.value - yMin) / (yMax - yMin) * plotHeight);
        canvas.drawCircle(Offset(x, y), 5, trendPaint);
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
