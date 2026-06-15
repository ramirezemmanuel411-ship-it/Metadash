/// Personalized heart-rate zones using the Karvonen formula.
///
/// maxHR  = 208 - 0.7 * age  (Tanaka formula, more accurate than 220-age)
/// HRR    = maxHR - restingHR
/// zone N = restingHR + (loPct * HRR)  ..  restingHR + (hiPct * HRR)
///
/// Zone percentages match Apple Fitness+ / Polar five-zone model:
///   Z1  50–60 %  Recovery
///   Z2  60–70 %  Fat Burn / aerobic base
///   Z3  70–80 %  Cardio / aerobic threshold
///   Z4  80–90 %  Threshold / anaerobic
///   Z5  90–100%  Max effort
class HrZones {
  final int maxHr;
  final int restingHr;

  // Zone boundaries (inclusive on low, exclusive on high)
  final int z1Lo, z1Hi;
  final int z2Lo, z2Hi;
  final int z3Lo, z3Hi;
  final int z4Lo, z4Hi;
  final int z5Lo;

  HrZones._({
    required this.maxHr,
    required this.restingHr,
    required this.z1Lo,
    required this.z1Hi,
    required this.z2Lo,
    required this.z2Hi,
    required this.z3Lo,
    required this.z3Hi,
    required this.z4Lo,
    required this.z4Hi,
    required this.z5Lo,
  });

  factory HrZones.compute({required int age, required int restingHr}) {
    final max = (208 - 0.7 * age).round().clamp(120, 220);
    final hrr = (max - restingHr).clamp(20, 200);
    int t(double pct) => (restingHr + pct * hrr).round();

    return HrZones._(
      maxHr: max,
      restingHr: restingHr,
      z1Lo: t(0.50), z1Hi: t(0.60),
      z2Lo: t(0.60), z2Hi: t(0.70),
      z3Lo: t(0.70), z3Hi: t(0.80),
      z4Lo: t(0.80), z4Hi: t(0.90),
      z5Lo: t(0.90),
    );
  }

  /// Fallback when no profile data is available (assumes age 30, RHR 65)
  factory HrZones.defaults() => HrZones.compute(age: 30, restingHr: 65);

  /// Which zone does this BPM fall in? Returns 1–5.
  int zoneFor(int bpm) {
    if (bpm < z2Lo) return 1;
    if (bpm < z3Lo) return 2;
    if (bpm < z4Lo) return 3;
    if (bpm < z5Lo) return 4;
    return 5;
  }

  String labelFor(int zone) => const [
    'Zone 1 · Recovery',
    'Zone 2 · Fat Burn',
    'Zone 3 · Cardio',
    'Zone 4 · Threshold',
    'Zone 5 · Max Effort',
  ][zone - 1];

  String rangeFor(int zone) {
    switch (zone) {
      case 1: return '< $z2Lo bpm';
      case 2: return '$z2Lo–${z3Lo - 1} bpm';
      case 3: return '$z3Lo–${z4Lo - 1} bpm';
      case 4: return '$z4Lo–${z5Lo - 1} bpm';
      default: return '$z5Lo+ bpm';
    }
  }

  /// Maps zones to WorkoutIntensity:
  ///   Z1–Z2 → light  |  Z3 → moderate  |  Z4–Z5 → intense
  static const _intensityMap = [null, 0, 0, 1, 2, 2]; // index = zone
  int? intensityIndexFor(int bpm) => _intensityMap[zoneFor(bpm)];
}
