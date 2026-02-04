/// FatSecret OAuth 2.0 Proxy Server
/// 
/// Responsibilities:
/// 1. Manage OAuth 2.0 access token validity and renewal
/// 2. Forward all FatSecret API requests through this proxy
/// 3. Handle token refresh automatically
/// 4. Provide a single IP for FatSecret whitelisting
///
/// Architecture:
///   Mobile App → HTTPS → This Proxy (Static IP)
///                        ↓ HTTP
///                   FatSecret API
///
/// To deploy:
/// 1. Create Dart project: dart create -t console fatsecret_proxy
/// 2. Add to pubspec.yaml:
///    dependencies:
///      shelf: ^1.4.0
///      shelf_router: ^1.1.0
///      http: ^1.1.0
/// 3. Copy this to bin/main.dart
/// 4. Deploy to Railway/Heroku/DigitalOcean

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

// === CONFIGURATION ===

final String clientId = const String.fromEnvironment('FATSECRET_CLIENT_ID');
final String clientSecret = const String.fromEnvironment('FATSECRET_CLIENT_SECRET');
const String fatsecretBaseUrl = 'https://platform.fatsecret.com/rest/';
const String oauthScope = 'basic';

// === TOKEN MANAGEMENT ===

class OAuthToken {
  final String accessToken;
  final int expiresIn;
  final DateTime issuedAt;

  OAuthToken({
    required this.accessToken,
    required this.expiresIn,
    required this.issuedAt,
  });

  bool get isExpired {
    // Consider token expired 60 seconds before actual expiry
    final expirationTime = issuedAt.add(Duration(seconds: expiresIn - 60));
    return DateTime.now().isAfter(expirationTime);
  }

  bool get isValid => !isExpired;

  int get secondsRemaining {
    final expirationTime = issuedAt.add(Duration(seconds: expiresIn));
    return expirationTime.difference(DateTime.now()).inSeconds;
  }

  factory OAuthToken.fromJson(Map<String, dynamic> json) {
    return OAuthToken(
      accessToken: json['access_token'] ?? '',
      expiresIn: json['expires_in'] ?? 3600,
      issuedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'expires_in': expiresIn,
    'issued_at': issuedAt.toIso8601String(),
    'seconds_remaining': secondsRemaining,
  };
}

/// Manages OAuth token lifecycle
class TokenManager {
  OAuthToken? _currentToken;
  final http.Client _httpClient;
  Timer? _refreshTimer;

  TokenManager({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  /// Get valid access token (refreshes if needed)
  Future<String> getAccessToken() async {
    if (_currentToken != null && _currentToken!.isValid) {
      return _currentToken!.accessToken;
    }
    return _refreshAccessToken();
  }

  /// Refresh access token
  Future<String> _refreshAccessToken() async {
    try {
      print('[Token] Refreshing access token...');

      final response = await _httpClient
          .post(
            Uri.parse('${fatsecretBaseUrl}oauth/authorize'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'grant_type': 'client_credentials',
              'client_id': clientId,
              'client_secret': clientSecret,
              'scope': oauthScope,
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _currentToken = OAuthToken.fromJson(json);

        print('[Token] ✅ Token refreshed');
        print('[Token]    Expires in: ${_currentToken!.expiresIn}s');
        print('[Token]    Token: ${_currentToken!.accessToken.substring(0, 20)}...');

        _scheduleNextRefresh();
        return _currentToken!.accessToken;
      } else {
        throw Exception(
          'OAuth failed: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      print('[Token] ❌ Token refresh failed: $e');
      rethrow;
    }
  }

  /// Schedule automatic token refresh before expiry
  void _scheduleNextRefresh() {
    _refreshTimer?.cancel();

    if (_currentToken == null) return;

    // Refresh 5 minutes before expiry
    final secondsUntilRefresh = (_currentToken!.expiresIn - 300).clamp(60, _currentToken!.expiresIn);

    _refreshTimer = Timer(Duration(seconds: secondsUntilRefresh), () async {
      await _refreshAccessToken();
    });

    print('[Token] 📅 Next refresh in: ${secondsUntilRefresh}s');
  }

  /// Get token info for debugging
  Map<String, dynamic> getTokenInfo() {
    if (_currentToken == null) {
      return {'status': 'no_token', 'message': 'No token yet'};
    }

    return {
      'status': _currentToken!.isValid ? 'valid' : 'expired',
      'access_token': _currentToken!.accessToken.substring(0, 20) + '...',
      'expires_in': _currentToken!.expiresIn,
      'seconds_remaining': _currentToken!.secondsRemaining,
      'issued_at': _currentToken!.issuedAt.toIso8601String(),
    };
  }

  void dispose() {
    _refreshTimer?.cancel();
  }
}

// === GLOBAL TOKEN MANAGER ===
late TokenManager _tokenManager;

// === MAIN ===
void main() async {
  print('🚀 FatSecret OAuth 2.0 Proxy Server');
  print('');

  // Validate credentials
  if (clientId.isEmpty || clientSecret.isEmpty) {
    print('❌ ERROR: Missing FatSecret credentials');
    print('Set environment variables:');
    print('  FATSECRET_CLIENT_ID');
    print('  FATSECRET_CLIENT_SECRET');
    print('');
    print('Example:');
    print('  dart run \\');
    print('    --define=FATSECRET_CLIENT_ID=your_id \\');
    print('    --define=FATSECRET_CLIENT_SECRET=your_secret');
    return;
  }

  // Initialize token manager
  _tokenManager = TokenManager();

  // Get initial token
  try {
    await _tokenManager.getAccessToken();
  } catch (e) {
    print('❌ Failed to get initial token: $e');
    return;
  }

  // Create router
  final router = Router()
    ..get('/health', _handleHealth)
    ..get('/token', _handleTokenInfo)
    ..all('/<path|.*>', _handleFatSecretProxy);

  // Create middleware pipeline
  final handler = shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addMiddleware(_corsMiddleware())
      .addMiddleware(_errorMiddleware())
      .addRoute(router);

  // Start server
  final port = int.parse(const String.fromEnvironment('PORT', defaultValue: '8080'));
  final server = await io.serve(handler, '0.0.0.0', port);

  print('✅ Server started');
  print('   URL: http://0.0.0.0:$port');
  print('   Listen: http://localhost:$port or http://${server.address.host}:$port');
  print('');
  print('📋 Endpoints:');
  print('   GET  /health                    Health check');
  print('   GET  /token                     Token info');
  print('   All other paths → FatSecret API');
  print('');
  print('💾 Whitelist this server\'s IP on FatSecret:');
  print('   https://platform.fatsecret.com/my-account/ip-restrictions');
}

// === MIDDLEWARE ===

shelf.Middleware _corsMiddleware() {
  return (innerHandler) {
    return (request) async {
      // Handle preflight
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '86400',
        });
      }

      // Add CORS headers
      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      });
    };
  };
}

shelf.Middleware _errorMiddleware() {
  return (innerHandler) {
    return (request) async {
      try {
        return await innerHandler(request);
      } catch (e) {
        print('❌ [${request.method}] ${request.url}: $e');
        return shelf.Response.internalServerError(
          body: jsonEncode({
            'error': 'Internal server error',
            'message': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}

// === HANDLERS ===

/// Health check endpoint
shelf.Response _handleHealth(shelf.Request request) {
  return shelf.Response.ok(
    jsonEncode({
      'status': 'healthy',
      'service': 'FatSecret OAuth Proxy',
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
      'token': _tokenManager.getTokenInfo(),
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Token info endpoint (for debugging)
shelf.Response _handleTokenInfo(shelf.Request request) {
  return shelf.Response.ok(
    jsonEncode({
      'token_info': _tokenManager.getTokenInfo(),
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

/// Main proxy handler - forwards requests to FatSecret API
Future<shelf.Response> _handleFatSecretProxy(shelf.Request request) async {
  // Get the path (remove leading slash)
  final path = request.url.path;
  if (path.isEmpty || path == '/') {
    return shelf.Response.notFound(
      jsonEncode({'error': 'No endpoint specified'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    // Get valid access token
    final accessToken = await _tokenManager.getAccessToken();

    // Build FatSecret URL
    final fatsecretUrl = Uri.parse('$fatsecretBaseUrl$path');

    // Add query parameters
    final queryParams = Map<String, String>.from(request.url.queryParameters);
    queryParams['access_token'] = accessToken;

    final urlWithParams = fatsecretUrl.replace(queryParameters: queryParams);

    print('[Proxy] ${request.method} $path');

    // Forward request based on method
    late http.Response response;

    switch (request.method.toUpperCase()) {
      case 'GET':
        response = await http.get(urlWithParams).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Request timeout'),
        );
        break;

      case 'POST':
        final bodyStr = await request.readAsString();
        response = await http.post(
          urlWithParams,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: bodyStr,
        ).timeout(const Duration(seconds: 15));
        break;

      case 'PUT':
        final bodyStr = await request.readAsString();
        response = await http.put(
          urlWithParams,
          body: bodyStr,
        ).timeout(const Duration(seconds: 15));
        break;

      case 'DELETE':
        response = await http.delete(urlWithParams).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception('Request timeout'),
        );
        break;

      default:
        return shelf.Response.methodNotAllowed(
          ['GET', 'POST', 'PUT', 'DELETE'],
          jsonEncode({'error': 'Method ${request.method} not allowed'}),
        );
    }

    // Check response status
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('[Proxy] ✅ ${response.statusCode} $path');
    } else if (response.statusCode == 401) {
      print('[Proxy] ⚠️  401 Unauthorized - Token might be invalid');
      // Force token refresh on next request
      _tokenManager = TokenManager();
    } else {
      print('[Proxy] ⚠️  ${response.statusCode} $path');
    }

    // Return response
    return shelf.Response(
      response.statusCode,
      body: response.body,
      headers: {
        'Content-Type': response.headers['content-type'] ?? 'application/json',
      },
    );
  } catch (e) {
    print('[Proxy] ❌ Error: $e');
    return shelf.Response.internalServerError(
      body: jsonEncode({
        'error': 'Proxy error',
        'message': e.toString(),
        'path': path,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
