import 'package:flutter/material.dart';

class Palette {
  // Brand Colors
  static const forestGreen = Color(0xFF2E8B57);
  static const nightAccentBlue = Color(0xFF4C7FA8);

  // Day Theme (#F6F3EC)
  static const dayBackground = Color(0xFFF6F3EC);
  static const dayCard = Color(0xFFE7E2D8);
  static const daySecondary = Color(0xFFDDD8CF);
  static const dayTextPrimary = Color(0xFF1F1F1B);
  static const dayTextSecondary = Color(0xFF2A2825);
  static const dayTextMuted = Color(0xFF3D3A35);
  static const dayDivider = Color(0x0F000000);

  // Night Theme (#161816)
  static const nightBackground = Color(0xFF161816);
  static const nightCard = Color(0xFF222522);
  static const nightSecondary = Color(0xFF2D312D);
  // Use Material dark-mode emphasis whites for better legibility
  static const nightTextPrimary = Color(0xDEFFFFFF); // 87% white
  static const nightTextSecondary = Color(0xCCFFFFFF); // 80% white
  static const nightTextMuted = Color(0x99FFFFFF); // 60% white
  static const nightDivider = Color(0x0FFFFFFF);

  // Legacy (Phasing out)
  static const warmNeutral = dayBackground;
  static const lightStone = dayCard;

  /// Backward-compat alias used by older screens.
  /// Keep as Night accent to avoid green interactive elements in Night mode.
  static const Color vibrantAction = nightAccentBlue;

  // Macro nutrient identity colors — shared across diary rings and food detail
  static const Color macroProtein = Colors.redAccent;
  static const Color macroCarbs   = Colors.teal;
  static const Color macroFat     = Colors.orange;

  // ── Dashboard widget tint colors ──────────────────────────────────────────
  // Day mode tints
  static const Color widgetWeightDay    = Color(0xFFB5860D); // warm amber/gold
  static const Color widgetActivityDay  = Color(0xFF3A7D54); // soft forest green
  static const Color widgetEnergyDay    = Color(0xFF3D7A8A); // blue-green
  static const Color widgetNutritionDay = Color(0xFFB5622D); // warm orange
  static const Color widgetProteinDay   = Color(0xFFB5404D); // muted coral/red
  static const Color widgetStepsDay     = Color(0xFF5A7A3A); // light sage green
  static const Color widgetTDEEDay      = Color(0xFF2E6E47); // deep forest green
  static const Color widgetFatChangeDay = Color(0xFF3A8C5A); // soft emerald
  static const Color widgetConsistDay   = Color(0xFF3A6EA5); // soft blue

  // Night mode tints
  static const Color widgetWeightNight    = Color(0xFF8B6200); // dark amber
  static const Color widgetActivityNight  = Color(0xFF2E6044); // dark sage
  static const Color widgetEnergyNight    = Color(0xFF2C5A7A); // deep blue (#4C7FA8 darker)
  static const Color widgetNutritionNight = Color(0xFF7A3C1A); // dark warm brown
  static const Color widgetProteinNight   = Color(0xFF8B2E38); // muted coral
  static const Color widgetStepsNight     = Color(0xFF445E28); // dark olive
  static const Color widgetTDEENight      = Color(0xFF1E5C40); // blue-green dark
  static const Color widgetFatChangeNight = Color(0xFF1E6644); // muted dark green
  static const Color widgetConsistNight   = Color(0xFF1E3D70); // deep cobalt
}

class MetaDashColors extends ThemeExtension<MetaDashColors> {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color cta;
  final Color divider;
  final Color primary;
  final Color onPrimary;
  final Color onSurface;
  final Color inputFill;

  const MetaDashColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.cta,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.onSurface,
    required this.inputFill,
  });

  @override
  ThemeExtension<MetaDashColors> copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? cta,
    Color? divider,
    Color? primary,
    Color? onPrimary,
    Color? onSurface,
    Color? inputFill,
  }) {
    return MetaDashColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      cta: cta ?? this.cta,
      divider: divider ?? this.divider,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      onSurface: onSurface ?? this.onSurface,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  ThemeExtension<MetaDashColors> lerp(
    ThemeExtension<MetaDashColors>? other,
    double t,
  ) {
    if (other is! MetaDashColors) return this;
    return MetaDashColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      cta: Color.lerp(cta, other.cta, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }

  static const day = MetaDashColors(
    background: Palette.dayBackground,
    surface: Palette.dayCard,
    surfaceVariant: Palette.daySecondary,
    textPrimary: Palette.dayTextPrimary,
    textSecondary: Palette.dayTextSecondary,
    textMuted: Palette.dayTextMuted,
    accent: Palette.forestGreen,
    cta: Palette.forestGreen,
    divider: Palette.dayDivider,
    primary: Palette.forestGreen,
    onPrimary: Colors.white,
    onSurface: Palette.dayCard,
    inputFill: Colors.white,
  );

  static const night = MetaDashColors(
    background: Palette.nightBackground,
    surface: Palette.nightCard,
    surfaceVariant: Palette.nightSecondary,
    textPrimary: Palette.nightTextPrimary,
    textSecondary: Palette.nightTextSecondary,
    textMuted: Palette.nightTextMuted,
    accent: Palette.nightAccentBlue,
    cta: Palette.nightAccentBlue,
    divider: Palette.nightDivider,
    primary: Palette.nightAccentBlue,
    onPrimary: Colors.white,
    onSurface: Palette.nightCard,
    inputFill: Palette.nightSecondary,
  );
}

extension MetaDashThemeContext on BuildContext {
  MetaDashColors get colors => Theme.of(this).extension<MetaDashColors>()!;

  Color get bg => colors.background;
  Color get surface => colors.surface;
  Color get surfaceVariant => colors.surfaceVariant;
  Color get textPrimary => colors.textPrimary;
  Color get textSecondary => colors.textSecondary;
  Color get textMuted => colors.textMuted;
  Color get accent => colors.accent;
  Color get cta => colors.cta;
  Color get divider => colors.divider;
  Color get primary => colors.primary;
  Color get onPrimary => colors.onPrimary;
  Color get onSurface => colors.onSurface;
}
