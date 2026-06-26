import 'package:flutter/material.dart';

import 'package:metadash/shared/palette.dart';
import 'package:metadash/shared/user_settings.dart';

class AppearanceSelectorClean extends StatelessWidget {
  const AppearanceSelectorClean({super.key});

  @override
  Widget build(BuildContext context) {
    const tileSpacing = 8.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Make tile sizing responsive so the row cannot overflow.
          LayoutBuilder(
            builder: (context, constraints) {
              final available = constraints.maxWidth;
              // Reserve some padding and spacing; compute a reasonable tile width.
              final ideal = (available - 16) / 3.0; // try to fit 3 tiles
              final tileWidth = ideal.clamp(68.0, 128.0);

              return ValueListenableBuilder<ThemeMode>(
                valueListenable: UserSettings.themeMode,
                builder: (context, currentMode, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _AppearanceOption(
                          label: 'Auto',
                          mode: ThemeMode.system,
                          selected: currentMode == ThemeMode.system,
                          onTap: () =>
                              UserSettings.themeMode.value = ThemeMode.system,
                        ),
                      ),
                      const SizedBox(width: tileSpacing),
                      SizedBox(
                        width: tileWidth,
                        child: _AppearanceOption(
                          label: 'Day',
                          mode: ThemeMode.light,
                          selected: currentMode == ThemeMode.light,
                          onTap: () =>
                              UserSettings.themeMode.value = ThemeMode.light,
                        ),
                      ),
                      const SizedBox(width: tileSpacing),
                      SizedBox(
                        width: tileWidth,
                        child: _AppearanceOption(
                          label: 'Night',
                          mode: ThemeMode.dark,
                          selected: currentMode == ThemeMode.dark,
                          onTap: () =>
                              UserSettings.themeMode.value = ThemeMode.dark,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _AppearanceOption({
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(context),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? context.colors.accent
                  : context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    // Keep icon area flexible but with a sensible baseline size.
    const baseWidth = 96.0;
    const baseHeight = 72.0;

    final borderColor = selected
        ? context.colors.accent
        : context.colors.textMuted.withValues(alpha: 0.18);

    if (mode == ThemeMode.system) {
      // Auto: split thumbnail showing Day on the left and Night on the right.
      return Container(
        width: baseWidth,
        height: baseHeight,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: context.colors.accent.withValues(alpha: 0.11),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              // Left: Day art (use Palette colors; not runtime)
              Expanded(child: _autoHalf(isLeft: true)),
              Container(
                width: 1,
                color: Palette.dayTextMuted.withValues(alpha: 0.22),
              ),
              // Right: Night art
              Expanded(child: _autoHalf(isLeft: false)),
            ],
          ),
        ),
      );
    }

    final isDark = mode == ThemeMode.dark;
    final outerBg = isDark ? Palette.nightSecondary : Palette.dayBackground;
    final innerBg = isDark ? Palette.nightCard : Palette.dayCard;
    final accent = isDark ? Palette.nightAccentBlue : Palette.forestGreen;

    return Container(
      width: baseWidth,
      height: baseHeight,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: outerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.11),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: innerBg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: LayoutBuilder(
            builder: (context, c) {
              final h = c.maxHeight.isFinite && c.maxHeight > 0
                  ? c.maxHeight
                  : baseHeight;
              // Emphasize the accent color with a larger solid block and a lighter secondary block below.
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: h * 0.5,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: h * 0.22,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.14 : 0.16),
                      borderRadius: BorderRadius.circular(6),
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
        final h = c.maxHeight.isFinite && c.maxHeight > 0 ? c.maxHeight : 1.0;
        final bg = isLeft ? Palette.dayCard : Palette.nightCard;
        final accent = isLeft ? Palette.forestGreen : Palette.nightAccentBlue;

        // Simplified artwork for each half to avoid intrinsic minimum-width rows.
        return Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: h * 0.28,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              SizedBox(height: h * 0.10),
              Container(
                height: h * 0.16,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
