import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:metadash/core/shared/palette.dart';
import 'package:metadash/core/shared/user_settings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _wordmarkController;
  late final Animation<double> _ringAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _ringAnim = CurvedAnimation(parent: _ringController, curve: Curves.easeOut);

    _wordmarkController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _wordmarkController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _wordmarkController, curve: Curves.easeOut),
        );

    _ringController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _wordmarkController.forward();
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _wordmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        UserSettings.themeMode.value == ThemeMode.dark ||
        (UserSettings.themeMode.value == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    final bg = isDark ? Palette.nightBackground : Palette.dayBackground;
    final textPrimary = isDark
        ? Palette.nightTextPrimary
        : Palette.dayTextPrimary;
    final accent = isDark ? Palette.nightAccentBlue : Palette.forestGreen;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Animated ring ──────────────────────────────────────────
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (context, _) => CustomPaint(
                    size: const Size(88, 88),
                    painter: _MetricRingPainter(
                      progress: _ringAnim.value,
                      color: accent,
                      trackColor: accent.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Wordmark ───────────────────────────────────────────────
                Text(
                  'MetaDash',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Greeting ───────────────────────────────────────────────
                Text(
                  '${_greeting()}, Welcome to MetaDash',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: accent,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _MetricRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _MetricRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    const strokeWidth = 5.5;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Center percentage text
    final label = '${(progress * 100).round()}';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_MetricRingPainter old) => old.progress != progress;
}
