/// FatSecret Backend Proxy Server
/// Run this on a server with a static IP and whitelist that IP in FatSecret dashboard
/// 
/// To run this server:
/// 1. Create a new Dart project: dart create -t console fatsecret_backend
/// 2. Add 'shelf: ^1.4.0' to pubspec.yaml
/// 3. Copy this file and run: dart bin/server.dart
/// 4. Deploy to Heroku, Railway, DigitalOcean, etc. to get a static IP

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

// Client ID and Secret - load from environment variables
final String clientId = const String.fromEnvironment('FATSECRET_CLIENT_ID');
final String clientSecret = const String.fromEnvironment('FATSECRET_CLIENT_SECRET');
final String fatsecretBaseUrl = 'https://platform.fatsecret.com/rest/';

void main() async {
  if (clientId.isEmpty || clientSecret.isEmpty) {
    print('❌ Error: FATSECRET_CLIENT_ID and FATSECRET_CLIENT_SECRET environment variables not set');
    print('Usage: dart run --define=FATSECRET_CLIENT_ID=xxx --define=FATSECRET_CLIENT_SECRET=yyy');
    return;
  }

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addRoute(router);

  final server = await io.serve(handler, 'localhost', 8080);
  print('✅ FatSecret Proxy Server running on http://${server.address.host}:${server.port}');
}

/// CORS middleware to allow mobile app requests
Middleware _corsMiddleware() {
  return (innerHandler) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        });
      }

      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      });
    };
  };
}

/// Router for proxy endpoints
Response router(Request request) {
  final path = request.url.path;

  if (path == '/health') {
    return _healthCheck();
  } else if (path.startsWith('/api/foods/search') && request.method == 'GET') {
    return _searchFoods(request);
  } else if (path.startsWith('/api/foods/') && request.method == 'GET') {
    return _getFoodNutrition(request);
  } else if (path.startsWith('/api/recipes/') && request.method == 'GET') {
    return _getRecipe(request);
  } else {
    return Response.notFound('Endpoint not found');
  }
}

/// Health check endpoint
Response _healthCheck() {
  return Response.ok(
    jsonEncode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Search foods endpoint: GET /api/foods/search?q=coke
Future<Response> _searchFoods(Request request) async {
  try {
    final query = request.url.queryParameters['q'] ?? '';
    if (query.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing query parameter: q'}),
      );
    }

    final token = await _getAccessToken();
    final searchUrl = Uri.parse(
      '$fatsecretBaseUrl'
      'food.search.v3.1'
      '?search_expression=$query'
      '&access_token=$token',
    );

    final response = await _makeRequest(searchUrl);
    return Response.ok(response, headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Search failed: $e'}),
    );
  }
}

/// Get food nutrition endpoint: GET /api/foods/12345
Future<Response> _getFoodNutrition(Request request) async {
  try {
    final foodId = request.url.pathSegments[2];
    if (foodId.isEmpty) {
      return Response.badRequest(body: 'Missing food ID');
    }

    final token = await _getAccessToken();
    final url = Uri.parse(
      '$fatsecretBaseUrl'
      'food.get.v3.1'
      '?food_id=$foodId'
      '&access_token=$token',
    );

    final response = await _makeRequest(url);
    return Response.ok(response, headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to get nutrition: $e'}),
    );
  }
}

/// Get recipe endpoint: GET /api/recipes/12345
Future<Response> _getRecipe(Request request) async {
  try {
    final recipeId = request.url.pathSegments[2];
    if (recipeId.isEmpty) {
      return Response.badRequest(body: 'Missing recipe ID');
    }

    final token = await _getAccessToken();
    final url = Uri.parse(
      '$fatsecretBaseUrl'
      'recipe.get.v3.1'
      '?recipe_id=$recipeId'
      '&access_token=$token',
    );

    final response = await _makeRequest(url);
    return Response.ok(response, headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to get recipe: $e'}),
    );
  }
}

/// Get OAuth access token from FatSecret
Future<String> _getAccessToken() async {
  final url = Uri.parse('$fatsecretBaseUrl/oauth/authorize');
  
  final response = await _makeRequest(
    url,
    method: 'POST',
    body: {
      'grant_type': 'client_credentials',
      'client_id': clientId,
      'client_secret': clientSecret,
      'scope': 'basic',
    },
  );

  final json = jsonDecode(response) as Map<String, dynamic>;
  final accessToken = json['access_token'] as String?;

  if (accessToken == null) {
    throw Exception('Failed to get access token from FatSecret');
  }

  return accessToken;
}

/// Make HTTP request to FatSecret (or other endpoint)
Future<String> _makeRequest(
  Uri url, {
  String method = 'GET',
  Map<String, String>? body,
}) async {
  try {
    final response = await (method == 'POST'
        ? _http.post(url, body: body)
        : _http.get(url));

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    throw Exception('Request failed: $e');
  }
}

// Mock HTTP client (replace with actual package:http in production)
final _http = _MockHttpClient();

class _MockHttpClient {
  Future<_Response> get(Uri url) async {
    // In production, use: import 'package:http/http.dart' as http;
    throw UnimplementedError('Implement with actual HTTP client');
  }

  Future<_Response> post(Uri url, {Map<String, String>? body}) async {
    throw UnimplementedError('Implement with actual HTTP client');
  }
}

class _Response {
  final int statusCode;
  final String body;

  _Response(this.statusCode, this.body);
}
