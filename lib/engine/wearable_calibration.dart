/// Wearable device family calibration multipliers.
///
/// These are research-informed confidence multipliers applied ONLY to active
/// workout calories reported by a specific device family.
///
/// NOT applied to: BMR, food intake, body weight, manually entered calories,
/// or daily steps.
enum WearableFamily {
  appleWatch,
  garmin,
  whoop,
  fitbit,
  samsungGalaxyWatch,
  polar,
  oura,
  pixelWatch,
  unknown,
}

class WearableCalibration {
  WearableCalibration._();

  /// Confidence multiplier for a given [WearableFamily].
  static double multiplierFor(WearableFamily family) {
    switch (family) {
      case WearableFamily.appleWatch:
        return 0.82;
      case WearableFamily.garmin:
        return 0.86;
      case WearableFamily.whoop:
        return 0.78;
      case WearableFamily.fitbit:
        return 0.75;
      case WearableFamily.samsungGalaxyWatch:
        return 0.76;
      case WearableFamily.polar:
        return 0.84;
      case WearableFamily.oura:
        return 0.70;
      case WearableFamily.pixelWatch:
        return 0.76;
      case WearableFamily.unknown:
        return 0.75;
    }
  }

  /// Infer device family from a source / device name string (e.g. HealthKit
  /// `sourceName` metadata). Falls back to [WearableFamily.unknown].
  static WearableFamily inferFromSourceName(String? sourceName) {
    if (sourceName == null || sourceName.isEmpty) return WearableFamily.unknown;
    final s = sourceName.toLowerCase();
    if (s.contains('apple watch') || s.contains('applewatch')) {
      return WearableFamily.appleWatch;
    }
    if (s.contains('garmin')) return WearableFamily.garmin;
    if (s.contains('whoop')) return WearableFamily.whoop;
    if (s.contains('fitbit')) return WearableFamily.fitbit;
    if (s.contains('samsung') || s.contains('galaxy watch')) {
      return WearableFamily.samsungGalaxyWatch;
    }
    if (s.contains('polar')) return WearableFamily.polar;
    if (s.contains('oura')) return WearableFamily.oura;
    if (s.contains('pixel')) return WearableFamily.pixelWatch;
    return WearableFamily.unknown;
  }

  /// Serialise a [WearableFamily] to a stable string for storage.
  static String toStorageString(WearableFamily family) => family.name;

  /// Deserialise from storage string. Returns [WearableFamily.unknown] on
  /// unrecognised input.
  static WearableFamily fromStorageString(String? value) {
    if (value == null) return WearableFamily.unknown;
    return WearableFamily.values.firstWhere(
      (f) => f.name == value,
      orElse: () => WearableFamily.unknown,
    );
  }
}
