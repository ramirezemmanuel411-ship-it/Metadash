import 'dart:convert';

class ServingOptionRaw {
  final String? label;
  final double? quantity;
  final String? unit;
  final double? weightGrams;
  final double? volumeMl;
  final Map<String, dynamic>? rawJson;

  const ServingOptionRaw({
    this.label,
    this.quantity,
    this.unit,
    this.weightGrams,
    this.volumeMl,
    this.rawJson,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'quantity': quantity,
      'unit': unit,
      'weight_grams': weightGrams,
      'volume_ml': volumeMl,
      'raw_json': rawJson,
    };
  }

  factory ServingOptionRaw.fromJson(Map<String, dynamic> json) {
    return ServingOptionRaw(
      label: json['label'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      weightGrams: (json['weight_grams'] as num?)?.toDouble(),
      volumeMl: (json['volume_ml'] as num?)?.toDouble(),
      rawJson: json['raw_json'] as Map<String, dynamic>?,
    );
  }

  static List<ServingOptionRaw> listFromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return const [];
    final decoded = jsonDecode(jsonString) as List<dynamic>;
    return decoded
        .map((e) => ServingOptionRaw.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJsonString(List<ServingOptionRaw> options) {
    return jsonEncode(options.map((e) => e.toJson()).toList());
  }
}

class FoodSearchResultRaw {
  // Required IDs / source
  final String id;
  final String source;
  final String? sourceId;
  final String? barcode;
  final bool? verified;
  final double? providerScore;

  // Naming fields
  final String? foodNameRaw;
  final String? foodName;
  final String? brandName;
  final String? brandOwner;
  final String? restaurantName;
  final String? category;
  final String? subcategory;
  final String? languageCode;

  // Serving / portion fields
  final double? servingQty;
  final String? servingUnit;
  final double? servingWeightGrams;
  final double? servingVolumeMl;
  final List<ServingOptionRaw> servingOptions;

  // Nutrition fields
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String? nutritionBasis;
  final Map<String, dynamic> rawJson;

  // Metadata / quality signals
  final DateTime? lastUpdated;
  final String? dataType;
  final int? popularity;
  final bool? isGeneric;
  final bool? isBranded;

  const FoodSearchResultRaw({
    required this.id,
    required this.source,
    required this.rawJson,
    this.sourceId,
    this.barcode,
    this.verified,
    this.providerScore,
    this.foodNameRaw,
    this.foodName,
    this.brandName,
    this.brandOwner,
    this.restaurantName,
    this.category,
    this.subcategory,
    this.languageCode,
    this.servingQty,
    this.servingUnit,
    this.servingWeightGrams,
    this.servingVolumeMl,
    this.servingOptions = const [],
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.nutritionBasis,
    this.lastUpdated,
    this.dataType,
    this.popularity,
    this.isGeneric,
    this.isBranded,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'source_id': sourceId,
      'barcode': barcode,
      'verified': verified,
      'provider_score': providerScore,
      'food_name_raw': foodNameRaw,
      'food_name': foodName,
      'brand_name': brandName,
      'brand_owner': brandOwner,
      'restaurant_name': restaurantName,
      'category': category,
      'subcategory': subcategory,
      'language_code': languageCode,
      'serving_qty': servingQty,
      'serving_unit': servingUnit,
      'serving_weight_grams': servingWeightGrams,
      'serving_volume_ml': servingVolumeMl,
      'serving_options': servingOptions.map((e) => e.toJson()).toList(),
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'nutrition_basis': nutritionBasis,
      'raw_json': rawJson,
      'last_updated': lastUpdated?.toIso8601String(),
      'data_type': dataType,
      'popularity': popularity,
      'is_generic': isGeneric,
      'is_branded': isBranded,
    };
  }

  factory FoodSearchResultRaw.fromJson(Map<String, dynamic> json) {
    return FoodSearchResultRaw(
      id: json['id'] as String,
      source: json['source'] as String,
      sourceId: json['source_id'] as String?,
      barcode: json['barcode'] as String?,
      verified: json['verified'] as bool?,
      providerScore: (json['provider_score'] as num?)?.toDouble(),
      foodNameRaw: json['food_name_raw'] as String?,
      foodName: json['food_name'] as String?,
      brandName: json['brand_name'] as String?,
      brandOwner: json['brand_owner'] as String?,
      restaurantName: json['restaurant_name'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      languageCode: json['language_code'] as String?,
      servingQty: (json['serving_qty'] as num?)?.toDouble(),
      servingUnit: json['serving_unit'] as String?,
      servingWeightGrams: (json['serving_weight_grams'] as num?)?.toDouble(),
      servingVolumeMl: (json['serving_volume_ml'] as num?)?.toDouble(),
      servingOptions: (json['serving_options'] as List<dynamic>? ?? [])
          .map((e) => ServingOptionRaw.fromJson(e as Map<String, dynamic>))
          .toList(),
      calories: (json['calories'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      nutritionBasis: json['nutrition_basis'] as String?,
      rawJson: (json['raw_json'] as Map<String, dynamic>?) ?? const {},
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
      dataType: json['data_type'] as String?,
      popularity: json['popularity'] as int?,
      isGeneric: json['is_generic'] as bool?,
      isBranded: json['is_branded'] as bool?,
    );
  }
}
