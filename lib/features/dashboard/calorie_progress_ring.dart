import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../shared/palette.dart';

class CalorieProgressRing extends StatefulWidget {
  final int consumed;
  final int target;
  final Color? accentColor;
  final Color? statusColor;
  final Color? textColor;
  final Color? secondaryTextColor;
  final Color? trackColor;
  final Color? knobFillColor;
  final bool lightSurface;
  final double size;
  final Duration animationDuration;

  const CalorieProgressRing({
    super.key,
    required this.consumed,
    required this.target,
    this.accentColor,
    this.statusColor,
    this.textColor,
    this.secondaryTextColor,
    this.trackColor,
    this.knobFillColor,
    this.lightSurface = false,
    this.size = 246,
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
    if (oldWidget.consumed != widget.consumed ||
        oldWidget.target != widget.target) {
      _controller.reset();
      _setupAnimation();
      _controller.forward();
    }
  }

  void _setupAnimation() {
    final progress = widget.target > 0
        ? (widget.consumed / widget.target).clamp(0.0, 1.0)
        : 0.0;
    _progressAnimation = Tween<double>(begin: 0, end: progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final themeIsDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = widget.lightSurface ? false : themeIsDark;
    final exceeded = widget.consumed > widget.target;
    final accentColor = widget.accentColor ?? colors.accent;
    final statusColor =
        widget.statusColor ?? (exceeded ? colors.cta : accentColor);
    final textColor = widget.textColor ?? colors.textPrimary;
    final secondaryTextColor =
        widget.secondaryTextColor ?? colors.textSecondary;
    final trackColor =
        widget.trackColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.07));
    final knobFillColor =
        widget.knobFillColor ??
        (isDark ? const Color(0xFF172016) : const Color(0xFFF7F2E9));

    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: _RingPainter(
                progress: _progressAnimation.value,
                backgroundColor: trackColor,
                progressColor: statusColor,
                color: accentColor,
                knobFillColor: knobFillColor,
                isDark: isDark,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatRingInt(widget.consumed),
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w500,
                        height: 0.95,
                        color: textColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'of ${_formatRingInt(widget.target)} kcal goal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final Color color;
  final Color knobFillColor;
  final bool isDark;

  _RingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.color,
    required this.knobFillColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 17;
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    final innerRadius = radius - 23;

    final innerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isDark ? 0.10 : 0.08),
          color.withValues(alpha: 0.018),
          Colors.transparent,
        ],
        stops: const [0, 0.58, 1],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));

    canvas.drawCircle(center, innerRadius, innerPaint);

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.20 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..isAntiAlias = true;

    canvas.drawCircle(center.translate(0, 2), radius - 1, shadowPaint);
    canvas.drawCircle(center, radius, backgroundPaint);

    if (progress <= 0) return;

    final glowPaint = Paint()
      ..color = progressColor.withValues(alpha: isDark ? 0.18 : 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..isAntiAlias = true;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          progressColor.withValues(alpha: 0.62),
          progressColor,
          Color.alphaBlend(Colors.white.withValues(alpha: 0.16), progressColor),
        ],
        stops: const [0, 0.72, 1],
      ).createShader(ringRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    const startAngle = math.pi * 0.82;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(ringRect, startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(ringRect, startAngle, sweepAngle, false, progressPaint);

    final endAngle = startAngle + sweepAngle;
    final knobCenter = Offset(
      center.dx + math.cos(endAngle) * radius,
      center.dy + math.sin(endAngle) * radius,
    );
    canvas.drawCircle(
      knobCenter,
      10,
      Paint()
        ..color = knobFillColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      knobCenter,
      8.2,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.color != color ||
        oldDelegate.knobFillColor != knobFillColor ||
        oldDelegate.isDark != isDark;
  }
}

String _formatRingInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return buffer.toString();
}
