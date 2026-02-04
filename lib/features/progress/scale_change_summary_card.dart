import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../shared/palette.dart';
import 'scale_change_service.dart';

typedef DateSelector<T> = DateTime Function(T);
typedef ValueSelector<T> = double Function(T);

class ScaleChangeSummaryCard<T> extends StatefulWidget {
  final List<T> items;
  final DateSelector<T> dateSelector;
  final ValueSelector<T> valueSelector;
  final String filter;
  final String label; // displayed left side title
  final String unit; // unit to display for deltas (e.g., 'lb', 'Kcal/Day')

  const ScaleChangeSummaryCard({
    super.key,
    required this.items,
    required this.dateSelector,
    required this.valueSelector,
    required this.filter,
    this.label = 'Scale change',
    this.unit = 'lb',
  });

  @override
  State<ScaleChangeSummaryCard<T>> createState() => _ScaleChangeSummaryCardState<T>();
}

class _ScaleChangeSummaryCardState<T> extends State<ScaleChangeSummaryCard<T>> {
  static const _otherRanges = ['3D', '7D', '14D', '30D', '90D', 'ALL'];
  static const double _labelWidth = 110;
  static const double _sparkWidth = 42;
  static const double _arrowWidth = 60;

  @override
  void initState() {
    super.initState();
  }

  String _labelForFilter(String f) {
    switch (f) {
      case '1D': return '1 Day';
      case '1W': return '1 Week';
      case '1M': return '1 Month';
      case '3D': return '3 day';
      case '7D': return '7 day';
      case '14D': return '14 day';
      case '30D': return '30 day';
      case '90D': return '90 day';
      case '3M': return '3 Months';
      case '1Y': return '1 Year';
      case 'YTD': return 'YTD';
      case 'ALL': return 'All Time';
      default:
        if (f.endsWith('D')) return '${f.replaceAll('D','')}D';
        return f;
    }
  }

  ({String arrow, Color color, String statusText}) _arrowProps(double delta) {
    if (delta <= -0.2) return (arrow: '↓', color: Palette.forestGreen, statusText: '');
    if (delta >= 0.2) return (arrow: '↑', color: Colors.redAccent, statusText: '');
    return (arrow: '−', color: Colors.black45, statusText: 'Stable');
  }

  Widget _row({
    required String label,
    required String deltaText,
    required double delta,
    Widget? sparkWidget,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 8),
  }) {
    final props = _arrowProps(delta);

    return Container(
      padding: padding,
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _sparkWidth,
            height: 18,
            child: sparkWidget ?? const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Text(
                deltaText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: _arrowWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    props.statusText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                Text(props.arrow, style: TextStyle(color: props.color, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    // prepare vertical rows for other ranges (label | mini bar | delta | status)
    for (final rng in _otherRanges) {
      final res = computeDeltaByRange<T>(widget.items, rng, widget.dateSelector, widget.valueSelector);
      if (!res.hasEnoughData) continue;
      final d = res.delta ?? 0.0;
      final absText = '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} ${widget.unit}';
      rows.add(_row(
        label: _labelForFilter(rng),
        deltaText: absText,
        delta: d,
        sparkWidget: _MiniSparkline<T>(
          items: widget.items,
          dateSelector: widget.dateSelector,
          valueSelector: widget.valueSelector,
          range: rng,
          color: Colors.blue.shade300,
        ),
      ));
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      // Blend into parent card: no background or shadow so it appears attached
      decoration: const BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          if (rows.isNotEmpty) ...rows else const Text('Not enough data', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _MiniSparkline<T> extends StatelessWidget {
  final List<T> items;
  final DateSelector<T> dateSelector;
  final ValueSelector<T> valueSelector;
  final String range;
  final Color color;

  const _MiniSparkline({
    required this.items,
    required this.dateSelector,
    required this.valueSelector,
    required this.range,
    required this.color,
  });

  DateTime? _cutoff() {
    final now = DateTime.now();
    if (range == 'ALL') return null;
    if (range.endsWith('D')) {
      final days = int.tryParse(range.replaceAll('D', '')) ?? 0;
      return now.subtract(Duration(days: days));
    }
    if (range == '3M') return DateTime(now.year, now.month - 3, now.day);
    if (range == '1M') return DateTime(now.year, now.month - 1, now.day);
    if (range == '1W') return now.subtract(const Duration(days: 7));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cutoff = _cutoff();
    final filtered = cutoff == null ? items : items.where((i) => dateSelector(i).isAfter(cutoff)).toList();
    final values = filtered.map((i) => valueSelector(i)).toList();
    return CustomPaint(
      painter: _MiniSparklinePainter(values: values, color: color),
    );
  }
}

class _MiniSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _MiniSparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.6..style = PaintingStyle.stroke..isAntiAlias = true;
    final fill = Paint()..color = color.withValues(alpha: 0.15)..style = PaintingStyle.fill;

    if (values.isEmpty) {
      // draw an empty subtle line
      final p = Path()..moveTo(0, size.height/2)..lineTo(size.width, size.height/2);
      canvas.drawPath(p, paint..color = color.withValues(alpha: 0.4));
      return;
    }

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV).abs();
    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1).clamp(1, double.infinity)) * size.width;
      final norm = (values[i] - minV) / span;
      final y = size.height - (norm * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    // close fill
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSparklinePainter old) => old.values != values || old.color != color;
}
