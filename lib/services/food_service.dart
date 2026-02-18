// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Food data model
class Food {
  final String id;
  final String name;
  final String? brand;
  final double servingSize;
  final String servingUnit;
  final int calories;
  final double protein; // grams
  final double carbs; // grams
  final double fat; // grams
  final String source; // 'usda' or 'open_food_facts'

  Food({
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
  });

  @override
  String toString() =>
      '$name ($brand) - $calories cal, P:${protein}g C:${carbs}g F:${fat}g';
}

/// Service for searching foods from multiple sources
class FoodService {
  static final FoodService _instance = FoodService._internal();

  factory FoodService() {
    return _instance;
  }

  FoodService._internal();

  // API endpoints and credentials
  static const String _offBaseUrl =
      'https://world.openfoodfacts.org/api/v0/product';
  static const String _usdaBaseUrl =
      'https://api.nal.usda.gov/fdc/v1/foods/search';
  static const String _usdaApiKey = 'eLHyw1HDnNnuWOPVff5Oj99XcPcRWX06Bylqr2Mu';

  /// Search food by barcode (Open Food Facts is better for this)
  Future<Food?> searchByBarcode(String barcode) async {
    try {
      final food = await _searchOpenFoodFactsByBarcode(barcode);
      if (food != null) return food;

      // If not found in OFF, could fall back to other sources here
      return null;
    } catch (e) {
      print('Error searching by barcode: $e');
      return null;
    }
  }

  /// Search food by name - tries both sources
  Future<List<Food>> searchFoods(String query) async {
    try {
      final results = <Food>[];

      // Try Open Food Facts first (has branded items like Coke)
      final offResults = await _searchOpenFoodFacts(query);
      results.addAll(offResults);

      // If we got results, return them quickly
      if (results.isNotEmpty) {
        return results;
      }

      // If nothing found in OFF, try USDA (generic foods)
      final usdaResults = await Future.wait(
        [_searchUSDA(query)],
        eagerError: true,
      ).timeout(const Duration(seconds: 5), onTimeout: () => [[]]);
      results.addAll(usdaResults[0]);

      // Remove duplicates and return
      return _deduplicateFoods(results);
    } catch (e) {
      print('Error searching foods: $e');
      return [];
    }
  }

  /// Search Open Food Facts only
  Future<List<Food>> searchOpenFoodFactsOnly(String query) async {
    try {
      return await _searchOpenFoodFacts(query);
    } catch (e) {
      print('Error searching Open Food Facts: $e');
      return [];
    }
  }

  /// Search USDA only
  Future<List<Food>> searchUSDAOnly(String query) async {
    try {
      final results = await _searchUSDA(query);
      print('USDA search completed with ${results.length} results');
      return results;
    } catch (e) {
      print('Error searching USDA: $e');
      return [];
    }
  }

  /// Search Open Food Facts by barcode
  Future<Food?> _searchOpenFoodFactsByBarcode(String barcode) async {
    try {
      final response = await http
          .get(Uri.parse('$_offBaseUrl/$barcode.json'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          return _parseOpenFoodFactsProduct(data['product']);
        }
      }
      return null;
    } catch (e) {
      print('Error searching OFF by barcode: $e');
      return null;
    }
  }

  /// Search Open Food Facts by name
  Future<List<Food>> _searchOpenFoodFacts(String query) async {
    try {
      // Use simpler search without search_simple for broader results
      final url =
          'https://world.openfoodfacts.org/cgi/search.pl'
          '?search_terms=${Uri.encodeComponent(query)}'
          '&action=process'
          '&json=1'
          '&page_size=50'; // Get more results for fuzzy matching

      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Metadash/1.0'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final products = data['products'] as List? ?? [];

        // Parse all products
        final allResults = products
            .map((p) => _parseOpenFoodFactsProduct(p))
            .where((f) => f != null)
            .cast<Food>()
            .toList();

        // Strict filtering - only show items that actually match the query
        final queryLower = query.toLowerCase().trim();
        final queryWords = queryLower.split(RegExp(r'\s+'));

        final filtered = allResults.where((food) {
          final nameLower = food.name.toLowerCase();
          final brandLower = (food.brand ?? '').toLowerCase();
          final fullText = '$nameLower $brandLower';

          // At least one query word must appear as a whole word in name or brand
          return queryWords.any((word) {
            if (word.length < 2) return false; // Skip single chars
            return RegExp(
              r'\b' + RegExp.escape(word) + r'\b',
            ).hasMatch(fullText);
          });
        }).toList();

        return filtered.take(20).toList();
      }
      return [];
    } catch (e) {
      print('OFF error: $e');
      return [];
    }
  }

  /// Parse Open Food Facts product to Food object
  Food? _parseOpenFoodFactsProduct(Map<String, dynamic> product) {
    try {
      final name =
          product['product_name'] ?? product['product_name_en'] ?? 'Unknown';
      if (name.isEmpty || name == 'Unknown') return null;

      final brand = product['brands'] ?? product['brand'] ?? 'Generic';
      final calories = _safeToDouble(product['energy_kcal_100g'] ?? 0);
      final nutriments = product['nutriments'] as Map? ?? {};
      final protein = _safeToDouble(nutriments['proteins'] ?? 0);
      final carbs = _safeToDouble(nutriments['carbohydrates'] ?? 0);
      final fat = _safeToDouble(nutriments['fat'] ?? 0);

      // Accept products with just a name - nutrition can be incomplete
      if (name.isNotEmpty && name != 'Unknown') {
        // Open Food Facts provides per 100g, we'll use that as serving
        return Food(
          id: product['code'] ?? '',
          name: name,
          brand: brand,
          servingSize: 100,
          servingUnit: 'g',
          calories: calories.toInt(),
          protein: protein,
          carbs: carbs,
          fat: fat,
          source: 'open_food_facts',
        );
      }
      return null;
    } catch (e) {
      print('Error parsing OFF product: $e');
      return null;
    }
  }

  /// Search USDA FoodData Central
  Future<List<Food>> _searchUSDA(String query) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_usdaBaseUrl?query=${Uri.encodeComponent(query)}&pageSize=20&api_key=$_usdaApiKey',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final foods = data['foods'] as List? ?? [];

        final allResults = foods
            .map((f) => _parseUSDAFood(f))
            .where((f) => f != null)
            .cast<Food>()
            .toList();

        // Apply same strict filtering as Open Food Facts
        final queryLower = query.toLowerCase().trim();
        final queryWords = queryLower.split(RegExp(r'\s+'));

        final filtered = allResults.where((food) {
          final nameLower = food.name.toLowerCase();
          final brandLower = (food.brand ?? '').toLowerCase();
          final fullText = '$nameLower $brandLower';

          // At least one query word must appear as a whole word
          return queryWords.any((word) {
            if (word.length < 2) return false;
            return RegExp(
              r'\b' + RegExp.escape(word) + r'\b',
            ).hasMatch(fullText);
          });
        }).toList();

        return filtered;
      }
      return [];
    } catch (e) {
      print('USDA error: $e');
      return [];
    }
  }

  /// Parse USDA food to Food object
  Food? _parseUSDAFood(Map<String, dynamic> food) {
    try {
      final rawDescription = food['description'] ?? 'Unknown';
      // Extract brand and product name from USDA description
      final parsed = _parseUSDABrandAndName(rawDescription);
      final productName = parsed['name'] ?? 'Unknown';
      final brandName = parsed['brand'];

      final nutrients = food['foodNutrients'] as List? ?? [];

      // Extract macros from nutrients
      double calories = 0;
      double protein = 0;
      double carbs = 0;
      double fat = 0;

      for (final nutrient in nutrients) {
        final name = (nutrient['nutrientName'] ?? '').toLowerCase();
        // Try both 'value' and 'amount' fields
        final value = (nutrient['value'] ?? nutrient['amount'] ?? 0).toDouble();

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

      return Food(
        id: food['fdcId']?.toString() ?? '',
        name: productName,
        brand: brandName,
        servingSize: 100,
        servingUnit: 'g',
        calories: calories.toInt(),
        protein: protein,
        carbs: carbs,
        fat: fat,
        source: 'usda',
      );
    } catch (e) {
      print('Error parsing USDA food: $e');
      return null;
    }
  }

  /// Parse USDA description to extract brand and product name
  Map<String, String?> _parseUSDABrandAndName(String rawName) {
    // Check if it starts with a brand name (all caps followed by comma)
    final brandMatch = RegExp(r'^([A-Z][A-Z\s&]+),\s*(.+)').firstMatch(rawName);

    String? brand;
    String productName;

    if (brandMatch != null) {
      // Extract brand and product separately
      brand = _toTitleCase(brandMatch.group(1)!.trim());
      productName = brandMatch.group(2)!;
    } else {
      // No clear brand, use whole name
      productName = rawName;
    }

    // Clean up the product name
    productName = _cleanProductName(productName);

    return {'name': productName, 'brand': brand};
  }

  /// Clean up product name by removing brand, filler words, and measurements
  String _cleanProductName(String name) {
    String cleaned = name.trim();

    // Remove leading brand names (anything before first comma)
    if (cleaned.contains(',')) {
      cleaned = cleaned.split(',').last.trim();
    }

    // Remove WITH X FLAVOR, X pattern first
    cleaned = cleaned.replaceAll(
      RegExp(r'\bWITH\s+(\w+)\s+FLAVOR,\s+\1\b', caseSensitive: false),
      '',
    );

    // Remove common filler words and descriptors
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(FLAVOR|FLAVORED|TASTING|TASTE|DRINK|BEVERAGE|ORIGINAL|ZERO|DIET|MINI|CAN|BOTTLE|PACK)\b',
        caseSensitive: false,
      ),
      '',
    );

    // Remove extra commas, "with", and spaces
    cleaned = cleaned.replaceAll(RegExp(r'\bWITH\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r',\s*,'), ',');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.trim().replaceAll(RegExp(r',\s*$'), '');

    // Convert to title case
    cleaned = _toTitleCase(cleaned);

    // Limit length
    if (cleaned.length > 40) {
      cleaned = '${cleaned.substring(0, 37)}...';
    }

    return cleaned.isEmpty ? 'Unknown' : cleaned;
  }

  /// Convert string to title case
  String _toTitleCase(String text) {
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Safely convert dynamic values to double (handles strings and numbers)
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  /// Remove duplicate foods by simple alphanumeric comparison
  List<Food> _deduplicateFoods(List<Food> foods) {
    final seen = <String>{};
    final result = <Food>[];

    for (final food in foods) {
      // Strip all non-alphanumeric and compare
      final key = (food.name + (food.brand ?? '')).toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );

      if (!seen.contains(key)) {
        seen.add(key);
        result.add(food);
      }
    }

    return result;
  }
}
