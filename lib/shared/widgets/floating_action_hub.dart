import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../palette.dart';

// Night mode tokens used by this widget.
const Color _nightAccentBlue = Color(0xFF4C7FA8);
const Color _nightSurface = Color(0xFF222522);
const Color _nightTextPrimary = Color(0xFFF2F1EC);

/// A draggable, snapping FAB with radial menu on long-press.
/// Tap = primary action, Long-press = show radial menu.
class FloatingActionHub extends StatefulWidget {
  final VoidCallback onAddFood;
  final VoidCallback onOpenAI;
  final VoidCallback onAddWorkout;
  final VoidCallback onAddWeight;
  final VoidCallback onSettings;
  final Color? fabColor;
  final Color? backgroundColor;

  const FloatingActionHub({
    super.key,
    required this.onAddFood,
    required this.onOpenAI,
    required this.onAddWorkout,
    required this.onAddWeight,
    required this.onSettings,
    this.fabColor,
    this.backgroundColor,
  });

  @override
  State<FloatingActionHub> createState() => _FloatingActionHubState();
}

class _FloatingActionHubState extends State<FloatingActionHub> {
  static const String _positionKeyX = 'fab_position_x';
  static const String _positionKeyY = 'fab_position_y';
  static const double _fabSize = 56.0;
  static const double _edgePadding = 16.0;

  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _menuOpen = false;
  OverlayEntry? _overlayEntry;
  OverlayEntry? _fabEntry;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPosition());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fabEntry = OverlayEntry(builder: _buildFabOverlay);
      Overlay.of(context, rootOverlay: true).insert(_fabEntry!);
    });
  }

  @override
  void dispose() {
    _fabEntry?.remove();
    _fabEntry = null;
    _closeMenu(animate: false);
    super.dispose();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final x = prefs.getDouble(_positionKeyX);
    final y = prefs.getDouble(_positionKeyY);

    if (x != null && y != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _position = Offset(x, y);
        });
        _fabEntry?.markNeedsBuild();
      });
    } else {
      // Default to bottom-right
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final size = MediaQuery.of(context).size;
        final safeArea = MediaQuery.of(context).padding;
        setState(() {
          _position = Offset(
            size.width - _fabSize - _edgePadding - safeArea.right,
            size.height - _fabSize - _edgePadding - safeArea.bottom - 80,
          );
        });
        _fabEntry?.markNeedsBuild();
      });
    }
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_positionKeyX, _position.dx);
    await prefs.setDouble(_positionKeyY, _position.dy);
  }

  void _snapToEdge() {
    final size = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;

    final centerX = _position.dx + _fabSize / 2;
    final centerY = _position.dy + _fabSize / 2;
    final isLeft = centerX < size.width / 2;

    final isNearBottom = centerY > size.height * 3 / 4;
    final isNearTop = centerY < size.height / 4;

    double newY;
    if (isNearBottom) {
      newY = size.height - _fabSize - _edgePadding - safeArea.bottom;
    } else if (isNearTop) {
      newY = safeArea.top + _edgePadding;
    } else {
      newY = _position.dy.clamp(
        safeArea.top + _edgePadding,
        size.height - _fabSize - _edgePadding - safeArea.bottom,
      );
    }

    setState(() {
      _position = Offset(
        isLeft
            ? _edgePadding + safeArea.left
            : size.width - _fabSize - _edgePadding - safeArea.right,
        newY,
      );
    });
    _fabEntry?.markNeedsBuild();
    unawaited(_savePosition());
  }

  void _onTap() {
    if (_menuOpen) return;
    HapticFeedback.lightImpact();
    _openMenu();
  }

  void _onLongPress() {
    if (_menuOpen) return;
    HapticFeedback.lightImpact();
    _openMenu();
  }

  void _openMenu() {
    if (_menuOpen) return;

    final overlay = Overlay.of(context, rootOverlay: true);

    _overlayEntry?.remove();

    setState(() {
      _menuOpen = true;
    });
    _fabEntry?.markNeedsBuild();

    final size = MediaQuery.of(context).size;
    final fabCenter = Offset(
      _position.dx + _fabSize / 2,
      _position.dy + _fabSize / 2,
    );

    _overlayEntry = OverlayEntry(
      builder: (context) => _RadialMenuOverlay(
        fabCenter: fabCenter,
        screenSize: size,
        onDismiss: _closeMenu,
        onAddFood: () {
          _closeMenu();
          widget.onAddFood();
        },
        onOpenAI: () {
          _closeMenu();
          widget.onOpenAI();
        },
        onAddWorkout: () {
          _closeMenu();
          widget.onAddWorkout();
        },
        onAddWeight: () {
          _closeMenu();
          widget.onAddWeight();
        },
        onSettings: () {
          _closeMenu();
          widget.onSettings();
        },
        fabColor: widget.fabColor,
        backgroundColor: widget.backgroundColor,
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _closeMenu({bool animate = true}) {
    if (!_menuOpen) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _menuOpen = false;
    _fabEntry?.markNeedsBuild();
  }

  Widget _buildFabOverlay(BuildContext ctx) {
    final theme = Theme.of(ctx);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedFabColor = isDark
        ? _nightAccentBlue
        : (widget.fabColor ?? theme.colorScheme.primary);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onTap: _menuOpen ? null : _onTap,
        onLongPress: _menuOpen ? null : _onLongPress,
        onPanStart: _menuOpen
            ? null
            : (_) {
                setState(() {
                  _isDragging = true;
                });
                _fabEntry?.markNeedsBuild();
              },
        onPanUpdate: _menuOpen
            ? null
            : (details) {
                setState(() {
                  _position += details.delta;
                });
                _fabEntry?.markNeedsBuild();
              },
        onPanEnd: _menuOpen
            ? null
            : (_) {
                setState(() {
                  _isDragging = false;
                });
                _snapToEdge();
              },
        child: Container(
          width: _fabSize,
          height: _fabSize,
          decoration: BoxDecoration(
            color: resolvedFabColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.32)
                    : Colors.black.withValues(alpha: 0.15),
                blurRadius: _isDragging ? 12 : 8,
                offset: Offset(0, _isDragging ? 4 : 2),
              ),
            ],
          ),
          child: Icon(
            Icons.add,
            color: isDark ? _nightTextPrimary : Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _RadialMenuOverlay extends StatefulWidget {
  final Offset fabCenter;
  final Size screenSize;
  final VoidCallback onDismiss;
  final VoidCallback onAddFood;
  final VoidCallback onOpenAI;
  final VoidCallback onAddWorkout;
  final VoidCallback onAddWeight;
  final VoidCallback onSettings;
  final Color? fabColor;
  final Color? backgroundColor;

  const _RadialMenuOverlay({
    required this.fabCenter,
    required this.screenSize,
    required this.onDismiss,
    required this.onAddFood,
    required this.onOpenAI,
    required this.onAddWorkout,
    required this.onAddWeight,
    required this.onSettings,
    this.fabColor,
    this.backgroundColor,
  });

  @override
  State<_RadialMenuOverlay> createState() => _RadialMenuOverlayState();
}

class _RadialMenuOverlayState extends State<_RadialMenuOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
        ),
        // Radial menu items
        _RadialMenu(
          fabCenter: widget.fabCenter,
          screenSize: widget.screenSize,
          scaleAnimation: _scaleAnimation,
          fadeAnimation: _fadeAnimation,
          rotationAnimation: _fadeAnimation,
          onDismiss: widget.onDismiss,
          onAddFood: widget.onAddFood,
          onOpenAI: widget.onOpenAI,
          onAddWorkout: widget.onAddWorkout,
          onAddWeight: widget.onAddWeight,
          onSettings: widget.onSettings,
          fabColor: widget.fabColor,
          backgroundColor: widget.backgroundColor,
        ),
      ],
    );
  }
}

class _RadialMenu extends StatelessWidget {
  final Offset fabCenter;
  final Size screenSize;
  final Animation<double> scaleAnimation;
  final Animation<double> fadeAnimation;
  final Animation<double> rotationAnimation;
  final VoidCallback onDismiss;
  final VoidCallback onAddFood;
  final VoidCallback onOpenAI;
  final VoidCallback onAddWorkout;
  final VoidCallback onAddWeight;
  final VoidCallback onSettings;
  final Color? fabColor;
  final Color? backgroundColor;

  static const double _radius = 120.0;
  static const double _itemSize = 64.0;

  const _RadialMenu({
    required this.fabCenter,
    required this.screenSize,
    required this.scaleAnimation,
    required this.fadeAnimation,
    required this.rotationAnimation,
    required this.onDismiss,
    required this.onAddFood,
    required this.onOpenAI,
    required this.onAddWorkout,
    required this.onAddWeight,
    required this.onSettings,
    this.fabColor,
    this.backgroundColor,
  });

  List<_RadialMenuItem> _getItems() {
    return [
      _RadialMenuItem(icon: Icons.auto_awesome, label: 'AI', onTap: onOpenAI),
      _RadialMenuItem(icon: Icons.restaurant, label: 'Food', onTap: onAddFood),
      _RadialMenuItem(
        icon: Icons.fitness_center,
        label: 'Workout',
        onTap: onAddWorkout,
      ),
      _RadialMenuItem(
        icon: Icons.monitor_weight_outlined,
        label: 'Progress',
        onTap: onAddWeight,
      ),
      _RadialMenuItem(
        icon: Icons.settings,
        label: 'Settings',
        onTap: onSettings,
      ),
    ];
  }

  List<Offset> _calculatePositions() {
    final items = _getItems();
    final positions = <Offset>[];

    // Determine FAB position relative to screen
    final isLeft = fabCenter.dx < screenSize.width / 4;
    final isRight = fabCenter.dx > screenSize.width * 3 / 4;
    final isTop = fabCenter.dy < screenSize.height / 4;
    final isBottom = fabCenter.dy > screenSize.height * 3 / 4;

    final edgeInset = (_itemSize / 2) + 8.0;
    final leftSpace = fabCenter.dx - edgeInset;
    final rightSpace = screenSize.width - fabCenter.dx - edgeInset;
    final topSpace = fabCenter.dy - edgeInset;
    final bottomSpace = screenSize.height - fabCenter.dy - edgeInset;

    final isCorner = (isTop || isBottom) && (isLeft || isRight);
    final desiredCornerRadius = 200.0;
    final desiredEdgeRadius = _radius;

    double effectiveRadius;
    if (isCorner) {
      final maxRadiusX = isLeft ? rightSpace : leftSpace;
      final maxRadiusY = isTop ? bottomSpace : topSpace;
      effectiveRadius = math.min(
        desiredCornerRadius,
        math.min(maxRadiusX, maxRadiusY),
      );
    } else if (isLeft) {
      effectiveRadius = math.min(desiredEdgeRadius, rightSpace);
    } else if (isRight) {
      effectiveRadius = math.min(desiredEdgeRadius, leftSpace);
    } else if (isTop) {
      effectiveRadius = math.min(desiredEdgeRadius, bottomSpace);
    } else if (isBottom) {
      effectiveRadius = math.min(desiredEdgeRadius, topSpace);
    } else {
      effectiveRadius = desiredEdgeRadius;
    }

    // Determine best direction for semicircle based on FAB position
    double baseAngle;

    if (isTop && isLeft) {
      // Top-left corner: spread down and right
      baseAngle = math.pi * 0.25; // 45 degrees
    } else if (isTop && isRight) {
      // Top-right corner: spread down and left
      baseAngle = math.pi * 0.75; // 135 degrees
    } else if (isBottom && isLeft) {
      // Bottom-left corner: spread up and right
      baseAngle = -math.pi * 0.25; // -45 degrees
    } else if (isBottom && isRight) {
      // Bottom-right corner: spread up and left
      baseAngle = -math.pi * 0.75; // -135 degrees
    } else if (isLeft) {
      // Left edge: spread right
      baseAngle = 0.0;
    } else if (isRight) {
      // Right edge: spread left
      baseAngle = math.pi;
    } else if (isTop) {
      // Top edge: spread down
      baseAngle = math.pi / 2;
    } else if (isBottom) {
      // Bottom edge: spread up
      baseAngle = -math.pi / 2;
    } else {
      // Center: default to left
      baseAngle = math.pi;
    }

    // Use quarter-circle in corners, semicircle elsewhere
    final angleSpan = isCorner ? (math.pi / 2) : math.pi;
    final startAngle = baseAngle - (angleSpan / 2);
    final endAngle = baseAngle + (angleSpan / 2);

    final angleRange = endAngle - startAngle;
    final angleStep = items.length > 1 ? angleRange / (items.length - 1) : 0;

    for (int i = 0; i < items.length; i++) {
      final angle = startAngle + (angleStep * i);
      final x =
          fabCenter.dx + (effectiveRadius * math.cos(angle)) - (_itemSize / 2);
      final y =
          fabCenter.dy + (effectiveRadius * math.sin(angle)) - (_itemSize / 2);

      positions.add(Offset(x, y));
    }

    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedFabColor = isDark
        ? _nightAccentBlue
        : (fabColor ?? theme.colorScheme.primary);

    final items = _getItems();
    final positions = _calculatePositions();

    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Central hub (FAB stays visible)
            Positioned(
              left: fabCenter.dx - (_itemSize / 2),
              top: fabCenter.dy - (_itemSize / 2),
              child: GestureDetector(
                onTap: onDismiss,
                child: Container(
                  width: _itemSize,
                  height: _itemSize,
                  decoration: BoxDecoration(
                    color: resolvedFabColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                          ? Colors.black.withValues(alpha: 0.32)
                          : context.colors.textMuted.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: rotationAnimation,
                    // Rotate the "+" 45° as the menu opens so it reads as an
                    // "×" (close) while open, and back to "+" when dismissed.
                    builder: (context2, child2) => Transform.rotate(
                      angle: rotationAnimation.value * (math.pi / 4),
                      child: Icon(
                        Icons.add,
                        color: context.colors.onPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Radial items
            ...List.generate(items.length, (index) {
              final item = items[index];
              final position = positions[index];

              return Positioned(
                left: position.dx,
                top: position.dy,
                child: Transform.scale(
                  scale: scaleAnimation.value,
                  child: Opacity(
                    opacity: fadeAnimation.value,
                    child: _RadialItemWidget(
                      item: item,
                      backgroundColor: backgroundColor,
                      labelOnLeft: fabCenter.dx > screenSize.width / 2,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _RadialMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RadialMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _RadialItemWidget extends StatelessWidget {
  final _RadialMenuItem item;
  final Color? backgroundColor;
  final bool labelOnLeft;

  const _RadialItemWidget({
    required this.item,
    this.backgroundColor,
    this.labelOnLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedBackground =
        backgroundColor ?? (isDark ? _nightSurface : theme.colorScheme.surface);
    final resolvedIconColor =
        isDark ? _nightAccentBlue : theme.colorScheme.primary;
    final resolvedLabelColor =
        isDark ? _nightTextPrimary : theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        item.onTap();
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: resolvedBackground,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: resolvedIconColor, size: 20),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: resolvedLabelColor,
                decoration: TextDecoration.none,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
