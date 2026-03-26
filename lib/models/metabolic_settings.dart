/// Metabolic Engine Settings
/// Controls how TDEE and energy expenditure are calculated
class MetabolicSettings {
  final String energyModel; // 'Static', 'Adaptive', 'Hybrid (Recommended)'
  final String workoutAccuracy; // 'Strict', 'Balanced', 'Flexible'

  const MetabolicSettings({
    required this.energyModel,
    required this.workoutAccuracy,
  });

  /// Default settings
  factory MetabolicSettings.defaults() {
    return const MetabolicSettings(
      energyModel: 'Hybrid (Recommended)',
      workoutAccuracy: 'Balanced',
    );
  }

  /// Copy with modifications
  MetabolicSettings copyWith({
    String? energyModel,
    String? workoutAccuracy,
  }) {
    return MetabolicSettings(
      energyModel: energyModel ?? this.energyModel,
      workoutAccuracy: workoutAccuracy ?? this.workoutAccuracy,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'energyModel': energyModel,
      'workoutAccuracy': workoutAccuracy,
    };
  }

  /// Create from JSON
  factory MetabolicSettings.fromJson(Map<String, dynamic> json) {
    return MetabolicSettings(
      energyModel: json['energyModel'] as String? ?? 'Hybrid (Recommended)',
      workoutAccuracy: json['workoutAccuracy'] as String? ?? 'Balanced',
    );
  }

  /// Get workout calorie multiplier based on accuracy setting
  /// Strict = 0.7 (most conservative)
  /// Balanced = 0.8 (default)
  /// Flexible = 1.0 (trusts device data)
  double get workoutCalorieMultiplier {
    switch (workoutAccuracy) {
      case 'Strict':
        return 0.7;
      case 'Flexible':
        return 1.0;
      case 'Balanced':
      default:
        return 0.8;
    }
  }

  /// Whether adaptive adjustments are enabled
  bool get isAdaptiveEnabled {
    return energyModel == 'Adaptive' || energyModel == 'Hybrid (Recommended)';
  }

  /// Whether to use static baseline only
  bool get isStaticOnly {
    return energyModel == 'Static';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetabolicSettings &&
          runtimeType == other.runtimeType &&
          energyModel == other.energyModel &&
          workoutAccuracy == other.workoutAccuracy;

  @override
  int get hashCode => energyModel.hashCode ^ workoutAccuracy.hashCode;
}
