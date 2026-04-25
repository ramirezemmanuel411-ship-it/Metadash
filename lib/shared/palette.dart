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
  static const dayTextSecondary = Color(0xFF6E6A63);
  static const dayTextMuted = Color(0xFF8C887F);
  static const dayDivider = Color(0x0F000000);

  // Night Theme (#161816)
  static const nightBackground = Color(0xFF161816);
  static const nightCard = Color(0xFF222522);
  static const nightSecondary = Color(0xFF2D312D);
  static const nightTextPrimary = Color(0xFFF2F1EC);
  static const nightTextSecondary = Color(0xFFA9ADA6);
  static const nightTextMuted = Color(0xFF6F746E);
  static const nightDivider = Color(0x0FFFFFFF);

  // Legacy (Phasing out)
  static const warmNeutral = dayBackground;
  static const lightStone = dayCard;
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
  );
}

extension MetaDashThemeContext on BuildContext {
  MetaDashColors get colors => Theme.of(this).extension<MetaDashColors>()!;
}
