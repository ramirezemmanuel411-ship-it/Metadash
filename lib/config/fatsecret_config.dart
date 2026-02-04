/// FatSecret API Configuration Service
/// Loads credentials from environment variables securely

class FatSecretConfig {
  static String get clientId {
    final id = const String.fromEnvironment('FATSECRET_CLIENT_ID');
    if (id.isEmpty) {
      throw Exception(
        'FATSECRET_CLIENT_ID not configured. '
        'Please add it to your .env file or pass via --dart-define=FATSECRET_CLIENT_ID=...',
      );
    }
    return id;
  }

  static String get clientSecret {
    final secret = const String.fromEnvironment('FATSECRET_CLIENT_SECRET');
    if (secret.isEmpty) {
      throw Exception(
        'FATSECRET_CLIENT_SECRET not configured. '
        'Please add it to your .env file or pass via --dart-define=FATSECRET_CLIENT_SECRET=...',
      );
    }
    return secret;
  }

  /// Base URL for FatSecret API
  static const String baseUrl = 'https://platform.fatsecret.com/rest/';

  /// API version
  static const String apiVersion = '0';

  /// Get authorization header for OAuth2
  static Map<String, String> getAuthHeaders() {
    return {
      'Authorization': 'OAuth oauth_consumer_key="${clientId}"',
      'Content-Type': 'application/x-www-form-urlencoded',
    };
  }

  /// Validate configuration
  static bool isConfigured() {
    try {
      clientId;
      clientSecret;
      return true;
    } catch (_) {
      return false;
    }
  }
}
