/// FatSecret Backend Proxy - Deployable Version
/// 
/// Quick start:
/// 1. Create new Dart project: dart create -t console fatsecret_backend
/// 2. Add to pubspec.yaml:
///    dependencies:
///      shelf: ^1.4.0
///      http: ^1.1.0
/// 3. Copy this to bin/main.dart
/// 4. Run: dart run
///    Or with credentials: dart run --define=FATSECRET_CLIENT_ID=xxx --define=FATSECRET_CLIENT_SECRET=yyy
/// 5. Deploy to Railway/Heroku/DigitalOcean to get static IP

import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:http/http.dart' as http;

// Configuration
final String clientId = const String.fromEnvironment('FATSECRET_CLIENT_ID');
final String clientSecret = const String.fromEnvironment('FATSECRET_CLIENT_SECRET');
final String fatsecretBaseUrl = 'https://platform.fatsecret.com/rest/';

void main() async {
  // Validate credentials
  if (clientId.isEmpty || clientSecret.isEmpty) {
    print('❌ Error: Missing FatSecret credentials');
    print('Set FATSECRET_CLIENT_ID and FATSECRET_CLIENT_SECRET environment variables');
    print('Example: dart run --define=FATSECRET_CLIENT_ID=xxx --define=FATSECRET_CLIENT_SECRET=yyy');
    return;
  }

  print('✅ Credentials loaded');
  print('   Client ID: ${clientId.substring(0, 8)}...');
  print('   Ready to authenticate with FatSecret');

  // Create middleware chain
  final handler = shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addMiddleware(_corsMiddleware())
      .addMiddleware(_errorMiddleware())
      .addRoute(_router);

  // Start server
  final port = int.parse(const String.fromEnvironment('PORT', defaultValue: '8080'));
  final server = await io.serve(handler, '0.0.0.0', port);

  print('');
  print('🚀 FatSecret Backend Proxy Server');
  print('   Running on: http://0.0.0.0:$port');
  print('   Listening on: http://localhost:$port');
  print('   or: http://${server.address.host}:${server.port}');
  print('');
  print('📝 Endpoints:');
  print('   GET /health                    - Health check');
  print('   GET /api/foods/search?q=coke   - Search foods');
  print('   GET /api/foods/{id}            - Get food nutrition');
  print('   GET /api/recipes/{id}          - Get recipe');
  print('');
  print('💾 Remember to whitelist this server\'s IP on FatSecret dashboard:');
  print('   https://platform.fatsecret.com/my-account/ip-restrictions');
}

/// CORS middleware - allow requests from mobile app
shelf.Middleware _corsMiddleware() {
  return (innerHandler) {
    return (request) async {
      // Handle preflight
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '3600',
        });
      }

      // Add CORS headers to response
      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      });
    };
  };
}

/// Error handling middleware
shelf.Middleware _errorMiddleware() {
  return (innerHandler) {
    return (request) async {
      try {
        return await innerHandler(request);
      } catch (e) {
        print('❌ Error handling ${request.method} ${request.url}: $e');
        return shelf.Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}

/// Router for all endpoints
shelf.Response _router(shelf.Request request) {
  final path = request.url.path;
  final method = request.method;

  // Health check
  if (path == 'health' && method == 'GET') {
    return _handleHealth();
  }

  // Search foods: GET /api/foods/search?q=...
  if (path.startsWith('api/foods/search') && method == 'GET') {
    return _handleSearchFoods(request);
  }

  // Get food: GET /api/foods/{id}
  if (path.startsWith('api/foods/') && method == 'GET') {
    return _handleGetFood(request);
  }

  // Get recipe: GET /api/recipes/{id}
  if (path.startsWith('api/recipes/') && method == 'GET') {
    return _handleGetRecipe(request);
  }

  // Not found
  return shelf.Response.notFound(
    jsonEncode({'error': 'Endpoint not found: $path'}),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Health check endpoint
shelf.Response _handleHealth() {
  return shelf.Response.ok(
    jsonEncode({
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
      'service': 'FatSecret Backend Proxy',
      'version': '1.0.0',
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Search foods endpoint
shelf.Response _handleSearchFoods(shelf.Request request) {
  final query = request.url.queryParameters['q'] ?? '';

  if (query.isEmpty) {
    return shelf.Response.badRequest(
      body: jsonEncode({'error': 'Missing query parameter: q'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Make async request without awaiting
  _searchFoodsAsync(query);

  // Return accepted response immediately
  return shelf.Response.accepted(
    jsonEncode({'status': 'searching', 'query': query}),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Async search to avoid blocking
Future<void> _searchFoodsAsync(String query) async {
  try {
    final token = await _getAccessToken();
    final searchUrl = Uri.parse(
      '$fatsecretBaseUrl'
      'food.search.v3.1'
      '?search_expression=$query'
      '&access_token=$token',
    );

    final response = await http.get(searchUrl).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('FatSecret search timeout'),
    );

    if (response.statusCode == 200) {
      print('✅ Search "$query": ${response.body.length} bytes');
    } else {
      print('❌ Search "$query" failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Search error: $e');
  }
}

/// Get food endpoint
shelf.Response _handleGetFood(shelf.Request request) {
  final segments = request.url.pathSegments;
  if (segments.length < 3 || segments[1] != 'foods') {
    return shelf.Response.badRequest(
      body: jsonEncode({'error': 'Invalid path'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final foodId = segments[2];
  _getFoodAsync(int.tryParse(foodId) ?? 0);

  return shelf.Response.accepted(
    jsonEncode({'status': 'loading', 'foodId': foodId}),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<void> _getFoodAsync(int foodId) async {
  try {
    final token = await _getAccessToken();
    final url = Uri.parse(
      '$fatsecretBaseUrl'
      'food.get.v3.1'
      '?food_id=$foodId'
      '&access_token=$token',
    );

    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Timeout'),
    );

    if (response.statusCode == 200) {
      print('✅ Food $foodId: loaded');
    } else {
      print('❌ Food $foodId: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Get food error: $e');
  }
}

/// Get recipe endpoint
shelf.Response _handleGetRecipe(shelf.Request request) {
  final segments = request.url.pathSegments;
  if (segments.length < 3 || segments[1] != 'recipes') {
    return shelf.Response.badRequest(body: 'Invalid path');
  }

  final recipeId = segments[2];
  _getRecipeAsync(int.tryParse(recipeId) ?? 0);

  return shelf.Response.accepted(
    jsonEncode({'status': 'loading', 'recipeId': recipeId}),
    headers: {'Content-Type': 'application/json'},
  );
}

Future<void> _getRecipeAsync(int recipeId) async {
  try {
    final token = await _getAccessToken();
    final url = Uri.parse(
      '$fatsecretBaseUrl'
      'recipe.get.v3.1'
      '?recipe_id=$recipeId'
      '&access_token=$token',
    );

    final response = await http.get(url).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Timeout'),
    );

    if (response.statusCode == 200) {
      print('✅ Recipe $recipeId: loaded');
    } else {
      print('❌ Recipe $recipeId: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Get recipe error: $e');
  }
}

String? _cachedToken;
DateTime? _tokenExpiry;

/// Get OAuth access token from FatSecret (with caching)
Future<String> _getAccessToken() async {
  // Return cached token if still valid
  if (_cachedToken != null && _tokenExpiry != null) {
    if (DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 1)))) {
      return _cachedToken!;
    }
  }

  try {
    final response = await http.post(
      Uri.parse('$fatsecretBaseUrl/oauth/authorize'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
        'scope': 'basic',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final token = json['access_token'] as String?;
      final expiresIn = (json['expires_in'] as int?) ?? 3600;

      if (token != null) {
        _cachedToken = token;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        print('✅ OAuth token refreshed (expires in ${expiresIn}s)');
        return token;
      }
    }

    throw Exception('Failed to get token: ${response.statusCode}');
  } catch (e) {
    print('❌ OAuth error: $e');
    rethrow;
  }
}
