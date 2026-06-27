/// Internal energy behaviour buckets for workout classification.
///
/// Users always see original workout names from Apple Health / Health Connect.
/// These buckets are used only inside the MetaDash energy engine.
enum WorkoutBucket {
  /// Primary movement driven by displacement / steps.
  /// Requires step de-duplication; uses distance-based calorie formula.
  locomotion,

  /// Resistance / free-weight training.
  strength,

  /// Machine-paced or water-based steady-state cardio.
  steadyCardio,

  /// Minimal caloric demand movement.
  lowImpact,

  /// Court / field / racket sports with highly variable intensity.
  sport,

  /// Golf — separated because wearable calorie behaviour is unusually inconsistent.
  golf,

  /// Unknown or multi-modal — engine uses 50/50 fallback blend.
  mixed,
}

/// Maps raw workout type strings (from HealthKit / Health Connect) to an
/// internal [WorkoutBucket].
///
/// Input strings are normalised to lower-case before matching.
class WorkoutClassifier {
  WorkoutClassifier._();

  static WorkoutBucket classify(String? rawType) {
    if (rawType == null || rawType.isEmpty) return WorkoutBucket.mixed;

    final t = rawType.toLowerCase().replaceAll(RegExp(r'[_\s]+'), '_').trim();

    if (_locomotionTokens.any(t.contains)) return WorkoutBucket.locomotion;
    if (_strengthTokens.any(t.contains)) return WorkoutBucket.strength;
    if (t.contains('golf')) return WorkoutBucket.golf;
    if (_sportTokens.any(t.contains)) return WorkoutBucket.sport;
    if (_steadyCardioTokens.any(t.contains)) return WorkoutBucket.steadyCardio;
    if (_lowImpactTokens.any(t.contains)) return WorkoutBucket.lowImpact;

    return WorkoutBucket.mixed;
  }

  // ── Token lists ─────────────────────────────────────────────────────────────

  static const _locomotionTokens = [
    'run',
    'walk',
    'hike',
    'hiking',
    'treadmill',
    'stair',
    'trail',
    'jog',
    'race',
    'march',
    'trek',
  ];

  static const _strengthTokens = [
    'strength',
    'weight',
    'resistance',
    'bodybuilding',
    'powerlifting',
    'functional_strength',
    'core_training',
    'cross_training',
  ];

  static const _sportTokens = [
    'tennis',
    'basketball',
    'soccer',
    'pickleball',
    'boxing',
    'martial',
    'volleyball',
    'baseball',
    'softball',
    'football',
    'badminton',
    'squash',
    'racquetball',
    'handball',
    'lacrosse',
    'hockey',
    'wrestling',
    'climbing',
    'bouldering',
    'fencing',
    'dance',
    'kickbox',
    'muay',
    'judo',
    'karate',
    'taekwondo',
    'gymnastics',
    'cheerleading',
    'surfing',
    'skateboard',
    'snowboard',
    'skiing',
    'ice_skat',
    'roller',
    'cricket',
    'rugby',
  ];

  static const _steadyCardioTokens = [
    'cycl',
    'bike',
    'row',
    'elliptical',
    'swim',
    'water_fitness',
    'cross_country_ski',
    'paddle',
    'kayak',
    'canoe',
  ];

  static const _lowImpactTokens = [
    'yoga',
    'pilate',
    'mobility',
    'stretch',
    'flexibility',
    'mindful',
    'meditation',
    'barre',
    'tai_chi',
  ];
}
