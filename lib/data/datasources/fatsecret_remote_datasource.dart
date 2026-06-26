/// FatSecret Remote Data Source
/// Communicates with FatSecret OAuth 2.0 Proxy Server
///
/// The proxy handles:
/// - OAuth 2.0 authentication (token management, refresh)
/// - Request forwarding to FatSecret API
/// - Token lifecycle management
///
/// Mobile app just needs to:
/// - Send requests to proxy
/// - Proxy handles adding authentication
/// - Proxy returns FatSecret responses
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:metadash/core/logging/app_logger.dart';

import '../../data/models/food_model.dart';

class FatSecretRemoteDatasource {
  final String backendUrl; // Proxy server URL (with static IP)
  final http.Client httpClient;

  FatSecretRemoteDatasource({required this.backendUrl, http.Client? httpClient})
    : httpClient = httpClient ?? http.Client() {
    // Validate URL format
    if (!backendUrl.startsWith('http://') &&
        !backendUrl.startsWith('https://')) {
      throw ArgumentError('Backend URL must start with http:// or https://');
    }
  }

  /// Search for foods on FatSecret via proxy
  ///
  /// The proxy:
  /// 1. Receives this request
  /// 2. Gets/refreshes OAuth token if needed
  /// 3. Adds token to request
  /// 4. Forwards to FatSecret API
  /// 5. Returns results to mobile app
  Future<Map<String, dynamic>> searchFoods(String query) async {
    if (query.trim().isEmpty) {
      return {};
    }

    try {
      // Build URL - proxy will add token automatically
      final url = Uri.parse(
        '$backendUrl/foods.search',
      ).replace(queryParameters: {'search_expression': query});

      AppLogger.d('🔍 [FatSecret] Searching via proxy: $query');
      AppLogger.d('   Proxy: $backendUrl');

      final response = await httpClient
          .get(url)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('FatSecret search timeout'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // FatSecret returns HTTP 200 with an {"error":{code,message}} body for
        // API-level failures (notably code 21 = the caller's IP isn't on the
        // FatSecret allowlist). Surface it instead of silently treating the
        // missing "foods" field as an empty result set.
        final error = data['error'];
        if (error is Map) {
          throw Exception(
            'FatSecret API error ${error['code']}: ${error['message']}',
          );
        }
        AppLogger.d(
          '✅ [FatSecret] Search successful: ${data['foods']?.length ?? 0} results',
        );
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('FatSecret authentication failed (proxy token issue)');
      } else if (response.statusCode == 403) {
        throw Exception('FatSecret access denied (check IP whitelist)');
      } else {
        throw Exception('FatSecret search error: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.d('❌ [FatSecret] Error searching: $e');
      throw Exception('Error searching FatSecret: $e');
    }
  }

  /// Get detailed nutrition for a specific food via proxy
  Future<Map<String, dynamic>> getFoodNutrition(int foodId) async {
    try {
      final url = Uri.parse(
        '$backendUrl/food.get.v3.1',
      ).replace(queryParameters: {'food_id': foodId.toString()});

      AppLogger.d('📊 [FatSecret] Getting nutrition for food $foodId');

      final response = await httpClient
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('FatSecret nutrition fetch timeout'),
          );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('FatSecret nutrition error: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.d('❌ [FatSecret] Error fetching nutrition: $e');
      throw Exception('Error fetching nutrition: $e');
    }
  }

  /// Get recipe details via proxy
  Future<Map<String, dynamic>> getRecipe(int recipeId) async {
    try {
      final url = Uri.parse(
        '$backendUrl/recipe.get.v3.1',
      ).replace(queryParameters: {'recipe_id': recipeId.toString()});

      AppLogger.d('🍳 [FatSecret] Getting recipe $recipeId');

      final response = await httpClient
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('FatSecret recipe fetch timeout'),
          );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('FatSecret recipe error: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.d('❌ [FatSecret] Error fetching recipe: $e');
      throw Exception('Error fetching recipe: $e');
    }
  }

  /// Check proxy health (for debugging/monitoring)
  Future<Map<String, dynamic>> checkProxyHealth() async {
    try {
      final url = Uri.parse('$backendUrl/health');

      final response = await httpClient
          .get(url)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Proxy unhealthy: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Health check failed: $e');
    }
  }

  /// Parse FatSecret search results into FoodModel objects
  static List<FoodModel> parseFoodsFromSearch(Map<String, dynamic> data) {
    final foods = <FoodModel>[];

    try {
      final foodsDataRaw = data['foods'];
      final foodsData = foodsDataRaw is Map<String, dynamic>
          ? foodsDataRaw['food'] as List?
          : foodsDataRaw as List?;
      if (foodsData == null || foodsData.isEmpty) {
        return foods;
      }

      for (final foodJson in foodsData) {
        if (foodJson is! Map<String, dynamic>) continue;

        try {
          final description = foodJson['food_description']?.toString() ?? '';
          final parsed = _parseDescription(description);

          // ── Name / Brand extraction ────────────────────────────────────────
          // FatSecret food_name often uses "Food Name - Brand Name" format.
          // brand_name is a separate field but is frequently absent.
          final rawFoodName = (foodJson['food_name'] ?? 'Unknown').toString();
          final rawBrandName = foodJson['brand_name']?.toString();
          final (foodName, brandName) = _splitFoodAndBrand(
            rawFoodName,
            rawBrandName,
          );

          // Skip brand-only stubs — entries where no real food name could be
          // recovered (e.g. food_name = "Kirkland Signature" with no descriptor).
          // foodName == brandName is set by _splitFoodAndBrand exactly when
          // the entire raw name was a company/store brand with no food part.
          if (brandName != null && foodName == brandName) {
            AppLogger.d('⏭️  [FatSecret] Skipping brand stub: $rawFoodName');
            continue;
          }

          // Parse food_type field ("Brand" / "Generic") for quality engine signals.
          final foodTypeRaw = foodJson['food_type']?.toString().toLowerCase();
          final isBranded = foodTypeRaw == 'brand';
          final isGenericEntry = foodTypeRaw == 'generic';

          final food = FoodModel(
            id: 'fs_${foodJson['food_id']}',
            name: foodName,
            brand: brandName,
            servingSize: parsed.servingQty ?? 1.0,
            servingUnit: parsed.servingUnit ?? 'serving',
            calories: parsed.calories ?? 0,
            protein: parsed.protein ?? 0,
            carbs: parsed.carbs ?? 0,
            fat: parsed.fat ?? 0,
            source: 'FatSecret',
            foodNameRaw: rawFoodName,
            foodName: foodName,
            brandName: brandName,
            sourceId: foodJson['food_id']?.toString(),
            servingQty: parsed.servingQty ?? 1.0,
            servingUnitRaw: parsed.servingUnit ?? 'serving',
            rawJson: foodJson,
            isBranded: isBranded,
            isGeneric: isGenericEntry,
          );

          foods.add(food);
        } catch (e) {
          AppLogger.d('⚠️  [FatSecret] Skipping malformed food item: $e');
          continue;
        }
      }
    } catch (e) {
      AppLogger.d('⚠️  [FatSecret] Error parsing search results: $e');
    }

    return foods;
  }

  // ── Name / brand splitting helpers ────────────────────────────────────────

  /// Corporate suffixes to strip from food/brand display names.
  static const _corpSuffixes = [
    ', Inc.',
    ', Inc',
    ' Inc.',
    ' Inc',
    ', LLC',
    ' LLC',
    ', Ltd.',
    ', Ltd',
    ' Ltd.',
    ' Ltd',
    ', Corp.',
    ', Corp',
    ' Corp.',
    ' Corp',
    ', Co.',
    ' Co.',
    ' Corporation',
    ' Company',
    ' Brands',
    ' Foods Co',
    ' Foods Company',
    ' International',
    ' Enterprises',
    ' S Corp',
    ' S. Corp',
  ];

  /// Known grocery store chains and private-label brands.
  /// When food_name matches one of these exactly it IS the brand, not a food.
  static const _knownStoreBrands = {
    // Costco
    'kirkland', 'kirkland signature',
    // Walmart
    'great value', "sam's choice", 'equate', 'mainstays',
    // Target
    'good & gather',
    'market pantry',
    'archer farms',
    'up & up',
    'simply balanced',
    // Kroger / Albertsons
    'simple truth', 'simple truth organic', 'private selection',
    'kroger', 'lucerne', 'signature select', 'open nature',
    // Whole Foods
    '365', '365 everyday value', '365 by whole foods market',
    // HEB
    'h e butt', 'h e butt grocery', 'h-e-b', 'heb', 'central market',
    // Publix
    'publix', 'publix greenwise',
    // Other US chains
    'giant eagle', 'meijer', "trader joe's", 'trader joes',
    'safeway', 'vons', 'jewel-osco', 'food lion', 'winn-dixie',
    'stop & shop', 'hannaford', 'wegmans', 'harris teeter',
    'fred meyer', 'king soopers', 'ralphs',
    // Discount / warehouse
    'aldi', 'lidl',
    // Meat / packing companies that show up as food names in FatSecret
    'eddy packing', 'eddy packing co',
  };

  /// Strip corporate legal suffixes and trailing punctuation.
  static String _stripCorporateSuffixes(String s) {
    var result = s;
    bool changed = true;
    while (changed) {
      changed = false;
      for (final suffix in _corpSuffixes) {
        if (result.toLowerCase().endsWith(suffix.toLowerCase())) {
          result = result.substring(0, result.length - suffix.length).trim();
          changed = true;
        }
      }
    }
    return result.replaceAll(RegExp(r'[,\.]+$'), '').trim();
  }

  /// Remove "X, X" comma-separated duplicates (e.g. "Giant Eagle, Giant Eagle" → "Giant Eagle").
  static String _deduplicateRepeated(String s) {
    final m = RegExp(r'^(.+),\s*\1$', caseSensitive: false).firstMatch(s);
    if (m != null) return m.group(1)!.trim();
    return s;
  }

  /// True if the string looks like a company/store name rather than a food name.
  static bool _looksLikeCompanyName(String s) {
    final lower = s.toLowerCase().trim();
    if (_knownStoreBrands.contains(lower)) return true;
    return _corpSuffixes.any((x) => lower.contains(x.toLowerCase())) ||
        RegExp(r'\b(inc|llc|corp|ltd|co)\b').hasMatch(lower);
  }

  /// Remove a leading or trailing brand fragment from a food name so the title
  /// reads as the food alone (e.g. "Kirkland Signature Strawberry Spread" with
  /// brand "Kirkland Signature" → "Strawberry Spread"). Returns the original
  /// name when stripping would leave nothing meaningful.
  static String _stripBrandFromName(String name, String brand) {
    final nLower = name.toLowerCase();
    final bLower = brand.toLowerCase();
    if (nLower == bLower) return name;

    String result = name;
    if (nLower.startsWith(bLower)) {
      result = name.substring(brand.length);
    } else if (nLower.endsWith(bLower)) {
      result = name.substring(0, name.length - brand.length);
    }
    // Trim separators left behind by the strip (spaces, commas, dashes).
    result = result
        .replaceAll(RegExp(r'^[\s,\-–]+'), '')
        .replaceAll(RegExp(r'[\s,\-–]+$'), '')
        .trim();

    return result.isEmpty ? name : result;
  }

  /// Split FatSecret "FoodName - BrandName" convention into (foodName, brandName).
  /// Strips corporate suffixes and deduplicates repeated segments.
  static (String, String?) _splitFoodAndBrand(
    String rawName,
    String? rawBrand,
  ) {
    String foodName = rawName.trim();
    String? brandName = rawBrand?.trim();

    // Split on last " - " separator (FatSecret convention) when no explicit
    // brand_name field is present.
    if (brandName == null || brandName.isEmpty) {
      final dashIdx = rawName.lastIndexOf(' - ');
      if (dashIdx > 0) {
        final before = rawName.substring(0, dashIdx).trim();
        final after = rawName.substring(dashIdx + 3).trim();
        if (_looksLikeCompanyName(before) && !_looksLikeCompanyName(after)) {
          // "CompanyName - Food" — flip them
          foodName = after;
          brandName = before;
        } else {
          foodName = before;
          brandName = after;
        }
      }
    }

    // Clean both
    foodName = _deduplicateRepeated(_stripCorporateSuffixes(foodName));
    if (brandName != null) {
      brandName = _deduplicateRepeated(_stripCorporateSuffixes(brandName));
      if (brandName.isEmpty) brandName = null;
    }

    // Strip a redundant brand prefix/suffix from the food name so the title is
    // just the food itself.
    //   food: "Kirkland Signature Strawberry Spread", brand: "Kirkland Signature"
    //   -> food: "Strawberry Spread"
    if (brandName != null && brandName.isNotEmpty) {
      foodName = _stripBrandFromName(foodName, brandName);
    }

    // If the food name is itself a company/store/brand name (no real food
    // descriptor left), treat it as a brand-only stub: title == brand so the
    // caller skips it.
    if (_looksLikeCompanyName(foodName)) {
      brandName ??= foodName;
      foodName = brandName;
    }

    // Capitalise first letter
    if (foodName.isNotEmpty) {
      foodName = foodName[0].toUpperCase() + foodName.substring(1);
    }

    return (foodName, brandName?.isEmpty == true ? null : brandName);
  }

  static _ParsedDescription _parseDescription(String description) {
    if (description.isEmpty) return const _ParsedDescription();

    final pattern = RegExp(
      r'Per\s+(.+?)\s+-\s+Calories:\s*([\d.]+)kcal\s*\|\s*Fat:\s*([\d.]+)g\s*\|\s*Carbs:\s*([\d.]+)g\s*\|\s*Protein:\s*([\d.]+)g',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(description);
    if (match == null) return const _ParsedDescription();

    final servingPart = match.group(1)?.trim() ?? '';
    final calories = double.tryParse(match.group(2) ?? '');
    final fat = double.tryParse(match.group(3) ?? '');
    final carbs = double.tryParse(match.group(4) ?? '');
    final protein = double.tryParse(match.group(5) ?? '');

    double? servingQty;
    String? servingUnit;

    final servingMatch = RegExp(
      r'^([\d.]+)\s*([a-zA-Z]+)$',
    ).firstMatch(servingPart.replaceAll(' ', ''));
    if (servingMatch != null) {
      servingQty = double.tryParse(servingMatch.group(1) ?? '');
      servingUnit = servingMatch.group(2)?.toLowerCase();
    } else if (servingPart.toLowerCase().contains('serving')) {
      servingQty = 1.0;
      servingUnit = 'serving';
    }

    return _ParsedDescription(
      calories: calories?.toInt(),
      fat: fat,
      carbs: carbs,
      protein: protein,
      servingQty: servingQty,
      servingUnit: servingUnit,
    );
  }
}

class _ParsedDescription {
  final int? calories;
  final double? fat;
  final double? carbs;
  final double? protein;
  final double? servingQty;
  final String? servingUnit;

  const _ParsedDescription({
    this.calories,
    this.fat,
    this.carbs,
    this.protein,
    this.servingQty,
    this.servingUnit,
  });
}
