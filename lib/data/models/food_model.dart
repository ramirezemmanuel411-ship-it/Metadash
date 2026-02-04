import 'dart:convert';
import 'package:equatable/equatable.dart';
import '../../services/food_text_normalizer.dart';
import '../../services/food_dedup_normalizer.dart';
import 'food_search_result_raw.dart';

/// Enhanced Food model with caching metadata and serialization
class FoodModel extends Equatable {
  final String id;
  final String name;
  final String? brand;
  final double servingSize;
  final String servingUnit;
  final int calories;
  final double protein; // grams
  final double carbs; // grams
  final double fat; // grams
  final String source; // 'usda', 'open_food_facts', or 'local'
  final String nameNormalized; // Lowercase, no special chars for search
  final DateTime? updatedAt;
  final bool isFavorite;

  // Raw fields for normalization/ranking/deduplication
  final String? sourceId;
  final String? barcode;
  final bool? verified;
  final double? confidence;
  final String? foodNameRaw;
  final String? foodName;
  final String? brandName;
  final String? brandOwner;
  final String? restaurantName;
  final String? category;
  final String? subcategory;
  final String? languageCode;
  final double? servingQty;
  final String? servingUnitRaw;
  final double? servingWeightGrams;
  final double? servingVolumeMl;
  final List<ServingOptionRaw> servingOptions;
  final String? nutritionBasis;
  final Map<String, dynamic>? rawJson;
  final DateTime? lastUpdated;
  final String? dataType;
  final int? popularity;
  final bool? isGeneric;
  final bool? isBranded;

  const FoodModel({
    required this.id,
    required this.name,
    this.brand,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.source,
    String? nameNormalized,
    this.updatedAt,
    this.isFavorite = false,
    this.sourceId,
    this.barcode,
    this.verified,
    this.confidence,
    this.foodNameRaw,
    this.foodName,
    this.brandName,
    this.brandOwner,
    this.restaurantName,
    this.category,
    this.subcategory,
    this.languageCode,
    this.servingQty,
    this.servingUnitRaw,
    this.servingWeightGrams,
    this.servingVolumeMl,
    this.servingOptions = const [],
    this.nutritionBasis,
    this.rawJson,
    this.lastUpdated,
    this.dataType,
    this.popularity,
    this.isGeneric,
    this.isBranded,
  }) : nameNormalized = nameNormalized ?? '';

  /// Display title: clean, readable product name
  /// Keep brand in title for clarity, just normalize and clean
  String get displayTitle {
    String title = name;
    
    // Remove trademark symbols
    title = title.replaceAll('®', '').replaceAll('™', '').replaceAll('©', '');
    
    // Normalize text (lowercase, accents, punctuation, whitespace)
    title = FoodTextNormalizer.normalize(title);
    
    // Remove repeated words (e.g., "coke coke" -> "coke")
    final words = title.split(RegExp(r'\s+'));
    final uniqueWords = <String>[];
    String? lastWord;
    for (final word in words) {
      if (word.isNotEmpty && word.toLowerCase() != lastWord?.toLowerCase()) {
        uniqueWords.add(word);
      }
      lastWord = word;
    }
    title = uniqueWords.join(' ').trim();
    
    // If title is empty, use brand as fallback
    if (title.isEmpty && brand != null && brand!.isNotEmpty) {
      title = FoodTextNormalizer.normalize(brand!);
    }
    
    return title;
  }
  
  /// Convert to title case while preserving brand stylization
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    
    // Preserve known brand stylizations
    const preservedWords = {
      'coke': 'Coke',
      'pepsi': 'Pepsi',
      'mcdonald': 'McDonald',
      'kfc': 'KFC',
      'usda': 'USDA',
    };
    
    final words = text.split(' ');
    final titleCased = words.map((word) {
      if (word.isEmpty) return word;
      
      final lower = word.toLowerCase();
      // Check for preserved brand names
      for (final entry in preservedWords.entries) {
        if (lower.contains(entry.key)) {
          return word.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
        }
      }
      
      // Standard title case
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();
    
    return titleCased.join(' ');
  }

  /// Display brand: normalized and cleaned, or empty
  String get displayBrand {
    if (brand == null || brand!.isEmpty) return '';
    final cleaned = FoodTextNormalizer.cleanBrandString(brand!);
    return _toTitleCase(cleaned);
  }

  /// Display subtitle: "Brand • Calories • Serving" format
  /// Example: "Coca Cola • 140 cal • 355 ml"
  String get displaySubtitle {
    final parts = <String>[];
    
    // Add brand if available and not generic
    final cleanBrand = displayBrand;
    if (cleanBrand.isNotEmpty && cleanBrand.toLowerCase() != 'generic') {
      parts.add(cleanBrand);
    } else if (source == 'usda') {
      parts.add('USDA');
    } else if (source == 'open_food_facts') {
      parts.add('Open Food Facts');
    }
    
    // Add calories
    parts.add('$calories cal');
    
    // Add serving info
    final serving = servingLine;
    if (serving != 'serving?') {
      parts.add(serving);
    }
    
    return parts.join(' • ');
  }

  /// Detect if this is a beverage/liquid product
  bool get isBeverage {
    final nameLower = name.toLowerCase();
    final brandLower = (brand ?? '').toLowerCase();
    final searchText = '$nameLower $brandLower';
    
    const beverageKeywords = [
      'coke', 'cola', 'soda', 'beverage', 'drink', 'juice', 
      'coffee', 'tea', 'milk', 'water', 'energy', 'lemonade',
      'sprite', 'fanta', 'pepsi', 'smoothie', 'shake', 'beer',
      'wine', 'liquor', 'cocktail', 'champagne', 'cider'
    ];
    
    return beverageKeywords.any((keyword) => searchText.contains(keyword));
  }

  /// Nutrition basis type detection
  String get nutritionBasisType {
    // If we have a real serving (not 100g/100ml), it's per-serving
    if (servingSize > 0 && servingSize != 100.0 && servingUnit.isNotEmpty) {
      return 'perServing';
    }
    
    // Check if it's per 100ml (beverage standard)
    if (isBeverage || servingUnit.toLowerCase().contains('ml') || servingUnit.toLowerCase().contains('fluid')) {
      return 'per100ml';
    }
    
    // Default to per 100g
    if (servingSize == 100.0 && (servingUnit.toLowerCase().contains('g') || servingUnit.toLowerCase().contains('gram'))) {
      return 'per100g';
    }
    
    return 'unknown';
  }

  /// Serving line for display: "100 ml" or "1 serving" with proper liquid/solid units
  String get servingLine {
    if (servingSize == 0 || servingUnit.isEmpty) {
      return 'serving?';
    }
    
    final sizeStr = servingSize == servingSize.toInt() 
        ? servingSize.toInt().toString() 
        : servingSize.toStringAsFixed(1);
    
    // Fix unit for beverages: if it says "g" but it's a liquid, show "ml"
    String displayUnit = servingUnit;
    if (isBeverage && (servingUnit.toLowerCase() == 'g' || servingUnit.toLowerCase() == 'gram')) {
      displayUnit = 'ml';
    }
    
    return '$sizeStr $displayUnit';
  }

  /// Canonical key for deduplication (with accent/diacritic removal and brand aliases)
  /// Handles: "Diet Coke" vs "Coca-Cola ZÉRO®" vs "C.cola Zero"
  /// All map to same key if they're the same product
  String get canonicalKey {
    return FoodDedupNormalizer.generateCanonicalKey(
      name: name,
      brand: brand,
      nutritionBasisType: nutritionBasisType,
      servingSize: servingSize,
      servingUnit: servingUnit,
      calories: calories,
      isBeverage: isBeverage,
    );
  }

  /// Whether serving information is missing
  bool get isMissingServing => servingSize == 0 || servingUnit.isEmpty;

  /// Normalize name for fast searching (lowercase, no special chars)
  static String normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Create from JSON (SQLite or cache)
  factory FoodModel.fromJson(Map<String, dynamic> json) {
    return FoodModel(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      servingSize: (json['serving_size'] as num).toDouble(),
      servingUnit: json['serving_unit'] as String,
      calories: json['calories'] as int,
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      source: json['source'] as String,
      nameNormalized: json['name_normalized'] as String? ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int)
          : null,
      isFavorite: (json['is_favorite'] as int?) == 1,
      sourceId: json['source_id'] as String?,
      barcode: json['barcode'] as String?,
      verified: json['verified'] == null
          ? null
          : (json['verified'] as int?) == 1,
      confidence: (json['confidence'] as num?)?.toDouble(),
      foodNameRaw: json['food_name_raw'] as String?,
      foodName: json['food_name'] as String?,
      brandName: json['brand_name'] as String?,
      brandOwner: json['brand_owner'] as String?,
      restaurantName: json['restaurant_name'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      languageCode: json['language_code'] as String?,
      servingQty: (json['serving_qty'] as num?)?.toDouble(),
      servingUnitRaw: json['serving_unit_raw'] as String?,
      servingWeightGrams: (json['serving_weight_grams'] as num?)?.toDouble(),
      servingVolumeMl: (json['serving_volume_ml'] as num?)?.toDouble(),
      servingOptions: ServingOptionRaw.listFromJsonString(
        json['serving_options_json'] as String?,
      ),
      nutritionBasis: json['nutrition_basis'] as String?,
      rawJson: json['raw_json'] != null
          ? jsonDecode(json['raw_json'] as String) as Map<String, dynamic>
          : null,
      lastUpdated: json['last_updated'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['last_updated'] as int)
          : null,
      dataType: json['data_type'] as String?,
      popularity: json['popularity'] as int?,
      isGeneric: json['is_generic'] == null
          ? null
          : (json['is_generic'] as int?) == 1,
      isBranded: json['is_branded'] == null
          ? null
          : (json['is_branded'] as int?) == 1,
    );
  }

  /// Convert to JSON for caching/database
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'serving_size': servingSize,
      'serving_unit': servingUnit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'source': source,
      'name_normalized': nameNormalized.isEmpty
          ? normalizeName(name + (brand ?? ''))
          : nameNormalized,
      'updated_at': updatedAt?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      'is_favorite': isFavorite ? 1 : 0,
      'source_id': sourceId,
      'barcode': barcode,
      'verified': verified == null ? null : (verified! ? 1 : 0),
      'confidence': confidence,
      'food_name_raw': foodNameRaw,
      'food_name': foodName,
      'brand_name': brandName,
      'brand_owner': brandOwner,
      'restaurant_name': restaurantName,
      'category': category,
      'subcategory': subcategory,
      'language_code': languageCode,
      'serving_qty': servingQty,
      'serving_unit_raw': servingUnitRaw,
      'serving_weight_grams': servingWeightGrams,
      'serving_volume_ml': servingVolumeMl,
      'serving_options_json': ServingOptionRaw.listToJsonString(servingOptions),
      'nutrition_basis': nutritionBasis,
      'raw_json': rawJson == null ? null : jsonEncode(rawJson),
      'last_updated': lastUpdated?.millisecondsSinceEpoch,
      'data_type': dataType,
      'popularity': popularity,
      'is_generic': isGeneric == null ? null : (isGeneric! ? 1 : 0),
      'is_branded': isBranded == null ? null : (isBranded! ? 1 : 0),
    };
  }

  /// Create with normalized name
  factory FoodModel.create({
    required String id,
    required String name,
    String? brand,
    required double servingSize,
    required String servingUnit,
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    required String source,
    bool isFavorite = false,
    FoodSearchResultRaw? raw,
  }) {
    final normalized = normalizeName(name + (brand ?? ''));
    return FoodModel(
      id: id,
      name: name,
      brand: brand,
      servingSize: servingSize,
      servingUnit: servingUnit,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      source: source,
      nameNormalized: normalized,
      updatedAt: DateTime.now(),
      isFavorite: isFavorite,
      sourceId: raw?.sourceId,
      barcode: raw?.barcode,
      verified: raw?.verified,
      confidence: raw?.providerScore,
      foodNameRaw: raw?.foodNameRaw,
      foodName: raw?.foodName,
      brandName: raw?.brandName,
      brandOwner: raw?.brandOwner,
      restaurantName: raw?.restaurantName,
      category: raw?.category,
      subcategory: raw?.subcategory,
      languageCode: raw?.languageCode,
      servingQty: raw?.servingQty,
      servingUnitRaw: raw?.servingUnit,
      servingWeightGrams: raw?.servingWeightGrams,
      servingVolumeMl: raw?.servingVolumeMl,
      servingOptions: raw?.servingOptions ?? const [],
      nutritionBasis: raw?.nutritionBasis,
      rawJson: raw?.rawJson,
      lastUpdated: raw?.lastUpdated,
      dataType: raw?.dataType,
      popularity: raw?.popularity,
      isGeneric: raw?.isGeneric,
      isBranded: raw?.isBranded,
    );
  }

  /// Create from raw result (preferred for API responses)
  factory FoodModel.fromRaw(FoodSearchResultRaw raw) {
    final name = raw.foodName ?? raw.foodNameRaw ?? 'Unknown';
    final brand = raw.brandName ?? raw.brandOwner ?? raw.restaurantName;
    final servingSize = raw.servingQty ??
        raw.servingWeightGrams ??
        raw.servingVolumeMl ??
        0;
    final servingUnit = raw.servingUnit ??
        (raw.servingWeightGrams != null ? 'g' : raw.servingVolumeMl != null ? 'ml' : 'g');

    return FoodModel.create(
      id: raw.id,
      name: name,
      brand: brand,
      servingSize: servingSize,
      servingUnit: servingUnit,
      calories: raw.calories?.round() ?? 0,
      protein: raw.proteinG ?? 0,
      carbs: raw.carbsG ?? 0,
      fat: raw.fatG ?? 0,
      source: raw.source,
      raw: raw,
    );
  }

  /// Check if cached data is still fresh (< 24 hours)
  bool get isFresh {
    if (updatedAt == null) return false;
    final age = DateTime.now().difference(updatedAt!);
    return age.inHours < 24;
  }

  /// Copy with updated fields
  FoodModel copyWith({
    String? id,
    String? name,
    String? brand,
    double? servingSize,
    String? servingUnit,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? source,
    String? nameNormalized,
    DateTime? updatedAt,
    bool? isFavorite,
    String? sourceId,
    String? barcode,
    bool? verified,
    double? confidence,
    String? foodNameRaw,
    String? foodName,
    String? brandName,
    String? brandOwner,
    String? restaurantName,
    String? category,
    String? subcategory,
    String? languageCode,
    double? servingQty,
    String? servingUnitRaw,
    double? servingWeightGrams,
    double? servingVolumeMl,
    List<ServingOptionRaw>? servingOptions,
    String? nutritionBasis,
    Map<String, dynamic>? rawJson,
    DateTime? lastUpdated,
    String? dataType,
    int? popularity,
    bool? isGeneric,
    bool? isBranded,
  }) {
    return FoodModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      source: source ?? this.source,
      nameNormalized: nameNormalized ?? this.nameNormalized,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      sourceId: sourceId ?? this.sourceId,
      barcode: barcode ?? this.barcode,
      verified: verified ?? this.verified,
      confidence: confidence ?? this.confidence,
      foodNameRaw: foodNameRaw ?? this.foodNameRaw,
      foodName: foodName ?? this.foodName,
      brandName: brandName ?? this.brandName,
      brandOwner: brandOwner ?? this.brandOwner,
      restaurantName: restaurantName ?? this.restaurantName,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      languageCode: languageCode ?? this.languageCode,
      servingQty: servingQty ?? this.servingQty,
      servingUnitRaw: servingUnitRaw ?? this.servingUnitRaw,
      servingWeightGrams: servingWeightGrams ?? this.servingWeightGrams,
      servingVolumeMl: servingVolumeMl ?? this.servingVolumeMl,
      servingOptions: servingOptions ?? this.servingOptions,
      nutritionBasis: nutritionBasis ?? this.nutritionBasis,
      rawJson: rawJson ?? this.rawJson,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      dataType: dataType ?? this.dataType,
      popularity: popularity ?? this.popularity,
      isGeneric: isGeneric ?? this.isGeneric,
      isBranded: isBranded ?? this.isBranded,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        brand,
        servingSize,
        servingUnit,
        calories,
        protein,
        carbs,
        fat,
        source,
      sourceId,
      barcode,
      verified,
      confidence,
      foodNameRaw,
      foodName,
      brandName,
      brandOwner,
      restaurantName,
      category,
      subcategory,
      languageCode,
      servingQty,
      servingUnitRaw,
      servingWeightGrams,
      servingVolumeMl,
      nutritionBasis,
      dataType,
      popularity,
      isGeneric,
      isBranded,
      ];

  @override
  String toString() =>
      '$name${brand != null ? ' ($brand)' : ''} - $calories cal, P:${protein}g C:${carbs}g F:${fat}g';
}
