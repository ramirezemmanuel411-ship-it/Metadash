/// FatSecret Backend Proxy Service
/// Handles OAuth 2.0 token management and proxies requests to FatSecret API
/// This runs on a backend server with a static IP for IP whitelisting
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/fatsecret_config.dart';

class FatSecretToken {
  final String accessToken;
  final int expiresIn;
  final DateTime issuedAt;

  FatSecretToken({
    required this.accessToken,
    required this.expiresIn,
    required this.issuedAt,
  });

  bool get isExpired {
    final expirationTime = issuedAt.add(Duration(seconds: expiresIn - 60)); // 60s buffer
    return DateTime.now().isAfter(expirationTime);
  }

  factory FatSecretToken.fromJson(Map<String, dynamic> json) {
    return FatSecretToken(
      accessToken: json['access_token'] ?? '',
      expiresIn: json['expires_in'] ?? 3600,
      issuedAt: DateTime.now(),
    );
  }
}

/// FatSecret Backend API Client
/// Handles OAuth2 authentication and provides proxy methods for food search
class FatSecretBackendClient {
  final String backendUrl; // e.g., https://your-backend.com
  FatSecretToken? _cachedToken;

  FatSecretBackendClient({required this.backendUrl});

  /// Authenticate with FatSecret and get access token
  Future<FatSecretToken> _getAccessToken() async {
    if (_cachedToken != null && !_cachedToken!.isExpired) {
      return _cachedToken!;
    }

    try {
      final response = await http.post(
        Uri.parse('${FatSecretConfig.baseUrl}oauth/authorize'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'client_credentials',
          'client_id': FatSecretConfig.clientId,
          'client_secret': FatSecretConfig.clientSecret,
          'scope': 'basic',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedToken = FatSecretToken.fromJson(json);
        return _cachedToken!;
      } else {
        throw Exception('Failed to get FatSecret token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting FatSecret token: $e');
    }
  }

  /// Search foods on FatSecret
  Future<Map<String, dynamic>> searchFoods(String query) async {
    try {
      final token = await _getAccessToken();

      final response = await http.get(
        Uri.parse(
          '${FatSecretConfig.baseUrl}food.search.v3.1'
          '?search_expression=$query'
          '&access_token=${token.accessToken}',
        ),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('FatSecret search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching foods: $e');
    }
  }

  /// Get detailed nutrition info for a food
  Future<Map<String, dynamic>> getFoodNutrition(int foodId) async {
    try {
      final token = await _getAccessToken();

      final response = await http.get(
        Uri.parse(
          '${FatSecretConfig.baseUrl}food.get.v3.1'
          '?food_id=$foodId'
          '&access_token=${token.accessToken}',
        ),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get nutrition: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting nutrition: $e');
    }
  }

  /// Get recipe details
  Future<Map<String, dynamic>> getRecipe(int recipeId) async {
    try {
      final token = await _getAccessToken();

      final response = await http.get(
        Uri.parse(
          '${FatSecretConfig.baseUrl}recipe.get.v3.1'
          '?recipe_id=$recipeId'
          '&access_token=${token.accessToken}',
        ),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting recipe: $e');
    }
  }
}
