import 'package:flutter/material.dart';
import 'package:metadash/features/progress/scale_change_service.dart';
import 'package:metadash/shared/palette.dart';

typedef DateSelector<T> = DateTime Function(T);
typedef ValueSelector<T> = double Function(T);

class MiniSummaryCard<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String filter;
  final DateSelector<T> dateSelector;
  final ValueSelector<T> valueSelector;
  final Color? color;

  const MiniSummaryCard({
    super.key,
    required this.title,
    required this.items,
    required this.filter,
    required this.dateSelector,
    required this.valueSelector,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final res = computeDeltaByRange<T>(
      items,
      filter,
      dateSelector,
      valueSelector,
    );

    Widget right;
    if (!res.hasEnoughData) {
      right = Text(
        'Not enough data',
        style: TextStyle(color: context.colors.textSecondary),
      );
    } else {
      final d = res.delta ?? 0.0;
      final sign = d >= 0 ? '+' : '';
      right = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // small sparkline
          SizedBox(
            width: 56,
            height: 28,
            child: CustomPaint(
              painter: _SparklinePainter(
                items,
                dateSelector,
                valueSelector,
                color ?? context.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${d.toStringAsFixed(1)} lb',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
          ),
          right,
        ],
      ),
    );
  }
}

class _SparklinePainter<T> extends CustomPainter {
  final List<T> items;
  final DateSelector<T> dateSelector;
  final ValueSelector<T> valueSelector;
  final Color color;

  _SparklinePainter(
    this.items,
    this.dateSelector,
    this.valueSelector,
    this.color,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) {
      return;
    }
    final points =
        items.map((e) => MapEntry(dateSelector(e), valueSelector(e))).toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final values = points.map((e) => e.value).toList();
    if (values.isEmpty) {
      return;
    }

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / span * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => false;
}
