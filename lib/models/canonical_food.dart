/// Canonical food display model - used only for UI rendering
///
/// This model represents the cleaned, deduplicated version of food data
/// that should be shown to users. Raw database strings are never displayed.
class CanonicalFoodDisplay {
  /// Canonical brand name (resolved from restaurant_name → brand_owner → brand_name → inferred)
  final String brand;

  /// Detected variant from fixed whitelist, or null if none
  /// Whitelist: Diet, Zero, Cherry, Vanilla, Lime, Caffeine Free
  final String? variant;

  /// Grouping key for deduplication: {brand + variant}
  final String canonicalKey;

  /// Clean display name for UI
  /// Format: {Brand} or {Brand} ({Variant})
  final String displayName;

  /// Normalized nutrition display (shown once)
  /// Format: "X kcal · Y ml" or "X kcal · 100 ml" or "X kcal"
  final String nutritionDisplay;

  /// Original raw result ID this was derived from
  final String rawResultId;

  /// Selection reason for debugging
  final String? selectionReason;

  CanonicalFoodDisplay({
    required this.brand,
    this.variant,
    required this.canonicalKey,
    required this.displayName,
    required this.nutritionDisplay,
    required this.rawResultId,
    this.selectionReason,
  });

  /// Generate display name from brand and variant
  /// Format: {Brand} or {Brand} ({Variant})
  static String generateDisplayName(String brand, String? variant) {
    if (variant == null || variant.isEmpty) {
      return brand;
    }
    return '$brand ($variant)';
  }

  @override
  String toString() =>
      'CanonicalFoodDisplay(brand: $brand, variant: $variant, displayName: $displayName)';
}
