// ignore_for_file: avoid_print

import 'package:dio/dio.dart';
import '../models/food_model.dart';
import '../models/food_search_result_raw.dart';
import '../../services/raw_search_debug_store.dart';

/// Remote datasource for API calls with cancellation support
/// Implements smart retry, timeout, and request cancellation
class FoodRemoteDatasource {
  static final FoodRemoteDatasource _instance =
      FoodRemoteDatasource._internal();
  late final Dio _dio;

  // API endpoints
  static const String _offBaseUrl = 'https://world.openfoodfacts.org';
  static const String _usdaBaseUrl = 'https://api.nal.usda.gov/fdc/v1';
  static const String _usdaApiKey = 'eLHyw1HDnNnuWOPVff5Oj99XcPcRWX06Bylqr2Mu';

  factory FoodRemoteDatasource() => _instance;

  FoodRemoteDatasource._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent': 'Metadash/1.0 (Food Tracking App)',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors for logging (optional, can be removed in production)
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) {
          // Only log errors in production
          if (obj.toString().contains('ERROR')) {
            print(obj);
          }
        },
      ),
    );
  }

  // ==================== SEARCH METHODS ====================

  /// Search Open Food Facts with cancellation support
  Future<List<FoodModel>> searchOpenFoodFacts(
    String query, {
    int page = 1,
    int pageSize = 25,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_offBaseUrl/cgi/search.pl',
        queryParameters: {
          'search_terms': query,
          'action': 'process',
          'json': '1',
          'page': page,
          'page_size': pageSize,
        },
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final products = (data['products'] as List?) ?? [];
        final rawResults = _buildOffRawList(products);
        RawSearchDebugStore.addResults(query, rawResults);

        final results = products
            .map((p) => _parseOpenFoodFactsProduct(p as Map<String, dynamic>))
            .where((f) => f != null)
            .cast<FoodModel>()
            .toList();

        return _filterAndRankResults(results, query);
      }

      return [];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // Search cancelled, that's fine
        return [];
      }
      // OFF is slow, silently fail and let USDA handle it
      return [];
    } catch (e) {
      // OFF timeout or error, silently fail
      return [];
    }
  }

  /// Search USDA FoodData Central with cancellation support
  Future<List<FoodModel>> searchUSDA(
    String query, {
    int page = 1,
    int pageSize = 25,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_usdaBaseUrl/foods/search',
        queryParameters: {
          'query': query,
          'pageSize': pageSize,
          'pageNumber': page,
          'api_key': _usdaApiKey,
        },
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final foods = (data['foods'] as List?) ?? [];
        final rawResults = _buildUsdaRawList(foods);
        RawSearchDebugStore.addResults(query, rawResults);

        final results = foods
            .map((f) => _parseUSDAFood(f as Map<String, dynamic>))
            .where((f) => f != null)
            .cast<FoodModel>()
            .toList();

        return _filterAndRankResults(results, query);
      }

      return [];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        print('USDA search cancelled');
        return [];
      }
      print('USDA search error: ${e.message}');
      return [];
    } catch (e) {
      print('USDA search error: $e');
      return [];
    }
  }

  /// Search both sources in parallel (with cancellation)
  Future<List<FoodModel>> searchBoth(
    String query, {
    int pageSize = 25,
    CancelToken? cancelToken,
  }) async {
    try {
      RawSearchDebugStore.setResults(query, const []);
      List<FoodModel> offResults = [];
      List<FoodModel> usdaResults = [];

      // Run both in parallel, but don't block on OFF if it's slow
      final offFuture = searchOpenFoodFacts(
        query,
        pageSize: pageSize ~/ 2,
        cancelToken: cancelToken,
      ).then((results) => offResults = results).catchError((e) {
        print('OFF search failed: $e');
        return <FoodModel>[];
      });

      final usdaFuture = searchUSDA(
        query,
        pageSize: pageSize ~/ 2,
        cancelToken: cancelToken,
      ).then((results) => usdaResults = results).catchError((e) {
        print('USDA search failed: $e');
        return <FoodModel>[];
      });

      // Wait for both but give OFF 15s and USDA 10s
      await Future.any([
        usdaFuture,
        Future.delayed(const Duration(seconds: 5)),
      ]);

      // Wait a bit more for OFF if we can
      try {
        await offFuture.timeout(const Duration(seconds: 8));
      } catch (e) {
        // OFF timed out, that's okay, use what we have
      }

      final combined = [...offResults, ...usdaResults];
      return _deduplicateResults(combined);
    } catch (e) {
      print('Parallel search error: $e');
      return [];
    }
  }

  // ==================== BARCODE LOOKUP (UNTOUCHED) ====================

  /// Search by barcode - DO NOT MODIFY (per requirements)
  Future<FoodModel?> searchByBarcode(
    String barcode, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_offBaseUrl/api/v0/product/$barcode.json',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 1 && data['product'] != null) {
          return _parseOpenFoodFactsProduct(
            data['product'] as Map<String, dynamic>,
          );
        }
      }

      return null;
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        print('Barcode search error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('Barcode search error: $e');
      return null;
    }
  }

  // ==================== PARSING METHODS ====================

  /// Parse Open Food Facts product
  FoodModel? _parseOpenFoodFactsProduct(Map<String, dynamic> product) {
    try {
      final name =
          product['product_name'] ?? product['product_name_en'] ?? 'Unknown';
      if (name.isEmpty || name == 'Unknown') return null;

      final brand = product['brands'] ?? product['brand'] ?? 'Generic';
      final nutrients = product['nutriments'] as Map<String, dynamic>? ?? {};

      final caloriesPer100 = _safeToDouble(
        nutrients['energy-kcal_100g'] ?? product['energy_kcal_100g'] ?? 0,
      );
      final caloriesPerServing = _safeToDouble(
        nutrients['energy-kcal_serving'] ?? 0,
      );
      final protein = _safeToDouble(nutrients['proteins_100g'] ?? 0);
      final carbs = _safeToDouble(nutrients['carbohydrates_100g'] ?? 0);
      final fat = _safeToDouble(nutrients['fat_100g'] ?? 0);

      // Skip if no nutritional data
      if (caloriesPer100 == 0 && caloriesPerServing == 0 && protein == 0 && carbs == 0 && fat == 0) {
        return null;
      }

      final servingInfo = _parseServingInfo(
        product['serving_size']?.toString(),
      );

      final servingQty = _safeToDouble(
        product['serving_quantity'] ?? servingInfo.quantity ?? 0,
      );
      final servingUnit =
          product['serving_quantity_unit']?.toString() ?? servingInfo.unit;

      final nutritionBasis = caloriesPerServing > 0 ? 'per_serving' : 'per_100g';
      final calories = caloriesPerServing > 0 ? caloriesPerServing : caloriesPer100;

      final raw = FoodSearchResultRaw(
        id: 'off_${product['code'] ?? DateTime.now().millisecondsSinceEpoch}',
        source: 'open_food_facts',
        sourceId: product['code']?.toString(),
        barcode: product['code']?.toString(),
        verified: _isOffVerified(product),
        providerScore: null,
        foodNameRaw: name,
        foodName: product['product_name_en']?.toString() ?? name,
        brandName: brand?.toString(),
        brandOwner: product['brand_owner']?.toString(),
        restaurantName: null,
        category: _firstCommaPart(product['categories']?.toString()),
        subcategory: _secondCommaPart(product['categories']?.toString()),
        languageCode: product['lang']?.toString() ?? product['lc']?.toString(),
        servingQty: servingQty > 0 ? servingQty : 100,
        servingUnit: servingUnit ?? 'g',
        servingWeightGrams: (servingUnit ?? '').toLowerCase().contains('g')
            ? (servingQty > 0 ? servingQty : 100)
            : null,
        servingVolumeMl: (servingUnit ?? '').toLowerCase().contains('ml')
            ? (servingQty > 0 ? servingQty : 100)
            : null,
        servingOptions: const [],
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        nutritionBasis: nutritionBasis,
        rawJson: product,
        lastUpdated: null,
        dataType: 'branded',
        popularity: null,
        isGeneric: (brand?.toString().toLowerCase() ?? '') == 'generic',
        isBranded: (brand?.toString().isNotEmpty ?? false) && (brand?.toString().toLowerCase() != 'generic'),
      );

      return FoodModel.fromRaw(raw);
    } catch (e) {
      print('Error parsing OFF product: $e');
      return null;
    }
  }

  /// Parse USDA food
  FoodModel? _parseUSDAFood(Map<String, dynamic> food) {
    try {
      final rawDescription = food['description'] ?? 'Unknown';
      final parsed = _parseUSDABrandAndName(rawDescription);
      final productName = parsed['name'] ?? 'Unknown';
      final brandName = parsed['brand'];

      final nutrients = food['foodNutrients'] as List? ?? [];

      double calories = 0;
      double protein = 0;
      double carbs = 0;
      double fat = 0;

      for (final nutrient in nutrients) {
        final name = (nutrient['nutrientName'] ?? '').toLowerCase();
        final value = _safeToDouble(nutrient['value'] ?? 0);

        if (name.contains('energy')) {
          calories = value;
        } else if (name.contains('protein')) {
          protein = value;
        } else if (name.contains('carbohydrate') && !name.contains('fiber')) {
          carbs = value;
        } else if (name.contains('total lipid') ||
            (name.contains('fat') && !name.contains('saturated'))) {
          fat = value;
        }
      }

      // Skip if no meaningful nutrition data
      if (calories == 0 && protein == 0 && carbs == 0 && fat == 0) {
        return null;
      }

      final servingSize = _safeToDouble(food['servingSize'] ?? 0);
      final servingUnit = food['servingSizeUnit']?.toString();
      final dataType = food['dataType']?.toString();

      final portions = (food['foodPortions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((portion) {
            final portionUnit = portion['measureUnit']?['name']?.toString();
            return ServingOptionRaw(
              label: portion['portionDescription']?.toString(),
              quantity: _safeToDouble(portion['amount'] ?? 0),
              unit: portionUnit,
              weightGrams: _safeToDouble(portion['gramWeight'] ?? 0),
              volumeMl: null,
              rawJson: portion,
            );
          })
          .toList();

      final raw = FoodSearchResultRaw(
        id: 'usda_${food['fdcId'] ?? DateTime.now().millisecondsSinceEpoch}',
        source: 'usda',
        sourceId: food['fdcId']?.toString(),
        barcode: food['gtinUpc']?.toString(),
        verified: null,
        providerScore: null,
        foodNameRaw: rawDescription?.toString(),
        foodName: productName,
        brandName: brandName,
        brandOwner: food['brandOwner']?.toString(),
        restaurantName: null,
        category: food['foodCategory']?.toString(),
        subcategory: null,
        languageCode: null,
        servingQty: servingSize > 0 ? servingSize : 100,
        servingUnit: servingUnit ?? 'g',
        servingWeightGrams: (servingUnit ?? '').toLowerCase().contains('g')
            ? (servingSize > 0 ? servingSize : 100)
            : null,
        servingVolumeMl: (servingUnit ?? '').toLowerCase().contains('ml')
            ? (servingSize > 0 ? servingSize : 100)
            : null,
        servingOptions: portions,
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        nutritionBasis: 'per_100g',
        rawJson: food,
        lastUpdated: null,
        dataType: dataType,
        popularity: null,
        isGeneric: (dataType ?? '').toLowerCase().contains('survey') ||
            (brandName ?? '').isEmpty,
        isBranded: (dataType ?? '').toLowerCase().contains('branded') ||
            (brandName ?? '').isNotEmpty,
      );

      return FoodModel.fromRaw(raw);
    } catch (e) {
      print('Error parsing USDA food: $e');
      return null;
    }
  }

  // ==================== RAW HELPERS ====================

  /// Build raw FoodSearchResultRaw list from Open Food Facts API response
  /// Captures ALL fields from product without any cleaning/inference
  List<FoodSearchResultRaw> _buildOffRawList(List<dynamic> products) {
    final raw = <FoodSearchResultRaw>[];

    for (final item in products) {
      try {
        final product = item as Map<String, dynamic>;
        final code = product['code']?.toString();

        if (code == null || code.isEmpty) continue;

        // Extract all fields as-is (no cleaning/inference)
        final foodNameRaw = product['product_name']?.toString();
        final brandRaw = product['brands']?.toString();

        // Parse brand and name (extract first part before comma if present)
        String? brandName;
        String? displayName = foodNameRaw;

        if (brandRaw != null && brandRaw.isNotEmpty) {
          brandName = _firstCommaPart(brandRaw);
        }

        // Get serving info from product (if available)
        final servingSizeRaw = product['serving_size']?.toString();
        final servingInfo = _parseServingInfo(servingSizeRaw);

        // Extract nutrition from nutriments (or null if missing)
        final nutriments = (product['nutriments'] as Map<String, dynamic>?) ?? {};
        final calories =
            _safeToDouble(nutriments['energy-kcal'] ?? nutriments['energy']);
        final proteinG = _safeToDouble(nutriments['proteins']);
        final carbsG = _safeToDouble(nutriments['carbohydrates']);
        final fatG = _safeToDouble(nutriments['fat']);

        // Extract serving options from product_quantity
        final servingOptions = <ServingOptionRaw>[];
        if (servingInfo.unit != null && servingInfo.quantity != null) {
          servingOptions.add(
            ServingOptionRaw(
              label: '${servingInfo.quantity} ${servingInfo.unit}',
              quantity: servingInfo.quantity,
              unit: servingInfo.unit,
            ),
          );
        }

        final isGeneric = (product['categories']?.toString() ?? '').isEmpty;
        final isBranded =
            (brandName ?? '').isNotEmpty && (brandName != 'Unknown');
        final verified = _isOffVerified(product);

        raw.add(
          FoodSearchResultRaw(
            id: 'off_$code',
            source: 'open_food_facts',
            sourceId: code,
            barcode: code,
            verified: verified,
            providerScore: null,
            foodNameRaw: foodNameRaw,
            foodName: displayName,
            brandName: brandName,
            brandOwner: null,
            restaurantName: null,
            category: _firstCommaPart(product['categories']?.toString()),
            subcategory: _secondCommaPart(product['categories']?.toString()),
            languageCode: product['lang']?.toString(),
            servingQty: servingInfo.quantity,
            servingUnit: servingInfo.unit,
            servingWeightGrams: (servingInfo.unit ?? '').toLowerCase() == 'g'
                ? servingInfo.quantity
                : null,
            servingVolumeMl: (servingInfo.unit ?? '').toLowerCase() == 'ml'
                ? servingInfo.quantity
                : null,
            servingOptions: servingOptions,
            calories: calories > 0 ? calories : null,
            proteinG: proteinG > 0 ? proteinG : null,
            carbsG: carbsG > 0 ? carbsG : null,
            fatG: fatG > 0 ? fatG : null,
            nutritionBasis: 'per_100g',
            rawJson: product,
            lastUpdated: null,
            dataType: 'branded',
            popularity: null,
            isGeneric: isGeneric,
            isBranded: isBranded,
          ),
        );
      } catch (e) {
        // Skip items that fail to parse
        print('Error building OFF raw result: $e');
        continue;
      }
    }

    return raw;
  }

  /// Build raw FoodSearchResultRaw list from USDA API response
  /// Captures ALL fields from food without any cleaning/inference
  List<FoodSearchResultRaw> _buildUsdaRawList(List<dynamic> foods) {
    final raw = <FoodSearchResultRaw>[];

    for (final item in foods) {
      try {
        final food = item as Map<String, dynamic>;
        final fdcId = food['fdcId']?.toString();

        if (fdcId == null || fdcId.isEmpty) continue;

        // Extract all fields as-is (no cleaning/inference)
        final rawDescription = food['description']?.toString();

        // Parse brand and name from description
        final parsed = _parseUSDABrandAndName(rawDescription ?? 'Unknown');
        final brandName = parsed['brand'];
        final displayName = parsed['name'];

        // Get serving info (default 100g if not available)
        final servingSize = food['servingSize']?.toString();
        final servingUnit = food['servingSizeUnit']?.toString() ?? 'g';
        final servingQty = double.tryParse(servingSize ?? '100') ?? 100;

        // Extract nutrition from foodNutrients
        final foodNutrients = (food['foodNutrients'] as List?) ?? [];
        double? calories;
        double? proteinG;
        double? carbsG;
        double? fatG;

        for (final nutrient in foodNutrients) {
          final nut = nutrient as Map<String, dynamic>;
          final nutrientId = nut['nutrientId'];
          final value = _safeToDouble(nut['value']);

          if (nutrientId == 1008) {
            calories = value;
          } else if (nutrientId == 1003) {
            proteinG = value;
          } else if (nutrientId == 1005) {
            carbsG = value;
          } else if (nutrientId == 1004) {
            fatG = value;
          }
        }

        // Extract serving options from foodPortions
        final servingOptions = <ServingOptionRaw>[];
        final portions = (food['foodPortions'] as List?) ?? [];
        for (final portion in portions) {
          final p = portion as Map<String, dynamic>;
          final portionDescription = p['portionDescription']?.toString();
          final portionGrams = _safeToDouble(p['gramWeight']);

          if (portionDescription != null && portionGrams > 0) {
            servingOptions.add(
              ServingOptionRaw(
                label: portionDescription,
                quantity: portionGrams,
                unit: 'g',
              ),
            );
          }
        }

        // Determine if generic or branded
        final isGeneric = (brandName ?? '').isEmpty;
        final isBranded =
            (brandName ?? '').isNotEmpty && (brandName != 'Unknown');
        final dataType = food['dataType']?.toString() ?? 'survey';
        final gtinUpc = food['gtinUpc']?.toString();

        raw.add(
          FoodSearchResultRaw(
            id: 'usda_$fdcId',
            source: 'usda',
            sourceId: fdcId,
            barcode: gtinUpc,
            verified: null,
            providerScore: null,
            foodNameRaw: rawDescription,
            foodName: displayName,
            brandName: brandName,
            brandOwner: null,
            restaurantName: null,
            category: food['foodCategory']?.toString(),
            subcategory: null,
            languageCode: null,
            servingQty: servingQty,
            servingUnit: servingUnit,
            servingWeightGrams: servingUnit.toLowerCase() == 'g'
                ? servingQty
                : null,
            servingVolumeMl: servingUnit.toLowerCase() == 'ml'
                ? servingQty
                : null,
            servingOptions: servingOptions,
            calories: calories != null && calories > 0 ? calories : null,
            proteinG: proteinG != null && proteinG > 0 ? proteinG : null,
            carbsG: carbsG != null && carbsG > 0 ? carbsG : null,
            fatG: fatG != null && fatG > 0 ? fatG : null,
            nutritionBasis: 'per_100g',
            rawJson: food,
            lastUpdated: null,
            dataType: dataType,
            popularity: null,
            isGeneric: isGeneric,
            isBranded: isBranded,
          ),
        );
      } catch (e) {
        // Skip items that fail to parse
        print('Error building USDA raw result: $e');
        continue;
      }
    }

    return raw;
  }

  _ServingInfo _parseServingInfo(String? servingSizeRaw) {
    if (servingSizeRaw == null || servingSizeRaw.trim().isEmpty) {
      return const _ServingInfo();
    }

    final match = RegExp(r'(\d+(?:\.\d+)?)\s*([a-zA-Z]+)')
        .firstMatch(servingSizeRaw);
    if (match == null) return const _ServingInfo();

    final qty = double.tryParse(match.group(1) ?? '');
    final unit = match.group(2)?.toLowerCase();
    return _ServingInfo(quantity: qty, unit: unit);
  }

  bool _isOffVerified(Map<String, dynamic> product) {
    final states = (product['states_tags'] as List?) ?? [];
    return states.any((s) => s.toString().contains('en:validated')) ||
        states.any((s) => s.toString().contains('en:complete'));
  }

  String? _firstCommaPart(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final part = text
        .split(',')
        .map((e) => e.trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    return part.isEmpty ? null : part;
  }

  String? _secondCommaPart(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final parts = text.split(',').map((e) => e.trim()).toList();
    if (parts.length < 2) return null;
    return parts[1].isNotEmpty ? parts[1] : null;
  }

  // ==================== UTILITIES ====================

  /// Safely convert dynamic to double
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Parse USDA brand and name
  Map<String, String?> _parseUSDABrandAndName(String rawName) {
    String? brand;
    String productName = rawName;

    // Extract brand (usually before comma or in parentheses)
    if (rawName.contains(',')) {
      final parts = rawName.split(',');
      brand = parts[0].trim();
      productName = parts.skip(1).join(',').trim();
    } else if (rawName.contains('(') && rawName.contains(')')) {
      final match = RegExp(r'\(([^)]+)\)').firstMatch(rawName);
      if (match != null) {
        brand = match.group(1);
        productName = rawName.replaceAll(match.group(0)!, '').trim();
      }
    }

    return {'name': productName, 'brand': brand};
  }

  /// Filter and rank results by relevance
  List<FoodModel> _filterAndRankResults(
    List<FoodModel> results,
    String query,
  ) {
    if (results.isEmpty) return results;

    final queryLower = query.toLowerCase().trim();
    final queryWords = queryLower.split(RegExp(r'\s+'));

    // Filter: at least one word must match
    final filtered = results.where((food) {
      final nameLower = food.name.toLowerCase();
      final brandLower = (food.brand ?? '').toLowerCase();
      final fullText = '$nameLower $brandLower';

      return queryWords.any((word) {
        if (word.length < 2) return false;
        return fullText.contains(word);
      });
    }).toList();

    // Sort by relevance: startsWith > contains
    filtered.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();

      final aStarts = aName.startsWith(queryLower) ? 0 : 1;
      final bStarts = bName.startsWith(queryLower) ? 0 : 1;

      if (aStarts != bStarts) return aStarts.compareTo(bStarts);

      // Then by name length (shorter = more relevant)
      return aName.length.compareTo(bName.length);
    });

    return filtered;
  }

  /// Remove duplicate results (same name + brand)
  List<FoodModel> _deduplicateResults(List<FoodModel> results) {
    final seen = <String>{};
    final unique = <FoodModel>[];

    for (final food in results) {
      final key = '${food.name}_${food.brand ?? ''}'.toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(food);
      }
    }

    return unique;
  }

  /// Create a new cancel token
  CancelToken createCancelToken() => CancelToken();
}

class _ServingInfo {
  final double? quantity;
  final String? unit;

  const _ServingInfo({this.quantity, this.unit});
}
