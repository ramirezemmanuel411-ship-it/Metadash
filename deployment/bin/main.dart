import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  // Load configuration from environment
  final clientId = _getEnvVar('FATSECRET_CLIENT_ID');
  final clientSecret = _getEnvVar('FATSECRET_CLIENT_SECRET');
  final port = int.tryParse(_getEnvVar('PORT', defaultValue: '8080')) ?? 8080;

  // Initialize token manager
  final tokenManager = TokenManager(clientId, clientSecret);

  // Create router
  final router = Router()
    ..get('/health', (Request request) async {
      final tokenInfo = await tokenManager.getTokenInfo();
      return Response.ok(
        '{"status":"ok","token_valid":${tokenInfo['isValid']},"expires_in":${tokenInfo['expiresIn']}}',
        headers: {'Content-Type': 'application/json'},
      );
    })
    ..get('/token', (Request request) async {
      final tokenInfo = await tokenManager.getTokenInfo();
      return Response.ok(
        '{"access_token":"${tokenInfo['token']}","expires_in":${tokenInfo['expiresIn']}}',
        headers: {'Content-Type': 'application/json'},
      );
    })
    ..all('/<ignored|.*>', (Request request) async {
      return _handleFatSecretProxy(request, tokenManager);
    });

  // Add middleware
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware)
      .addMiddleware(_errorMiddleware)
      .addHandler(router.call);

  // Start server
  final server = await shelf_io.serve(
    handler,
    '0.0.0.0',
    port,
  );

  print('✅ FatSecret OAuth Proxy started on http://${server.address.host}:${server.port}');
  print('📍 Health check: http://localhost:$port/health');
  print('🔐 Token endpoint: http://localhost:$port/token');
  print('🔄 All other paths forwarded to FatSecret API');
}

/// Main proxy handler - forwards requests to FatSecret
Future<Response> _handleFatSecretProxy(
  Request request,
  TokenManager tokenManager,
) async {
  try {
    // Get valid access token
    final accessToken = await tokenManager.getAccessToken();

    // Build FatSecret URL using REST API format
    final path = request.requestedUri.path.startsWith('/') 
        ? request.requestedUri.path.substring(1) 
        : request.requestedUri.path;
    final queryParams = request.requestedUri.queryParameters;
    
    // FatSecret REST API endpoint
    final fatsecretUrl = Uri(
      scheme: 'https',
      host: 'platform.fatsecret.com',
      path: '/rest/$path',
      queryParameters: queryParams,
    );

    // Create headers with Bearer token
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    // Forward request based on method
    late http.Response response;
    
    switch (request.method) {
      case 'GET':
        response = await http.get(fatsecretUrl, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          fatsecretUrl,
          headers: headers,
          body: await request.readAsString(),
        );
        break;
      case 'PUT':
        response = await http.put(
          fatsecretUrl,
          headers: headers,
          body: await request.readAsString(),
        );
        break;
      case 'DELETE':
        response = await http.delete(fatsecretUrl, headers: headers);
        break;
      default:
        return Response(405, body: jsonEncode({'error': 'Method not allowed'}));
    }

    return Response(
      response.statusCode,
      body: response.body,
      headers: {
        'Content-Type': response.headers['content-type'] ?? 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  } catch (e) {
    print('❌ Proxy error: $e');
    return Response(
      500,
      body: '{"error":"Proxy error: $e"}',
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// CORS middleware
Middleware _corsMiddleware = createMiddleware(
  responseHandler: (Response response) {
    return response.change(headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    });
  },
);

/// Error handling middleware
Middleware _errorMiddleware = (innerHandler) {
  return (request) async {
    try {
      return await innerHandler(request);
    } catch (e) {
      print('❌ Request error: $e');
      return Response(
        500,
        body: '{"error":"Internal server error"}',
        headers: {'Content-Type': 'application/json'},
      );
    }
  };
};

/// Get environment variable
String _getEnvVar(String name, {String defaultValue = ''}) {
  final envValue = _getEnv(name);
  if (envValue != null && envValue.isNotEmpty) return envValue;
  
  if (defaultValue.isEmpty) {
    throw Exception('Required environment variable not found: $name');
  }
  return defaultValue;
}

/// Stub for environment variable reading (handled by --dart-define or .env)
String? _getEnv(String name) {
  // First try system environment
  final sysEnv = Platform.environment[name];
  if (sysEnv != null && sysEnv.isNotEmpty) return sysEnv;
  
  // Then try .env file
  try {
    final envFile = File('.env');
    if (envFile.existsSync()) {
      final lines = envFile.readAsLinesSync();
      for (final line in lines) {
        if (line.isEmpty || line.startsWith('#')) continue;
        final parts = line.split('=');
        if (parts.length == 2 && parts[0].trim() == name) {
          return parts[1].trim();
        }
      }
    }
  } catch (e) {
    print('Warning: Could not read .env file: $e');
  }
  
  return null;
}

/// Token Manager - handles OAuth 2.0 token lifecycle
class TokenManager {
  final String clientId;
  final String clientSecret;
  
  String? _accessToken;
  late DateTime _expiryTime;
  final http.Client _httpClient = http.Client();

  TokenManager(this.clientId, this.clientSecret) {
    _expiryTime = DateTime.now();
  }

  /// Get valid access token, refreshing if needed
  Future<String> getAccessToken() async {
    // Check if current token is still valid (60 second buffer)
    if (_accessToken != null &&
        DateTime.now().isBefore(_expiryTime.subtract(Duration(seconds: 60)))) {
      return _accessToken!;
    }

    // Token expired or doesn't exist, refresh
    return _refreshAccessToken();
  }

  /// Get token info for health check
  Future<Map<String, dynamic>> getTokenInfo() async {
    try {
      final token = await getAccessToken();
      final secondsRemaining = _expiryTime.difference(DateTime.now()).inSeconds;
      return {
        'token': '${token.substring(0, 10)}...', // Masked
        'isValid': true,
        'expiresIn': secondsRemaining,
      };
    } catch (e) {
      return {
        'token': 'error',
        'isValid': false,
        'expiresIn': 0,
      };
    }
  }

  /// Refresh access token from FatSecret
  Future<String> _refreshAccessToken() async {
    try {
      // Use Basic Authentication as per OAuth 2.0 spec
      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
      
      final response = await _httpClient.post(
        Uri.parse('https://oauth.fatsecret.com/connect/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic $credentials',
        },
        body: {
          'grant_type': 'client_credentials',
          'scope': 'basic',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('❌ FatSecret OAuth error: ${response.statusCode}');
        print('   Response body: ${response.body}');
        throw Exception('Token refresh failed: ${response.statusCode}');
      }

      final data = _parseJson(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final expiresIn = data['expires_in'] as int?;

      if (token == null || expiresIn == null) {
        throw Exception('Invalid token response');
      }

      _accessToken = token;
      _expiryTime = DateTime.now().add(Duration(seconds: expiresIn));

      print('✅ Token refreshed, expires in $expiresIn seconds');
      return token;
    } catch (e) {
      print('❌ Token refresh error: $e');
      rethrow;
    }
  }

  /// Simple JSON parser
  dynamic _parseJson(String json) {
    try {
      // Minimal JSON parsing without external dependency
      if (json.contains('"access_token"')) {
        final tokenMatch = RegExp(r'"access_token":"([^"]+)"').firstMatch(json);
        final expiresMatch = RegExp(r'"expires_in":(\d+)').firstMatch(json);
        
        if (tokenMatch != null && expiresMatch != null) {
          return {
            'access_token': tokenMatch.group(1),
            'expires_in': int.parse(expiresMatch.group(1)!),
          };
        }
      }
      throw Exception('Failed to parse token response');
    } catch (e) {
      throw Exception('JSON parse error: $e');
    }
  }
}
