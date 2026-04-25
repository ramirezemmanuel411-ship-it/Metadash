import 'package:flutter/material.dart';
import '../../shared/user_settings.dart';
import '../../shared/palette.dart';

class AppearanceSelector extends StatelessWidget {
  const AppearanceSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Appearance',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: UserSettings.themeMode,
            builder: (context, currentMode, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AppearanceOption(
                    label: 'Auto',
                    mode: ThemeMode.system,
                    selected: currentMode == ThemeMode.system,
                    onTap: () => UserSettings.themeMode.value = ThemeMode.system,
                  ),
                  _AppearanceOption(
                    label: 'Day',
                    mode: ThemeMode.light,
                    selected: currentMode == ThemeMode.light,
                    onTap: () => UserSettings.themeMode.value = ThemeMode.light,
                  ),
                  _AppearanceOption(
                    label: 'Night',
                    mode: ThemeMode.dark,
                    selected: currentMode == ThemeMode.dark,
                    onTap: () => UserSettings.themeMode.value = ThemeMode.dark,
                  ),
                ],
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
        children: [
          Container(
            width: 80,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? Palette.forestGreen : Colors.grey.withOpacity(0.3),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Palette.forestGreen.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _buildPreview(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Palette.forestGreen : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (mode == ThemeMode.system) {
      return Row(
        children: [
          Expanded(child: _buildThemePreview(Brightness.light)),
          Expanded(child: _buildThemePreview(Brightness.dark)),
        ],
      );
    }
    return _buildThemePreview(
      mode == ThemeMode.light ? Brightness.light : Brightness.dark,
    );
  }

  Widget _buildThemePreview(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? Palette.nightBackground : Palette.dayBackground;
    final cardColor = isDark ? Palette.nightCard : Palette.dayCard;
    final accentColor = Palette.forestGreen;

    return Container(
      color: bgColor,
      child: Stack(
        children: [
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 12,
            child: Container(
              color: isDark ? Palette.nightSecondary : Palette.daySecondary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 2,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          // Main Card
          Positioned(
            top: 18,
            left: 6,
            right: 6,
            bottom: 6,
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 15,
                      height: 2,
                      color: isDark ? Palette.nightTextMuted : Palette.dayTextSecondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 10,
                      height: 2,
                      color: isDark ? Palette.nightTextMuted : Palette.dayTextSecondary.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
