// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:metadash/features/food_search/food_plate_screen.dart';
import 'package:metadash/providers/food_plate_provider.dart';
import 'package:metadash/shared/palette.dart';
import 'package:provider/provider.dart';

/// Floating pill displayed above the dot navigation indicators when the
/// Food Plate has at least one staged item. Tapping opens [FoodPlateScreen].
class FoodPlatePill extends StatelessWidget {
  /// Called after items are committed from FoodPlateScreen so the parent
  /// shell can reload its daily totals.
  final VoidCallback? onAdded;

  const FoodPlatePill({super.key, this.onAdded});

  @override
  Widget build(BuildContext context) {
    return Consumer<FoodPlateProvider>(
      builder: (context, plate, _) {
        final visible = plate.isNotEmpty;

        return AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.5),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              ignoring: !visible,
              child: _PillContent(plate: plate, onAdded: onAdded),
            ),
          ),
        );
      },
    );
  }
}

class _PillContent extends StatelessWidget {
  final FoodPlateProvider plate;
  final VoidCallback? onAdded;

  const _PillContent({required this.plate, this.onAdded});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = plate.itemCount;
    final kcal = plate.totalCalories;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FoodPlateScreen(onAdded: onAdded)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.cta,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Plate icon with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.dinner_dining_outlined,
                  size: 16,
                  color: colors.onPrimary,
                ),
                Positioned(
                  top: -4,
                  right: -5,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.cta),
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: colors.cta,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count item${count == 1 ? '' : 's'} on plate',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimary,
                    height: 1.2,
                  ),
                ),
                Text(
                  '${_fmtNum(kcal)} kcal · P ${plate.totalProtein}g C ${plate.totalCarbs}g F ${plate.totalFat}g',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onPrimary.withOpacity(0.75),
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: colors.onPrimary.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}
