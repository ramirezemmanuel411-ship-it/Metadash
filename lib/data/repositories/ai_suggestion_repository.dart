import 'package:metadash/data/datasources/fatsecret_remote_datasource.dart';
import 'package:metadash/data/models/food_model.dart';

class AiSuggestionRepository {
  final FatSecretRemoteDatasource _fatSecret;

  AiSuggestionRepository({FatSecretRemoteDatasource? fatSecret})
    : _fatSecret =
          fatSecret ??
          FatSecretRemoteDatasource(
            backendUrl:
                'https://fatsecret-proxy-production-d58c.up.railway.app',
          );

  Future<List<FoodModel>> searchRestaurantItems(String query) async {
    final data = await _fatSecret.searchFoods(query);
    return FatSecretRemoteDatasource.parseFoodsFromSearch(data);
  }
}
