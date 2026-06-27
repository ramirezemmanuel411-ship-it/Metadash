import 'package:flutter/material.dart';
import 'package:metadash/core/shared/palette.dart';

export 'appearance_selector_clean.dart';

class AppearanceSelector extends StatelessWidget {
  final bool selected;
  final ThemeMode mode;

  const AppearanceSelector({
    super.key,
    required this.selected,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return _buildIcon(context);
  }

  Widget _buildIcon(BuildContext context) {
    final borderColor = selected
        ? context.colors.accent
        : context.colors.textMuted.withValues(alpha: 0.18);

    if (mode == ThemeMode.system) {
      // Auto: split thumbnail (left = day, right = night)
      return Container(
        width: 96.0,
        height: 72.0,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: context.colors.accent.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              Expanded(child: _autoHalf(isLeft: true)),
              Container(
                width: 1,
                color: context.colors.divider.withValues(alpha: 0.22),
              ),
              Expanded(child: _autoHalf(isLeft: false)),
            ],
          ),
        ),
      );
    }

    // Day/Night thumbnails (fixed artwork colors)
    final isDark = mode == ThemeMode.dark;
    final outerBg = isDark
        ? context.colors.surfaceVariant
        : context.colors.background;
    final innerBg = isDark
        ? context.colors.surface
        : context.colors.surfaceVariant;
    final accent = isDark
        ? context.colors.accent
        : context.colors.accent; // Corrected reference

    return Container(
      width: 96.0,
      height: 72.0,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: outerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: innerBg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: w * 0.36,
                    height: h * 0.12,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.22 : 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: w * 0.72,
                    height: h * 0.18,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.12 : 0.14),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _autoHalf({required bool isLeft}) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final bg = isLeft ? Palette.dayCard : Palette.nightCard;
        final accent = isLeft ? Palette.forestGreen : Palette.nightAccentBlue;

        return Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: w * 0.6,
                height: h * 0.18,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              SizedBox(height: h * 0.12),
              if (w >= 36)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: context.colors.cta.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
