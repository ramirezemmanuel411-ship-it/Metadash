import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../palette.dart';

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

class _FloatingActionHubState extends State<FloatingActionHub>
    with SingleTickerProviderStateMixin {
  static const String _positionKeyX = 'fab_position_x';
  static const String _positionKeyY = 'fab_position_y';
  static const double _fabSize = 56.0;
  static const double _edgePadding = 16.0;

  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _menuOpen = false;
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadPosition();
  }

  @override
  void dispose() {
    _closeMenu();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_positionKeyX);
    final y = prefs.getDouble(_positionKeyY);
    
    if (mounted && x != null && y != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _position = Offset(x, y);
          });
        }
      });
    } else {
      // Default to bottom-right
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final size = MediaQuery.of(context).size;
          final safeArea = MediaQuery.of(context).padding;
          setState(() {
            _position = Offset(
              size.width - _fabSize - _edgePadding - safeArea.right,
              size.height - _fabSize - _edgePadding - safeArea.bottom - 80,
            );
          });
        }
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

    // Snap to vertical edge too when near top/bottom (corner snap),
    // using the same 25% thresholds as _calculatePositions().
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
    _savePosition();
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
    
    setState(() {
      _menuOpen = true;
    });

    final size = MediaQuery.of(context).size;
    final fabCenter = Offset(
      _position.dx + _fabSize / 2,
      _position.dy + _fabSize / 2,
    );

    _overlayEntry = OverlayEntry(
      builder: (context) => _RadialMenuOverlay(
        fabCenter: fabCenter,
        screenSize: size,
        scaleAnimation: _scaleAnimation,
        fadeAnimation: _fadeAnimation,
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

    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
  }

  void _closeMenu() {
    if (!_menuOpen) return;
    
    _animationController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted) {
        setState(() {
          _menuOpen = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onTap: _menuOpen ? null : _onTap,
        onLongPress: _menuOpen ? null : _onLongPress,
        onPanStart: _menuOpen ? null : (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: _menuOpen ? null : (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onPanEnd: _menuOpen ? null : (_) {
          setState(() {
            _isDragging = false;
          });
          _snapToEdge();
        },
        child: Container(
          width: _fabSize,
          height: _fabSize,
          decoration: BoxDecoration(
            color: widget.fabColor ?? Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: _isDragging ? 12 : 8,
                offset: Offset(0, _isDragging ? 4 : 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _RadialMenuOverlay extends StatelessWidget {
  final Offset fabCenter;
  final Size screenSize;
  final Animation<double> scaleAnimation;
  final Animation<double> fadeAnimation;
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
    required this.scaleAnimation,
    required this.fadeAnimation,
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
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ),
        // Radial menu items
        _RadialMenu(
          fabCenter: fabCenter,
          screenSize: screenSize,
          scaleAnimation: scaleAnimation,
          fadeAnimation: fadeAnimation,
          onDismiss: onDismiss,
          onAddFood: onAddFood,
          onOpenAI: onOpenAI,
          onAddWorkout: onAddWorkout,
          onAddWeight: onAddWeight,
          onSettings: onSettings,
          fabColor: fabColor,
          backgroundColor: backgroundColor,
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
  final VoidCallback onDismiss;
  final VoidCallback onAddFood;
  final VoidCallback onOpenAI;
  final VoidCallback onAddWorkout;
  final VoidCallback onAddWeight;
  final VoidCallback onSettings;
  final Color? fabColor;
  final Color? backgroundColor;

  static const double _radius = 120.0;
  static const double _itemSize = 56.0;

  const _RadialMenu({
    required this.fabCenter,
    required this.screenSize,
    required this.scaleAnimation,
    required this.fadeAnimation,
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
      _RadialMenuItem(
        icon: Icons.auto_awesome,
        label: 'AI',
        onTap: onOpenAI,
      ),
      _RadialMenuItem(
        icon: Icons.restaurant,
        label: 'Food',
        onTap: onAddFood,
      ),
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
      effectiveRadius = math.min(desiredCornerRadius, math.min(maxRadiusX, maxRadiusY));
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
      final x = fabCenter.dx + (effectiveRadius * math.cos(angle)) - (_itemSize / 2);
      final y = fabCenter.dy + (effectiveRadius * math.sin(angle)) - (_itemSize / 2);

      positions.add(Offset(x, y));
    }

    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final items = _getItems();
    final positions = _calculatePositions();
    final rotationValue = CurvedAnimation(
      parent: fadeAnimation,
      curve: Curves.easeOutCubic,
    );

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
                    color: fabColor ?? Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: rotationValue.value * (math.pi / 4),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 28,
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

  const _RadialItemWidget({
    required this.item,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        item.onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: backgroundColor ?? (isDark ? Palette.nightSecondary : Palette.daySecondary),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              item.icon,
              color: isDark ? Colors.white : Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
