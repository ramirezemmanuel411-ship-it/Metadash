// ignore_for_file: avoid_print

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
import '../../data/models/food_model.dart';

class FatSecretRemoteDatasource {
  final String backendUrl; // Proxy server URL (with static IP)
  final http.Client httpClient;

  FatSecretRemoteDatasource({
    required this.backendUrl,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client() {
    // Validate URL format
    if (!backendUrl.startsWith('http://') && !backendUrl.startsWith('https://')) {
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
      final url = Uri.parse('$backendUrl/foods.search').replace(
        queryParameters: {'search_expression': query},
      );

      print('🔍 [FatSecret] Searching via proxy: $query');
      print('   Proxy: $backendUrl');

      final response = await httpClient.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('FatSecret search timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('✅ [FatSecret] Search successful: ${data['foods']?.length ?? 0} results');
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('FatSecret authentication failed (proxy token issue)');
      } else if (response.statusCode == 403) {
        throw Exception('FatSecret access denied (check IP whitelist)');
      } else {
        throw Exception('FatSecret search error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [FatSecret] Error searching: $e');
      throw Exception('Error searching FatSecret: $e');
    }
  }

  /// Get detailed nutrition for a specific food via proxy
  Future<Map<String, dynamic>> getFoodNutrition(int foodId) async {
    try {
      final url = Uri.parse('$backendUrl/food.get.v3.1').replace(
        queryParameters: {'food_id': foodId.toString()},
      );

      print('📊 [FatSecret] Getting nutrition for food $foodId');

      final response = await httpClient.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('FatSecret nutrition fetch timeout'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('FatSecret nutrition error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [FatSecret] Error fetching nutrition: $e');
      throw Exception('Error fetching nutrition: $e');
    }
  }

  /// Get recipe details via proxy
  Future<Map<String, dynamic>> getRecipe(int recipeId) async {
    try {
      final url = Uri.parse('$backendUrl/recipe.get.v3.1').replace(
        queryParameters: {'recipe_id': recipeId.toString()},
      );

      print('🍳 [FatSecret] Getting recipe $recipeId');

      final response = await httpClient.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('FatSecret recipe fetch timeout'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('FatSecret recipe error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [FatSecret] Error fetching recipe: $e');
      throw Exception('Error fetching recipe: $e');
    }
  }

  /// Check proxy health (for debugging/monitoring)
  Future<Map<String, dynamic>> checkProxyHealth() async {
    try {
      final url = Uri.parse('$backendUrl/health');
      
      final response = await httpClient.get(url).timeout(
        const Duration(seconds: 5),
      );

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
          final calories = parsed.calories ?? 0;
          final protein = parsed.protein ?? 0;
          final carbs = parsed.carbs ?? 0;
          final fat = parsed.fat ?? 0;
          final servingSizeNum = parsed.servingQty ?? 1.0;
          final servingUnit = parsed.servingUnit ?? 'serving';

          final food = FoodModel(
            id: 'fs_${foodJson['food_id']}',
            name: foodJson['food_name'] ?? 'Unknown',
            servingSize: servingSizeNum,
            servingUnit: servingUnit,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            source: 'FatSecret',
            foodName: foodJson['food_name'],
            sourceId: foodJson['food_id']?.toString(),
            brandName: foodJson['brand_name'],
            servingQty: servingSizeNum,
            servingUnitRaw: servingUnit,
            rawJson: foodJson,
            isFavorite: false,
          );

          foods.add(food);
        } catch (e) {
          // Skip malformed items
          print('⚠️  [FatSecret] Skipping malformed food item: $e');
          continue;
        }
      }
    } catch (e) {
      print('⚠️  [FatSecret] Error parsing search results: $e');
      // Return what we could parse
    }

    return foods;
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

    final servingMatch = RegExp(r'^([\d.]+)\s*([a-zA-Z]+)$').firstMatch(
      servingPart.replaceAll(' ', ''),
    );
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
