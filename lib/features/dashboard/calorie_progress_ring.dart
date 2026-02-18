import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../shared/palette.dart';

class CalorieProgressRing extends StatefulWidget {
  final int consumed;
  final int target;
  final Duration animationDuration;

  const CalorieProgressRing({
    super.key,
    required this.consumed,
    required this.target,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  @override
  State<CalorieProgressRing> createState() => _CalorieProgressRingState();
}

class _CalorieProgressRingState extends State<CalorieProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _setupAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(CalorieProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consumed != widget.consumed || oldWidget.target != widget.target) {
      _controller.reset();
      _setupAnimation();
      _controller.forward();
    }
  }

  void _setupAnimation() {
    final progress = widget.target > 0 ? (widget.consumed / widget.target).clamp(0.0, 1.0) : 0.0;
    _progressAnimation = Tween<double>(begin: 0, end: progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getProgressColor(bool exceeded) {
    if (exceeded) {
      return Colors.amber.shade600;
    }
    return Palette.forestGreen;
  }

  @override
  Widget build(BuildContext context) {
    final exceeded = widget.consumed > widget.target;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _RingPainter(
                    progress: _progressAnimation.value,
                    color: _getProgressColor(exceeded),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${widget.consumed}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'of ${widget.target} kcal',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _RemainingLabel(
            consumed: widget.consumed,
            target: widget.target,
            exceeded: exceeded,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background ring
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _RemainingLabel extends StatelessWidget {
  final int consumed;
  final int target;
  final bool exceeded;

  const _RemainingLabel({
    required this.consumed,
    required this.target,
    required this.exceeded,
  });

  @override
  Widget build(BuildContext context) {
    final diff = (consumed - target).abs();
    final label = exceeded ? 'Over by' : 'Remaining';
    final color = exceeded ? Colors.amber.shade600 : Palette.forestGreen;

    return Text(
      '$label: $diff kcal',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
