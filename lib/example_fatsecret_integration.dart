/// FatSecret Integration Example
/// Shows how to use FatSecret in your app
///
/// To use this in your app:
/// 1. Deploy the backend proxy (see FATSECRET_BACKEND_SETUP.md)
/// 2. Get the backend URL (e.g., https://fatsecret-proxy.herokuapp.com)
/// 3. Initialize the repository
/// 4. Use in your search screen

import 'package:metadash/data/datasources/fatsecret_remote_datasource.dart';
import 'package:metadash/data/repositories/fatsecret_repository.dart';

// Example 1: Initialize FatSecret repository
void initializeFatSecret() {
  // Backend URL - replace with your actual server URL
  const backendUrl = 'https://fatsecret-proxy.herokuapp.com';

  final datasource = FatSecretRemoteDatasource(
    backendUrl: backendUrl,
  );

  final repository = FatSecretRepository(
    remoteDatasource: datasource,
  );

  print('✅ FatSecret initialized with backend: $backendUrl');
}

// Example 2: Search foods on FatSecret
Future<void> searchFatSecret() async {
  const backendUrl = 'https://fatsecret-proxy.herokuapp.com';
  final datasource = FatSecretRemoteDatasource(backendUrl: backendUrl);
  final repository = FatSecretRepository(remoteDatasource: datasource);

  try {
    final results = await repository.searchFoods('coke');
    print('Found ${results.length} results for "coke"');
    for (final food in results) {
      print('  - ${food.name}: ${food.calories} kcal');
    }
  } catch (e) {
    print('❌ Error searching: $e');
  }
}

// Example 3: Integrate into search bloc
/*
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:metadash/domain/search_state.dart';
import 'package:metadash/presentation/bloc/food_search_bloc.dart';

class FoodSearchBlocWithFatSecret extends Bloc<FoodSearchEvent, FoodSearchState> {
  final repository = FatSecretRepository(
    remoteDatasource: FatSecretRemoteDatasource(
      backendUrl: 'https://fatsecret-proxy.herokuapp.com',
    ),
  );

  Future<void> _handleSearch(SearchQuery event, Emitter emit) async {
    // 1. Show loading
    emit(SearchLoading(message: 'Searching...'));

    try {
      // 2. Search USDA/OFF (existing)
      final localResults = await searchRepository.search(event.query);
      emit(SearchLoading(
        message: 'Found ${localResults.length} local results...',
        partialResults: localResults,
      ));

      // 3. Search FatSecret
      final fatSecretResults = await repository.searchFoods(event.query);

      // 4. Combine and deduplicate
      final allResults = [...localResults, ...fatSecretResults];
      final deduped = deduplicateFoods(allResults);

      // 5. Emit success
      emit(SearchSuccess(results: deduped));
    } catch (e) {
      emit(SearchError(message: 'Search failed: $e'));
    }
  }
}
*/

// Example 4: Configuration constants
class FatSecretConfig {
  // Set this to your actual backend URL
  static const String backendUrl =
      String.fromEnvironment(
    'FATSECRET_BACKEND_URL',
    defaultValue: 'https://fatsecret-proxy.herokuapp.com',
  );

  // Endpoints
  static const String searchEndpoint = '/api/foods/search';
  static const String foodEndpoint = '/api/foods';
  static const String recipeEndpoint = '/api/recipes';
  static const String healthEndpoint = '/health';

  // Timeouts
  static const Duration searchTimeout = Duration(seconds: 15);
  static const Duration foodTimeout = Duration(seconds: 10);
}

// Example 5: Error handling
Future<void> handleFatSecretErrors() async {
  const backendUrl = 'https://fatsecret-proxy.herokuapp.com';
  final datasource = FatSecretRemoteDatasource(backendUrl: backendUrl);

  try {
    await datasource.searchFoods('coke');
  } on Exception catch (e) {
    if (e.toString().contains('Connection refused')) {
      print('❌ Backend server is not running');
      print('   Start the server with: dart run fatsecret_backend');
    } else if (e.toString().contains('Unauthorized')) {
      print('❌ FatSecret credentials are invalid');
      print('   Check FATSECRET_CLIENT_ID and FATSECRET_CLIENT_SECRET');
    } else if (e.toString().contains('IP restricted')) {
      print('❌ Your server IP is not whitelisted on FatSecret');
      print('   Add your IP to: https://platform.fatsecret.com/my-account/ip-restrictions');
    } else {
      print('❌ Error: $e');
    }
  }
}

// Example 6: Health check
Future<void> checkBackendHealth() async {
  const backendUrl = 'https://fatsecret-proxy.herokuapp.com';

  try {
    final datasource = FatSecretRemoteDatasource(backendUrl: backendUrl);
    // The datasource will make a request to verify connectivity
    await datasource.searchFoods('test');
    print('✅ Backend is healthy');
  } catch (e) {
    print('❌ Backend health check failed: $e');
    print('   Ensure backend server is running and accessible at: $backendUrl');
  }
}

// Example 7: Environment-based configuration
void initializeFromEnvironment() {
  // Get backend URL from environment
  const backendUrl = String.fromEnvironment(
    'FATSECRET_BACKEND_URL',
    defaultValue: 'http://localhost:8080', // Local development
  );

  // Or for production
  const prodBackendUrl = String.fromEnvironment(
    'FATSECRET_BACKEND_URL_PROD',
    defaultValue: 'https://fatsecret-proxy.herokuapp.com',
  );

  print('Using backend URL: $backendUrl');

  final datasource = FatSecretRemoteDatasource(backendUrl: backendUrl);
  final repository = FatSecretRepository(remoteDatasource: datasource);
}

// Example 8: Running locally for testing
/*
To test locally without deploying:

1. Start the backend server (in a separate terminal):
   cd fatsecret_backend/
   dart run --define=FATSECRET_CLIENT_ID=b9f7e7de97b340b7915c3ac9bab9bfe0 \
           --define=FATSECRET_CLIENT_SECRET=b788a80bfaaf4e569e811a381be3865f

2. In your Flutter app:
   const backendUrl = 'http://localhost:8080';

3. Run the app:
   flutter run --dart-define=FATSECRET_BACKEND_URL=http://localhost:8080

4. Test with:
   searchFatSecret();
*/

void main() {
  print('🔍 FatSecret Integration Examples');
  print('');
  print('1. Initialize FatSecret');
  print('   initializeFatSecret();');
  print('');
  print('2. Search foods');
  print('   await searchFatSecret();');
  print('');
  print('3. Check backend health');
  print('   await checkBackendHealth();');
  print('');
  print('4. Handle errors');
  print('   await handleFatSecretErrors();');
  print('');
  print('See FATSECRET_BACKEND_SETUP.md for deployment instructions');
}
