import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_food_item.dart';

class CloudFoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'global_food_library';

  /// Adds or updates a food item in the global shared library.
  /// This allows all users to benefit from the community's contributions.
  Future<void> contributeToGlobalLibrary(UserFoodItem food) async {
    try {
      // Use a normalized ID to prevent duplicates (e.g., lowercase name + brand)
      final String normalizedId = _generateFoodId(food.name, food.brand ?? '');
      
      final docRef = _firestore.collection(_collectionName).doc(normalizedId);
      
      // We use set with merge: true so we don't overwrite if multiple people contribute 
      // but we could also check if it exists first.
      await docRef.set({
        'name': food.name,
        'brand': food.brand,
        'calories': food.calories,
        'protein': food.protein,
        'carbs': food.carbs,
        'fat': food.fat,
        'servingSize': food.servingSize,
        'servingUnit': food.servingUnit,
        'contributorId': food.userId,
        'updatedAt': FieldValue.serverTimestamp(),
        // Keep a search-friendly name
        'searchName': food.name.toLowerCase(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error contributing to global library: $e');
    }
  }

  /// Searches the global Firestore library for food items matching the query.
  Future<List<UserFoodItem>> searchGlobalLibrary(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final String searchQuery = query.toLowerCase();
      
      // Firestore doesn't have partial matches like SQL 'LIKE', but we can use >= and <=
      // for prefix matching. For full text search, people usually use Algolia, 
      // but this is a simple "starts with" approach.
      final snapshot = await _firestore.collection(_collectionName)
          .where('searchName', isGreaterThanOrEqualTo: searchQuery)
          .where('searchName', isLessThanOrEqualTo: searchQuery + '\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserFoodItem(
          id: doc.id, // Use the doc ID (normalized name_brand)
          userId: (data['contributorId'] ?? 0) as int,
          name: data['name'] ?? 'Unknown',
          brand: data['brand'] ?? '',
          calories: (data['calories'] ?? 0).toDouble(),
          protein: (data['protein'] ?? 0).toDouble(),
          carbs: (data['carbs'] ?? 0).toDouble(),
          fat: (data['fat'] ?? 0).toDouble(),
          servingSize: (data['servingSize'] ?? 100).toDouble(),
          servingUnit: data['servingUnit'] ?? 'g',
          lastUsed: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('Error searching global library: $e');
      return [];
    }
  }

  String _generateFoodId(String name, String brand) {
    final cleanName = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanBrand = brand.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${cleanName}_$cleanBrand';
  }
}
