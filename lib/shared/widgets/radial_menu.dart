import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../palette.dart';
import '../../features/food_search/food_search_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/progress/progress_screen.dart';

class RadialMenu extends StatefulWidget {
  const RadialMenu();

  @override
  State<RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 45).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _closeMenu() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dimmed backdrop (behind menu items)
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        // Radial menu items
        ..._buildMenuItems(),
        // Main FAB button (always on top, z-index last)
        Positioned(
          bottom: 48,
          right: 32,
          child: GestureDetector(
            onTap: _toggleMenu,
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * (math.pi / 180),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Palette.forestGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      color: Palette.warmNeutral,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMenuItems() {
    const arcStart = 0.0;
    const arcEnd = 90.0;
    const radius = 140.0;
    const fabSize = 56.0;
    const fabBottom = 32.0;
    const fabRight = 32.0;
    const itemSize = 44.0;

    final items = [
      (icon: Icons.person, label: 'Profile', index: 0),
      (icon: Icons.fitness_center, label: 'Workouts', index: 1),
      (icon: Icons.restaurant, label: 'Log Food', index: 2),
      (icon: Icons.scale, label: 'Progress', index: 3),
    ];

    if (!_isOpen) return [];

    return items.map((item) {
      final angle = arcStart + (arcEnd - arcStart) * (item.index / (items.length - 1));
      final radians = angle * (math.pi / 180);
      
      // For bottom-right quarter circle: 0° is right, 90° is up
      final offsetX = math.cos(radians) * radius;
      final offsetY = math.sin(radians) * radius;

      // Final position relative to FAB center
      final itemRight = fabRight + (fabSize - itemSize) / 2 + offsetX;
      final itemBottom = fabBottom + (fabSize - itemSize) / 2 + offsetY;
      
      // Initial position (at FAB center)
      final initialRight = fabRight + (fabSize - itemSize) / 2;
      final initialBottom = fabBottom + (fabSize - itemSize) / 2;

      final isEmphasized = item.index == 1;
      final scale = isEmphasized ? 1.08 : 1.0;

      return AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final animationProgress = _scaleAnimation.value;
          final animatedRight = initialRight + (itemRight - initialRight) * animationProgress;
          final animatedBottom = initialBottom + (itemBottom - initialBottom) * animationProgress;
          
          return Positioned(
            bottom: animatedBottom,
            right: animatedRight,
            child: child!,
          );
        },
        child: GestureDetector(
          onTap: () async {
            _closeMenu();
            await Future.delayed(const Duration(milliseconds: 250));
            if (!context.mounted) return;
            
            if (item.label == 'Profile') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            } else if (item.label == 'Log Food') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FoodSearchScreen()),
              );
            } else if (item.label == 'Progress') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProgressScreen()),
              );
            }
          },
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: itemSize,
                height: itemSize,
                decoration: BoxDecoration(
                  color: Palette.forestGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  item.icon,
                  color: Palette.warmNeutral,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
