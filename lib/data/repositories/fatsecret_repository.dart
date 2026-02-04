/// FatSecret Repository
/// Provides high-level interface for food search and nutrition queries
import '../../data/models/food_model.dart';
import '../datasources/fatsecret_remote_datasource.dart';

class FatSecretRepository {
  final FatSecretRemoteDatasource remoteDatasource;

  FatSecretRepository({required this.remoteDatasource});

  /// Search for foods on FatSecret
  Future<List<FoodModel>> searchFoods(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final data = await remoteDatasource.searchFoods(query);
      return FatSecretRemoteDatasource.parseFoodsFromSearch(data);
    } catch (e) {
      print('FatSecretRepository error: $e');
      return [];
    }
  }

  /// Get detailed nutrition for a food
  Future<Map<String, dynamic>> getFoodNutrition(int foodId) async {
    return remoteDatasource.getFoodNutrition(foodId);
  }

  /// Get recipe details
  Future<Map<String, dynamic>> getRecipe(int recipeId) async {
    return remoteDatasource.getRecipe(recipeId);
  }
}
